import Foundation

protocol Clock {
    func now() -> Date
}

struct SystemClock: Clock {
    func now() -> Date { Date() }
}

final class AttemptCounter {
    private let keys: KeyStoring
    private let clock: Clock

    init(keys: KeyStoring, clock: Clock) {
        self.keys = keys
        self.clock = clock
    }

    func beginAttempt() throws {
        let record = try load()
        if let next = record.nextAttemptAt, clock.now() < next {
            throw VaultError.lockedOut
        }
    }

    func recordFailure() throws {
        var record = try load()
        record.failures += 1
        if record.failures >= 5 {
            record.nextAttemptAt = clock.now().addingTimeInterval(delay(after: record.failures))
        }
        try save(record)
    }

    func recordSuccess() throws {
        try save(LockoutRecord(failures: 0, nextAttemptAt: nil))
    }

    private func delay(after failures: Int) -> TimeInterval {
        var delay = 30
        let steps = failures - 5
        if steps > 0 {
            for _ in 0..<steps {
                delay = min(delay * 2, 900)
            }
        }
        return TimeInterval(delay)
    }

    private func load() throws -> LockoutRecord {
        guard let data = try keys.data(service: KeychainServiceName.lockout, account: KeychainAccount.lockout) else {
            return LockoutRecord(failures: 0, nextAttemptAt: nil)
        }
        return try decoder.decode(LockoutRecord.self, from: data)
    }

    private func save(_ record: LockoutRecord) throws {
        let data = try encoder.encode(record)
        try keys.set(data, service: KeychainServiceName.lockout, account: KeychainAccount.lockout)
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }
}

private struct LockoutRecord: Codable {
    var failures: Int
    var nextAttemptAt: Date?
}
