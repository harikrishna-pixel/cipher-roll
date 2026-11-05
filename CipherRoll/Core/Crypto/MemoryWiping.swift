import Foundation
import Security

enum RandomBytes {
    static func generate(count: Int) throws -> Data {
        var data = Data(count: count)
        let status = data.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, count, buffer.baseAddress!)
        }
        guard status == errSecSuccess else { throw VaultError.randomFailed }
        return data
    }
}

extension Data {
    mutating func wipeSensitive() {
        withUnsafeMutableBytes { buffer in
            guard let base = buffer.baseAddress, buffer.count > 0 else { return }
            memset_s(base, buffer.count, 0, buffer.count)
        }
        removeAll(keepingCapacity: false)
    }
}
