import AppFeature
import Basket
import ComposableArchitecture
import Foundation
import Models
import Networking
import ProductDetailFeature
import ProductsClient
import Testing

@MainActor
struct ProductDetailFeatureTests {
    /// Orderable from 5 to 20.
    private let racket = Product(
        id: 152, title: "Tennis Racket", category: "sports-accessories", price: 50, stock: 20, minimumOrderQuantity: 5
    )

    @Test func opensWithTheTappedProductUpdatesItInPlaceAndAddsTheMinimumOnce() async {
        let current = Product(
            id: 152, title: "Tennis Racket Pro", category: "sports-accessories", price: 55, stock: 30,
            minimumOrderQuantity: 5
        )
        let clock = TestClock()
        let requested = LockIsolated<[Int]>([])
        let store = TestStore(initialState: ProductDetailFeature.State(product: racket)) {
            ProductDetailFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.productsClient.product = { id in
                requested.withValue { $0.append(id) }
                try await clock.sleep(for: .seconds(1))
                return current
            }
        }

        await store.send(.onAppear) {
            $0.refresh = .loading(isSlow: false)
        }
        await clock.advance(by: .seconds(1))
        await store.receive(\.refreshResponse) {
            $0.product = current
            $0.refresh = .updated
        }
        #expect(requested.value == [152])
        #expect(store.state.basketControl.title == "Add 5 to basket", "The label names the minimum a tap adds")

        // The line snapshots the refreshed product, not the row it was opened from.
        let line = BasketLine(product: current, quantity: 5)
        await store.send(.addToBasketButtonTapped) {
            $0.$basket.withLock { $0 = Basket(lines: [line]) }
        }
        #expect(store.state.basketControl == .inBasket(line))
        #expect(store.state.basketControl.title == "5 in basket")

        // A second tap that lands before the stepper replaces the button adds nothing.
        await store.send(.addToBasketButtonTapped)
    }

    @Test func productAlreadyInTheBasketOpensOnItsStepperAndARefreshLeavesTheLineAlone() async {
        let line = BasketLine(product: racket, quantity: 7)
        @Shared(.basket) var basket
        $basket.withLock { $0 = Basket(lines: [line]) }
        // Stock has fallen below the minimum since the line was added.
        let refreshed = Product(
            id: 152, title: "Tennis Racket Pro", category: "sports-accessories", price: 55, stock: 3,
            minimumOrderQuantity: 5
        )
        let store = TestStore(initialState: ProductDetailFeature.State(product: racket)) {
            ProductDetailFeature()
        } withDependencies: {
            $0.continuousClock = TestClock()
            $0.productsClient.product = { _ in refreshed }
        }
        #expect(store.state.basketControl == .inBasket(line), "The screen must open on the stepper, never on Add")
        #expect(store.state.basketControl.title == "7 in basket")

        await store.send(.onAppear) {
            $0.refresh = .loading(isSlow: false)
        }
        await store.receive(\.refreshResponse) {
            $0.product = refreshed
            $0.refresh = .updated
        }
        #expect(store.state.basketControl == .inBasket(line), "A basket line wins over availability")
        #expect(basket.lines == [line], "Only an add refreshes a line's snapshot")
    }

    @Test func notFoundDisablesTheControlEvenInTheBasketAndTheLineStays() async {
        let line = BasketLine(product: racket, quantity: 6)
        @Shared(.basket) var basket
        $basket.withLock { $0 = Basket(lines: [line]) }
        let store = TestStore(initialState: ProductDetailFeature.State(product: racket)) {
            ProductDetailFeature()
        } withDependencies: {
            $0.continuousClock = TestClock()
            $0.productsClient = .liveValue
            $0.dataTransfer = StubDataTransfer.answering(404, Payloads.notFound)
        }

        await store.send(.onAppear) {
            $0.refresh = .loading(isSlow: false)
        }
        await store.receive(\.refreshResponse) {
            $0.refresh = .gone
        }
        #expect(store.state.basketControl == .gone, "Gone wins over the basket line")
        #expect(store.state.basketControl.title == "This product is no longer available")

        await store.send(.incrementButtonTapped)
        await store.send(.removeButtonTapped)
        #expect(basket.lines == [line], "The line stays for the Basket tab")
    }

    /// Refusals only: the cases of one parameterized test share a basket, so none of them may write to it.
    @Test(arguments: [
        (stock: 0, minimum: 5, title: "Out of stock"),
        (stock: 3, minimum: 5, title: "Only 3 in stock — minimum order is 5"),
    ])
    func productThatCantBeAddedSaysWhyAndAddDoesNothing(stock: Int, minimum: Int, title: String) async {
        let volleyball = Product(
            id: 153, title: "Volleyball", category: "sports-accessories", price: 12, stock: stock,
            minimumOrderQuantity: minimum
        )
        let store = TestStore(initialState: ProductDetailFeature.State(product: volleyball)) {
            ProductDetailFeature()
        }
        #expect(store.state.basketControl.title == title)

        await store.send(.addToBasketButtonTapped)
    }

    @Test func stepperMovesTheLineWithinMinimumAndStockAndDeleteBringsAddBack() async {
        let lamp = Product(id: 7, title: "Lamp", category: "furniture", price: 20, stock: 3, minimumOrderQuantity: 1)
        func holding(_ quantity: Int) -> Basket {
            Basket(lines: [BasketLine(product: lamp, quantity: quantity)])
        }
        let store = TestStore(initialState: ProductDetailFeature.State(product: lamp)) {
            ProductDetailFeature()
        }
        #expect(store.state.basketControl.title == "Add to basket")

        await store.send(.addToBasketButtonTapped) { $0.$basket.withLock { $0 = holding(1) } }
        await store.send(.incrementButtonTapped) { $0.$basket.withLock { $0 = holding(2) } }
        await store.send(.incrementButtonTapped) { $0.$basket.withLock { $0 = holding(3) } }
        await store.send(.incrementButtonTapped)
        #expect(store.state.basketControl.title == "3 in basket", "+ stops at stock")

        await store.send(.decrementButtonTapped) { $0.$basket.withLock { $0 = holding(2) } }
        await store.send(.decrementButtonTapped) { $0.$basket.withLock { $0 = holding(1) } }
        await store.send(.decrementButtonTapped)
        #expect(store.state.basketControl.title == "1 in basket", "− never goes below the minimum")

        await store.send(.removeButtonTapped) { $0.$basket.withLock { $0 = Basket() } }
        #expect(store.state.basketControl.title == "Add to basket")
        await store.send(.addToBasketButtonTapped) { $0.$basket.withLock { $0 = holding(1) } }
    }

    @Test func aChangeMadeInTheBasketTabShowsOnTheControlAtOnce() async {
        let store = TestStore(initialState: ProductDetailFeature.State(product: racket)) {
            ProductDetailFeature()
        }
        @Shared(.basket) var basketTab

        $basketTab.withLock {
            _ = $0.add(racket, quantity: 5)
            $0.setQuantity(9, forProduct: 152)
        }
        #expect(store.state.basketControl.title == "9 in basket")

        $basketTab.withLock { $0.removeAll() }
        #expect(store.state.basketControl.title == "Add 5 to basket")
    }

    @Test func slowConnectionShowsAfterThreeSecondsOfRefreshAndGoesWhenTheRequestEnds() async {
        let current = Product(
            id: 152, title: "Tennis Racket", category: "sports-accessories", price: 45, stock: 20, minimumOrderQuantity: 5
        )
        let clock = TestClock()
        let calls = LockIsolated(0)
        let store = TestStore(initialState: ProductDetailFeature.State(product: racket)) {
            ProductDetailFeature()
        } withDependencies: {
            $0.continuousClock = clock
            // Every answer takes 5 s; the first one fails.
            $0.productsClient.product = { _ in
                try await clock.sleep(for: .seconds(5))
                let call = calls.withValue { $0 += 1; return $0 }
                if call == 1 { throw CatalogError.server(status: 503) }
                return current
            }
        }

        await store.send(.onAppear) {
            $0.refresh = .loading(isSlow: false)
        }
        await clock.advance(by: .milliseconds(2_999))
        #expect(store.state.refresh == .loading(isSlow: false), "No hint before 3 s")
        await clock.advance(by: .milliseconds(1))
        await store.receive(\.slowHintTimerFired) {
            $0.refresh = .loading(isSlow: true)
        }
        await clock.advance(by: .seconds(2))
        await store.receive(\.refreshResponse) {
            $0.refresh = .failed(.server(status: 503))
        }

        await store.send(.retryButtonTapped) {
            $0.refresh = .loading(isSlow: false)
        }
        await clock.advance(by: .seconds(3))
        await store.receive(\.slowHintTimerFired) {
            $0.refresh = .loading(isSlow: true)
        }
        await clock.advance(by: .seconds(2))
        await store.receive(\.refreshResponse) {
            $0.product = current
            $0.refresh = .updated
        }
    }

    @Test func serverErrorKeepsTheProductAddableAndNothingRetriesByItself() async {
        let transport = StubDataTransfer.answering(503, "")
        let store = TestStore(initialState: ProductDetailFeature.State(product: racket)) {
            ProductDetailFeature()
        } withDependencies: {
            $0.continuousClock = TestClock()
            $0.productsClient = .liveValue
            $0.dataTransfer = transport
        }

        await store.send(.onAppear) {
            $0.refresh = .loading(isSlow: false)
        }
        await store.receive(\.refreshResponse) {
            $0.refresh = .failed(.server(status: 503))
        }
        await store.send(.onAppear)
        #expect(transport.requests.count == 1, "Coming back to the screen must not retry")

        await store.send(.addToBasketButtonTapped) {
            $0.$basket.withLock { $0 = Basket(lines: [BasketLine(product: self.racket, quantity: 5)]) }
        }
        #expect(store.state.basketControl.title == "5 in basket")
    }

    @Test func leavingTheScreenCancelsItsRequest() async {
        let cancelled = LockIsolated(false)
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.continuousClock = TestClock()
            $0.productsClient.product = { _ in
                do {
                    return try await Task<Product, Never>.never()
                } catch {
                    cancelled.setValue(error is CancellationError)
                    throw error
                }
            }
        }

        await store.send(.catalog(.delegate(.productTapped(racket)))) {
            $0.path[id: 0] = .detail(ProductDetailFeature.State(product: self.racket))
        }
        await store.send(\.path[id: 0].detail.onAppear) {
            $0.path[id: 0, case: \.detail]?.refresh = .loading(isSlow: false)
        }
        await store.send(.path(.popFrom(id: 0))) {
            $0.path.removeAll()
        }
        // Fails if the request or the slow-hint timer is still running.
        await store.finish()
        #expect(cancelled.value, "The product request must not outlive the screen")
    }
}
