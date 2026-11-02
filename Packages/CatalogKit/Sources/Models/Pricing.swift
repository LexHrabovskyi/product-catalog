import Foundation

public enum Pricing {
    /// The price after the discount, rounded half-up to cents.
    public static func discounted(_ price: Decimal, by percentage: Decimal) -> Decimal {
        (price * (100 - percentage) / 100).rounded(toPlaces: 2)
    }
}

extension Decimal {
    /// Rounds half-up (away from zero) to the given number of decimal places.
    public func rounded(toPlaces places: Int) -> Decimal {
        var source = self
        var result = Decimal()
        NSDecimalRound(&result, &source, places, .plain)
        return result
    }
}
