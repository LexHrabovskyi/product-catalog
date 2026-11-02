import ComposableArchitecture
import Models
import ProductsClient
import SharedUI
import SwiftUI

public struct ProductDetailView: View {
    @Bindable var store: StoreOf<ProductDetailFeature>

    public init(store: StoreOf<ProductDetailFeature>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Gallery(images: store.product.images)
                summary
                Text(store.product.description)
                InventoryFacts(product: store.product)
                ReviewList(reviews: store.product.reviews)
            }
            .padding()
        }
        .safeAreaInset(edge: .top) { refreshStatus }
        .safeAreaInset(edge: .bottom) { addToBasketBar }
        .navigationTitle(store.product.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if case .loading = store.refresh {
                ToolbarItem(placement: .topBarTrailing) {
                    ProgressView().accessibilityLabel("Updating")
                }
            }
        }
        .onAppear { store.send(.onAppear) }
    }

    @ViewBuilder private var refreshStatus: some View {
        switch store.refresh {
        case .loading(isSlow: true):
            SlowConnectionHint()
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: Capsule())
                .padding(.top, 8)
        case let .failed(error):
            InlineRetryNotice(title: "Couldn't update", error: error, identifier: "detail.updateNotice") {
                store.send(.retryButtonTapped)
            }
            .padding([.horizontal, .top])
        case .notRequested, .loading, .updated, .gone:
            EmptyView()
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.product.title)
                .font(.title2.bold())
            Text(store.product.brand ?? store.product.categoryName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            PriceView(price: store.product.price, discountPercentage: store.product.discountPercentage, style: .detail)
            RatingSummary(rating: store.product.rating, reviewCount: store.product.reviews.count)
        }
    }

    private var addToBasketBar: some View {
        VStack(spacing: 12) {
            if store.refresh == .gone {
                Text(CatalogError.notFound.message)
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("detail.unavailable")
            } else if let message = store.addMessage {
                Text(message)
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("detail.addMessage")
            }
            if let range = store.quantityRange {
                QuantityStepper(quantity: $store.quantity, range: range)
                    .accessibilityIdentifier("detail.quantity")
            }
            Button {
                store.send(.addToBasketButtonTapped)
                if let message = store.addMessage {
                    AccessibilityNotification.Announcement(message).post()
                }
            } label: {
                Text(store.addButtonTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(store.quantityRange == nil)
            .accessibilityIdentifier("detail.addToBasket")
        }
        .multilineTextAlignment(.center)
        .padding()
        .background(.bar)
    }
}

#Preview("Discounted") {
    NavigationStack {
        ProductDetailView(
            store: Store(initialState: ProductDetailFeature.State(product: Product.fixtures[0])) {
                ProductDetailFeature()
            }
        )
    }
}

#Preview("Below minimum, no brand") {
    NavigationStack {
        ProductDetailView(
            store: Store(initialState: ProductDetailFeature.State(product: Product.fixtures[2])) {
                ProductDetailFeature()
            }
        )
    }
}

#Preview("Couldn't update") {
    NavigationStack {
        ProductDetailView(
            store: Store(initialState: ProductDetailFeature.State(product: Product.fixtures[1])) {
                ProductDetailFeature()
            } withDependencies: {
                $0.productsClient.product = { _ in throw CatalogError.server(status: 503) }
            }
        )
    }
}
