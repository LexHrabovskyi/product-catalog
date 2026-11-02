import Basket
import ComposableArchitecture
import Foundation
import Models
import os
import ProductsClient

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ProductCatalog", category: "detail")

@Reducer
public struct ProductDetailFeature {
    @ObservableState
    public struct State: Equatable {
        public var product: Product
        public var quantity: Int
        public var refresh: Refresh = .notRequested
        /// What the last "Add to basket" tap did, until the next tap.
        public var addOutcome: Basket.AddOutcome?
        @Shared(.basket) public var basket

        public init(product: Product) {
            self.product = product
            self.quantity = max(product.minimumOrderQuantity, 1)
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

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case retryButtonTapped
        case refreshResponse(Result<Product, CatalogError>)
        case slowHintTimerFired
        case addToBasketButtonTapped
    }

    enum CancelID {
        case refresh
        case slowHint
    }

    @Dependency(\.productsClient) var productsClient
    @Dependency(\.continuousClock) var clock

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
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
                if let range = state.quantityRange {
                    state.quantity = min(max(state.quantity, range.lowerBound), range.upperBound)
                }
                let quantity = state.quantity
                logger.info("Product \(product.id) updated; quantity \(quantity)")
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
                guard state.refresh != .gone else { return .none }
                let product = state.product
                let quantity = state.quantity
                let outcome = state.$basket.withLock { $0.add(product, quantity: quantity) }
                state.addOutcome = outcome
                logger.info("Adding \(quantity) of product \(product.id): \(String(describing: outcome), privacy: .public)")
                return .none

            case .binding:
                return .none
            }
        }
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
    /// The quantities the stepper offers; `nil` while the product can't be added.
    public var quantityRange: ClosedRange<Int>? {
        guard refresh != .gone, case let .available(range) = Basket.availability(of: product) else { return nil }
        return range
    }

    public var addButtonTitle: String {
        // A product that no longer exists has no stock worth quoting.
        guard refresh != .gone else { return "Add to basket" }
        return switch Basket.availability(of: product) {
        case .available: "Add to basket"
        case .outOfStock: "Out of stock"
        case let .belowMinimumOrder(stock, minimum): "Only \(stock) in stock — minimum order is \(minimum)"
        }
    }

    public var addMessage: String? {
        switch addOutcome {
        case let .added(quantity): "Added · \(quantity) in basket"
        case let .capped(stock): "Only \(stock) in stock"
        case .refused, nil: nil
        }
    }
}
