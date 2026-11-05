import CryptoKit
import XCTest
@testable import CipherRoll

final class BackupRulesTests: XCTestCase {
    private var root: URL!
    private var service: VaultService!

    override func setUp() {
        super.setUp()
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        service = VaultService(
            root: root,
            keys: BackupKeyStore(),
            sealer: BackupSealer(),
            passcode: BackupPasscode(),
            derivation: PBKDF2KeyDerivation(),
            iterations: 1_000,
            clock: SystemClock(),
            originals: NoOriginalsDeleting()
        )
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
        super.tearDown()
    }

    func testRoundTripWrongPasswordAndTruncation() throws {
        let marker = Data("REAL-MARKER-BYTES".utf8)
        var body = Data(repeating: 0x5A, count: BackupFile.chunkBytes + 32)
        body.append(marker)
        let file = root.appendingPathComponent("vault.crbackup")
        let chunks = [body.prefix(BackupFile.chunkBytes), body.suffix(from: BackupFile.chunkBytes)]
        var index = 0
        let source = BackupFile.Source(kind: "photo", name: "holiday.jpg", nextChunk: {
            guard index < chunks.count else { return nil }
            let chunk = Data(chunks[index])
            index += 1
            return chunk
        })
        try BackupFile.write(
            title: "Personal",
            sources: [source],
            password: "backup-pass-1",
            derivation: PBKDF2KeyDerivation(),
            iterations: 1_000,
            to: file,
            workRoot: root.appendingPathComponent("work", isDirectory: true)
        )
        XCTAssertEqual(try BackupFile.storedIterations(at: file), 1_000)
        XCTAssertGreaterThanOrEqual(try BackupFile.frameCount(at: file), 3)
        XCTAssertEqual(BackupFile.productionFloor, 600_000)
        XCTAssertEqual(KeyDerivation.productionFloor, 600_000)
        let raw = try Data(contentsOf: file)
        XCTAssertNil(raw.range(of: marker))
        let opened = try BackupFile.read(
            file,
            password: "backup-pass-1",
            derivation: PBKDF2KeyDerivation(),
            into: root.appendingPathComponent("out", isDirectory: true)
        )
        XCTAssertEqual(opened.title, "Personal")
        XCTAssertEqual(try Data(contentsOf: opened.items[0].file), body)
        for wrong in ["backup-pass-2", "not-the-password"] {
            XCTAssertThrowsError(try BackupFile.read(file, password: wrong, derivation: PBKDF2KeyDerivation(), into: root.appendingPathComponent(wrong, isDirectory: true))) { error in
                XCTAssertEqual(error as? BackupFile.Failure, .wrongPassword)
                XCTAssertFalse(String(describing: error).lowercased().contains("salt"))
            }
        }
        var truncated = raw
        truncated.removeLast(20)
        let broken = root.appendingPathComponent("broken.crbackup")
        try truncated.write(to: broken)
        XCTAssertThrowsError(try BackupFile.read(broken, password: "backup-pass-1", derivation: PBKDF2KeyDerivation(), into: root.appendingPathComponent("bad", isDirectory: true))) { error in
            XCTAssertEqual(error as? BackupFile.Failure, .badFile)
        }
    }

    func testStoppedExportIsNotAValidFileAndSweepRemovesIt() throws {
        let destination = root.appendingPathComponent("done.crbackup")
        let work = root.appendingPathComponent(InterruptedWorkSweeper.backupWork, isDirectory: true)
        let source = BackupFile.Source(kind: "note", name: "Note", nextChunk: { nil })
        XCTAssertThrowsError(try BackupFile.write(
            title: "Personal",
            sources: [source],
            password: "backup-pass-1",
            derivation: PBKDF2KeyDerivation(),
            iterations: 1_000,
            to: destination,
            workRoot: work,
            stopAfterHeader: true
        )) { error in
            XCTAssertEqual(error as? BackupFile.Stop, .beforeMove)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        let partial = work.appendingPathComponent("export.partial")
        XCTAssertTrue(FileManager.default.fileExists(atPath: partial.path))
        XCTAssertThrowsError(try BackupFile.read(partial, password: "backup-pass-1", derivation: PBKDF2KeyDerivation(), into: work.appendingPathComponent("read"))) { error in
            XCTAssertEqual(error as? BackupFile.Failure, .badFile)
        }
        try InterruptedWorkSweeper.sweep(root: root)
        XCTAssertFalse(FileManager.default.fileExists(atPath: partial.path))
    }

    func testCopyPasswordAndNames() {
        XCTAssertFalse(BackupRules.canCreate(password: "short-one", repeated: "short-one"))
        XCTAssertFalse(BackupRules.canCreate(password: "backup-pass-1", repeated: "backup-pass-2"))
        XCTAssertTrue(BackupRules.canCreate(password: "backup-pass-1", repeated: "backup-pass-1"))
        XCTAssertEqual(BackupFile.restoredName(existingRealVaults: 1), "Personal (restored)")
        XCTAssertEqual(BackupFile.restoredName(existingRealVaults: 2), "Personal (restored) 2")
        let name = BackupRules.fileName(on: Date(timeIntervalSince1970: 1_762_214_400))
        XCTAssertTrue(name.hasSuffix(".crbackup"))
        XCTAssertTrue(name.hasPrefix("CipherRoll_Backup_"))
        let properties = BackupRules.properties(count: 52, destination: "files", reason: "wrong_password")
        XCTAssertFalse(AnalyticsPrivacy.namesContent(properties))
        XCTAssertNil(properties["password"])
        XCTAssertNil(properties["filename"])
        XCTAssertNil(properties["vault_name"])
        let text = BackupRules.scanned.lowercased()
        XCTAssertFalse(text.contains("encrypted"))
        XCTAssertFalse(text.contains("decoy"))
        XCTAssertTrue(text.contains("protected by the password you choose") || text.contains("password you chose"))
        XCTAssertEqual(BackupRules.reason(for: BackupFile.Failure.wrongPassword), "wrong_password")
        XCTAssertEqual(BackupRules.reason(for: BackupFile.Failure.badFile), "bad_file")
        XCTAssertEqual(BackupRules.message(for: BackupFile.Failure.wrongPassword), BackupRules.wrongPassword)
    }

    func testVaultRoundTripLeavesTheOriginalAndSkipsTheDecoy() throws {
        let realMarker = Data("REAL-MARKER-BYTES".utf8)
        let decoyMarker = Data("DECOY-MARKER-BYTES".utf8)
        let created = try service.createVault(secret: .pin("135790"), role: .real)
        let real = try service.unlock(activeVault: created.id, secret: .pin("135790"))
        let realID = try real.addItem(kind: .note, displayName: "Note", bytes: realMarker)
        _ = try service.createVault(secret: .pin("246801"), role: .decoy)
        let decoy = try service.unlock(activeVault: created.id, secret: .pin("246801"))
        _ = try decoy.addItem(kind: .note, displayName: "Other", bytes: decoyMarker)
        let refused = root.appendingPathComponent("refused.crbackup")
        XCTAssertThrowsError(try decoy.exportBackup(password: "backup-pass-1", to: refused)) { error in
            XCTAssertEqual(error as? BackupFile.Failure, .unavailable)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: refused.path))
        let backup = root.appendingPathComponent("personal.crbackup")
        XCTAssertEqual(try real.exportBackup(password: "backup-pass-1", to: backup), 1)
        let raw = try Data(contentsOf: backup)
        XCTAssertNil(raw.range(of: decoyMarker))
        XCTAssertNil(raw.range(of: realMarker))
        let before = try service.indexedVaults().count
        XCTAssertThrowsError(try real.restoreBackup(from: backup, password: "wrong-password-1", secret: .pin("135791"))) { error in
            XCTAssertEqual(error as? BackupFile.Failure, .wrongPassword)
        }
        XCTAssertEqual(try service.indexedVaults().count, before)
        let restored = try real.restoreBackup(from: backup, password: "backup-pass-1", secret: .pin("135791"))
        XCTAssertEqual(restored.name, "Personal (restored)")
        XCTAssertEqual(restored.itemCount, 1)
        let restoredID = try XCTUnwrap(service.indexedVaults().first { $0.role == .real && $0.id != created.id }?.id)
        let opened = try service.unlock(activeVault: restoredID, secret: .pin("135791"))
        XCTAssertEqual(try opened.libraryItems().map(\.displayName), ["Note"])
        XCTAssertEqual(try opened.readItem(opened.libraryItems()[0].id), realMarker)
        XCTAssertTrue(try real.isPrimaryRealVault())
        XCTAssertFalse(try opened.isPrimaryRealVault())
        XCTAssertEqual(try real.readItem(realID), realMarker)
        let decoyItems = try decoy.libraryItems()
        XCTAssertEqual(try decoy.readItem(decoyItems[0].id), decoyMarker)
    }

    func testInterruptedRestoreDoesNotChangeTheExistingVault() throws {
        let marker = Data("KEEP-MARKER".utf8)
        let created = try service.createVault(secret: .pin("135790"), role: .real)
        let session = try service.unlock(activeVault: created.id, secret: .pin("135790"))
        let item = try session.addItem(kind: .note, displayName: "Keep", bytes: marker)
        let backup = root.appendingPathComponent("keep.crbackup")
        _ = try session.exportBackup(password: "backup-pass-1", to: backup)
        XCTAssertThrowsError(try session.restoreBackup(from: backup, password: "backup-pass-1", secret: .pin("135791"), halt: .beforePublish))
        XCTAssertEqual(try service.indexedVaults().count, 1)
        XCTAssertThrowsError(try session.restoreBackup(from: backup, password: "backup-pass-1", secret: .pin("135791"), halt: .afterCreate))
        XCTAssertEqual(try service.indexedVaults().count, 2)
        try service.sweepInterruptedWork()
        XCTAssertEqual(try service.indexedVaults().count, 1)
        XCTAssertEqual(try session.readItem(item), marker)
        let work = root.appendingPathComponent(InterruptedWorkSweeper.backupWork)
        if FileManager.default.fileExists(atPath: work.path) {
            let left = try FileManager.default.contentsOfDirectory(at: work, includingPropertiesForKeys: nil)
            XCTAssertTrue(left.isEmpty)
        }
        let restored = try session.restoreBackup(from: backup, password: "backup-pass-1", secret: .pin("135791"))
        XCTAssertEqual(restored.itemCount, 1)
        let opened = try service.unlock(activeVault: created.id, secret: .pin("135791"))
        XCTAssertNotEqual(opened.vaultID, created.id)
        XCTAssertEqual(try opened.readItem(opened.libraryItems()[0].id), marker)
        XCTAssertEqual(try session.readItem(item), marker)
    }
}

private final class BackupKeyStore: KeyStoring {
    private var values: [String: Data] = [:]
    func set(_ data: Data, service: String, account: String) throws { values["\(service)\n\(account)"] = data }
    func data(service: String, account: String) throws -> Data? { values["\(service)\n\(account)"] }
    func delete(service: String, account: String) throws { values.removeValue(forKey: "\(service)\n\(account)") }
}

private struct BackupPasscode: PasscodeChecking {
    func deviceHasPasscode() -> Bool { true }
}

private struct BackupSealer: BundleSealing {
    private let key = SymmetricKey(size: .bits256)
    func seal(_ plaintext: Data) throws -> Data {
        try AESGCMBox.seal(plaintext, using: key, authenticating: Data("bundle-v1".utf8))
    }
    func open(_ sealed: Data) throws -> Data {
        try AESGCMBox.open(sealed, using: key, authenticating: Data("bundle-v1".utf8))
    }
}
