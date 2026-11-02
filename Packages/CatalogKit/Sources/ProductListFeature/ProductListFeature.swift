import ComposableArchitecture
import Models
import SwiftUI

@Reducer
public struct ProductListFeature {
    @ObservableState
    public struct State: Equatable {
        public init() {}
    }

    public enum Action {
        case delegate(Delegate)

        @CasePathable
        public enum Delegate {
            case productTapped(Product)
            case basketButtonTapped
        }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        EmptyReducer()
    }
}

public struct ProductListView: View {
    let store: StoreOf<ProductListFeature>

    public init(store: StoreOf<ProductListFeature>) {
        self.store = store
    }

    public var body: some View {
        ContentUnavailableView("Catalog", systemImage: "list.bullet")
            .navigationTitle("Catalog")
    }
}

#Preview {
    NavigationStack {
        ProductListView(store: Store(initialState: ProductListFeature.State()) { ProductListFeature() })
    }
}
