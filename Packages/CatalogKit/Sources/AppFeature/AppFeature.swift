import Basket
import Catalog
import ComposableArchitecture
import Foundation
import os
import SwiftUI

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ProductCatalog", category: "basket")

@Reducer
public struct AppFeature {
    @Reducer
    public enum Path {
        case detail(ProductDetailFeature)
    }

    public enum Tab: Hashable, Sendable {
        case catalog
        case basket
    }

    @ObservableState
    public struct State: Equatable {
        public var selectedTab: Tab = .catalog
        public var catalog = ProductListFeature.State()
        public var path = StackState<Path.State>()
        public var basketTab = BasketFeature.State()
        @Shared(.basket) public var basket

        public init() {}
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case catalog(ProductListFeature.Action)
        case path(StackActionOf<Path>)
        case basketTab(BasketFeature.Action)
        case launched
        case scenePhaseChanged(ScenePhase)
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Scope(\.catalog, action: \.catalog) {
            ProductListFeature()
        }
        Scope(\.basketTab, action: \.basketTab) {
            BasketFeature()
        }
        Reduce { state, action in
            switch action {
            case let .catalog(.delegate(.productTapped(product))):
                state.path.append(.detail(ProductDetailFeature.State(product: product)))
                return .none

            case let .basketTab(.delegate(.productTapped(line))):
                // The catalog shows just this product, so Back returns to the list.
                state.selectedTab = .catalog
                state.path = StackState([.detail(ProductDetailFeature.State(product: Product(line)))])
                return .none

            case .launched:
                if let error = state.$basket.loadError {
                    logger.warning("Stored basket unreadable, starting empty: \(String(describing: error), privacy: .public)")
                }
                return .none

            case .scenePhaseChanged(.background):
                // Shared file storage writes a second after a change, and a suspended app may never get that second.
                return .run { [basket = state.$basket] _ in
                    do {
                        try await basket.save()
                    } catch {
                        logger.error("Saving the basket on background failed: \(String(describing: error), privacy: .public)")
                    }
                }

            case .binding, .catalog, .path, .basketTab, .scenePhaseChanged:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }
}

extension AppFeature.Path.State: Equatable {}

extension AppFeature {
    @MainActor
    public static func makeStore() -> StoreOf<AppFeature> {
        Store(initialState: State()) { AppFeature() }
    }
}

public struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>
    @Environment(\.scenePhase) private var scenePhase

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        TabView(selection: $store.selectedTab) {
            SwiftUI.Tab("Catalog", systemImage: "list.bullet", value: AppFeature.Tab.catalog) {
                NavigationStack(path: $store.scope(\.path, action: \.path)) {
                    ProductListView(store: store.scope(\.catalog, action: \.catalog))
                } destination: { store in
                    switch store.case {
                    case let .detail(store):
                        ProductDetailView(store: store)
                    }
                }
            }
            .accessibilityIdentifier("tab.catalog")

            SwiftUI.Tab("Basket", systemImage: "basket", value: AppFeature.Tab.basket) {
                NavigationStack {
                    BasketView(store: store.scope(\.basketTab, action: \.basketTab))
                }
            }
            .badge(store.basket.lineCount)
            .accessibilityValue(basketTabValue)
            .accessibilityIdentifier("tab.basket")
        }
        .task { store.send(.launched) }
        .onChange(of: scenePhase) { _, phase in
            store.send(.scenePhaseChanged(phase))
        }
    }

    /// The tab bar's badge isn't read by VoiceOver, so the tab says the count itself.
    private var basketTabValue: String {
        switch store.basket.lineCount {
        case 0: ""
        case 1: "1 product"
        case let count: "\(count) products"
        }
    }
}

private extension Product {
    /// The basket's copy of a product: enough for the detail screen until its refresh arrives.
    init(_ line: BasketLine) {
        self.init(
            id: line.productID,
            title: line.title,
            category: "",
            price: line.price,
            discountPercentage: line.discountPercentage,
            stock: line.stock,
            minimumOrderQuantity: line.minimumOrderQuantity,
            thumbnail: line.thumbnail
        )
    }
}
