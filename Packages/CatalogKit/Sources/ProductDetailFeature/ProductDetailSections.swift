import Models
import SharedUI
import SwiftUI

/// Pages through up to six images; VoiceOver reads it as one adjustable element.
struct Gallery: View {
    let images: [URL]
    @State private var page: Int = 0

    var body: some View {
        // A product without images still gets one page: the placeholder.
        let urls: [URL?] = images.isEmpty ? [nil] : images.prefix(6).map { $0 }
        TabView(selection: $page) {
            ForEach(urls.indices, id: \.self) { index in
                RemoteImage(url: urls[index], contentMode: .fit)
                    .tag(index)
            }
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .frame(height: 320)
        .clipShape(.rect(cornerRadius: 16))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Product images")
        .accessibilityValue("\(page + 1) of \(urls.count)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: page = min(page + 1, urls.count - 1)
            case .decrement: page = max(page - 1, 0)
            @unknown default: break
            }
        }
        .accessibilityIdentifier("detail.gallery")
    }
}

/// Five stars for a 0–5 rating, to the nearest half. Hidden from VoiceOver: callers read the rating out.
struct Stars: View {
    let rating: Double

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: symbol(forStar: star))
            }
        }
        .foregroundStyle(.orange)
        .accessibilityHidden(true)
    }

    private func symbol(forStar star: Int) -> String {
        switch Int((rating * 2).rounded()) - (star - 1) * 2 {
        case 2...: "star.fill"
        case 1: "star.leadinghalf.filled"
        default: "star"
        }
    }
}

struct RatingSummary: View {
    let rating: Double
    let reviewCount: Int

    var body: some View {
        let average = rating.formatted(.number.precision(.fractionLength(1)))
        let reviews = reviewCount == 1 ? "1 review" : "\(reviewCount) reviews"
        HStack(spacing: 8) {
            Stars(rating: rating)
            Text("\(average) · \(reviews)")
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rated \(average) out of 5, \(reviews)")
    }
}

struct InventoryFacts: View {
    let product: Product

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Inventory")
                .font(.title3.bold())
                .accessibilityAddTraits(.isHeader)
            StockBadge(status: product.availabilityStatus, stock: product.stock)
            Fact(label: "Minimum order", value: "\(product.minimumOrderQuantity)")
            Fact(label: "SKU", value: product.sku)
            Fact(label: "Barcode", value: product.barcode)
            Fact(label: "Category", value: product.categoryName)
            Fact(label: "Shipping", value: product.shippingInformation)
            Fact(label: "Warranty", value: product.warrantyInformation)
            Fact(label: "Return policy", value: product.returnPolicy)
            Fact(label: "Tags", value: product.tags.joined(separator: ", "))
        }
    }
}

/// A label and its value side by side, stacked when they don't fit on one line. Hidden without a value.
private struct Fact: View {
    let label: String
    let value: String

    var body: some View {
        if !value.isEmpty {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    Text(label).foregroundStyle(.secondary)
                    Spacer()
                    Text(value)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).foregroundStyle(.secondary)
                    Text(value)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}

struct ReviewList: View {
    let reviews: [Review]

    var body: some View {
        if !reviews.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Text("Reviews")
                    .font(.title3.bold())
                    .accessibilityAddTraits(.isHeader)
                ForEach(reviews.indices, id: \.self) { index in
                    ReviewRow(review: reviews[index])
                }
            }
        }
    }
}

private struct ReviewRow: View {
    let review: Review

    var body: some View {
        let date = review.date.formatted(date: .abbreviated, time: .omitted)
        VStack(alignment: .leading, spacing: 4) {
            Text("\(review.reviewerName) · \(date)")
                .font(.subheadline.weight(.semibold))
            Stars(rating: Double(review.rating))
                .font(.caption)
            Text(review.comment)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(review.reviewerName), \(date), rated \(review.rating) out of 5. \(review.comment)")
    }
}
