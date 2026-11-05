import Foundation

/// Events stay behind this type. Mixpanel is not started in this phase, and nothing is sent.
protocol AnalyticsClient {
    func track(_ name: String, properties: [String: String])
}

struct NoOpAnalyticsClient: AnalyticsClient {
    func track(_ name: String, properties: [String: String]) {}
}
