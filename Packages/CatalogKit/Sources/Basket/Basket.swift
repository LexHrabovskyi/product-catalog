import Catalog
import Foundation

/// A product in the basket, with the product data as it was when it was added.
public struct BasketLine: Codable, Hashable, Identifiable, Sendable {
    public var productID: Int
    public var title: String
    public var thumbnail: URL?
    public var price: Decimal
    public var discountPercentage: Decimal
    public var stock: Int
    public var minimumOrderQuantity: Int
    public var quantity: Int

    public var id: Int { productID }

    public init(
        productID: Int,
        title: String,
        thumbnail: URL?,
        price: Decimal,
        discountPercentage: Decimal,
        stock: Int,
        minimumOrderQuantity: Int,
        quantity: Int
    ) {
        self.productID = productID
        self.title = title
        self.thumbnail = thumbnail
        self.price = price
        self.discountPercentage = discountPercentage
        self.stock = stock
        self.minimumOrderQuantity = minimumOrderQuantity
        self.quantity = quantity
    }

    public init(product: Product, quantity: Int) {
        self.init(
            productID: product.id,
            title: product.title,
            thumbnail: product.thumbnail,
            price: product.price,
            discountPercentage: product.discountPercentage,
            stock: product.stock,
            minimumOrderQuantity: max(product.minimumOrderQuantity, 1),
            quantity: quantity
        )
    }

    public var unitPrice: Decimal { Pricing.discounted(price, by: discountPercentage) }
    public var lineTotal: Decimal { unitPrice * Decimal(quantity) }
    public var listTotal: Decimal { price * Decimal(quantity) }
    public var quantityRange: ClosedRange<Int> { minimumOrderQuantity...max(minimumOrderQuantity, stock) }
}

public struct Basket: Codable, Hashable, Sendable {
    /// Whether a product can be added at all, and in what quantities.
    public enum Availability: Hashable, Sendable {
        case available(ClosedRange<Int>)
        case outOfStock
        case belowMinimumOrder(stock: Int, minimum: Int)
    }

    public enum AddOutcome: Hashable, Sendable {
        /// `quantity` is the line's quantity after the add, not the amount added.
        case added(quantity: Int)
        /// The basket now holds the whole stock; part of the request didn't fit.
        case capped(stock: Int)
        case refused(Availability)
    }

    /// Oldest first.
    public private(set) var lines: [BasketLine]

    public init(lines: [BasketLine] = []) {
        self.lines = lines
    }

    public static func availability(of product: Product) -> Availability {
        let minimum = max(product.minimumOrderQuantity, 1)
        guard product.stock > 0 else { return .outOfStock }
        guard product.stock >= minimum else { return .belowMinimumOrder(stock: product.stock, minimum: minimum) }
        return .available(minimum...product.stock)
    }

    /// Adds `quantity` (clamped to the minimum order and stock), merging with an existing line.
    /// The line's product data is refreshed from `product`.
    public mutating func add(_ product: Product, quantity: Int) -> AddOutcome {
        let availability = Self.availability(of: product)
        guard case let .available(range) = availability else { return .refused(availability) }
        let requested = min(max(quantity, range.lowerBound), range.upperBound)
        guard let index = lines.firstIndex(where: { $0.productID == product.id }) else {
            lines.append(BasketLine(product: product, quantity: requested))
            return .added(quantity: requested)
        }
        let wanted = lines[index].quantity + requested
        let kept = min(wanted, product.stock)
        lines[index] = BasketLine(product: product, quantity: kept)
        return wanted > kept ? .capped(stock: product.stock) : .added(quantity: kept)
    }

    /// Clamps to the line's minimum order and stock. Unknown products are ignored.
    public mutating func setQuantity(_ quantity: Int, forProduct productID: Int) {
        guard let index = lines.firstIndex(where: { $0.productID == productID }) else { return }
        let range = lines[index].quantityRange
        lines[index].quantity = min(max(quantity, range.lowerBound), range.upperBound)
    }

    public mutating func remove(productID: Int) {
        lines.removeAll { $0.productID == productID }
    }

    public mutating func removeAll() {
        lines.removeAll()
    }

    public func line(forProduct productID: Int) -> BasketLine? {
        lines.first { $0.productID == productID }
    }

    public var lineCount: Int { lines.count }
    /// At list prices.
    public var subtotal: Decimal { lines.reduce(0) { $0 + $1.listTotal } }
    /// At discounted prices.
    public var total: Decimal { lines.reduce(0) { $0 + $1.lineTotal } }
    public var savings: Decimal { subtotal - total }
}
