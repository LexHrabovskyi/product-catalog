import ComposableArchitecture
import Models
import SharedUI
import SwiftUI

public struct ProductListView: View {
    @Bindable var store: StoreOf<ProductListFeature>

    public init(store: StoreOf<ProductListFeature>) {
        self.store = store
    }

    public var body: some View {
        // Search and toolbar sit outside the phase switch, so the search field survives content changes.
        content
            .navigationTitle("Catalog")
            .searchable(text: $store.searchText.sending(\.searchTextChanged), prompt: "Search products")
            // Sort stays reachable during a search; the bar would otherwise hide it.
            .searchPresentationToolbarBehavior(.avoidHidingContent)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { categoryMenu }
                ToolbarItem(placement: .topBarTrailing) { sortMenu }
                ToolbarItem(placement: .topBarTrailing) { basketButton }
            }
            .onAppear { store.send(.onAppear) }
    }

    @ViewBuilder
    private var content: some View {
        switch store.phase {
        case .loading:
            skeleton
        case let .failed(error):
            ErrorStateView(error: error, identifier: "catalog.error") { store.send(.retryTapped) }
        case .loaded where store.products.isEmpty:
            emptyState
        case .loaded:
            productList
        }
    }

    private var skeleton: some View {
        List {
            if store.isSlow {
                SlowConnectionHint()
            }
            ForEach(0..<8, id: \.self) { _ in
                ProductRow(product: .skeleton)
            }
            .redacted(reason: .placeholder)
            .accessibilityHidden(true)
        }
        .listStyle(.plain)
        .scrollDisabled(true)
    }

    private var productList: some View {
        List {
            if let error = store.refreshError {
                InlineRetryNotice(title: "Couldn't refresh", error: error, identifier: "catalog.refresh") {
                    store.send(.refreshRetryTapped)
                }
                .disabled(store.inFlight == .refresh)
                .listRowSeparator(.hidden)
            }
            if store.inFlight == .refresh, store.isSlow {
                SlowConnectionHint()
                    .listRowSeparator(.hidden)
            }
            ForEach(store.products) { product in
                Button {
                    store.send(.rowTapped(product))
                } label: {
                    ProductRow(product: product)
                }
                .accessibilityIdentifier("catalog.row.\(product.id)")
                .onAppear { store.send(.rowAppeared(product.id)) }
            }
            footer
        }
        .listStyle(.plain)
        .accessibilityIdentifier("catalog.list")
        .refreshable { await store.send(.refreshPulled).finish() }
    }

    private var footer: some View {
        Group {
            if store.inFlight == .nextPage {
                HStack(spacing: 8) {
                    ProgressView()
                        .accessibilityIdentifier("catalog.footer.spinner")
                    if store.isSlow {
                        SlowConnectionHint()
                    }
                }
            } else if let error = store.nextPageError {
                VStack(spacing: 8) {
                    Text("Couldn't load more")
                        .font(.subheadline.weight(.semibold))
                    Text(error.message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Try again") { store.send(.loadMoreRetryTapped) }
                        .buttonStyle(.bordered)
                        .disabled(store.inFlight != nil)
                        .accessibilityIdentifier("catalog.footer.retry")
                }
                .padding(.vertical, 8)
            } else if store.isComplete {
                Text("All ^[\(store.products.count) product](inflect: true)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("catalog.footer.end")
            }
        }
        .frame(maxWidth: .infinity)
        .listRowSeparator(.hidden)
    }

    private var emptyState: some View {
        Group {
            if let query = store.searchQuery {
                ContentUnavailableView {
                    Label("No products match “\(query)”", systemImage: "magnifyingglass")
                } actions: {
                    Button("Clear search") { store.send(.searchTextChanged("")) }
                        .buttonStyle(.bordered)
                }
            } else if let category = store.category {
                ContentUnavailableView("No products in \(category.name)", systemImage: "tray")
            } else {
                ContentUnavailableView("No products yet", systemImage: "shippingbox")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("catalog.empty")
    }

    private var categoryMenu: some View {
        Menu(categoryTitle) {
            Picker("Category", selection: $store.category.sending(\.categorySelected)) {
                Text("All categories").tag(ProductCategory?.none)
                if case let .loaded(categories) = store.categories {
                    ForEach(categories) { category in
                        Text(category.name).tag(Optional(category))
                    }
                }
            }
            switch store.categories {
            case .loading:
                Text("Loading categories…")
            case .failed:
                Section("Couldn't load categories") {
                    Button("Retry", systemImage: "arrow.clockwise") { store.send(.categoriesRetryTapped) }
                }
            case .loaded:
                EmptyView()
            }
        }
        .disabled(store.searchQuery != nil)
        .accessibilityLabel("Category")
        .accessibilityValue(categoryTitle)
        .accessibilityIdentifier("catalog.categoryMenu")
    }

    /// A search spans every category, so the control reads "All categories" while one runs.
    private var categoryTitle: String {
        guard store.searchQuery == nil, let category = store.category else { return "All categories" }
        return category.name
    }

    private var sortMenu: some View {
        Menu("Sort", systemImage: "arrow.up.arrow.down") {
            Picker("Sort", selection: $store.sort.sending(\.sortSelected)) {
                ForEach(SortOption.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
        }
        .accessibilityValue(store.sort.title)
        .accessibilityIdentifier("catalog.sortMenu")
    }

    private var basketButton: some View {
        Button("Basket", systemImage: "basket") { store.send(.basketButtonTapped) }
            .badge(store.basket.lineCount)
            .accessibilityIdentifier("catalog.basketButton")
    }
}

#Preview {
    NavigationStack {
        ProductListView(store: Store(initialState: ProductListFeature.State()) { ProductListFeature() })
    }
}
