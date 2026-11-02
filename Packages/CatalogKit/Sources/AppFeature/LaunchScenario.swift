import Foundation
#if DEBUG
import ComposableArchitecture
import Networking
import os

private let scenarioLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ProductCatalog", category: "scenario")
#endif

extension AppFeature {
    /// Called once at launch, before any dependency is used. Debug builds read `-scenario <name>`
    /// to swap the network and the basket storage for scripted ones; Release builds do nothing.
    public static func bootstrap(launchArguments: [String]) {
        #if DEBUG
        guard let flag = launchArguments.firstIndex(of: "-scenario") else {
            return
        }
        let name = launchArguments.dropFirst(flag + 1).first ?? ""
        guard let scenario = ScriptedDataTransfer.Scenario(rawValue: name) else {
            scenarioLogger.error("Unknown launch scenario \"\(name, privacy: .public)\"; using the live network")
            return
        }
        prepareDependencies {
            $0.dataTransfer = ScriptedDataTransfer(scenario: scenario)
            $0.defaultFileStorage = .inMemory
        }
        scenarioLogger.notice("Launch scenario \(name, privacy: .public) installed")
        #endif
    }
}
