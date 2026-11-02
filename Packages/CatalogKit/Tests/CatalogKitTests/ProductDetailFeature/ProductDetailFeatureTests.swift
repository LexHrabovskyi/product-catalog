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

    @Test func opensWithTheTappedProductThenUpdatesItInPlaceKeepingTheChosenQuantity() async {
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
        await store.send(.binding(.set(\.quantity, 9))) {
            $0.quantity = 9
        }
        await clock.advance(by: .seconds(1))
        await store.receive(\.refreshResponse) {
            $0.product = current
            $0.refresh = .updated
        }
        #expect(requested.value == [152])

        await store.send(.addToBasketButtonTapped) {
            $0.$basket.withLock {
                $0 = Basket(lines: [
                    BasketLine(
                        productID: 152, title: "Tennis Racket Pro", thumbnail: nil, price: 55, discountPercentage: 0,
                        stock: 30, minimumOrderQuantity: 5, quantity: 9
                    ),
                ])
            }
            $0.addOutcome = .added(quantity: 9)
        }
        #expect(store.state.addMessage == "Added · 9 in basket")
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

    @Test func notFoundMeansTheProductIsGoneAndNothingCanBeAdded() async {
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
        #expect(store.state.quantityRange == nil, "Adding must be disabled")

        await store.send(.addToBasketButtonTapped)
        #expect(store.state.basket.lines.isEmpty)
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
            $0.addOutcome = .added(quantity: 5)
        }
    }

    @Test func eachAddLandsInTheSharedBasketAndAddingPastStockIsCapped() async {
        let lamp = Product(id: 7, title: "Lamp", category: "furniture", price: 20, stock: 7, minimumOrderQuantity: 2)
        let store = TestStore(initialState: ProductDetailFeature.State(product: lamp)) {
            ProductDetailFeature()
        }
        @Shared(.basket) var basketElsewhere
        #expect(store.state.quantity == 2, "The stepper starts at the minimum order")
        #expect(store.state.quantityRange == 2...7)

        await store.send(.addToBasketButtonTapped) {
            $0.$basket.withLock { $0 = Basket(lines: [BasketLine(product: lamp, quantity: 2)]) }
            $0.addOutcome = .added(quantity: 2)
        }
        #expect(store.state.addMessage == "Added · 2 in basket")
        #expect(basketElsewhere.line(forProduct: 7)?.quantity == 2)

        await store.send(.binding(.set(\.quantity, 6))) {
            $0.quantity = 6
        }
        await store.send(.addToBasketButtonTapped) {
            $0.$basket.withLock { $0 = Basket(lines: [BasketLine(product: lamp, quantity: 7)]) }
            $0.addOutcome = .capped(stock: 7)
        }
        #expect(store.state.addMessage == "Only 7 in stock")
        #expect(basketElsewhere.line(forProduct: 7)?.quantity == 7)
    }

    @Test(arguments: [
        (stock: 0, minimum: 1, title: "Out of stock"),
        (stock: 3, minimum: 5, title: "Only 3 in stock — minimum order is 5"),
    ])
    func unorderableProductCannotBeAddedAndSaysWhy(stock: Int, minimum: Int, title: String) async {
        let volleyball = Product(
            id: 153, title: "Volleyball", category: "sports-accessories", price: 12, stock: stock,
            minimumOrderQuantity: minimum
        )
        let store = TestStore(initialState: ProductDetailFeature.State(product: volleyball)) {
            ProductDetailFeature()
        }
        store.exhaustivity = .off

        #expect(store.state.addButtonTitle == title)
        #expect(store.state.quantityRange == nil, "Adding must be disabled")

        await store.send(.addToBasketButtonTapped)
        #expect(store.state.basket.lines.isEmpty)
        #expect(store.state.addMessage == nil)
    }

    @Test(arguments: Reclamp.cases)
    func refreshThatMovesStockOrMinimumReclampsTheQuantity(_ reclamp: Reclamp) async {
        let store = TestStore(initialState: ProductDetailFeature.State(product: reclamp.shown)) {
            ProductDetailFeature()
        } withDependencies: {
            $0.continuousClock = TestClock()
            $0.productsClient.product = { _ in reclamp.refreshed }
        }
        if let chosen = reclamp.chosen {
            await store.send(.binding(.set(\.quantity, chosen))) {
                $0.quantity = chosen
            }
        }

        await store.send(.onAppear) {
            $0.refresh = .loading(isSlow: false)
        }
        await store.receive(\.refreshResponse) {
            $0.product = reclamp.refreshed
            $0.refresh = .updated
            $0.quantity = reclamp.expected
        }
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

    struct Reclamp: Sendable, CustomTestStringConvertible {
        let testDescription: String
        let shown: Product
        let chosen: Int?
        let refreshed: Product
        let expected: Int

        static let cases = [
            Reclamp(
                testDescription: "stock falls below the chosen quantity",
                shown: lemon(stock: 20, minimum: 2), chosen: 15, refreshed: lemon(stock: 8, minimum: 2), expected: 8
            ),
            Reclamp(
                testDescription: "minimum rises above the chosen quantity",
                shown: lemon(stock: 20, minimum: 2), chosen: nil, refreshed: lemon(stock: 20, minimum: 5), expected: 5
            ),
            Reclamp(
                testDescription: "an out-of-stock product comes back",
                shown: lemon(stock: 0, minimum: 1), chosen: nil, refreshed: lemon(stock: 20, minimum: 4), expected: 4
            ),
        ]

        private static func lemon(stock: Int, minimum: Int) -> Product {
            Product(id: 31, title: "Lemon", category: "groceries", price: 1, stock: stock, minimumOrderQuantity: minimum)
        }
    }
}
