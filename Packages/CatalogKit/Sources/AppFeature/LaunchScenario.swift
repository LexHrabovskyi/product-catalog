import Dependencies
import Foundation

extension AppFeature {
    /// Called once at launch, before any dependency is used. Debug builds read `-scenario <name>`
    /// to swap the network and the basket storage for scripted ones; Release builds do nothing.
    public static func bootstrap(launchArguments: [String]) {
        #if DEBUG
        guard let flag = launchArguments.firstIndex(of: "-scenario"), launchArguments.indices.contains(flag + 1) else {
            return
        }
        logger.notice("Launch scenario \(launchArguments[flag + 1], privacy: .public) requested, but no scenarios exist yet")
        #endif
    }
}
