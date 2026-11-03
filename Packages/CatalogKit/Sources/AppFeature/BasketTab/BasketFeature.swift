import Basket
import ComposableArchitecture
import Foundation
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ProductCatalog", category: "basket")

@Reducer
public struct BasketFeature {
    @ObservableState
    public struct State: Equatable {
        @Shared(.basket) public var basket
        @Presents public var alert: AlertState<Action.Alert>?

        public init() {}
    }

    public enum Action {
        case alert(PresentationAction<Alert>)
        case clearButtonTapped
        case quantityChanged(id: BasketLine.ID, quantity: Int)
        case removeButtonTapped(id: BasketLine.ID)
        case lineTapped(id: BasketLine.ID)
        case delegate(Delegate)

        public enum Alert: Equatable {
            case confirmClear
        }

        @CasePathable
        public enum Delegate: Equatable {
            case productTapped(BasketLine)
        }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .alert(.presented(.confirmClear)):
                let lineCount = state.basket.lineCount
                state.$basket.withLock { $0.removeAll() }
                logger.info("Cleared the basket, lines removed: \(lineCount)")
                return .none

            case .alert:
                return .none

            case .clearButtonTapped:
                let lineCount = state.basket.lineCount
                state.alert = AlertState {
                    TextState("Clear basket?")
                } actions: {
                    ButtonState(role: .destructive, action: .confirmClear) {
                        TextState("Clear")
                    }
                    ButtonState(role: .cancel) {
                        TextState("Cancel")
                    }
                } message: {
                    lineCount == 1 ? TextState("Remove 1 product?") : TextState("Remove all \(lineCount) products?")
                }
                return .none

            case let .quantityChanged(id, quantity):
                state.$basket.withLock { $0.setQuantity(quantity, forProduct: id) }
                return .none

            case let .removeButtonTapped(id):
                state.$basket.withLock { $0.remove(productID: id) }
                logger.info("Removed product \(id) from the basket")
                return .none

            case let .lineTapped(id):
                guard let line = state.basket.line(forProduct: id) else { return .none }
                return .send(.delegate(.productTapped(line)))

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
