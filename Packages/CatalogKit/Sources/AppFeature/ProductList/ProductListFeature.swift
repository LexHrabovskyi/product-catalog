import Catalog
import ComposableArchitecture
import Foundation
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ProductCatalog", category: "list")

@Reducer
public struct ProductListFeature {
    @ObservableState
    public struct State: Equatable {
        public var products: IdentifiedArrayOf<Product> = []
        public var phase: Phase = .loading
        /// The one page request in flight. A new page 1 or refresh replaces it; a next page waits for it.
        public var inFlight: PageRequest?
        /// Where the next page starts. A failure leaves it in place, so "Try again" asks for the same page.
        public var nextSkip = 0
        public var isComplete = false
        public var nextPageError: CatalogError?
        public var refreshError: CatalogError?
        /// The request in flight has taken 3 s.
        public var isSlow = false
        public var searchText = ""
        /// The trimmed query the list shows; `nil` while browsing.
        public var searchQuery: String?
        /// `nil` shows every category. A search spans every category, so running one resets it.
        public var category: ProductCategory?
        public var sort: SortOption = .default
        public var categories: Categories = .loading

        public init() {}

        var scope: ProductQuery.Scope {
            if let searchQuery {
                .search(searchQuery)
            } else if let category {
                .category(slug: category.slug)
            } else {
                .all
            }
        }
    }

    public enum Phase: Equatable, Sendable {
        /// Page 1 is on its way; skeleton rows show.
        case loading
        case failed(CatalogError)
        /// Rows, or the empty state when there are none.
        case loaded
    }

    public enum PageRequest: Equatable, Sendable {
        case firstPage
        case nextPage
        case refresh
    }

    public enum Categories: Equatable, Sendable {
        case loading
        case loaded([ProductCategory])
        case failed(CatalogError)
    }

    public enum Action {
        case onAppear
        case rowAppeared(Product.ID)
        case rowTapped(Product)
        case retryTapped
        case loadMoreRetryTapped
        case refreshPulled
        case refreshRetryTapped
        case searchTextChanged(String)
        case searchDebounced(String)
        case categorySelected(ProductCategory?)
        case sortSelected(SortOption)
        case categoriesRetryTapped
        case pageResponse(PageRequest, Result<ProductPage, CatalogError>)
        case categoriesResponse(Result<[ProductCategory], CatalogError>)
        case slowHintTimerFired
        case delegate(Delegate)

        @CasePathable
        public enum Delegate {
            case productTapped(Product)
        }
    }

    private enum CancelID {
        case page
        case slowHint
        case search
    }

    @Dependency(\.productsClient) var productsClient
    @Dependency(\.continuousClock) var clock

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                // Only the first appearance loads; coming back from a detail or another tab keeps the list.
                guard state.phase == .loading, state.inFlight == nil else { return .none }
                return .merge(loadFirstPage(&state), loadCategories())

            case let .rowAppeared(id):
                guard
                    state.inFlight == nil, state.nextPageError == nil, !state.isComplete,
                    let index = state.products.index(id: id), index >= state.products.count - 5
                else { return .none }
                return start(.nextPage, &state)

            case let .rowTapped(product):
                return .send(.delegate(.productTapped(product)))

            case .retryTapped:
                return loadFirstPage(&state)

            case .loadMoreRetryTapped:
                guard state.inFlight == nil else { return .none }
                state.nextPageError = nil
                return start(.nextPage, &state)

            case .refreshPulled, .refreshRetryTapped:
                guard state.phase == .loaded else { return .none }
                return start(.refresh, &state)

            case let .searchTextChanged(text):
                state.searchText = text
                let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if query == state.searchQuery ?? "" {
                    return .cancel(id: CancelID.search)
                }
                if query.isEmpty {
                    state.searchQuery = nil
                    return .merge(.cancel(id: CancelID.search), loadFirstPage(&state))
                }
                return .run { [clock] send in
                    try await clock.sleep(for: .milliseconds(300))
                    logger.info("Searching for \(query, privacy: .private)")
                    await send(.searchDebounced(query))
                }
                .cancellable(id: CancelID.search, cancelInFlight: true)

            case let .searchDebounced(query):
                state.searchQuery = query
                state.category = nil
                return loadFirstPage(&state)

            case let .categorySelected(category):
                guard state.searchQuery == nil, category != state.category else { return .none }
                state.category = category
                return loadFirstPage(&state)

            case let .sortSelected(sort):
                guard sort != state.sort else { return .none }
                state.sort = sort
                return loadFirstPage(&state)

            case .categoriesRetryTapped:
                guard case .failed = state.categories else { return .none }
                state.categories = .loading
                return loadCategories()

            case let .pageResponse(request, result):
                state.inFlight = nil
                state.isSlow = false
                switch result {
                case let .success(page):
                    let skip = request == .nextPage ? state.nextSkip : 0
                    if request != .nextPage {
                        state.products = []
                        state.phase = .loaded
                        state.nextPageError = nil
                        state.refreshError = nil
                    }
                    // Appending skips products already listed, so a page that shifted adds no duplicates.
                    state.products.append(contentsOf: page.products)
                    state.nextSkip = skip + page.products.count
                    state.isComplete = page.products.isEmpty || state.nextSkip >= page.total
                case let .failure(error):
                    switch request {
                    case .firstPage: state.phase = .failed(error)
                    case .nextPage: state.nextPageError = error
                    case .refresh: state.refreshError = error
                    }
                }
                return .cancel(id: CancelID.slowHint)

            case let .categoriesResponse(.success(categories)):
                state.categories = .loaded(categories)
                return .none

            case let .categoriesResponse(.failure(error)):
                state.categories = .failed(error)
                return .none

            case .slowHintTimerFired:
                state.isSlow = true
                return .none

            case .delegate:
                return .none
            }
        }
    }

    private func loadFirstPage(_ state: inout State) -> Effect<Action> {
        state.phase = .loading
        state.products = []
        return start(.firstPage, &state)
    }

    /// Starts a page request and the slow-connection timer, replacing whatever request is in flight.
    private func start(_ request: PageRequest, _ state: inout State) -> Effect<Action> {
        state.inFlight = request
        state.isSlow = false
        let query = ProductQuery(scope: state.scope, sort: state.sort, skip: request == .nextPage ? state.nextSkip : 0)
        return .merge(
            // Cancelling now, not with cancelInFlight, also drops a response already queued for the old request.
            .cancel(id: CancelID.page),
            .cancel(id: CancelID.slowHint),
            .run { [productsClient] send in
                let page = try await productsClient.page(query)
                logger.info("\(String(describing: request), privacy: .public) loaded \(page.products.count) of \(page.total) for \(query.logName, privacy: .public)")
                await send(.pageResponse(request, .success(page)))
            } catch: { error, send in
                let failure = error as? CatalogError ?? .unexpected
                logger.error("\(String(describing: request), privacy: .public) failed for \(query.logName, privacy: .public): \(String(describing: failure), privacy: .public)")
                await send(.pageResponse(request, .failure(failure)))
            }
            .cancellable(id: CancelID.page),
            .run { [clock] send in
                try await clock.sleep(for: .seconds(3))
                await send(.slowHintTimerFired)
            }
            .cancellable(id: CancelID.slowHint)
        )
    }

    private func loadCategories() -> Effect<Action> {
        .run { [productsClient] send in
            let categories = try await productsClient.categories()
            logger.info("Loaded \(categories.count) categories")
            await send(.categoriesResponse(.success(categories)))
        } catch: { error, send in
            let failure = error as? CatalogError ?? .unexpected
            logger.error("Categories failed: \(String(describing: failure), privacy: .public)")
            await send(.categoriesResponse(.failure(failure)))
        }
    }
}

extension ProductQuery {
    /// Names the request in logs. Search text stays out of it, because it is only ever logged as private.
    var logName: String {
        let list = switch scope {
        case .all: "all products"
        case let .category(slug): "category \(slug)"
        case .search: "search results"
        }
        return "\(list) by \(sort.rawValue) at \(skip)"
    }
}
