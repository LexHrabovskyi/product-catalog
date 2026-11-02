import Dependencies
import DependenciesMacros
import Models

/// The DummyJSON catalog. Every method throws `CatalogError`, or `CancellationError` when cancelled.
@DependencyClient
public struct ProductsClient: Sendable {
    public var page: @Sendable (_ query: ProductQuery) async throws -> ProductPage
    public var product: @Sendable (_ id: Int) async throws -> Product
    public var categories: @Sendable () async throws -> [ProductCategory]
}

extension ProductsClient: DependencyKey {
    public static let liveValue = ProductsClient.live
    public static let testValue = ProductsClient()
    public static let previewValue = ProductsClient.fixtures
}

extension DependencyValues {
    public var productsClient: ProductsClient {
        get { self[ProductsClient.self] }
        set { self[ProductsClient.self] = newValue }
    }
}
