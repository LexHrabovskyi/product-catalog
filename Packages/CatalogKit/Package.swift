// swift-tools-version: 6.2
import PackageDescription

// Nonisolated by default: TCA 1.x breaks under default MainActor isolation.
let concurrency: [SwiftSetting] = [
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
]

let tca = Target.Dependency.product(name: "ComposableArchitecture", package: "swift-composable-architecture")
let dependencies = Target.Dependency.product(name: "Dependencies", package: "swift-dependencies")
let dependenciesMacros = Target.Dependency.product(name: "DependenciesMacros", package: "swift-dependencies")
let sharing = Target.Dependency.product(name: "Sharing", package: "swift-sharing")

let package = Package(
    name: "CatalogKit",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "AppFeature", targets: ["AppFeature"]),
        .library(name: "Presentation", targets: ["Presentation"]),
        .library(name: "Basket", targets: ["Basket"]),
        .library(name: "Catalog", targets: ["Catalog"]),
        .library(name: "Networking", targets: ["Networking"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            from: "1.26.2",
            traits: [.defaults, "ComposableArchitecture2Deprecations"]
        ),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.17.2"),
        .package(url: "https://github.com/pointfreeco/swift-sharing", from: "2.8.1"),
    ],
    targets: [
        .target(name: "Networking", dependencies: [dependencies], swiftSettings: concurrency),
        .target(
            name: "Catalog",
            dependencies: ["Networking", dependencies, dependenciesMacros],
            swiftSettings: concurrency
        ),
        .target(name: "Basket", dependencies: ["Catalog", sharing], swiftSettings: concurrency),
        .target(name: "Presentation", dependencies: ["Catalog", "Networking", dependencies], swiftSettings: concurrency),
        .target(
            name: "AppFeature",
            dependencies: ["Basket", "Catalog", "Networking", "Presentation", tca],
            swiftSettings: concurrency
        ),
        .testTarget(
            name: "CatalogKitTests",
            dependencies: [
                "AppFeature", "Basket", "Catalog", "Networking", "Presentation",
                tca,
                .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
            ],
            swiftSettings: concurrency
        ),
    ]
)
