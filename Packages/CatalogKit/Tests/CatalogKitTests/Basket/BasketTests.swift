import Basket
import Foundation
import Models
import Testing

struct BasketTests {
    @Test(arguments: [
        (stock: 0, minimum: 1, label: AvailabilityStatus.inStock, expected: Basket.Availability.outOfStock),
        (stock: 0, minimum: 44, label: .outOfStock, expected: .outOfStock),
        (stock: 3, minimum: 5, label: .lowStock, expected: .belowMinimumOrder(stock: 3, minimum: 5)),
        (stock: 5, minimum: 5, label: .lowStock, expected: .available(5...5)),
        (stock: 60, minimum: 17, label: .inStock, expected: .available(17...60)),
        (stock: 10, minimum: 1, label: .outOfStock, expected: .available(1...10)),
    ])
    func availabilityFollowsStockAndMinimumNeverTheLabel(
        stock: Int,
        minimum: Int,
        label: AvailabilityStatus,
        expected: Basket.Availability
    ) {
        let product = product(id: 1, stock: stock, minimum: minimum, label: label)

        #expect(Basket.availability(of: product) == expected)
    }

    @Test func addStartsAtTheMinimumMergesInPlaceAndReportsTheCap() {
        var basket = Basket()
        let lamp = product(id: 1, stock: 7, minimum: 2)
        let mug = product(id: 2, stock: 9, minimum: 1)

        _ = basket.add(lamp, quantity: 1)
        #expect(quantities(basket) == [[1, 2]])

        _ = basket.add(mug, quantity: 1)
        _ = basket.add(lamp, quantity: 3)
        #expect(quantities(basket) == [[1, 5], [2, 1]])

        let reachingStock = basket.add(lamp, quantity: 2)
        #expect(quantities(basket) == [[1, 7], [2, 1]])
        #expect(!isCapped(reachingStock), "Reaching stock exactly is not a cap")

        let beyondStock = basket.add(lamp, quantity: 2)
        #expect(quantities(basket) == [[1, 7], [2, 1]])
        #expect(beyondStock == .capped(stock: 7))
    }

    @Test(arguments: [
        (stock: 0, minimum: 1, expected: Basket.Availability.outOfStock),
        (stock: 3, minimum: 5, expected: .belowMinimumOrder(stock: 3, minimum: 5)),
    ])
    func addRefusesAnUnavailableProductAndLeavesTheBasketAlone(
        stock: Int,
        minimum: Int,
        expected: Basket.Availability
    ) {
        var basket = Basket()
        _ = basket.add(product(id: 1, stock: 9, minimum: 2), quantity: 4)
        let before = basket

        let outcome = basket.add(product(id: 1, stock: stock, minimum: minimum), quantity: 4)

        #expect(outcome == .refused(expected))
        #expect(basket == before)
    }

    @Test(arguments: [(0, 2), (1, 2), (5, 5), (7, 7), (8, 7), (99, 7)])
    func setQuantityClampsToMinimumThroughStock(requested: Int, expected: Int) {
        var basket = Basket()
        _ = basket.add(product(id: 1, stock: 7, minimum: 2), quantity: 2)

        basket.setQuantity(requested, forProduct: 1)

        #expect(basket.line(forProduct: 1)?.quantity == expected)
    }

    @Test func totalsRoundEachUnitPriceThenSumAndCountLinesNotUnits() throws {
        let basket = Basket(lines: [
            line(id: 1, price: try decimal("10.00"), discount: try decimal("12.35"), quantity: 3),
            line(id: 2, price: try decimal("5.00"), discount: 0, quantity: 1),
        ])

        #expect(basket.subtotal == (try decimal("35.00")))
        #expect(basket.total == (try decimal("31.31")))
        #expect(basket.savings == (try decimal("3.69")))
        #expect(basket.lineCount == 2)

        let empty = Basket()
        #expect(empty.subtotal == 0)
        #expect(empty.total == 0)
        #expect(empty.savings == 0)
        #expect(empty.lineCount == 0)
    }

    private func product(id: Int, stock: Int, minimum: Int, label: AvailabilityStatus = .inStock) -> Product {
        Product(
            id: id,
            title: "Product \(id)",
            category: "groceries",
            price: 10,
            stock: stock,
            availabilityStatus: label,
            minimumOrderQuantity: minimum
        )
    }

    private func line(id: Int, price: Decimal, discount: Decimal, quantity: Int) -> BasketLine {
        BasketLine(
            productID: id,
            title: "Product \(id)",
            thumbnail: nil,
            price: price,
            discountPercentage: discount,
            stock: 9,
            minimumOrderQuantity: 1,
            quantity: quantity
        )
    }

    /// `[productID, quantity]` per line, in basket order.
    private func quantities(_ basket: Basket) -> [[Int]] {
        basket.lines.map { [$0.productID, $0.quantity] }
    }

    private func isCapped(_ outcome: Basket.AddOutcome) -> Bool {
        if case .capped = outcome { true } else { false }
    }

    private func decimal(_ text: String) throws -> Decimal {
        try #require(Decimal(string: text))
    }
}
