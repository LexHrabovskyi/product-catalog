import ComposableArchitecture
import Models
import ProductsClient
import SwiftUI

@Reducer
public struct ProductDetailFeature {
    @ObservableState
    public struct State: Equatable {
        public var product: Product

        public init(product: Product) {
            self.product = product
        }
    }

    public enum Action {}

    public init() {}

    public var body: some ReducerOf<Self> {
        EmptyReducer()
    }
}

public struct ProductDetailView: View {
    let store: StoreOf<ProductDetailFeature>

    public init(store: StoreOf<ProductDetailFeature>) {
        self.store = store
    }

    public var body: some View {
        ContentUnavailableView(store.product.title, systemImage: "shippingbox")
            .navigationTitle(store.product.title)
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ProductDetailView(
            store: Store(initialState: ProductDetailFeature.State(product: Product.fixtures[0])) {
                ProductDetailFeature()
            }
        )
    }
}
