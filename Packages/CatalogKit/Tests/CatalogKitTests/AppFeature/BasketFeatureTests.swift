import AppFeature
import Basket
import ComposableArchitecture
import Testing

@MainActor
struct BasketFeatureTests {
    private let mascara = BasketLine(
        productID: 1, title: "Mascara", thumbnail: nil, price: 10, discountPercentage: 10,
        stock: 5, minimumOrderQuantity: 1, quantity: 1
    )
    private let lemon = BasketLine(
        productID: 2, title: "Lemon", thumbnail: nil, price: 1, discountPercentage: 0,
        stock: 10, minimumOrderQuantity: 2, quantity: 2
    )
    private let lamp = BasketLine(
        productID: 3, title: "Lamp", thumbnail: nil, price: 20, discountPercentage: 5,
        stock: 7, minimumOrderQuantity: 2, quantity: 2
    )

    @Test func quantityChangesReachTheSharedLineWithinMinimumThroughStock() async {
        @Shared(.basket) var basket
        $basket.withLock { $0 = Basket(lines: [mascara, lemon]) }
        let store = TestStore(initialState: BasketFeature.State()) { BasketFeature() }

        await store.send(.quantityChanged(id: 2, quantity: 7)) {
            $0.$basket.withLock { $0 = Basket(lines: [self.mascara, self.lemon.with(quantity: 7)]) }
        }
        await store.send(.quantityChanged(id: 2, quantity: 11)) {
            $0.$basket.withLock { $0 = Basket(lines: [self.mascara, self.lemon.with(quantity: 10)]) }
        }
        // At stock, asking for more changes nothing.
        await store.send(.quantityChanged(id: 2, quantity: 11))
        await store.send(.quantityChanged(id: 2, quantity: 0)) {
            $0.$basket.withLock { $0 = Basket(lines: [self.mascara, self.lemon.with(quantity: 2)]) }
        }
        // At the minimum, asking for less keeps the line at the minimum instead of removing it.
        await store.send(.quantityChanged(id: 2, quantity: 1))
    }

    @Test func swipeRemovesThatLineAndKeepsTheOthersInOrder() async {
        @Shared(.basket) var basket
        $basket.withLock { $0 = Basket(lines: [mascara, lemon, lamp]) }
        let store = TestStore(initialState: BasketFeature.State()) { BasketFeature() }

        await store.send(.removeButtonTapped(id: 2)) {
            $0.$basket.withLock { $0 = Basket(lines: [self.mascara, self.lamp]) }
        }
    }

    @Test func clearAsksFirstThenCancelKeepsTheBasketAndClearEmptiesIt() async {
        @Shared(.basket) var basket
        $basket.withLock { $0 = Basket(lines: [mascara, lemon]) }
        let store = TestStore(initialState: BasketFeature.State()) { BasketFeature() }

        await store.send(.clearButtonTapped) {
            $0.alert = self.clearTwoLinesAlert
        }
        // Cancel dismisses the alert and leaves both lines.
        await store.send(.alert(.dismiss)) {
            $0.alert = nil
        }

        await store.send(.clearButtonTapped) {
            $0.alert = self.clearTwoLinesAlert
        }
        await store.send(.alert(.presented(.confirmClear))) {
            $0.alert = nil
            $0.$basket.withLock { $0 = Basket() }
        }
    }

    @Test func basketTabAndOtherScreensShareOneBasketBothWays() async {
        // Stands in for the detail screen's "Add to basket".
        @Shared(.basket) var detailBasket
        let store = TestStore(initialState: AppFeature.State()) { AppFeature() }

        $detailBasket.withLock { $0 = Basket(lines: [mascara, lemon]) }
        #expect(store.state.basketTab.basket.lines == [mascara, lemon])

        await store.send(.basketTab(.quantityChanged(id: 2, quantity: 4))) {
            $0.basketTab.$basket.withLock { $0 = Basket(lines: [self.mascara, self.lemon.with(quantity: 4)]) }
        }
        #expect(detailBasket.line(forProduct: 2)?.quantity == 4)

        await store.send(.basketTab(.removeButtonTapped(id: 1))) {
            $0.basketTab.$basket.withLock { $0 = Basket(lines: [self.lemon.with(quantity: 4)]) }
        }
        #expect(store.state.basket.lineCount == 1)
        #expect(detailBasket.lines == [lemon.with(quantity: 4)])

        // Another screen removed the line first: a late edit from the tab must not bring it back.
        $detailBasket.withLock { $0.remove(productID: 2) }
        await store.send(.basketTab(.quantityChanged(id: 2, quantity: 5)))
        await store.send(.basketTab(.removeButtonTapped(id: 2)))
        #expect(store.state.basket.lineCount == 0)
    }

    private var clearTwoLinesAlert: AlertState<BasketFeature.Action.Alert> {
        AlertState {
            TextState("Clear basket?")
        } actions: {
            ButtonState(role: .destructive, action: .confirmClear) {
                TextState("Clear")
            }
            ButtonState(role: .cancel) {
                TextState("Cancel")
            }
        } message: {
            TextState("Remove all 2 products?")
        }
    }
}

private extension BasketLine {
    func with(quantity: Int) -> BasketLine {
        var line = self
        line.quantity = quantity
        return line
    }
}
