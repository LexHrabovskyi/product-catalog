public struct ProductPage: Decodable, Hashable, Sendable {
    public var products: [Product]
    /// Every product matching the query, not just this page.
    public var total: Int
    public var skip: Int
    public var limit: Int

    public init(products: [Product], total: Int, skip: Int, limit: Int) {
        self.products = products
        self.total = total
        self.skip = skip
        self.limit = limit
    }
}
