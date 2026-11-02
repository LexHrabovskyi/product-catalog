import AppFeature
import Dependencies
import Networking
import Sharing
import Testing

/// What the launch arguments install, read in the live context the app runs in.
/// Swift Testing keeps each test's prepared dependencies apart, so these never leak into other tests.
struct LaunchScenarioTests {
    @Test func aScenarioLaunchInstallsItsScriptedNetworkAndAnInMemoryBasket() {
        withDependencies {
            $0.context = .live
        } operation: {
            AppFeature.bootstrap(launchArguments: ["Product catalog", "-scenario", "journey"])

            @Dependency(\.dataTransfer) var network
            @Dependency(\.defaultFileStorage) var basketStorage
            #expect(network is ScriptedDataTransfer)
            #expect(basketStorage != .fileSystem)
        }
    }

    @Test func aLaunchWithoutAKnownScenarioKeepsTheLiveNetworkAndTheBasketFile() {
        withDependencies {
            $0.context = .live
        } operation: {
            AppFeature.bootstrap(launchArguments: ["Product catalog"])
            AppFeature.bootstrap(launchArguments: ["Product catalog", "-scenario", "demo"])
            AppFeature.bootstrap(launchArguments: ["Product catalog", "-scenario"])

            @Dependency(\.dataTransfer) var network
            @Dependency(\.defaultFileStorage) var basketStorage
            #expect(network is URLSessionDataTransfer)
            #expect(basketStorage == .fileSystem)
        }
    }
}
