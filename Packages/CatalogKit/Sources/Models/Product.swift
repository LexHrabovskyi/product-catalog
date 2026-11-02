import Foundation

public struct Product: Hashable, Identifiable, Sendable {
    public let id: Int
    public var title: String
    public var description: String
    /// A category slug such as "home-decoration".
    public var category: String
    /// Missing for roughly half of the catalog.
    public var brand: String?
    public var price: Decimal
    public var discountPercentage: Decimal
    public var rating: Double
    public var stock: Int
    public var availabilityStatus: AvailabilityStatus
    public var minimumOrderQuantity: Int
    public var sku: String
    public var barcode: String
    public var warrantyInformation: String
    public var shippingInformation: String
    public var returnPolicy: String
    public var tags: [String]
    public var thumbnail: URL?
    public var images: [URL]
    public var reviews: [Review]

    public init(
        id: Int,
        title: String,
        description: String = "",
        category: String,
        brand: String? = nil,
        price: Decimal,
        discountPercentage: Decimal = 0,
        rating: Double = 0,
        stock: Int,
        availabilityStatus: AvailabilityStatus = .inStock,
        minimumOrderQuantity: Int = 1,
        sku: String = "",
        barcode: String = "",
        warrantyInformation: String = "",
        shippingInformation: String = "",
        returnPolicy: String = "",
        tags: [String] = [],
        thumbnail: URL? = nil,
        images: [URL] = [],
        reviews: [Review] = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.brand = brand
        self.price = price
        self.discountPercentage = discountPercentage
        self.rating = rating
        self.stock = stock
        self.availabilityStatus = availabilityStatus
        self.minimumOrderQuantity = minimumOrderQuantity
        self.sku = sku
        self.barcode = barcode
        self.warrantyInformation = warrantyInformation
        self.shippingInformation = shippingInformation
        self.returnPolicy = returnPolicy
        self.tags = tags
        self.thumbnail = thumbnail
        self.images = images
        self.reviews = reviews
    }

    public var discountedPrice: Decimal {
        Pricing.discounted(price, by: discountPercentage)
    }

    public var categoryName: String {
        ProductCategory.displayName(forSlug: category)
    }
}

extension Product: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, title, description, category, brand, price, discountPercentage, rating, stock
        case availabilityStatus, minimumOrderQuantity, sku, warrantyInformation, shippingInformation
        case returnPolicy, tags, thumbnail, images, reviews, meta
    }

    private struct Meta: Decodable {
        let barcode: String
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        category = try container.decode(String.self, forKey: .category)
        brand = try container.decodeIfPresent(String.self, forKey: .brand)
        // JSON numbers can arrive with binary noise (9.99 → 9.990000000000002); prices are cents.
        price = try container.decode(Decimal.self, forKey: .price).rounded(toPlaces: 2)
        discountPercentage = try container.decode(Decimal.self, forKey: .discountPercentage).rounded(toPlaces: 2)
        rating = try container.decode(Double.self, forKey: .rating)
        stock = try container.decode(Int.self, forKey: .stock)
        availabilityStatus = try container.decode(AvailabilityStatus.self, forKey: .availabilityStatus)
        minimumOrderQuantity = try container.decode(Int.self, forKey: .minimumOrderQuantity)
        sku = try container.decode(String.self, forKey: .sku)
        barcode = try container.decode(Meta.self, forKey: .meta).barcode
        warrantyInformation = try container.decode(String.self, forKey: .warrantyInformation)
        shippingInformation = try container.decode(String.self, forKey: .shippingInformation)
        returnPolicy = try container.decode(String.self, forKey: .returnPolicy)
        tags = try container.decode([String].self, forKey: .tags)
        thumbnail = try container.decodeIfPresent(URL.self, forKey: .thumbnail)
        images = try container.decode([URL].self, forKey: .images)
        reviews = try container.decode([Review].self, forKey: .reviews)
    }
}
