import Foundation
import Models

extension ProductsClient {
    /// SwiftUI previews only: every query answers the same single page, with no network.
    static let fixtures = ProductsClient(
        page: { _ in
            ProductPage(products: Product.fixtures, total: Product.fixtures.count, skip: 0, limit: Product.fixtures.count)
        },
        product: { id in
            guard let product = Product.fixtures.first(where: { $0.id == id }) else { throw CatalogError.notFound }
            return product
        },
        categories: {
            Set(Product.fixtures.map(\.category)).sorted().map {
                ProductCategory(slug: $0, name: ProductCategory.displayName(forSlug: $0))
            }
        }
    )
}

extension Product {
    /// A few products covering the cases screens must handle: discounts, no brand, low and no stock.
    public static let fixtures: [Product] = [
        Product(
            id: 1,
            title: "Essence Mascara Lash Princess",
            description: "A volumizing and lengthening mascara with a long-lasting, cruelty-free formula.",
            category: "beauty",
            brand: "Essence",
            price: 9.99,
            discountPercentage: 10.48,
            rating: 2.56,
            stock: 99,
            minimumOrderQuantity: 48,
            sku: "BEA-ESS-ESS-001",
            barcode: "5784719087687",
            warrantyInformation: "1 week warranty",
            shippingInformation: "Ships in 3-5 business days",
            returnPolicy: "No return policy",
            tags: ["beauty", "mascara"],
            reviews: [
                Review(
                    rating: 3,
                    comment: "Would not recommend!",
                    date: Date(timeIntervalSince1970: 1_746_006_062),
                    reviewerName: "Eleanor Collins"
                ),
            ]
        ),
        Product(
            id: 121,
            title: "iPhone 5s",
            category: "smartphones",
            brand: "Apple",
            price: 199.99,
            discountPercentage: 12.91,
            rating: 2.83,
            stock: 3,
            availabilityStatus: .lowStock,
            minimumOrderQuantity: 2,
            sku: "SMA-APP-IPH-121"
        ),
        Product(
            id: 17,
            title: "Apple",
            category: "groceries",
            price: 1.99,
            discountPercentage: 1.97,
            rating: 4.19,
            stock: 9,
            availabilityStatus: .lowStock,
            minimumOrderQuantity: 10,
            sku: "GRO-BRD-APP-017"
        ),
        Product(
            id: 4,
            title: "Red Lipstick",
            category: "beauty",
            brand: "Chic Cosmetics",
            price: 12.99,
            discountPercentage: 19.03,
            rating: 4.36,
            stock: 0,
            availabilityStatus: .outOfStock,
            minimumOrderQuantity: 1,
            sku: "BEA-CHI-LIP-004"
        ),
    ]
}
