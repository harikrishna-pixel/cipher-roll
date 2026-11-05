import CommonCrypto
import CryptoKit
import Foundation

protocol KeyDeriving {
    func derive(secret: Data, salt: Data, iterations: Int) throws -> SymmetricKey
}

struct PBKDF2KeyDerivation: KeyDeriving {
    func derive(secret: Data, salt: Data, iterations: Int) throws -> SymmetricKey {
        guard iterations > 0 else { throw VaultError.kdfFailed }
        var digest = Data(SHA256.hash(data: secret))
        defer { digest.wipeSensitive() }
        return try Self.pbkdf2(password: digest, salt: salt, iterations: iterations)
    }

    private static func pbkdf2(password: Data, salt: Data, iterations: Int) throws -> SymmetricKey {
        var derived = [UInt8](repeating: 0, count: 32)
        let status: CCStatus = derived.withUnsafeMutableBytes { derivedBuffer in
            password.withUnsafeBytes { passwordBuffer in
                salt.withUnsafeBytes { saltBuffer in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBuffer.baseAddress?.assumingMemoryBound(to: Int8.self),
                        password.count,
                        saltBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        derivedBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        32
                    )
                }
            }
        }
        let key = SymmetricKey(data: Data(derived))
        derived.withUnsafeMutableBytes { buffer in
            guard let base = buffer.baseAddress else { return }
            memset_s(base, buffer.count, 0, buffer.count)
        }
        guard status == kCCSuccess else { throw VaultError.kdfFailed }
        return key
    }
}

enum KeyDerivation {
    static let productionFloor = 600_000

    static func iterations(sampleCount: Int, elapsed: TimeInterval, floor: Int, target: TimeInterval) -> Int {
        guard elapsed > 0, sampleCount > 0 else { return floor }
        let needed = Int((target / elapsed) * Double(sampleCount))
        return max(floor, needed)
    }

    static func calibratedIterations(sampleCount: Int = 10_000, floor: Int = productionFloor, target: TimeInterval = 0.3) -> Int {
        let start = Date()
        _ = try? PBKDF2KeyDerivation().derive(
            secret: Data(repeating: 7, count: 16),
            salt: Data(repeating: 9, count: 16),
            iterations: sampleCount
        )
        let elapsed = Date().timeIntervalSince(start)
        return iterations(sampleCount: sampleCount, elapsed: elapsed, floor: floor, target: target)
    }
}
