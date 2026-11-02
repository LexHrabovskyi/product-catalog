import Foundation
import Models
import Testing

struct PricingTests {
    /// Each half-cent case differs under banker's rounding, truncation or `Double` arithmetic.
    @Test(arguments: [
        ("10.00", "12.35", "8.77"),
        ("0.25", "50", "0.13"),
        ("1.01", "50", "0.51"),
        ("1.00", "0.3", "1.00"),
        ("36999.99", "19.61", "29744.29"),
        ("9.99", "0", "9.99"),
    ])
    func discountedUnitPriceRoundsHalfUpToCents(price: String, discount: String, expected: String) throws {
        let discounted = Pricing.discounted(try decimal(price), by: try decimal(discount))

        #expect(discounted == (try decimal(expected)))
    }

    private func decimal(_ text: String) throws -> Decimal {
        try #require(Decimal(string: text))
    }
}
