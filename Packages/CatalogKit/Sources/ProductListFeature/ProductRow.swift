import Models
import ProductsClient
import SharedUI
import SwiftUI

/// A catalog row, read by VoiceOver as one element: title, brand or category, price and discount, stock.
struct ProductRow: View {
    let product: Product
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        layout {
            RemoteImage(url: product.thumbnail)
                .frame(width: 56, height: 56)
                .clipShape(.rect(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 4) {
                Text(product.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(product.brand ?? product.categoryName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                PriceView(price: product.price, discountPercentage: product.discountPercentage, style: .row)
                StockBadge(status: product.availabilityStatus, stock: product.stock)
            }
        }
        .foregroundStyle(.primary)
        .accessibilityElement(children: .combine)
    }
}

extension Product {
    /// Stands in for each row while page 1 loads; only its shape shows.
    static let skeleton = Product(
        id: 0,
        title: "Product title placeholder",
        category: "category",
        brand: "Brand name",
        price: 99.99,
        stock: 99
    )
}

#Preview {
    List {
        ForEach(Product.fixtures) { ProductRow(product: $0) }
        ProductRow(product: .skeleton).redacted(reason: .placeholder)
    }
    .listStyle(.plain)
}
