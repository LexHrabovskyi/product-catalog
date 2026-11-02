import ComposableArchitecture
import Foundation
import Models
import ProductListFeature
import ProductsClient
import Testing

@MainActor
struct ProductListFeatureTests {
    /// The two loading states that sit beside rows already shown.
    enum RowsLoading: CaseIterable, Sendable {
        case nextPage
        case refresh
    }

    /// What the merchant changes while a page is still loading.
    enum ContextChange: CaseIterable, Sendable {
        case query
        case category
        case sort
    }

    @Test func appearingAgainKeepsTheListAndFetchesNothing() async {
        let pages = PageScript(page(1...30, of: 194))
        let categoryRequests = LockIsolated(0)
        let store = makeStore(pages, categories: {
            categoryRequests.withValue { $0 += 1 }
            return [laptops, smartphones]
        })

        await appear(store, showing: 1...30, of: 194)
        await store.send(.onAppear)

        #expect(pages.requests.value == [ProductQuery()])
        #expect(categoryRequests.value == 1)
    }

    @Test func slowHintShowsAfterThreeSecondsAndGoesWhenTheRequestEnds() async {
        let clock = TestClock()
        let pages = PageScript(
            after(.seconds(5), on: clock, page(1...30, of: 194)),
            after(.seconds(1), on: clock, page(31...60, of: 194))
        )
        let store = makeStore(pages, clock: clock)

        await store.send(.onAppear) { $0.inFlight = .firstPage }
        await store.receive(\.categoriesResponse) { $0.categories = .loaded([laptops, smartphones]) }
        await clock.advance(by: .milliseconds(2999))
        #expect(!store.state.isSlow)
        await clock.advance(by: .milliseconds(1))
        await store.receive(\.slowHintTimerFired) { $0.isSlow = true }
        await clock.advance(by: .seconds(2))
        await store.receive(\.pageResponse) {
            $0.inFlight = nil
            $0.isSlow = false
            $0.phase = .loaded
            $0.products = rows(1...30)
            $0.nextSkip = 30
        }

        // A request that ends within 3 s never shows the hint, then or later.
        await store.send(.rowAppeared(30)) { $0.inFlight = .nextPage }
        await clock.advance(by: .seconds(1))
        await store.receive(\.pageResponse) {
            $0.inFlight = nil
            $0.products = rows(1...60)
            $0.nextSkip = 60
        }
        await clock.advance(by: .seconds(5))
        #expect(!store.state.isSlow)
    }

    @Test(arguments: RowsLoading.allCases)
    func slowHintAlsoShowsBesideTheFooterSpinnerAndTheRefresh(_ loading: RowsLoading) async {
        let clock = TestClock()
        let slowAnswer = loading == .nextPage ? page(31...60, of: 194) : page(1...30, of: 194)
        let pages = PageScript(page(1...30, of: 194), after(.seconds(5), on: clock, slowAnswer))
        let store = makeStore(pages, clock: clock)
        await appear(store, showing: 1...30, of: 194)

        switch loading {
        case .nextPage: await store.send(.rowAppeared(30)) { $0.inFlight = .nextPage }
        case .refresh: await store.send(.refreshPulled) { $0.inFlight = .refresh }
        }
        await clock.advance(by: .seconds(3))
        await store.receive(\.slowHintTimerFired) { $0.isSlow = true }
        await clock.advance(by: .seconds(2))
        await store.receive(\.pageResponse) {
            $0.inFlight = nil
            $0.isSlow = false
            if loading == .nextPage {
                $0.products = rows(1...60)
                $0.nextSkip = 60
            }
        }
    }

    @Test func nextPageLoadsFromTheLastFiveRowsOneRequestAtATime() async {
        let clock = TestClock()
        let pages = PageScript(page(1...30, of: 194), after(.seconds(1), on: clock, page(31...60, of: 194)))
        let store = makeStore(pages, clock: clock)
        await appear(store, showing: 1...30, of: 194)

        await store.send(.rowAppeared(25))
        await store.send(.rowAppeared(26)) { $0.inFlight = .nextPage }
        await store.send(.rowAppeared(27))
        await store.send(.rowAppeared(30))
        await clock.advance(by: .seconds(1))
        await store.receive(\.pageResponse) {
            $0.inFlight = nil
            $0.products = rows(1...60)
            $0.nextSkip = 60
        }

        #expect(pages.requests.value == [ProductQuery(), ProductQuery(skip: 30)])
    }

    @Test func aRepeatedIdShowsOnceAndNothingLoadsPastTheEnd() async {
        // The catalog shifted by one between the two pages, so product 30 comes back.
        let pages = PageScript(page(1...30, of: 35), page(30...34, of: 35))
        let store = makeStore(pages)
        await appear(store, showing: 1...30, of: 35)

        await store.send(.rowAppeared(30)) { $0.inFlight = .nextPage }
        await store.receive(\.pageResponse) {
            $0.inFlight = nil
            $0.products = rows(1...34)
            $0.nextSkip = 35
            $0.isComplete = true
        }
        await store.send(.rowAppeared(34))

        #expect(pages.requests.value == [ProductQuery(), ProductQuery(skip: 30)])
    }

    @Test func failedNextPageKeepsTheRowsAndRetriesTheSamePageOnlyWhenAsked() async {
        let pages = PageScript(page(1...30, of: 194), failure(.offline), page(31...60, of: 194))
        let store = makeStore(pages)
        await appear(store, showing: 1...30, of: 194)

        await store.send(.rowAppeared(30)) { $0.inFlight = .nextPage }
        await store.receive(\.pageResponse) {
            $0.inFlight = nil
            $0.nextPageError = .offline
        }
        await store.send(.rowAppeared(29))
        await store.send(.loadMoreRetryTapped) {
            $0.nextPageError = nil
            $0.inFlight = .nextPage
        }
        await store.receive(\.pageResponse) {
            $0.inFlight = nil
            $0.products = rows(1...60)
            $0.nextSkip = 60
        }

        #expect(pages.requests.value == [ProductQuery(), ProductQuery(skip: 30), ProductQuery(skip: 30)])
    }

    @Test func failedFirstPageKeepsTheClientErrorAndRetryReloadsTheSameCategory() async {
        let pages = PageScript(failure(.offline), failure(.server(status: 503)), page(1...5, of: 5))
        let store = makeStore(pages)

        await store.send(.onAppear) { $0.inFlight = .firstPage }
        await store.receive(\.categoriesResponse) { $0.categories = .loaded([laptops, smartphones]) }
        await store.receive(\.pageResponse) {
            $0.inFlight = nil
            $0.phase = .failed(.offline)
        }
        // Coming back to the tab is not a retry.
        await store.send(.onAppear)
        await store.send(.categorySelected(laptops)) {
            $0.category = laptops
            $0.phase = .loading
            $0.inFlight = .firstPage
        }
        await store.receive(\.pageResponse) {
            $0.inFlight = nil
            $0.phase = .failed(.server(status: 503))
        }
        await store.send(.retryTapped) {
            $0.phase = .loading
            $0.inFlight = .firstPage
        }
        await store.receive(\.pageResponse) {
            $0.inFlight = nil
            $0.phase = .loaded
            $0.products = rows(1...5)
            $0.nextSkip = 5
            $0.isComplete = true
        }

        let laptopsFirstPage = ProductQuery(scope: .category(slug: "laptops"))
        #expect(pages.requests.value == [ProductQuery(), laptopsFirstPage, laptopsFirstPage])
    }

    @Test func refreshKeepsTheRowsUntilItsAnswerAndAFailureOnlyAddsTheBanner() async {
        let clock = TestClock()
        var laptopsByPrice = ProductListFeature.State()
        laptopsByPrice.category = laptops
        laptopsByPrice.sort = .priceDescending
        let pages = PageScript(
            page(1...30, of: 194),
            page(31...60, of: 194),
            after(.seconds(1), on: clock, failure(.server(status: 503))),
            after(.seconds(1), on: clock, page(101...130, of: 194)),
            page(131...160, of: 194)
        )
        let store = makeStore(pages, clock: clock, initialState: laptopsByPrice)
        await appear(store, showing: 1...30, of: 194)
        await store.send(.rowAppeared(30)) { $0.inFlight = .nextPage }
        await store.receive(\.pageResponse) {
            $0.inFlight = nil
            $0.products = rows(1...60)
            $0.nextSkip = 60
        }

        await store.send(.refreshPulled) { $0.inFlight = .refresh }
        await clock.advance(by: .seconds(1))
        await store.receive(\.pageResponse) {
            $0.inFlight = nil
            $0.refreshError = .server(status: 503)
        }
        await store.send(.refreshRetryTapped) { $0.inFlight = .refresh }
        await clock.advance(by: .seconds(1))
        await store.receive(\.pageResponse) {
            $0.inFlight = nil
            $0.refreshError = nil
            $0.products = rows(101...130)
            $0.nextSkip = 30
        }
        await store.send(.rowAppeared(130)) { $0.inFlight = .nextPage }
        await store.receive(\.pageResponse) {
            $0.inFlight = nil
            $0.products = rows(101...160)
            $0.nextSkip = 60
        }

        let firstPage = ProductQuery(scope: .category(slug: "laptops"), sort: .priceDescending)
        let secondPage = ProductQuery(scope: .category(slug: "laptops"), sort: .priceDescending, skip: 30)
        #expect(pages.requests.value == [firstPage, secondPage, firstPage, firstPage, secondPage])
    }

    @Test func searchWaitsForAPauseTrimsTheQueryAndPagesLikeTheList() async {
        let clock = TestClock()
        let pages = PageScript(page(1...30, of: 194), page(1...30, of: 40), page(31...40, of: 40))
        let store = makeStore(pages, clock: clock)
        await appear(store, showing: 1...30, of: 194)

        await store.send(.searchTextChanged("ph")) { $0.searchText = "ph" }
        await clock.advance(by: .milliseconds(200))
        await store.send(.searchTextChanged("  phone ")) { $0.searchText = "  phone " }
        await clock.advance(by: .milliseconds(299))
        #expect(store.state.searchQuery == nil)
        await clock.advance(by: .milliseconds(1))
        await store.receive(\.searchDebounced) {
            $0.searchQuery = "phone"
            $0.phase = .loading
            $0.products = []
            $0.inFlight = .firstPage
        }
        await store.receive(\.pageResponse) {
            $0.inFlight = nil
            $0.phase = .loaded
            $0.products = rows(1...30)
            $0.nextSkip = 30
        }
        await store.send(.rowAppeared(30)) { $0.inFlight = .nextPage }
        await store.receive(\.pageResponse) {
            $0.inFlight = nil
            $0.products = rows(1...40)
            $0.nextSkip = 40
            $0.isComplete = true
        }

        #expect(pages.requests.value == [
            ProductQuery(),
            ProductQuery(scope: .search("phone")),
            ProductQuery(scope: .search("phone"), skip: 30),
        ])
    }

    @Test(arguments: ContextChange.allCases)
    func aNewQueryCategoryOrSortDropsThePageInFlight(_ change: ContextChange) async {
        let clock = TestClock()
        let pages = PageScript(
            page(1...30, of: 194),
            after(.seconds(1), on: clock, page(31...60, of: 194)),
            page(501...505, of: 5)
        )
        let store = makeStore(pages, clock: clock)
        await appear(store, showing: 1...30, of: 194)
        await store.send(.rowAppeared(30)) { $0.inFlight = .nextPage }

        let newFirstPage: ProductQuery
        switch change {
        case .query:
            newFirstPage = ProductQuery(scope: .search("phone"))
            await store.send(.searchTextChanged("phone")) { $0.searchText = "phone" }
            await clock.advance(by: .milliseconds(300))
            await store.receive(\.searchDebounced) {
                $0.searchQuery = "phone"
                $0.phase = .loading
                $0.products = []
                $0.inFlight = .firstPage
            }
        case .category:
            newFirstPage = ProductQuery(scope: .category(slug: "laptops"))
            await store.send(.categorySelected(laptops)) {
                $0.category = laptops
                $0.phase = .loading
                $0.products = []
                $0.inFlight = .firstPage
            }
        case .sort:
            newFirstPage = ProductQuery(sort: .priceAscending)
            await store.send(.sortSelected(.priceAscending)) {
                $0.sort = .priceAscending
                $0.phase = .loading
                $0.products = []
                $0.inFlight = .firstPage
            }
        }
        await store.receive(\.pageResponse) {
            $0.inFlight = nil
            $0.phase = .loaded
            $0.products = rows(501...505)
            $0.nextSkip = 5
            $0.isComplete = true
        }
        // The replaced page would have answered by now.
        await clock.advance(by: .seconds(1))

        #expect(store.state.products == rows(501...505))
        #expect(pages.requests.value == [ProductQuery(), ProductQuery(skip: 30), newFirstPage])
    }

    @Test func clearingASearchBringsBackTheCategoryWithTheCurrentSort() async {
        let clock = TestClock()
        let pages = PageScript(
            page(1...30, of: 194),
            page(1...5, of: 5),
            page(1...5, of: 5),
            page(1...23, of: 23),
            page(1...23, of: 23),
            page(1...5, of: 5)
        )
        let store = makeStore(pages, clock: clock)
        // The journey's outcome is what it asks the catalog for, step by step.
        store.exhaustivity = .off
        await appear(store, showing: 1...30, of: 194)

        await store.send(.categorySelected(laptops))
        await store.receive(\.pageResponse)
        await store.send(.sortSelected(.priceAscending))
        await store.receive(\.pageResponse)
        await store.send(.searchTextChanged("phone"))
        await clock.advance(by: .milliseconds(300))
        await store.receive(\.pageResponse)
        #expect(store.state.searchQuery == "phone")
        #expect(store.state.category == laptops)
        await store.send(.sortSelected(.titleAscending))
        await store.receive(\.pageResponse)
        await store.send(.searchTextChanged("   "))
        await store.receive(\.pageResponse)

        #expect(store.state.searchQuery == nil)
        #expect(pages.requests.value == [
            ProductQuery(),
            ProductQuery(scope: .category(slug: "laptops")),
            ProductQuery(scope: .category(slug: "laptops"), sort: .priceAscending),
            ProductQuery(scope: .search("phone"), sort: .priceAscending),
            ProductQuery(scope: .search("phone"), sort: .titleAscending),
            ProductQuery(scope: .category(slug: "laptops"), sort: .titleAscending),
        ])
    }

    @Test func aCategoriesFailureLeavesTheListWorkingAndRetryLoadsThem() async {
        let categoryRequests = LockIsolated(0)
        let store = makeStore(PageScript(page(1...30, of: 194)), categories: {
            let request = categoryRequests.withValue { $0 += 1; return $0 }
            guard request > 1 else { throw CatalogError.offline }
            return [laptops, smartphones]
        })

        await store.send(.onAppear) { $0.inFlight = .firstPage }
        await store.receive(\.categoriesResponse) { $0.categories = .failed(.offline) }
        await store.receive(\.pageResponse) {
            $0.inFlight = nil
            $0.phase = .loaded
            $0.products = rows(1...30)
            $0.nextSkip = 30
        }
        await store.send(.categoriesRetryTapped) { $0.categories = .loading }
        await store.receive(\.categoriesResponse) { $0.categories = .loaded([laptops, smartphones]) }
    }

    @Test func rowAndBasketButtonTapsReachTheDelegate() async {
        let store = TestStore(initialState: ProductListFeature.State()) { ProductListFeature() }

        await store.send(.rowTapped(product(7)))
        await store.receive(\.delegate.productTapped, product(7))
        await store.send(.basketButtonTapped)
        await store.receive(\.delegate.basketButtonTapped)
    }
}

private let laptops = ProductCategory(slug: "laptops", name: "Laptops")
private let smartphones = ProductCategory(slug: "smartphones", name: "Smartphones")

private func product(_ id: Int) -> Product {
    Product(id: id, title: "Product \(id)", category: "laptops", price: 10, stock: 5)
}

private func rows(_ ids: ClosedRange<Int>) -> IdentifiedArrayOf<Product> {
    IdentifiedArray(uniqueElements: ids.map(product))
}

/// Answers page requests in the order they arrive, and records each one.
private final class PageScript: Sendable {
    typealias Answer = @Sendable (ProductQuery) async throws -> ProductPage

    let requests = LockIsolated<[ProductQuery]>([])
    private let answers: LockIsolated<[Answer]>

    init(_ answers: Answer...) {
        self.answers = LockIsolated(answers)
    }

    func page(_ query: ProductQuery) async throws -> ProductPage {
        requests.withValue { $0.append(query) }
        guard let answer = answers.withValue({ $0.isEmpty ? nil : $0.removeFirst() }) else {
            Issue.record("Unexpected page request: \(query)")
            throw CatalogError.unexpected
        }
        return try await answer(query)
    }
}

/// Products `ids` out of `total`, at the offset that was asked for.
private func page(_ ids: ClosedRange<Int>, of total: Int) -> PageScript.Answer {
    { query in ProductPage(products: ids.map(product), total: total, skip: query.skip, limit: query.limit) }
}

private func failure(_ error: CatalogError) -> PageScript.Answer {
    { _ in throw error }
}

private func after(
    _ delay: Duration,
    on clock: TestClock<Duration>,
    _ answer: @escaping PageScript.Answer
) -> PageScript.Answer {
    { query in
        try await clock.sleep(for: delay)
        return try await answer(query)
    }
}

@MainActor
private func makeStore(
    _ pages: PageScript,
    clock: TestClock<Duration> = TestClock(),
    categories: @escaping @Sendable () async throws -> [ProductCategory] = { [laptops, smartphones] },
    initialState: ProductListFeature.State = ProductListFeature.State()
) -> TestStoreOf<ProductListFeature> {
    TestStore(initialState: initialState) {
        ProductListFeature()
    } withDependencies: {
        $0.continuousClock = clock
        $0.productsClient.page = { try await pages.page($0) }
        $0.productsClient.categories = categories
    }
}

/// The first appearance, with page 1 and the categories answered at once.
@MainActor
private func appear(_ store: TestStoreOf<ProductListFeature>, showing ids: ClosedRange<Int>, of total: Int) async {
    await store.send(.onAppear) { $0.inFlight = .firstPage }
    await store.receive(\.categoriesResponse) { $0.categories = .loaded([laptops, smartphones]) }
    await store.receive(\.pageResponse) {
        $0.inFlight = nil
        $0.phase = .loaded
        $0.products = rows(ids)
        $0.nextSkip = ids.count
        $0.isComplete = ids.count >= total
    }
}
