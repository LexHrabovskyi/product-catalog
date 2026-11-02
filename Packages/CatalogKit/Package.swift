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
        .library(name: "ProductListFeature", targets: ["ProductListFeature"]),
        .library(name: "ProductDetailFeature", targets: ["ProductDetailFeature"]),
        .library(name: "BasketFeature", targets: ["BasketFeature"]),
        .library(name: "SharedUI", targets: ["SharedUI"]),
        .library(name: "ProductsClient", targets: ["ProductsClient"]),
        .library(name: "Networking", targets: ["Networking"]),
        .library(name: "Basket", targets: ["Basket"]),
        .library(name: "Models", targets: ["Models"]),
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
        .target(name: "Models", swiftSettings: concurrency),
        .target(name: "Basket", dependencies: ["Models", sharing], swiftSettings: concurrency),
        .target(name: "Networking", dependencies: [dependencies], swiftSettings: concurrency),
        .target(
            name: "ProductsClient",
            dependencies: ["Models", "Networking", dependencies, dependenciesMacros],
            swiftSettings: concurrency
        ),
        .target(name: "SharedUI", dependencies: ["Models", "Networking", dependencies], swiftSettings: concurrency),
        .target(
            name: "ProductListFeature",
            dependencies: ["Models", "Basket", "ProductsClient", "SharedUI", tca],
            swiftSettings: concurrency
        ),
        .target(
            name: "ProductDetailFeature",
            dependencies: ["Models", "Basket", "ProductsClient", "SharedUI", tca],
            swiftSettings: concurrency
        ),
        .target(
            name: "BasketFeature",
            dependencies: ["Models", "Basket", "ProductsClient", "SharedUI", tca],
            swiftSettings: concurrency
        ),
        .target(
            name: "AppFeature",
            dependencies: ["ProductListFeature", "ProductDetailFeature", "BasketFeature", "Networking", "Basket", tca],
            swiftSettings: concurrency
        ),
        .testTarget(
            name: "CatalogKitTests",
            dependencies: [
                "Models", "Basket", "Networking", "ProductsClient", "SharedUI",
                "ProductListFeature", "ProductDetailFeature", "BasketFeature", "AppFeature",
                tca,
                .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
            ],
            swiftSettings: concurrency
        ),
    ]
)
