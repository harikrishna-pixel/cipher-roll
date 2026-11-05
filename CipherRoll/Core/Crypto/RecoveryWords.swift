import CryptoKit
import Foundation

enum RecoveryWords {
    static func generate() throws -> (entropy: Data, words: [String]) {
        let entropy = try RandomBytes.generate(count: 32)
        return (entropy, try encode(entropy))
    }

    static func encode(_ entropy: Data) throws -> [String] {
        guard entropy.count == 32 else { throw VaultError.secretInvalid }
        let checksum = Data(SHA256.hash(data: entropy)).prefix(1)
        let packed = entropy + checksum
        return stride(from: 0, to: 24, by: 1).map { index in
            BIP39English.words[bitIndex(packed, word: index)]
        }
    }

    static func entropy(from words: [String]) throws -> Data {
        guard words.count == 24 else { throw VaultError.authenticationFailed }
        var bits = [UInt8](repeating: 0, count: 33)
        for (wordIndex, word) in words.enumerated() {
            guard let index = BIP39English.lookup[word] else { throw VaultError.authenticationFailed }
            write(index, into: &bits, word: wordIndex)
        }
        let entropy = Data(bits.prefix(32))
        let expected = Data(SHA256.hash(data: entropy))[0]
        guard bits[32] == expected else { throw VaultError.authenticationFailed }
        return entropy
    }

    private static func bitIndex(_ data: Data, word: Int) -> Int {
        let start = word * 11
        var value = 0
        for offset in 0..<11 {
            let position = start + offset
            let byte = data[position / 8]
            let bit = (byte >> (7 - (position % 8))) & 1
            value = (value << 1) | Int(bit)
        }
        return value
    }

    private static func write(_ index: Int, into bits: inout [UInt8], word: Int) {
        let start = word * 11
        for offset in 0..<11 {
            let bit = (index >> (10 - offset)) & 1
            let position = start + offset
            if bit == 1 {
                bits[position / 8] |= 1 << (7 - (position % 8))
            }
        }
    }
}

extension BIP39English {
    static let lookup: [String: Int] = {
        Dictionary(uniqueKeysWithValues: words.enumerated().map { ($1, $0) })
    }()
}
