public struct ProductCategory: Decodable, Hashable, Identifiable, Sendable {
    public var slug: String
    public var name: String

    public var id: String { slug }

    public init(slug: String, name: String) {
        self.slug = slug
        self.name = name
    }

    /// "home-decoration" → "Home Decoration", matching the names the categories endpoint returns.
    public static func displayName(forSlug slug: String) -> String {
        slug.split(separator: "-")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}
