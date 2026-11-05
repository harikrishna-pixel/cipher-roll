import CryptoKit
import Foundation

struct CreatedVault {
    var id: UUID
    var role: VaultRole
    var recoveryWords: [String]?
}

struct UnlockAnalyticsPayload: Equatable {
    var method: String
}

struct StagedImport {
    let sourceURL: URL
    let tempURL: URL
}

protocol OriginalsDeleting: AnyObject {
    func deleteOriginal(at source: URL) throws
}

final class NoOriginalsDeleting: OriginalsDeleting {
    func deleteOriginal(at source: URL) throws {}
}

struct KeyBundle: Codable {
    var version: Int
    var kdf: String
    var iterations: Int
    var lockSalt: Data
    var lockWrap: Data
    var recoverySalt: Data?
    var recoveryWrap: Data?
    var role: VaultRole
    var manifestFileName: String
}

struct VaultIndex: Codable {
    struct Entry: Codable {
        var id: UUID
        var role: VaultRole
    }

    var vaults: [Entry]
}

struct PaddingRecord: Codable {
    var salt: Data
    var iterations: Int
    var wrap: Data
}

struct RecoveryMaterial: Codable {
    var salt: Data
    var iterations: Int
    var kek: Data
}

struct ItemRecord: Codable {
    var id: UUID
    var kind: ItemKind
    var fileName: String
    var wrappedItemKey: Data
    var displayName: String
    var sha256: Data
    var byteCount: Int?
    var album: String?
    var deletedAt: Date?
    var createdAt: Date?

    init(
        id: UUID,
        kind: ItemKind,
        fileName: String,
        wrappedItemKey: Data,
        displayName: String,
        sha256: Data,
        byteCount: Int? = nil,
        album: String? = nil,
        deletedAt: Date? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.kind = kind
        self.fileName = fileName
        self.wrappedItemKey = wrappedItemKey
        self.displayName = displayName
        self.sha256 = sha256
        self.byteCount = byteCount
        self.album = album
        self.deletedAt = deletedAt
        self.createdAt = createdAt
    }
}

struct LibraryItem: Identifiable, Equatable {
    var id: UUID
    var kind: ItemKind
    var displayName: String
    var byteCount: Int
    var album: String?
    var deletedAt: Date?
    var createdAt: Date?
}

struct VaultManifest: Codable {
    var items: [ItemRecord]
}

extension UUID {
    var bytes: Data {
        withUnsafeBytes(of: uuid) { Data($0) }
    }
}

extension SymmetricKey {
    var rawRepresentation: Data {
        withUnsafeBytes { Data($0) }
    }
}
