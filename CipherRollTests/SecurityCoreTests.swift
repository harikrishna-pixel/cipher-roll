import CryptoKit
import Foundation
import Security
import XCTest
@testable import CipherRoll

final class SecurityCoreTests: XCTestCase {
    private var root: URL!
    private var store: MemoryKeyStore!
    private var derivation: CountingDerivation!
    private var clock: ManualClock!
    private var originals: DeletingSpy!
    private var service: VaultService!

    override func setUp() {
        super.setUp()
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        store = MemoryKeyStore()
        derivation = CountingDerivation(inner: PBKDF2KeyDerivation())
        clock = ManualClock()
        originals = DeletingSpy()
        service = makeService(passcode: true, iterations: 1_000)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
        super.tearDown()
    }

    func testItemFileIsNotTheOriginalBytes() throws {
        let marker = Data("PLAINTEXT-MARKER-9f3a-not-on-disk".utf8)
        var plaintext = Data([0xFF, 0xD8, 0xFF, 0xE0])
        plaintext.append(marker)
        let created = try service.createVault(secret: .pin("135790"), role: .real)
        let session = try service.unlock(activeVault: created.id, secret: .pin("135790"))
        let item = try session.addItem(kind: .photo, displayName: "holiday-photo.jpg", bytes: plaintext)
        let fileURL = try session.fileURL(for: item)
        let stored = try Data(contentsOf: fileURL)
        XCTAssertNil(stored.range(of: marker))
        XCTAssertNotEqual(stored.prefix(4), Data([0xFF, 0xD8, 0xFF, 0xE0]))
        XCTAssertFalse(fileURL.lastPathComponent.contains("holiday"))
        let values = try fileURL.resourceValues(forKeys: [.isExcludedFromBackupKey])
        XCTAssertEqual(values.isExcludedFromBackup, true)
        XCTAssertThrowsError(
            try AESGCMBox.open(ItemFileFormat.combined(from: stored), using: SymmetricKey(size: .bits256), authenticating: item.bytes)
        )
        XCTAssertEqual(try session.readItem(item), plaintext)
        try session.deleteItem(item)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertThrowsError(try session.readItem(item))
    }

    func testEachItemHasItsOwnKey() throws {
        let created = try service.createVault(secret: .pin("135790"), role: .real)
        let session = try service.unlock(activeVault: created.id, secret: .pin("135790"))
        let first = try session.addItem(kind: .photo, displayName: "one", bytes: Data("first-item".utf8))
        let second = try session.addItem(kind: .file, displayName: "two", bytes: Data("second-item".utf8))
        let wraps = try session.wrappedKeyBlobs()
        XCTAssertEqual(wraps.count, 2)
        XCTAssertNotEqual(wraps[0], wraps[1])
        let firstURL = try session.fileURL(for: first)
        let secondURL = try session.fileURL(for: second)
        let firstBytes = try Data(contentsOf: firstURL)
        let secondBytes = try Data(contentsOf: secondURL)
        try firstBytes.write(to: secondURL)
        try secondBytes.write(to: firstURL)
        XCTAssertThrowsError(try session.readItem(first))
        XCTAssertThrowsError(try session.readItem(second))
    }

    func testKeychainClassIsPasscodeSetThisDeviceOnly() {
        let query = KeychainQuery.add(data: Data([1]), service: "app.cipherroll.vault", account: "item")
        let accessible = query[kSecAttrAccessible as String] as AnyObject
        XCTAssertTrue(CFEqual(accessible, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly))
        XCTAssertEqual(query[kSecAttrSynchronizable as String] as? Bool, false)
        XCTAssertNil(query[kSecAttrAccessGroup as String])
    }

    func testRefusesVaultWhenNoPasscode() {
        let empty = MemoryKeyStore()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let blocked = makeService(passcode: false, iterations: 1_000, store: empty, root: directory)
        XCTAssertThrowsError(try blocked.createVault(secret: .pin("135790"), role: .real)) { error in
            XCTAssertEqual(error as? VaultError, .noPasscode)
        }
        XCTAssertTrue(empty.snapshot.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("Vaults").path))
    }

    func testNoPlaintextFileAfterRead() throws {
        let marker = Data("PHOTO-BYTES-ONLY-IN-MEMORY-77".utf8)
        let created = try service.createVault(secret: .pin("135790"), role: .real)
        let session = try service.unlock(activeVault: created.id, secret: .pin("135790"))
        let item = try session.addItem(kind: .photo, displayName: "pic", bytes: marker)
        XCTAssertEqual(try session.readItem(item), marker)
        XCTAssertFalse(treeContains(marker, under: root))
    }

    func testVideoTempDeletedOnClose() throws {
        let marker = Data("VIDEO-TEMP-MARKER-18".utf8)
        let created = try service.createVault(secret: .pin("135790"), role: .real)
        let session = try service.unlock(activeVault: created.id, secret: .pin("135790"))
        let item = try session.addItem(kind: .video, displayName: "clip", bytes: marker)
        let playback = try session.prepareVideoPlayback(item)
        XCTAssertTrue(FileManager.default.fileExists(atPath: playback.path))
        XCTAssertNotNil(try Data(contentsOf: playback).range(of: marker))
        try session.endVideoPlayback(playback)
        XCTAssertFalse(FileManager.default.fileExists(atPath: playback.path))
    }

    func testVideoTempSweptOnLaunch() throws {
        let created = try service.createVault(secret: .pin("135790"), role: .real)
        let session = try service.unlock(activeVault: created.id, secret: .pin("135790"))
        let item = try session.addItem(kind: .video, displayName: "clip", bytes: Data("leftover-video".utf8))
        let playback = try session.prepareVideoPlayback(item)
        XCTAssertTrue(FileManager.default.fileExists(atPath: playback.path))
        try service.sweepInterruptedWork()
        XCTAssertFalse(FileManager.default.fileExists(atPath: playback.path))
    }

    func testImportKillLeavesOriginals() throws {
        let created = try service.createVault(secret: .pin("135790"), role: .real)
        let session = try service.unlock(activeVault: created.id, secret: .pin("135790"))
        let source = root.appendingPathComponent("original.bin")
        try Data("original-bytes".utf8).write(to: source)
        let staged = try service.stageImport(from: source)
        XCTAssertTrue(FileManager.default.fileExists(atPath: staged.tempURL.path))
        try service.sweepInterruptedWork()
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: staged.tempURL.path))
        XCTAssertTrue(try session.itemIDs().isEmpty)
        XCTAssertEqual(originals.calls, 0)
    }

    func testDeleteOriginalsOnlyAfterVerify() throws {
        let created = try service.createVault(secret: .pin("135790"), role: .real)
        let session = try service.unlock(activeVault: created.id, secret: .pin("135790"))
        let source = root.appendingPathComponent("source.bin")
        try Data("verified-source".utf8).write(to: source)
        let staged = try service.stageImport(from: source)
        var corrupted = try Data(contentsOf: staged.tempURL)
        corrupted[0] ^= 0x5A
        try corrupted.write(to: staged.tempURL)
        XCTAssertThrowsError(
            try service.commit(staged, session: session, kind: .file, displayName: "source.bin", deleteOriginal: true)
        ) { error in
            XCTAssertEqual(error as? VaultError, .verifyFailed)
        }
        XCTAssertEqual(originals.calls, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        XCTAssertTrue(try session.itemIDs().isEmpty)
    }

    func testDelaySurvivesNewStore() throws {
        let created = try service.createVault(secret: .pin("135790"), role: .real)
        for _ in 0..<5 {
            XCTAssertThrowsError(try service.unlock(activeVault: created.id, secret: .pin("000000"))) { error in
                XCTAssertEqual(error as? VaultError, .authenticationFailed)
            }
        }
        let restarted = makeService(passcode: true, iterations: 1_000)
        XCTAssertThrowsError(try restarted.unlock(activeVault: created.id, secret: .pin("135790"))) { error in
            XCTAssertEqual(error as? VaultError, .lockedOut)
        }
    }

    func testDecoyHasNoRecoveryWrap() throws {
        let real = try service.createVault(secret: .pin("135790"), role: .real)
        store.accesses.removeAll()
        let decoy = try service.createVault(secret: .pin("246801"), role: .decoy)
        let bundle = try service.bundle(id: decoy.id)
        XCTAssertEqual(bundle.role, .decoy)
        XCTAssertNil(bundle.recoveryWrap)
        XCTAssertNil(bundle.recoverySalt)
        XCTAssertFalse(bundle.lockWrap.isEmpty)
        XCTAssertNil(decoy.recoveryWords)
        let blob = try XCTUnwrap(service.sealedVaultBlob(id: decoy.id))
        XCTAssertNil(blob.range(of: Data("decoy".utf8)))
        XCTAssertFalse(service.vaultDirectory(id: decoy.id).path.lowercased().contains("decoy"))
        XCTAssertTrue(store.accesses.filter { $0.service == KeychainServiceName.recovery }.isEmpty)
        XCTAssertNotNil(real.recoveryWords)
    }

    func testUnlockPayloadIsIdentical() throws {
        let real = try service.createVault(secret: .pin("135790"), role: .real)
        _ = try service.createVault(secret: .pin("246801"), role: .decoy)
        let realSession = try service.unlock(activeVault: real.id, secret: .pin("135790"))
        let decoySession = try service.unlock(activeVault: real.id, secret: .pin("246801"))
        XCTAssertEqual(realSession.role, .real)
        XCTAssertEqual(decoySession.role, .decoy)
        XCTAssertEqual(realSession.analyticsPayload, decoySession.analyticsPayload)
        XCTAssertEqual(realSession.analyticsPayload.method, "secret")
    }

    func testBothWrapsAreTried() throws {
        let real = try service.createVault(secret: .pin("135790"), role: .real)
        derivation.calls = 0
        _ = try service.unlock(activeVault: real.id, secret: .pin("135790"))
        XCTAssertEqual(derivation.calls, 2)
        _ = try service.createVault(secret: .pin("246801"), role: .decoy)
        derivation.calls = 0
        _ = try service.unlock(activeVault: real.id, secret: .pin("135790"))
        XCTAssertEqual(derivation.calls, 2)
    }

    func testRecoveryRoundTrip() throws {
        let created = try service.createVault(secret: .pin("135790"), role: .real)
        let words = try XCTUnwrap(created.recoveryWords)
        XCTAssertEqual(words.count, 24)
        XCTAssertEqual(try RecoveryWords.encode(try RecoveryWords.entropy(from: words)), words)
        try service.testRecoveryWords(words)
        try service.confirmRecoveryWordsSaved()
        XCTAssertNil(try service.pendingRecoveryWords())
        let sentence = words.joined(separator: "\n").data(using: .utf8) ?? Data()
        XCTAssertFalse(store.snapshot.values.contains { $0.range(of: sentence) != nil })

        let decoy = try service.createVault(secret: .pin("246801"), role: .decoy)
        let decoySession = try service.unlock(activeVault: created.id, secret: .pin("246801"))
        let decoyItem = try decoySession.addItem(kind: .note, displayName: "note", bytes: Data("decoy-item".utf8))
        let realSession = try service.unlock(activeVault: created.id, secret: .pin("135790"))
        let realItem = try realSession.addItem(kind: .note, displayName: "note", bytes: Data("real-item".utf8))

        var tampered = words
        tampered[0] = words[0] == "abandon" ? "ability" : "abandon"
        XCTAssertThrowsError(try service.unlockWithRecovery(vault: created.id, words: tampered, newSecret: .pin("13579012")))

        _ = try service.unlockWithRecovery(vault: created.id, words: words, newSecret: .pin("13579012"))
        XCTAssertThrowsError(try service.unlock(activeVault: created.id, secret: .pin("135790")))
        let unlocked = try service.unlock(activeVault: created.id, secret: .pin("13579012"))
        XCTAssertEqual(try unlocked.readItem(realItem), Data("real-item".utf8))
        let decoyAgain = try service.unlock(activeVault: created.id, secret: .pin("246801"))
        XCTAssertEqual(decoyAgain.vaultID, decoy.id)
        XCTAssertEqual(try decoyAgain.readItem(decoyItem), Data("decoy-item".utf8))
        XCTAssertNil(try service.bundle(id: decoy.id).recoveryWrap)
    }

    func testRecoveryDoesNotOpenDecoy() throws {
        let real = try service.createVault(secret: .pin("135790"), role: .real)
        let words = try XCTUnwrap(real.recoveryWords)
        let decoy = try service.createVault(secret: .pin("246801"), role: .decoy)
        let session = try service.unlock(activeVault: real.id, secret: .pin("246801"))
        let item = try session.addItem(kind: .file, displayName: "kept", bytes: Data("still-here".utf8))
        XCTAssertThrowsError(
            try service.unlockWithRecovery(vault: decoy.id, words: words, newSecret: .pin("999999"))
        )
        let again = try service.unlock(activeVault: real.id, secret: .pin("246801"))
        XCTAssertEqual(try again.readItem(item), Data("still-here".utf8))
        XCTAssertNil(try service.bundle(id: decoy.id).recoveryWrap)
    }

    func testPINMinimumIsSixDigits() throws {
        XCTAssertThrowsError(try service.createVault(secret: .pin("1234"), role: .real)) { error in
            XCTAssertEqual(error as? VaultError, .secretTooShort)
        }
        XCTAssertThrowsError(try service.createVault(secret: .pin("12345"), role: .real)) { error in
            XCTAssertEqual(error as? VaultError, .secretTooShort)
        }
        XCTAssertThrowsError(try service.createVault(secret: .pin("12ab56"), role: .real)) { error in
            XCTAssertEqual(error as? VaultError, .secretInvalid)
        }
        XCTAssertThrowsError(try service.createVault(secret: .pattern([0, 1, 2, 3]), role: .real)) { error in
            XCTAssertEqual(error as? VaultError, .secretTooShort)
        }
        XCTAssertThrowsError(try service.createVault(secret: .password("short"), role: .real)) { error in
            XCTAssertEqual(error as? VaultError, .secretTooShort)
        }
        let created = try service.createVault(secret: .pin("123456"), role: .real)
        XCTAssertEqual(created.recoveryWords?.count, 24)
    }

    func testChangeLockSecretKeepsItemBytes() throws {
        let created = try service.createVault(secret: .pin("135790"), role: .real)
        let session = try service.unlock(activeVault: created.id, secret: .pin("135790"))
        let item = try session.addItem(kind: .note, displayName: "n", bytes: Data("kept".utf8))
        try service.changeSecret(session: session, to: .pin("13579012"))
        XCTAssertThrowsError(try service.unlock(activeVault: created.id, secret: .pin("135790")))
        let unlocked = try service.unlock(activeVault: created.id, secret: .pin("13579012"))
        XCTAssertEqual(try unlocked.readItem(item), Data("kept".utf8))
    }

    func testProductionIterationFloor() {
        XCTAssertGreaterThanOrEqual(KeyDerivation.productionFloor, 600_000)
        XCTAssertEqual(
            KeyDerivation.iterations(sampleCount: 1_000, elapsed: 1, floor: 600_000, target: 1),
            600_000
        )
        XCTAssertEqual(
            KeyDerivation.iterations(sampleCount: 1_000, elapsed: 1, floor: 100, target: 4),
            4_000
        )
    }

    private func makeService(passcode: Bool, iterations: Int, store customStore: MemoryKeyStore? = nil, root customRoot: URL? = nil) -> VaultService {
        VaultService(
            root: customRoot ?? root,
            keys: customStore ?? store,
            sealer: SoftwareBundleSealer(),
            passcode: StubPasscode(hasPasscode: passcode),
            derivation: derivation,
            iterations: iterations,
            clock: clock,
            originals: originals
        )
    }

    private func treeContains(_ marker: Data, under root: URL) -> Bool {
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            return false
        }
        for case let url as URL in enumerator {
            guard let data = try? Data(contentsOf: url) else { continue }
            if data.range(of: marker) != nil { return true }
        }
        return false
    }
}

private final class MemoryKeyStore: KeyStoring {
    private var values: [String: Data] = [:]
    var accesses: [(service: String, account: String)] = []

    var snapshot: [String: Data] { values }

    func set(_ data: Data, service: String, account: String) throws {
        accesses.append((service, account))
        values[key(service, account)] = data
    }

    func data(service: String, account: String) throws -> Data? {
        accesses.append((service, account))
        return values[key(service, account)]
    }

    func delete(service: String, account: String) throws {
        accesses.append((service, account))
        values.removeValue(forKey: key(service, account))
    }

    private func key(_ service: String, _ account: String) -> String {
        "\(service)\n\(account)"
    }
}

private struct StubPasscode: PasscodeChecking {
    var hasPasscode: Bool
    func deviceHasPasscode() -> Bool { hasPasscode }
}

private struct SoftwareBundleSealer: BundleSealing {
    private let key = SymmetricKey(size: .bits256)

    func seal(_ plaintext: Data) throws -> Data {
        try AESGCMBox.seal(plaintext, using: key, authenticating: Data("bundle-v1".utf8))
    }

    func open(_ sealed: Data) throws -> Data {
        try AESGCMBox.open(sealed, using: key, authenticating: Data("bundle-v1".utf8))
    }
}

private final class CountingDerivation: KeyDeriving {
    let inner: KeyDeriving
    var calls = 0

    init(inner: KeyDeriving) {
        self.inner = inner
    }

    func derive(secret: Data, salt: Data, iterations: Int) throws -> SymmetricKey {
        calls += 1
        return try inner.derive(secret: secret, salt: salt, iterations: iterations)
    }
}

private final class ManualClock: Clock {
    var date = Date(timeIntervalSince1970: 1_700_000_000)
    func now() -> Date { date }
}

private final class DeletingSpy: OriginalsDeleting {
    var calls = 0

    func deleteOriginal(at source: URL) throws {
        calls += 1
        try FileManager.default.removeItem(at: source)
    }
}
