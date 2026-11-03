import Catalog
import Foundation
import SwiftUI

/// Prices are USD formatted for the device locale.
public struct PriceView: View {
    public enum Style: Sendable {
        /// The list price and a whole-percent discount badge, hidden when it would read "−0%".
        case row
        /// The discounted price, then the struck-through list price and the exact discount.
        case detail
    }

    private let price: Decimal
    private let discountPercentage: Decimal
    private let style: Style

    public init(price: Decimal, discountPercentage: Decimal, style: Style) {
        self.price = price
        self.discountPercentage = discountPercentage
        self.style = style
    }

    public var body: some View {
        switch style {
        case .row:
            HStack(spacing: 6) {
                Text(price, format: .usd).font(.headline)
                if let discount = rowDiscount {
                    Text("−" + discount)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.red.opacity(0.12), in: Capsule())
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(rowDiscount.map { "\(price.formatted(.usd)), \($0) off" } ?? price.formatted(.usd))
        case .detail:
            VStack(alignment: .leading, spacing: 4) {
                Text(discountedPrice, format: .usd)
                    .font(.title.weight(.bold))
                if let discount = detailDiscount {
                    HStack(spacing: 8) {
                        Text(price, format: .usd)
                            .strikethrough()
                            .foregroundStyle(.secondary)
                        Text("−" + discount)
                            .foregroundStyle(.red)
                    }
                    .font(.subheadline)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                detailDiscount.map { "\(discountedPrice.formatted(.usd)), was \(price.formatted(.usd)), \($0) off" }
                    ?? discountedPrice.formatted(.usd)
            )
        }
    }

    private var discountedPrice: Decimal { Pricing.discounted(price, by: discountPercentage) }

    /// Rounded half-up to a whole percent first, so the badge and its visibility agree.
    private var rowDiscount: String? {
        let whole = discountPercentage.rounded(toPlaces: 0)
        guard whole > 0 else { return nil }
        return (whole / 100).formatted(.percent.precision(.fractionLength(0)))
    }

    private var detailDiscount: String? {
        guard discountPercentage > 0 else { return nil }
        return (discountPercentage / 100).formatted(.percent.precision(.fractionLength(0...2)))
    }
}

extension FormatStyle where Self == Decimal.FormatStyle.Currency {
    public static var usd: Self { .currency(code: "USD") }
}

#Preview {
    VStack(alignment: .leading, spacing: 24) {
        PriceView(price: 9.99, discountPercentage: 10.48, style: .row)
        PriceView(price: 9.99, discountPercentage: 0.04, style: .row)
        PriceView(price: 199.99, discountPercentage: 12.91, style: .detail)
    }
}
