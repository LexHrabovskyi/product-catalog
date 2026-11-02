/// The catalog's own stock label, shown as-is even where it disagrees with the count.
public enum AvailabilityStatus: Hashable, Sendable {
    case inStock
    case lowStock
    case outOfStock
    case other(String)

    public init(label: String) {
        switch label {
        case "In Stock": self = .inStock
        case "Low Stock": self = .lowStock
        case "Out of Stock": self = .outOfStock
        default: self = .other(label)
        }
    }

    public var label: String {
        switch self {
        case .inStock: "In Stock"
        case .lowStock: "Low Stock"
        case .outOfStock: "Out of Stock"
        case let .other(label): label
        }
    }
}

extension AvailabilityStatus: Decodable {
    public init(from decoder: any Decoder) throws {
        self.init(label: try decoder.singleValueContainer().decode(String.self))
    }
}
