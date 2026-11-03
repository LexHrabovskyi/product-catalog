import Basket
import ComposableArchitecture
import Models
import ProductsClient
import SharedUI
import SwiftUI

public struct ProductDetailView: View {
    let store: StoreOf<ProductDetailFeature>

    public init(store: StoreOf<ProductDetailFeature>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Gallery(images: store.product.images)
                summary
                ProductDescription(text: store.product.description)
                InventoryFacts(product: store.product)
                ReviewList(reviews: store.product.reviews)
            }
            .padding()
        }
        .safeAreaInset(edge: .top) { refreshStatus }
        .safeAreaBar(edge: .bottom) {
            basketControl
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
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
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(.bar)
        case let .failed(error):
            InlineRetryNotice(title: "Couldn't update", error: error, identifier: "detail.updateNotice") {
                store.send(.retryButtonTapped)
            }
            .padding([.horizontal, .top])
            .padding(.bottom, 8)
            .background(.bar)
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

    /// "Add to basket" until the product has a basket line, then a stepper on that line.
    @ViewBuilder private var basketControl: some View {
        let control = store.basketControl
        if case let .inBasket(line) = control {
            HStack {
                if line.quantity > line.quantityRange.lowerBound {
                    iconButton("Decrease quantity", systemImage: "minus") {
                        store.send(.decrementButtonTapped)
                    }
                    .accessibilityIdentifier("detail.quantity.decrement")
                } else {
                    iconButton("Remove from basket", systemImage: "trash", role: .destructive) {
                        withAnimation { _ = store.send(.removeButtonTapped) }
                        announce("Removed from basket")
                    }
                    .accessibilityIdentifier("detail.quantity.remove")
                }
                Text(control.title)
                    .font(.headline)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("detail.quantity")
                iconButton("Increase quantity", systemImage: "plus") {
                    store.send(.incrementButtonTapped)
                }
                .disabled(line.quantity >= line.quantityRange.upperBound)
                .accessibilityIdentifier("detail.quantity.increment")
            }
            .padding(4)
            .glassEffect(.regular.interactive())
        } else {
            let isAddable = if case .notInBasket(.available) = control { true } else { false }
            Button {
                withAnimation { _ = store.send(.addToBasketButtonTapped) }
                if case let .inBasket(line) = store.basketControl {
                    announce("Added, \(line.quantity) in basket")
                }
            } label: {
                Text(control.title)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(!isAddable)
            .accessibilityIdentifier("detail.addToBasket")
        }
    }

    private func iconButton(
        _ title: String,
        systemImage: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .font(.title3)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.circle)
        }
    }

    /// High priority, so VoiceOver moving to the swapped-in control doesn't cut it off.
    private func announce(_ message: String) {
        var announcement = AttributedString(message)
        announcement.accessibilitySpeechAnnouncementPriority = .high
        AccessibilityNotification.Announcement(announcement).post()
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

#Preview("In the basket") {
    let _ = Shared(.basket).withLock {
        $0 = Basket(lines: [BasketLine(product: Product.fixtures[1], quantity: 2)])
    }
    NavigationStack {
        ProductDetailView(
            store: Store(initialState: ProductDetailFeature.State(product: Product.fixtures[1])) {
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
