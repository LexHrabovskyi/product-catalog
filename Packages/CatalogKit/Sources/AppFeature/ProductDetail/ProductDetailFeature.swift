import Basket
import Catalog
import ComposableArchitecture
import Foundation
import os
import Presentation

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ProductCatalog", category: "detail")

@Reducer
public struct ProductDetailFeature {
    @ObservableState
    public struct State: Equatable {
        public var product: Product
        public var refresh: Refresh = .notRequested
        @Shared(.basket) public var basket

        public init(product: Product) {
            self.product = product
        }
    }

    public enum Refresh: Equatable {
        case notRequested
        case loading(isSlow: Bool)
        case updated
        case failed(CatalogError)
        /// The catalog answered that the product no longer exists.
        case gone
    }

    /// What the floating basket control shows.
    public enum BasketControl: Equatable {
        /// The catalog answered that the product no longer exists, even when it's in the basket.
        case gone
        /// A stepper on the product's basket line.
        case inBasket(BasketLine)
        /// "Add to basket" while the product can be added; otherwise the reason it can't.
        case notInBasket(Basket.Availability)
    }

    public enum Action {
        case onAppear
        case retryButtonTapped
        case refreshResponse(Result<Product, CatalogError>)
        case slowHintTimerFired
        case addToBasketButtonTapped
        case incrementButtonTapped
        case decrementButtonTapped
        case removeButtonTapped
    }

    enum CancelID {
        case refresh
        case slowHint
    }

    @Dependency(\.productsClient) var productsClient
    @Dependency(\.continuousClock) var clock

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                // Once per screen: coming back to it must not retry a failed refresh.
                guard state.refresh == .notRequested else { return .none }
                return refresh(&state)

            case .retryButtonTapped:
                return refresh(&state)

            case let .refreshResponse(.success(product)):
                state.product = product
                state.refresh = .updated
                logger.info("Product \(product.id) updated")
                return .cancel(id: CancelID.slowHint)

            case let .refreshResponse(.failure(error)):
                let id = state.product.id
                if error == .notFound {
                    logger.notice("Product \(id) is no longer in the catalog")
                    state.refresh = .gone
                } else {
                    logger.error("Refreshing product \(id) failed: \(String(describing: error), privacy: .public)")
                    state.refresh = .failed(error)
                }
                return .cancel(id: CancelID.slowHint)

            case .slowHintTimerFired:
                guard case .loading = state.refresh else { return .none }
                let id = state.product.id
                logger.info("Refreshing product \(id) is slow")
                state.refresh = .loading(isSlow: true)
                return .none

            case .addToBasketButtonTapped:
                // Adds the minimum once: from then on the product has a line, and the control is its stepper.
                guard case let .notInBasket(.available(range)) = state.basketControl else { return .none }
                let product = state.product
                let outcome = state.$basket.withLock { $0.add(product, quantity: range.lowerBound) }
                logger.info("Adding product \(product.id) to the basket: \(String(describing: outcome), privacy: .public)")
                return .none

            case .incrementButtonTapped:
                changeQuantity(&state, by: 1)
                return .none

            case .decrementButtonTapped:
                changeQuantity(&state, by: -1)
                return .none

            case .removeButtonTapped:
                guard case let .inBasket(line) = state.basketControl else { return .none }
                state.$basket.withLock { $0.remove(productID: line.productID) }
                logger.info("Removed product \(line.productID), quantity \(line.quantity), from the basket")
                return .none
            }
        }
    }

    /// Steps the line's quantity within its minimum…stock; a step past either end does nothing.
    private func changeQuantity(_ state: inout State, by step: Int) {
        guard case let .inBasket(line) = state.basketControl, line.quantityRange.contains(line.quantity + step) else {
            return
        }
        let quantity = line.quantity + step
        state.$basket.withLock { $0.setQuantity(quantity, forProduct: line.productID) }
        logger.info("Product \(line.productID) quantity \(line.quantity) → \(quantity)")
    }

    private func refresh(_ state: inout State) -> Effect<Action> {
        state.refresh = .loading(isSlow: false)
        return .merge(
            .run { [id = state.product.id, productsClient] send in
                let result: Result<Product, CatalogError>
                do {
                    result = .success(try await productsClient.product(id: id))
                } catch let error as CatalogError {
                    result = .failure(error)
                }
                await send(.refreshResponse(result))
            }
            .cancellable(id: CancelID.refresh, cancelInFlight: true),
            .run { [clock] send in
                try await clock.sleep(for: .seconds(3))
                await send(.slowHintTimerFired)
            }
            .cancellable(id: CancelID.slowHint, cancelInFlight: true)
        )
    }
}

extension ProductDetailFeature.State {
    /// A gone product wins over its basket line, and a basket line wins over availability.
    public var basketControl: ProductDetailFeature.BasketControl {
        if refresh == .gone { return .gone }
        if let line = basket.line(forProduct: product.id) { return .inBasket(line) }
        return .notInBasket(Basket.availability(of: product))
    }
}

extension ProductDetailFeature.BasketControl {
    /// The button's title, or the stepper's count.
    public var title: String {
        switch self {
        case .gone: CatalogError.notFound.message
        case let .inBasket(line): "\(line.quantity) in basket"
        case let .notInBasket(.available(range)): range.lowerBound > 1 ? "Add \(range.lowerBound) to basket" : "Add to basket"
        case .notInBasket(.outOfStock): "Out of stock"
        case let .notInBasket(.belowMinimumOrder(stock, minimum)): "Only \(stock) in stock — minimum order is \(minimum)"
        }
    }
}
