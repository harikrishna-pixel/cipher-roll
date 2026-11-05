import CryptoKit
import Foundation

final class VaultService {
    let root: URL
    private let keys: KeyStoring
    private let sealer: BundleSealing
    private let passcode: PasscodeChecking
    private let derivation: KeyDeriving
    private let iterations: Int
    private let counter: AttemptCounter
    private let originals: OriginalsDeleting

    init(
        root: URL,
        keys: KeyStoring,
        sealer: BundleSealing,
        passcode: PasscodeChecking,
        derivation: KeyDeriving,
        iterations: Int,
        clock: Clock,
        originals: OriginalsDeleting
    ) {
        self.root = root
        self.keys = keys
        self.sealer = sealer
        self.passcode = passcode
        self.derivation = derivation
        self.iterations = iterations
        self.counter = AttemptCounter(keys: keys, clock: clock)
        self.originals = originals
    }

    func createVault(secret: LockSecret, role: VaultRole) throws -> CreatedVault {
        guard passcode.deviceHasPasscode() else { throw VaultError.noPasscode }
        let material = try secret.material()
        var index = try loadIndex()
        if role == .decoy && index.vaults.contains(where: { $0.role == .decoy }) {
            throw VaultError.secretInvalid
        }
        if try secretOpensExistingVault(material, index: index) {
            throw VaultError.secretInvalid
        }
        try ensurePadding()

        let id = UUID()
        var vmk = try RandomBytes.generate(count: 32)
        defer { vmk.wipeSensitive() }
        let salt = try RandomBytes.generate(count: 16)
        let lockKey = try derivation.derive(secret: material, salt: salt, iterations: iterations)
        let lockWrap = try AESGCMBox.seal(vmk, using: lockKey, authenticating: id.bytes)

        var recoverySalt: Data?
        var recoveryWrap: Data?
        var words: [String]?
        if role == .real {
            let created = try recoveryKEKForNewRealVault()
            words = created.words
            var kek = created.kek
            defer { kek.wipeSensitive() }
            recoverySalt = created.salt
            recoveryWrap = try AESGCMBox.seal(vmk, using: SymmetricKey(data: kek), authenticating: id.bytes)
        }

        let bundle = KeyBundle(
            version: 1,
            kdf: "pbkdf2-sha256",
            iterations: iterations,
            lockSalt: salt,
            lockWrap: lockWrap,
            recoverySalt: recoverySalt,
            recoveryWrap: recoveryWrap,
            role: role,
            manifestFileName: UUID().uuidString
        )
        try saveBundle(bundle, id: id)
        index.vaults.append(VaultIndex.Entry(id: id, role: role))
        try saveIndex(index)
        try saveManifest(VaultManifest(items: []), vault: id, fileName: bundle.manifestFileName, vmk: vmk)
        return CreatedVault(id: id, role: role, recoveryWords: words)
    }

    func pendingRecoveryWords() throws -> [String]? {
        guard let data = try keys.data(service: KeychainServiceName.recovery, account: KeychainAccount.pendingWords),
              let text = String(data: data, encoding: .utf8),
              !text.isEmpty else {
            return nil
        }
        return text.split(separator: "\n").map(String.init)
    }

    func testRecoveryWords(_ words: [String]) throws {
        let index = try loadIndex()
        guard let real = index.vaults.first(where: { $0.role == .real }) else {
            throw VaultError.recoveryNotAvailable
        }
        _ = try recoveryVMK(vault: real.id, words: words)
        try keys.set(Data([1]), service: KeychainServiceName.recovery, account: KeychainAccount.recoveryTested)
    }

    func confirmRecoveryWordsSaved() throws {
        guard try keys.data(service: KeychainServiceName.recovery, account: KeychainAccount.recoveryTested) != nil else {
            throw VaultError.recoveryNotTested
        }
        try keys.delete(service: KeychainServiceName.recovery, account: KeychainAccount.pendingWords)
        try keys.delete(service: KeychainServiceName.recovery, account: KeychainAccount.recoveryTested)
    }

    func recoveryWordsWereTested() throws -> Bool {
        try keys.data(service: KeychainServiceName.recovery, account: KeychainAccount.recoveryTested) != nil
    }

    func indexedVaults() throws -> [(id: UUID, role: VaultRole)] {
        try loadIndex().vaults.map { ($0.id, $0.role) }
    }

    /// The first real vault. Callers use this to show the lock. It does not report whether a decoy exists.
    func realVaultID() throws -> UUID? {
        try loadIndex().vaults.first { $0.role == .real }?.id
    }

    /// Face ID stays manual when a second vault exists. The result is not logged.
    func allowsAutomaticBiometry() -> Bool {
        ((try? loadIndex().vaults.count) ?? 0) < 2
    }

    func unlock(activeVault: UUID, secret: LockSecret) throws -> UnlockedSession {
        try counter.beginAttempt()
        let material = try secret.material()
        let active = try loadBundle(activeVault)
        let other = try secondTarget(activeVault: activeVault)
        let firstKey = try derivation.derive(secret: material, salt: active.lockSalt, iterations: active.iterations)
        let secondKey = try derivation.derive(secret: material, salt: other.salt, iterations: other.iterations)
        let openedActive = AESGCMBox.openIfValid(active.lockWrap, using: firstKey, authenticating: activeVault.bytes)
        let openedOther = AESGCMBox.openIfValid(other.wrap, using: secondKey, authenticating: other.aad)
        if let vmk = openedActive {
            try counter.recordSuccess()
            return UnlockedSession(service: self, vaultID: activeVault, role: active.role, vmk: vmk)
        }
        if let vmk = openedOther, let otherID = other.vaultID {
            let bundle = try loadBundle(otherID)
            try counter.recordSuccess()
            return UnlockedSession(service: self, vaultID: otherID, role: bundle.role, vmk: vmk)
        }
        try counter.recordFailure()
        throw VaultError.authenticationFailed
    }

    func unlockWithRecovery(vault: UUID, words: [String], newSecret: LockSecret) throws -> UnlockedSession {
        try counter.beginAttempt()
        let bundle = try loadBundle(vault)
        guard bundle.role == .real, bundle.recoveryWrap != nil else {
            _ = try? derivation.derive(
                secret: Data(words.joined(separator: " ").utf8),
                salt: Data(repeating: 1, count: 16),
                iterations: iterations
            )
            try counter.recordFailure()
            throw VaultError.authenticationFailed
        }
        let vmk: Data
        do {
            vmk = try recoveryVMK(vault: vault, words: words)
        } catch {
            try counter.recordFailure()
            throw VaultError.authenticationFailed
        }
        let session = UnlockedSession(service: self, vaultID: vault, role: .real, vmk: vmk)
        try changeSecret(session: session, to: newSecret)
        try counter.recordSuccess()
        return session
    }

    func changeSecret(session: UnlockedSession, to newSecret: LockSecret) throws {
        let material = try newSecret.material()
        var bundle = try loadBundle(session.vaultID)
        let salt = try RandomBytes.generate(count: 16)
        let key = try derivation.derive(secret: material, salt: salt, iterations: iterations)
        let vmk = try session.vmkData()
        bundle.lockSalt = salt
        bundle.iterations = iterations
        bundle.lockWrap = try AESGCMBox.seal(vmk, using: key, authenticating: session.vaultID.bytes)
        try saveBundle(bundle, id: session.vaultID)
    }

    func stageImport(from source: URL) throws -> StagedImport {
        let data = try Data(contentsOf: source)
        let temp = directory(InterruptedWorkSweeper.imports).appendingPathComponent(UUID().uuidString)
        try ProtectedFile.write(data, to: temp)
        return StagedImport(sourceURL: source, tempURL: temp)
    }

    func commit(
        _ staged: StagedImport,
        session: UnlockedSession,
        kind: ItemKind,
        displayName: String,
        deleteOriginal: Bool
    ) throws -> UUID {
        let sourceData = try Data(contentsOf: staged.sourceURL)
        let tempData = try Data(contentsOf: staged.tempURL)
        guard SHA256.hash(data: sourceData) == SHA256.hash(data: tempData) else {
            try? FileManager.default.removeItem(at: staged.tempURL)
            throw VaultError.verifyFailed
        }
        let id = try session.addItem(kind: kind, displayName: displayName, bytes: tempData)
        try? FileManager.default.removeItem(at: staged.tempURL)
        if deleteOriginal {
            try originals.deleteOriginal(at: staged.sourceURL)
        }
        return id
    }

    func sweepInterruptedWork() throws {
        let vaultsDir = directory(InterruptedWorkSweeper.vaults)
        if let dirs = try? FileManager.default.contentsOfDirectory(at: vaultsDir, includingPropertiesForKeys: nil) {
            for dir in dirs {
                let flag = dir.appendingPathComponent("incomplete")
                guard FileManager.default.fileExists(atPath: flag.path),
                      let id = UUID(uuidString: dir.lastPathComponent) else { continue }
                try? discardVault(id)
            }
        }
        try InterruptedWorkSweeper.sweep(root: root)
    }

    /// Writes a backup of the real vault. A decoy session is refused and is not described.
    func exportBackup(session: UnlockedSession, password: String, to destination: URL, stopAfterHeader: Bool = false) throws -> Int {
        guard session.role == .real else { throw BackupFile.Failure.unavailable }
        let records = try manifest(session).items.filter { $0.deletedAt == nil }
        var cursors: [ItemPlaintextCursor] = []
        var sources: [BackupFile.Source] = []
        for record in records {
            let vmk = try session.vmkData()
            var itemKeyRaw = try AESGCMBox.open(record.wrappedItemKey, using: SymmetricKey(data: vmk), authenticating: record.id.bytes)
            defer { itemKeyRaw.wipeSensitive() }
            let cursor = ItemPlaintextCursor(
                url: itemFileURL(vault: session.vaultID, fileName: record.fileName),
                keyData: itemKeyRaw,
                aad: record.id.bytes,
                expected: record.sha256
            )
            cursors.append(cursor)
            sources.append(BackupFile.Source(kind: record.kind.rawValue, name: record.displayName, nextChunk: { try cursor.next() }))
        }
        _ = cursors.count
        try BackupFile.write(
            title: "Personal",
            sources: sources,
            password: password,
            derivation: derivation,
            iterations: iterations,
            to: destination,
            workRoot: directory(InterruptedWorkSweeper.backupWork),
            stopAfterHeader: stopAfterHeader
        )
        return sources.count
    }

    /// Adds items as a new vault. Existing vaults are not changed. The new vault is published only after every item is written.
    func restoreBackup(from file: URL, password: String, secret: LockSecret, halt: BackupRestoreHalt = .none) throws -> RestoredVault {
        let work = directory(InterruptedWorkSweeper.backupWork).appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: work) }
        let opened = try BackupFile.read(file, password: password, derivation: derivation, into: work)
        if halt == .beforePublish { throw BackupFile.Stop.beforeMove }
        let existing = try loadIndex().vaults.filter { $0.role == .real }.count
        let name = BackupFile.restoredName(existingRealVaults: existing)
        let created = try createVault(secret: secret, role: .real)
        let flag = vaultDirectory(id: created.id).appendingPathComponent("incomplete")
        try Data([1]).write(to: flag, options: [.atomic, .completeFileProtection])
        if halt == .afterCreate { throw BackupFile.Stop.beforeMove }
        do {
            let session = try unlock(activeVault: created.id, secret: secret)
            for item in opened.items {
                let kind = ItemKind(rawValue: item.kind) ?? .file
                _ = try addItem(session: session, from: item.file, kind: kind, displayName: item.name)
            }
            try? FileManager.default.removeItem(at: flag)
        } catch {
            try? discardVault(created.id)
            throw error
        }
        return RestoredVault(itemCount: opened.items.count, name: name)
    }

    private func discardVault(_ id: UUID) throws {
        var index = try loadIndex()
        index.vaults.removeAll { $0.id == id }
        try saveIndex(index)
        try keys.delete(service: KeychainServiceName.vault, account: id.uuidString)
        let dir = vaultDirectory(id: id)
        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.removeItem(at: dir)
        }
    }

    func sealedVaultBlob(id: UUID) throws -> Data? {
        try keys.data(service: KeychainServiceName.vault, account: id.uuidString)
    }

    func bundle(id: UUID) throws -> KeyBundle {
        try loadBundle(id)
    }

    func vaultDirectory(id: UUID) -> URL {
        directory(InterruptedWorkSweeper.vaults).appendingPathComponent(id.uuidString, isDirectory: true)
    }

    fileprivate func addItem(session: UnlockedSession, kind: ItemKind, displayName: String, bytes: Data) throws -> UUID {
        let vmk = try session.vmkData()
        let bundle = try loadBundle(session.vaultID)
        var manifest = try readManifest(vault: session.vaultID, fileName: bundle.manifestFileName, vmk: vmk)
        let itemID = UUID()
        let itemKey = SymmetricKey(size: .bits256)
        var itemKeyRaw = itemKey.rawRepresentation
        defer { itemKeyRaw.wipeSensitive() }
        let wrappedKey = try AESGCMBox.seal(itemKeyRaw, using: SymmetricKey(data: vmk), authenticating: itemID.bytes)
        let sealedBody = try AESGCMBox.seal(bytes, using: itemKey, authenticating: itemID.bytes)
        let fileName = UUID().uuidString
        try ProtectedFile.write(ItemFileFormat.encode(combined: sealedBody), to: itemFileURL(vault: session.vaultID, fileName: fileName))
        manifest.items.append(
            ItemRecord(
                id: itemID,
                kind: kind,
                fileName: fileName,
                wrappedItemKey: wrappedKey,
                displayName: displayName,
                sha256: Data(SHA256.hash(data: bytes)),
                byteCount: bytes.count,
                createdAt: Date()
            )
        )
        try saveManifest(manifest, vault: session.vaultID, fileName: bundle.manifestFileName, vmk: vmk)
        return itemID
    }

    /// Reads the source in chunks. Does not delete the source file.
    fileprivate func addItem(session: UnlockedSession, from source: URL, kind: ItemKind, displayName: String) throws -> UUID {
        let vmk = try session.vmkData()
        let bundle = try loadBundle(session.vaultID)
        var manifest = try readManifest(vault: session.vaultID, fileName: bundle.manifestFileName, vmk: vmk)
        let itemID = UUID()
        let itemKey = SymmetricKey(size: .bits256)
        var itemKeyRaw = itemKey.rawRepresentation
        defer { itemKeyRaw.wipeSensitive() }
        let wrappedKey = try AESGCMBox.seal(itemKeyRaw, using: SymmetricKey(data: vmk), authenticating: itemID.bytes)
        let fileName = UUID().uuidString
        let written = try ChunkedItemFile.write(
            from: source,
            to: itemFileURL(vault: session.vaultID, fileName: fileName),
            key: itemKey,
            authenticating: itemID.bytes
        )
        manifest.items.append(
            ItemRecord(
                id: itemID,
                kind: kind,
                fileName: fileName,
                wrappedItemKey: wrappedKey,
                displayName: displayName,
                sha256: written.sha256,
                byteCount: written.byteCount,
                createdAt: Date()
            )
        )
        try saveManifest(manifest, vault: session.vaultID, fileName: bundle.manifestFileName, vmk: vmk)
        return itemID
    }

    fileprivate func readItem(session: UnlockedSession, id: UUID) throws -> Data {
        let record = try itemRecord(session: session, id: id)
        let vmk = try session.vmkData()
        var itemKeyRaw = try AESGCMBox.open(record.wrappedItemKey, using: SymmetricKey(data: vmk), authenticating: id.bytes)
        defer { itemKeyRaw.wipeSensitive() }
        let file = try Data(contentsOf: itemFileURL(vault: session.vaultID, fileName: record.fileName))
        let plain: Data
        if file.starts(with: ChunkedItemFile.magic) {
            plain = try ChunkedItemFile.open(file, using: SymmetricKey(data: itemKeyRaw), authenticating: id.bytes)
        } else {
            let combined = try ItemFileFormat.combined(from: file)
            plain = try AESGCMBox.open(combined, using: SymmetricKey(data: itemKeyRaw), authenticating: id.bytes)
        }
        guard Data(SHA256.hash(data: plain)) == record.sha256 else { throw VaultError.verifyFailed }
        return plain
    }

    fileprivate func deleteItem(session: UnlockedSession, id: UUID) throws {
        try removeItem(session: session, id: id, deleteFile: true)
    }

    fileprivate func libraryItems(session: UnlockedSession) throws -> [LibraryItem] {
        try manifest(session).items.map { record in
            LibraryItem(
                id: record.id,
                kind: record.kind,
                displayName: record.displayName,
                byteCount: record.byteCount ?? 0,
                album: record.album,
                deletedAt: record.deletedAt,
                createdAt: record.createdAt
            )
        }
    }

    fileprivate func softDelete(session: UnlockedSession, id: UUID, at date: Date) throws {
        try updateRecord(session: session, id: id) { $0.deletedAt = date }
    }

    fileprivate func restoreItem(session: UnlockedSession, id: UUID) throws {
        try updateRecord(session: session, id: id) { $0.deletedAt = nil }
    }

    fileprivate func moveItem(session: UnlockedSession, id: UUID, album: String?) throws {
        try updateRecord(session: session, id: id) { $0.album = album }
    }

    fileprivate func replaceItem(session: UnlockedSession, id: UUID, displayName: String, bytes: Data) throws {
        let vmk = try session.vmkData()
        let bundle = try loadBundle(session.vaultID)
        var manifest = try readManifest(vault: session.vaultID, fileName: bundle.manifestFileName, vmk: vmk)
        guard let index = manifest.items.firstIndex(where: { $0.id == id }) else { throw VaultError.fileMissing }
        let previous = manifest.items[index]
        let itemKey = SymmetricKey(size: .bits256)
        var itemKeyRaw = itemKey.rawRepresentation
        defer { itemKeyRaw.wipeSensitive() }
        let wrappedKey = try AESGCMBox.seal(itemKeyRaw, using: SymmetricKey(data: vmk), authenticating: id.bytes)
        let sealedBody = try AESGCMBox.seal(bytes, using: itemKey, authenticating: id.bytes)
        let fileName = UUID().uuidString
        try ProtectedFile.write(ItemFileFormat.encode(combined: sealedBody), to: itemFileURL(vault: session.vaultID, fileName: fileName))
        manifest.items[index].fileName = fileName
        manifest.items[index].wrappedItemKey = wrappedKey
        manifest.items[index].displayName = displayName
        manifest.items[index].sha256 = Data(SHA256.hash(data: bytes))
        manifest.items[index].byteCount = bytes.count
        try saveManifest(manifest, vault: session.vaultID, fileName: bundle.manifestFileName, vmk: vmk)
        let oldURL = itemFileURL(vault: session.vaultID, fileName: previous.fileName)
        if FileManager.default.fileExists(atPath: oldURL.path) {
            try FileManager.default.removeItem(at: oldURL)
        }
    }

    fileprivate func purgeExpired(session: UnlockedSession, now: Date, after days: Int) throws -> Int {
        let cutoff = now.addingTimeInterval(-Double(days) * 24 * 60 * 60)
        let expired = try libraryItems(session: session).filter { item in
            guard let deleted = item.deletedAt else { return false }
            return deleted <= cutoff
        }
        for item in expired {
            try removeItem(session: session, id: item.id, deleteFile: true)
        }
        return expired.count
    }

    private func manifest(_ session: UnlockedSession) throws -> VaultManifest {
        let vmk = try session.vmkData()
        let bundle = try loadBundle(session.vaultID)
        return try readManifest(vault: session.vaultID, fileName: bundle.manifestFileName, vmk: vmk)
    }

    private func updateRecord(session: UnlockedSession, id: UUID, change: (inout ItemRecord) -> Void) throws {
        let vmk = try session.vmkData()
        let bundle = try loadBundle(session.vaultID)
        var manifest = try readManifest(vault: session.vaultID, fileName: bundle.manifestFileName, vmk: vmk)
        guard let index = manifest.items.firstIndex(where: { $0.id == id }) else { throw VaultError.fileMissing }
        change(&manifest.items[index])
        try saveManifest(manifest, vault: session.vaultID, fileName: bundle.manifestFileName, vmk: vmk)
    }

    private func removeItem(session: UnlockedSession, id: UUID, deleteFile: Bool) throws {
        let vmk = try session.vmkData()
        let bundle = try loadBundle(session.vaultID)
        var manifest = try readManifest(vault: session.vaultID, fileName: bundle.manifestFileName, vmk: vmk)
        guard let index = manifest.items.firstIndex(where: { $0.id == id }) else { throw VaultError.fileMissing }
        let fileName = manifest.items[index].fileName
        manifest.items.remove(at: index)
        try saveManifest(manifest, vault: session.vaultID, fileName: bundle.manifestFileName, vmk: vmk)
        guard deleteFile else { return }
        let url = itemFileURL(vault: session.vaultID, fileName: fileName)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    fileprivate func prepareVideoPlayback(session: UnlockedSession, id: UUID) throws -> URL {
        let record = try itemRecord(session: session, id: id)
        guard record.kind == .video else { throw VaultError.verifyFailed }
        let plain = try readItem(session: session, id: id)
        let url = directory(InterruptedWorkSweeper.playback).appendingPathComponent(UUID().uuidString)
        try ProtectedFile.write(plain, to: url)
        return url
    }

    fileprivate func endVideoPlayback(_ url: URL) throws {
        let playback = directory(InterruptedWorkSweeper.playback)
        guard url.deletingLastPathComponent().standardizedFileURL == playback.standardizedFileURL else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    fileprivate func itemIDs(session: UnlockedSession) throws -> [UUID] {
        let vmk = try session.vmkData()
        let bundle = try loadBundle(session.vaultID)
        return try readManifest(vault: session.vaultID, fileName: bundle.manifestFileName, vmk: vmk).items.map(\.id)
    }

    fileprivate func wrappedKeyBlobs(session: UnlockedSession) throws -> [Data] {
        let vmk = try session.vmkData()
        let bundle = try loadBundle(session.vaultID)
        return try readManifest(vault: session.vaultID, fileName: bundle.manifestFileName, vmk: vmk).items.map(\.wrappedItemKey)
    }

    fileprivate func fileURL(session: UnlockedSession, item: UUID) throws -> URL {
        let record = try itemRecord(session: session, id: item)
        return itemFileURL(vault: session.vaultID, fileName: record.fileName)
    }

    private func itemRecord(session: UnlockedSession, id: UUID) throws -> ItemRecord {
        let vmk = try session.vmkData()
        let bundle = try loadBundle(session.vaultID)
        let manifest = try readManifest(vault: session.vaultID, fileName: bundle.manifestFileName, vmk: vmk)
        guard let record = manifest.items.first(where: { $0.id == id }) else { throw VaultError.fileMissing }
        return record
    }

    private func recoveryKEKForNewRealVault() throws -> (kek: Data, salt: Data, words: [String]?) {
        if let existing = try keys.data(service: KeychainServiceName.recovery, account: KeychainAccount.recoveryKEK) {
            let plain = try sealer.open(existing)
            let material = try JSONDecoder().decode(RecoveryMaterial.self, from: plain)
            return (material.kek, material.salt, nil)
        }
        let generated = try RecoveryWords.generate()
        var entropy = generated.entropy
        defer { entropy.wipeSensitive() }
        let salt = try RandomBytes.generate(count: 16)
        let derived = try derivation.derive(secret: entropy, salt: salt, iterations: iterations)
        var kek = derived.rawRepresentation
        let material = RecoveryMaterial(salt: salt, iterations: iterations, kek: kek)
        let sealed = try sealer.seal(try JSONEncoder().encode(material))
        try keys.set(sealed, service: KeychainServiceName.recovery, account: KeychainAccount.recoveryKEK)
        let pending = generated.words.joined(separator: "\n").data(using: .utf8) ?? Data()
        try keys.set(pending, service: KeychainServiceName.recovery, account: KeychainAccount.pendingWords)
        return (kek, salt, generated.words)
    }

    private func recoveryVMK(vault: UUID, words: [String]) throws -> Data {
        let bundle = try loadBundle(vault)
        guard let wrap = bundle.recoveryWrap, let salt = bundle.recoverySalt else {
            throw VaultError.recoveryNotAvailable
        }
        var entropy = try RecoveryWords.entropy(from: words)
        defer { entropy.wipeSensitive() }
        let key = try derivation.derive(secret: entropy, salt: salt, iterations: bundle.iterations)
        guard let vmk = AESGCMBox.openIfValid(wrap, using: key, authenticating: vault.bytes) else {
            throw VaultError.authenticationFailed
        }
        return vmk
    }

    private func secretOpensExistingVault(_ material: Data, index: VaultIndex) throws -> Bool {
        for entry in index.vaults {
            let bundle = try loadBundle(entry.id)
            let key = try derivation.derive(secret: material, salt: bundle.lockSalt, iterations: bundle.iterations)
            if AESGCMBox.openIfValid(bundle.lockWrap, using: key, authenticating: entry.id.bytes) != nil {
                return true
            }
        }
        return false
    }

    private func ensurePadding() throws {
        if try keys.data(service: KeychainServiceName.vault, account: KeychainAccount.padding) != nil { return }
        let salt = try RandomBytes.generate(count: 16)
        let junkKey = SymmetricKey(size: .bits256)
        let junk = try RandomBytes.generate(count: 32)
        let wrap = try AESGCMBox.seal(junk, using: junkKey, authenticating: Data("padding-v1".utf8))
        let record = PaddingRecord(salt: salt, iterations: iterations, wrap: wrap)
        try keys.set(try JSONEncoder().encode(record), service: KeychainServiceName.vault, account: KeychainAccount.padding)
    }

    private struct SecondTarget {
        var salt: Data
        var iterations: Int
        var wrap: Data
        var aad: Data
        var vaultID: UUID?
    }

    private func secondTarget(activeVault: UUID) throws -> SecondTarget {
        let index = try loadIndex()
        if let decoy = index.vaults.first(where: { $0.role == .decoy && $0.id != activeVault }) {
            let bundle = try loadBundle(decoy.id)
            return SecondTarget(
                salt: bundle.lockSalt,
                iterations: bundle.iterations,
                wrap: bundle.lockWrap,
                aad: decoy.id.bytes,
                vaultID: decoy.id
            )
        }
        if let other = index.vaults.first(where: { $0.role == .real && $0.id != activeVault }) {
            let bundle = try loadBundle(other.id)
            return SecondTarget(
                salt: bundle.lockSalt,
                iterations: bundle.iterations,
                wrap: bundle.lockWrap,
                aad: other.id.bytes,
                vaultID: other.id
            )
        }
        guard let data = try keys.data(service: KeychainServiceName.vault, account: KeychainAccount.padding) else {
            throw VaultError.fileMissing
        }
        let padding = try JSONDecoder().decode(PaddingRecord.self, from: data)
        return SecondTarget(
            salt: padding.salt,
            iterations: padding.iterations,
            wrap: padding.wrap,
            aad: Data("padding-v1".utf8),
            vaultID: nil
        )
    }

    private func loadIndex() throws -> VaultIndex {
        guard let sealed = try keys.data(service: KeychainServiceName.vault, account: KeychainAccount.index) else {
            return VaultIndex(vaults: [])
        }
        let plain = try sealer.open(sealed)
        return try JSONDecoder().decode(VaultIndex.self, from: plain)
    }

    private func saveIndex(_ index: VaultIndex) throws {
        let sealed = try sealer.seal(try JSONEncoder().encode(index))
        try keys.set(sealed, service: KeychainServiceName.vault, account: KeychainAccount.index)
    }

    private func loadBundle(_ id: UUID) throws -> KeyBundle {
        guard let sealed = try keys.data(service: KeychainServiceName.vault, account: id.uuidString) else {
            throw VaultError.fileMissing
        }
        return try JSONDecoder().decode(KeyBundle.self, from: try sealer.open(sealed))
    }

    private func saveBundle(_ bundle: KeyBundle, id: UUID) throws {
        let sealed = try sealer.seal(try JSONEncoder().encode(bundle))
        try keys.set(sealed, service: KeychainServiceName.vault, account: id.uuidString)
    }

    private func readManifest(vault: UUID, fileName: String, vmk: Data) throws -> VaultManifest {
        let url = vaultDirectory(id: vault).appendingPathComponent(fileName)
        let file = try Data(contentsOf: url)
        let plain = try AESGCMBox.open(file, using: SymmetricKey(data: vmk), authenticating: vault.bytes)
        return try JSONDecoder().decode(VaultManifest.self, from: plain)
    }

    private func saveManifest(_ manifest: VaultManifest, vault: UUID, fileName: String, vmk: Data) throws {
        let plain = try JSONEncoder().encode(manifest)
        let sealed = try AESGCMBox.seal(plain, using: SymmetricKey(data: vmk), authenticating: vault.bytes)
        try ProtectedFile.write(sealed, to: vaultDirectory(id: vault).appendingPathComponent(fileName))
    }

    private func itemFileURL(vault: UUID, fileName: String) -> URL {
        vaultDirectory(id: vault).appendingPathComponent(fileName)
    }

    private func directory(_ name: String) -> URL {
        root.appendingPathComponent(name, isDirectory: true)
    }
}

final class UnlockedSession {
    let vaultID: UUID
    let role: VaultRole
    let analyticsPayload = UnlockAnalyticsPayload(method: "secret")
    private let service: VaultService
    private var vmk: Data
    private var isLocked = false

    fileprivate init(service: VaultService, vaultID: UUID, role: VaultRole, vmk: Data) {
        self.service = service
        self.vaultID = vaultID
        self.role = role
        self.vmk = vmk
    }

    func stageImport(from source: URL) throws -> StagedImport {
        try service.stageImport(from: source)
    }

    func commitImport(_ staged: StagedImport, kind: ItemKind, displayName: String, deleteOriginal: Bool) throws -> UUID {
        try service.commit(staged, session: self, kind: kind, displayName: displayName, deleteOriginal: deleteOriginal)
    }

    func addItem(kind: ItemKind, displayName: String, bytes: Data) throws -> UUID {
        try service.addItem(session: self, kind: kind, displayName: displayName, bytes: bytes)
    }

    func addItem(from source: URL, kind: ItemKind, displayName: String) throws -> UUID {
        try service.addItem(session: self, from: source, kind: kind, displayName: displayName)
    }

    func readItem(_ id: UUID) throws -> Data {
        try service.readItem(session: self, id: id)
    }

    func deleteItem(_ id: UUID) throws {
        try service.deleteItem(session: self, id: id)
    }

    func libraryItems() throws -> [LibraryItem] {
        try service.libraryItems(session: self)
    }

    func softDelete(_ id: UUID, at date: Date = Date()) throws {
        try service.softDelete(session: self, id: id, at: date)
    }

    func restoreItem(_ id: UUID) throws {
        try service.restoreItem(session: self, id: id)
    }

    func moveItem(_ id: UUID, album: String?) throws {
        try service.moveItem(session: self, id: id, album: album)
    }

    func replaceItem(_ id: UUID, displayName: String, bytes: Data) throws {
        try service.replaceItem(session: self, id: id, displayName: displayName, bytes: bytes)
    }

    func purgeExpired(now: Date = Date(), after days: Int = 30) throws -> Int {
        try service.purgeExpired(session: self, now: now, after: days)
    }

    func prepareVideoPlayback(_ id: UUID) throws -> URL {
        try service.prepareVideoPlayback(session: self, id: id)
    }

    func endVideoPlayback(_ url: URL) throws {
        try service.endVideoPlayback(url)
    }

    func itemIDs() throws -> [UUID] {
        try service.itemIDs(session: self)
    }

    func wrappedKeyBlobs() throws -> [Data] {
        try service.wrappedKeyBlobs(session: self)
    }

    func fileURL(for item: UUID) throws -> URL {
        try service.fileURL(session: self, item: item)
    }

    /// The first real vault stays editable when a plan ends. A decoy or a later vault does not.
    func isPrimaryRealVault() -> Bool {
        guard role == .real else { return false }
        return (try? service.realVaultID()) == vaultID
    }

    func exportBackup(password: String, to destination: URL, stopAfterHeader: Bool = false) throws -> Int {
        try service.exportBackup(session: self, password: password, to: destination, stopAfterHeader: stopAfterHeader)
    }

    func restoreBackup(from file: URL, password: String, secret: LockSecret, halt: BackupRestoreHalt = .none) throws -> RestoredVault {
        try service.restoreBackup(from: file, password: password, secret: secret, halt: halt)
    }

    func lock() {
        vmk.wipeSensitive()
        isLocked = true
    }

    fileprivate func vmkData() throws -> Data {
        if isLocked || vmk.isEmpty { throw VaultError.authenticationFailed }
        return vmk
    }

    deinit {
        lock()
    }
}

enum BackupRestoreHalt: Equatable {
    case none
    case beforePublish
    case afterCreate
}

/// Pulls plaintext from an item file one chunk at a time. The item key is wiped when the cursor is released.
private final class ItemPlaintextCursor {
    private let url: URL
    private var keyData: Data
    private let aad: Data
    private let expected: Data
    private var handle: FileHandle?
    private var legacy: Data?
    private var deliveredLegacy = false
    private var hasher = SHA256()
    private var headerDone = false
    private var finished = false
    private var opened = false

    init(url: URL, keyData: Data, aad: Data, expected: Data) {
        self.url = url
        var owned = Data(keyData)
        owned.withUnsafeMutableBytes { _ in }
        self.keyData = owned
        self.aad = aad
        self.expected = expected
    }

    deinit {
        keyData.wipeSensitive()
        try? handle?.close()
    }

    func next() throws -> Data? {
        if !opened { try open() }
        if let legacy {
            if deliveredLegacy { return nil }
            deliveredLegacy = true
            return legacy
        }
        guard let handle, !finished else { return nil }
        if !headerDone {
            let header = try handle.read(upToCount: 5) ?? Data()
            guard header.count == 5, header.starts(with: ChunkedItemFile.magic), header[4] == 1 else {
                throw VaultError.fileMissing
            }
            headerDone = true
        }
        let lengthData = try handle.read(upToCount: 4) ?? Data()
        if lengthData.isEmpty {
            finished = true
            guard Data(hasher.finalize()) == expected else { throw VaultError.verifyFailed }
            return nil
        }
        guard lengthData.count == 4 else { throw VaultError.authenticationFailed }
        let bytes = [UInt8](lengthData)
        let length = Int(UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3]))
        guard length > 0, length <= ChunkedItemFile.chunkBytes + 64 else { throw VaultError.authenticationFailed }
        let sealed = try handle.read(upToCount: length) ?? Data()
        guard sealed.count == length else { throw VaultError.authenticationFailed }
        let plain = try AESGCMBox.open(sealed, using: SymmetricKey(data: keyData), authenticating: aad)
        hasher.update(data: plain)
        return plain
    }

    private func open() throws {
        opened = true
        let handle = try FileHandle(forReadingFrom: url)
        let magic = try handle.read(upToCount: 4) ?? Data()
        if magic.starts(with: ChunkedItemFile.magic) {
            try handle.seek(toOffset: 0)
            self.handle = handle
            return
        }
        try handle.close()
        let file = try Data(contentsOf: url)
        let combined = try ItemFileFormat.combined(from: file)
        let plain = try AESGCMBox.open(combined, using: SymmetricKey(data: keyData), authenticating: aad)
        guard Data(SHA256.hash(data: plain)) == expected else { throw VaultError.verifyFailed }
        legacy = plain
    }
}
