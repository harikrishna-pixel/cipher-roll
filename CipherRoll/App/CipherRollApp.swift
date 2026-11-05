import SwiftUI

@main
struct CipherRollApp: App {
    @StateObject private var model: AppLockModel
    @StateObject private var settings: SettingsModel

    init() {
        try? InterruptedWorkSweeper.sweep(root: AppGroupStore.root())
        let gate = GatedAnalyticsClient()
        let settings = SettingsModel(gate: gate)
        _settings = StateObject(wrappedValue: settings)
        _model = StateObject(wrappedValue: AppLockModel(analytics: gate))
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let screen = ScreenshotLaunch.screenName {
                    ScreenshotRoot(name: screen)
                } else {
                    RootView(model: model, settings: settings)
                }
            }
            .environment(\.analyticsClient, settings.gate)
        }
    }
}
