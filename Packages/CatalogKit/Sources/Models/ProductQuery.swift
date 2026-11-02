public struct ProductQuery: Hashable, Sendable {
    /// Search ignores categories on the server, so the two never combine.
    public enum Scope: Hashable, Sendable {
        case all
        case category(slug: String)
        case search(String)
    }

    public static let pageSize = 30

    public var scope: Scope
    public var sort: SortOption
    public var skip: Int
    public var limit: Int

    public init(scope: Scope = .all, sort: SortOption = .default, skip: Int = 0, limit: Int = ProductQuery.pageSize) {
        self.scope = scope
        self.sort = sort
        self.skip = skip
        self.limit = limit
    }
}

public enum SortOption: String, CaseIterable, Hashable, Identifiable, Sendable {
    case `default`
    case priceAscending
    case priceDescending
    case titleAscending
    case ratingDescending

    public var id: Self { self }

    public var title: String {
        switch self {
        case .default: "Default"
        case .priceAscending: "Price: low to high"
        case .priceDescending: "Price: high to low"
        case .titleAscending: "Title: A–Z"
        case .ratingDescending: "Rating: highest first"
        }
    }

    /// The `sortBy` and `order` query values; `nil` keeps the catalog's own order.
    public var parameters: (sortBy: String, order: String)? {
        switch self {
        case .default: nil
        case .priceAscending: ("price", "asc")
        case .priceDescending: ("price", "desc")
        case .titleAscending: ("title", "asc")
        case .ratingDescending: ("rating", "desc")
        }
    }
}
