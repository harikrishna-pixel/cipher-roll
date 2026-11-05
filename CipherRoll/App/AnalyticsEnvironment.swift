import SwiftUI

private struct AnalyticsClientKey: EnvironmentKey {
    static let defaultValue: any AnalyticsClient = NoOpAnalyticsClient()
}

extension EnvironmentValues {
    var analyticsClient: any AnalyticsClient {
        get { self[AnalyticsClientKey.self] }
        set { self[AnalyticsClientKey.self] = newValue }
    }
}
