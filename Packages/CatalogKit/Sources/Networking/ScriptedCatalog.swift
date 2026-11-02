#if DEBUG
import CoreGraphics
import Foundation
import ImageIO

/// The scripted catalog in DummyJSON's shape: "Product 1" to "Product N", spread over three categories.
struct ScriptedCatalog {
    private static let categorySlugs = ["beauty", "fragrances", "furniture"]

    let products: [ScriptedProduct]

    init(productCount: Int) {
        products = (1...productCount).map { id in
            ScriptedProduct(id: id, category: Self.categorySlugs[(id - 1) % Self.categorySlugs.count])
        }
    }

    func product(_ id: Int) throws -> Data? {
        guard products.indices.contains(id - 1) else { return nil }
        return try JSONEncoder().encode(products[id - 1])
    }

    func page(_ matches: [ScriptedProduct], skip: Int, limit: Int) throws -> Data {
        let products = Array(matches.dropFirst(skip).prefix(limit))
        return try JSONEncoder().encode(ScriptedPage(products: products, total: matches.count, skip: skip, limit: products.count))
    }

    func categories() throws -> Data {
        try JSONEncoder().encode(Self.categorySlugs.map { slug in
            ["slug": slug, "name": slug.capitalized, "url": "https://dummyjson.com/products/category/\(slug)"]
        })
    }

    /// A small solid PNG whose colour follows the product id, so neighbouring rows look different.
    static func png(forProduct id: Int) throws -> Data {
        let palette: [(red: CGFloat, green: CGFloat, blue: CGFloat)] = [
            (0.91, 0.44, 0.38), (0.96, 0.70, 0.27), (0.47, 0.75, 0.44), (0.32, 0.61, 0.86), (0.60, 0.48, 0.84),
        ]
        let color = palette[id % palette.count]
        let data = NSMutableData()
        guard
            let context = CGContext(
                data: nil, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ),
            let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil)
        else { throw URLError(.cannotCreateFile) }
        context.setFillColor(red: color.red, green: color.green, blue: color.blue, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        guard let image = context.makeImage() else { throw URLError(.cannotCreateFile) }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw URLError(.cannotCreateFile) }
        return data as Data
    }
}

/// A product as DummyJSON sends it. Products 2 and 4 carry the journey's discounts and minimum orders.
struct ScriptedProduct: Encodable {
    struct Meta: Encodable {
        let barcode: String
    }

    let id: Int
    let title: String
    let description: String
    let category: String
    let price: Decimal
    let discountPercentage: Decimal
    let rating = 4.5
    let stock: Int
    let availabilityStatus = "In Stock"
    let minimumOrderQuantity: Int
    let sku: String
    let warrantyInformation = "1 year warranty"
    let shippingInformation = "Ships in 1-2 business days"
    let returnPolicy = "30 days return policy"
    let tags: [String] = []
    let meta: Meta
    let thumbnail: String
    let images: [String]
    let reviews: [String] = []

    init(id: Int, category: String) {
        self.id = id
        self.category = category
        title = "Product \(id)"
        description = "Scripted product \(id)."
        (price, discountPercentage, stock, minimumOrderQuantity) = switch id {
        case 2: (10, 10, 50, 5)
        case 4: (20, 5, 10, 2)
        default: (Decimal(id), 0, 50, 1)
        }
        sku = "SCRIPTED-\(id)"
        meta = Meta(barcode: String(id))
        let folder = "https://cdn.dummyjson.com/product-images/\(id)"
        thumbnail = "\(folder)/thumbnail.png"
        images = (1...3).map { "\(folder)/\($0).png" }
    }
}

private struct ScriptedPage: Encodable {
    let products: [ScriptedProduct]
    let total: Int
    let skip: Int
    let limit: Int
}
#endif
