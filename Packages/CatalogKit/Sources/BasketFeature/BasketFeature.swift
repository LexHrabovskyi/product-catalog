import Basket
import ComposableArchitecture
import SwiftUI

@Reducer
public struct BasketFeature {
    @ObservableState
    public struct State: Equatable {
        @Shared(.basket) public var basket

        public init() {}
    }

    public enum Action {}

    public init() {}

    public var body: some ReducerOf<Self> {
        EmptyReducer()
    }
}

public struct BasketView: View {
    let store: StoreOf<BasketFeature>

    public init(store: StoreOf<BasketFeature>) {
        self.store = store
    }

    public var body: some View {
        ContentUnavailableView("Basket", systemImage: "basket", description: Text("\(store.basket.lineCount) products"))
            .navigationTitle("Basket")
    }
}

#Preview {
    NavigationStack {
        BasketView(store: Store(initialState: BasketFeature.State()) { BasketFeature() })
    }
}
