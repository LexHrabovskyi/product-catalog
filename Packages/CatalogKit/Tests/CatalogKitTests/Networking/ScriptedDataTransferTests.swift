import Basket
import ComposableArchitecture
import Dependencies
import Foundation
import Models
import Networking
import ProductsClient
import Testing
import UIKit

/// The Debug scenarios, read through the live client exactly as the app reads them.
struct ScriptedDataTransferTests {
    struct DelayedRequest: Sendable, CustomTestStringConvertible {
        let scenario: ScriptedDataTransfer.Scenario
        let skip: Int

        var testDescription: String { "\(scenario) page at skip \(skip)" }
    }

    @Test func journeyPagesFollowTheScript() async throws {
        let journey = ScriptedDataTransfer(scenario: .journey)
        let clock = ImmediateClock()
        let start = clock.now

        try await withDependencies {
            $0.continuousClock = clock
        } operation: {
            await #expect(throws: CatalogError.server(status: 503)) { try await page(skip: 0, from: journey) }
            let first = try await page(skip: 0, from: journey)
            #expect(first.products.map(\.id) == Array(1...30))
            #expect(first.products.first?.title == "Product 1")
            #expect(first.total == 120)

            let second = try await timed(on: clock) { try await page(skip: 30, from: journey) }
            #expect(second.elapsed == .seconds(2))
            #expect(second.value.products.map(\.id) == Array(31...60))

            await #expect(throws: CatalogError.server(status: 500)) { try await page(skip: 60, from: journey) }
            let third = try await page(skip: 60, from: journey)
            #expect(third.products.map(\.id) == Array(61...90))

            let fourth = try await page(skip: 90, from: journey)
            #expect(fourth.products.map(\.id) == Array(91...120))
            #expect(fourth.products.last?.title == "Product 120")
            #expect(fourth.total == 120)
        }
        #expect(start.duration(to: clock.now) == .seconds(2), "only page 2 waits")
    }

    @Test func journeyProductsFollowTheScriptAndMakeTheExpectedBasket() async throws {
        let journey = ScriptedDataTransfer(scenario: .journey)
        let rows = try await firstJourneyPage(journey)

        let plain = try #require(rows.first { $0.id == 7 })
        #expect(plain.title == "Product 7")
        #expect(plain.price == 7)
        #expect(plain.discountPercentage == 0)
        #expect(plain.stock == 50)
        #expect(plain.minimumOrderQuantity == 1)
        #expect(plain.availabilityStatus == .inStock)
        let productA = try #require(rows.first { $0.id == 2 })
        #expect(productA.price == 10)
        #expect(productA.discountPercentage == 10)
        #expect(productA.stock == 50)
        #expect(productA.minimumOrderQuantity == 5)
        let productC = try #require(rows.first { $0.id == 4 })
        #expect(productC.price == 20)
        #expect(productC.discountPercentage == 5)
        #expect(productC.stock == 10)
        #expect(productC.minimumOrderQuantity == 2)

        // Each product's detail refresh.
        await #expect(throws: CatalogError.server(status: 503)) { try await product(2, from: journey) }
        await #expect(throws: CatalogError.server(status: 503)) { try await product(2, from: journey) }
        await #expect(throws: CatalogError.notFound) { try await product(3, from: journey) }
        #expect(try await product(4, from: journey) == productC)

        var basket = Basket()
        #expect(basket.add(productA, quantity: productA.minimumOrderQuantity) == .added(quantity: 5))
        #expect(basket.add(productC, quantity: productC.minimumOrderQuantity) == .added(quantity: 2))
        #expect(basket.subtotal == 90)
        #expect(basket.savings == 7)
        #expect(basket.total == 83)
    }

    @Test func journeyCategoriesAndSearchAnswerLikeDummyJSON() async throws {
        let journey = ScriptedDataTransfer(scenario: .journey)

        let menu = try await categories(from: journey)
        #expect(menu.count == 3)
        var listed: [Int] = []
        for category in menu {
            let products = try await page(ProductQuery(scope: .category(slug: category.slug), limit: 120), from: journey).products
            #expect(!products.isEmpty, "\(category.slug)")
            #expect(products.allSatisfy { $0.category == category.slug }, "\(category.slug)")
            listed += products.map(\.id)
        }
        #expect(listed.sorted() == Array(1...120))

        // "Product 11" and "Product 110" to "Product 119", whatever the case of the query.
        let firstMatches = try await page(ProductQuery(scope: .search("PRODUCT 11"), limit: 5), from: journey)
        #expect(firstMatches.total == 11)
        #expect(firstMatches.products.map(\.title) == ["Product 11", "Product 110", "Product 111", "Product 112", "Product 113"])
        let nextMatches = try await page(ProductQuery(scope: .search("PRODUCT 11"), skip: 5, limit: 5), from: journey)
        #expect(nextMatches.total == 11)
        #expect(nextMatches.products.map(\.id) == [114, 115, 116, 117, 118])
    }

    @Test func journeyImagesAnswer404ForEveryTenthProductAndAPNGForTheRest() async throws {
        let journey = ScriptedDataTransfer(scenario: .journey)
        let rows = try await firstJourneyPage(journey)

        for row in rows {
            let urls = [row.thumbnail].compactMap { $0 } + row.images
            #expect(!urls.isEmpty, "product \(row.id)")
            for url in urls {
                let (data, response) = try await journey.send(URLRequest(url: url))
                if row.id.isMultiple(of: 10) {
                    #expect(response.statusCode == 404, "product \(row.id): \(url)")
                } else {
                    #expect(response.statusCode == 200, "product \(row.id): \(url)")
                    #expect(UIImage(data: data) != nil, "product \(row.id): \(url)")
                }
            }
        }
    }

    @Test func anUnscriptedRequestAnswers404() async throws {
        let journey = ScriptedDataTransfer(scenario: .journey)
        let url = try #require(URL(string: "https://dummyjson.com/users/1"))

        let (_, response) = try await journey.send(URLRequest(url: url))

        #expect(response.statusCode == 404)
    }

    @Test func eachLaunchPlaysTheJourneyFromTheStart() async throws {
        let firstLaunch = ScriptedDataTransfer(scenario: .journey)
        _ = try await firstJourneyPage(firstLaunch)
        await #expect(throws: CatalogError.server(status: 500)) { try await page(skip: 60, from: firstLaunch) }

        let secondLaunch = ScriptedDataTransfer(scenario: .journey)

        await #expect(throws: CatalogError.server(status: 503)) { try await page(skip: 0, from: secondLaunch) }
        await #expect(throws: CatalogError.server(status: 500)) { try await page(skip: 60, from: secondLaunch) }
    }

    @Test func largeCatalogPagesTwelveHundredProductsInOrderAndAnswersEverythingOK() async throws {
        let large = ScriptedDataTransfer(scenario: .large)

        var ids: [Int] = []
        for skip in stride(from: 0, to: 1_200, by: ProductQuery.pageSize) {
            let batch = try await page(skip: skip, from: large)
            #expect(batch.total == 1_200)
            ids += batch.products.map(\.id)
        }
        #expect(ids == Array(1...1_200))
        let pastTheEnd = try await page(skip: 1_200, from: large)
        #expect(pastTheEnd.products.isEmpty)
        #expect(pastTheEnd.total == 1_200)

        // What fails in the journey answers here.
        #expect(try await product(2, from: large).id == 2)
        #expect(try await product(3, from: large).id == 3)
        let thumbnail = try #require(try await product(10, from: large).thumbnail)
        let (data, response) = try await large.send(URLRequest(url: thumbnail))
        #expect(response.statusCode == 200)
        #expect(UIImage(data: data) != nil)
    }

    @Test func slowCatalogAnswersWithoutTheJourneyFailuresAfterFourSecondsEach() async throws {
        let slow = ScriptedDataTransfer(scenario: .slow)
        let clock = ImmediateClock()

        try await withDependencies {
            $0.continuousClock = clock
        } operation: {
            let rows = try await timed(on: clock) { try await page(skip: 0, from: slow) }
            let productA = try await timed(on: clock) { try await product(2, from: slow) }
            let productB = try await timed(on: clock) { try await product(3, from: slow) }

            #expect(rows.value.products.map(\.id) == Array(1...30))
            #expect(productA.value.id == 2)
            #expect(productB.value.id == 3)
            #expect(rows.elapsed == .seconds(4))
            #expect(productA.elapsed == .seconds(4))
            #expect(productB.elapsed == .seconds(4))
        }
    }

    @Test func offlineFailsEveryRequestAsNotConnected() async throws {
        let offline = ScriptedDataTransfer(scenario: .offline)

        await #expect(throws: CatalogError.offline) { try await page(skip: 0, from: offline) }
        await #expect(throws: CatalogError.offline) { try await product(1, from: offline) }
        await #expect(throws: CatalogError.offline) { try await categories(from: offline) }
        let image = try #require(URL(string: "https://cdn.dummyjson.com/product-images/beauty/essence-mascara-lash-princess/thumbnail.webp"))
        let error = await #expect(throws: URLError.self) { try await offline.send(URLRequest(url: image)) }
        #expect(error?.code == .notConnectedToInternet)
    }

    @Test(.timeLimit(.minutes(1)), arguments: [
        DelayedRequest(scenario: .journey, skip: 30),
        DelayedRequest(scenario: .slow, skip: 0),
    ])
    func cancellingADelayedRequestEndsItAtOnce(_ delayed: DelayedRequest) async throws {
        let transport = ScriptedDataTransfer(scenario: delayed.scenario)
        let clock = TestClock()

        let request = Task {
            try await withDependencies {
                $0.continuousClock = clock
            } operation: {
                try await page(skip: delayed.skip, from: transport)
            }
        }
        request.cancel()

        // The clock never advances, so a delay that ignored the cancellation would never end.
        await #expect(throws: CancellationError.self) { try await request.value }
    }
}

/// Page 1 of the journey, past the 503 its first request answers.
private func firstJourneyPage(_ journey: ScriptedDataTransfer) async throws -> [Product] {
    await #expect(throws: CatalogError.server(status: 503)) { try await page(skip: 0, from: journey) }
    return try await page(skip: 0, from: journey).products
}

private func page(skip: Int, from transport: some DataTransfer) async throws -> ProductPage {
    try await page(ProductQuery(skip: skip), from: transport)
}

private func page(_ query: ProductQuery, from transport: some DataTransfer) async throws -> ProductPage {
    try await withDependencies {
        $0.dataTransfer = transport
    } operation: {
        try await ProductsClient.liveValue.page(query)
    }
}

private func product(_ id: Int, from transport: some DataTransfer) async throws -> Product {
    try await withDependencies {
        $0.dataTransfer = transport
    } operation: {
        try await ProductsClient.liveValue.product(id)
    }
}

private func categories(from transport: some DataTransfer) async throws -> [ProductCategory] {
    try await withDependencies {
        $0.dataTransfer = transport
    } operation: {
        try await ProductsClient.liveValue.categories()
    }
}

/// The operation's result and how far its scripted delays moved `clock`.
private func timed<Value>(
    on clock: ImmediateClock<Duration>,
    _ operation: () async throws -> Value
) async rethrows -> (value: Value, elapsed: Duration) {
    let start = clock.now
    let value = try await operation()
    return (value, start.duration(to: clock.now))
}
