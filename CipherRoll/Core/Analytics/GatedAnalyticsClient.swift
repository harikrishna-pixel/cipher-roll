import Foundation

/// Drops every event until the user allows usage stats. Mixpanel is not started.
final class GatedAnalyticsClient: AnalyticsClient {
    var allowed = false
    var sink: any AnalyticsClient = NoOpAnalyticsClient()

    func track(_ name: String, properties: [String: String]) {
        guard allowed else { return }
        sink.track(name, properties: properties)
    }
}

enum AnalyticsPrivacy {
    static let contentKeys = [
        "pin", "query", "filename", "file_name", "note", "search", "secret_value",
        "password", "phrase", "vault_name", "recovery"
    ]

    static func namesContent(_ properties: [String: String]) -> Bool {
        properties.keys.contains { key in
            contentKeys.contains(key.lowercased())
        }
    }
}

final class RecordingAnalyticsClient: AnalyticsClient {
    var events: [(name: String, properties: [String: String])] = []

    func track(_ name: String, properties: [String: String]) {
        events.append((name, properties))
    }
}
