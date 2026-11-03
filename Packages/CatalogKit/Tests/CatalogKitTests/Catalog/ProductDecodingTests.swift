import Catalog
import Foundation
import Testing

struct ProductDecodingTests {
    @Test func capturedPageDecodesWithExactPricesOptionalBrandAndMillisecondReviewDates() throws {
        let page = try JSONDecoder().decode(ProductPage.self, from: Data(Payloads.page.utf8))

        #expect(page.total == 194)
        #expect(page.skip == 151)
        #expect(page.limit == 3)
        #expect(page.products.map(\.id) == [152, 153, 154])
        #expect(page.products.map(\.brand) == [nil, nil, "Fashion Shades"])
        #expect(page.products.map(\.availabilityStatus.label) == ["Low Stock", "Out of Stock", "In Stock"])
        #expect(page.products.map(\.stock) == [6, 0, 60])
        #expect(page.products.map(\.minimumOrderQuantity) == [5, 44, 17])

        let racket = try #require(page.products.first)
        #expect(racket.price == Decimal(string: "49.99"))
        #expect(racket.discountPercentage == Decimal(string: "19.61"))
        #expect(racket.category == "sports-accessories")
        #expect(racket.barcode == "5611498376196")
        #expect(racket.reviews.count == 3)

        // 2025-04-30T09:41:02.054Z: the milliseconds must survive decoding.
        let reviewDate = try #require(racket.reviews.first?.date)
        #expect(abs(reviewDate.timeIntervalSince1970 - 1_746_006_062.054) < 0.0005)
    }

    @Test func reviewerEmailIsNeverDecoded() throws {
        #expect(Payloads.page.contains("@x.dummyjson.com"))
        #expect(Payloads.product.contains("@x.dummyjson.com"))

        let page = try JSONDecoder().decode(ProductPage.self, from: Data(Payloads.page.utf8))
        let product = try JSONDecoder().decode(Product.self, from: Data(Payloads.product.utf8))
        var decoded = ""
        dump(page, to: &decoded)
        dump(product, to: &decoded)

        #expect(!decoded.contains("@"))
        #expect(!decoded.localizedCaseInsensitiveContains("mail"))
    }

    @Test func unknownAvailabilityLabelIsKeptAsIs() throws {
        let edited = Payloads.page.replacingOccurrences(
            of: #""availabilityStatus": "Low Stock""#,
            with: #""availabilityStatus": "Discontinued""#
        )
        try #require(edited != Payloads.page)

        let page = try JSONDecoder().decode(ProductPage.self, from: Data(edited.utf8))

        #expect(page.products.map(\.availabilityStatus.label) == ["Discontinued", "Out of Stock", "In Stock"])
    }

    @Test func categoryNameFromSlugMatchesTheCategoriesTheAPIReturns() throws {
        let categories = try JSONDecoder().decode([ProductCategory].self, from: Data(Payloads.categories.utf8))
        try #require(categories.count == 24)

        for category in categories {
            #expect(ProductCategory.displayName(forSlug: category.slug) == category.name)
        }
    }
}
