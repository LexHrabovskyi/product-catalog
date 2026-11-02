import AppFeature
import SwiftUI

@main
struct Product_catalogApp: App {
    private static let store = AppFeature.makeStore()

    init() {
        AppFeature.bootstrap(launchArguments: ProcessInfo.processInfo.arguments)
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: Self.store)
        }
    }
}
