import Basket
import Dependencies
import Foundation
@_spi(Internals) import Sharing
import Testing

struct BasketStorageTests {
    private let basketURL = URL.applicationSupportDirectory.appending(component: "basket.json")

    @Test func basketIsStoredInApplicationSupportAndComesBackAfterARelaunch() throws {
        let saved = Basket(lines: [
            BasketLine(
                productID: 1, title: "Essence Mascara Lash Princess", thumbnail: nil,
                price: try decimal("9.99"), discountPercentage: try decimal("10.48"),
                stock: 99, minimumOrderQuantity: 48, quantity: 50
            ),
            BasketLine(
                productID: 31, title: "Lemon", thumbnail: nil,
                price: try decimal("0.79"), discountPercentage: try decimal("9.7"),
                stock: 31, minimumOrderQuantity: 29, quantity: 29
            ),
        ])
        let disk = LockIsolated<[URL: Data]>([:])
        withDependencies {
            $0.defaultFileStorage = .inMemory(fileSystem: disk)
        } operation: {
            @Shared(.basket) var basket
            $basket.withLock { $0 = saved }
        }

        let stored = try #require(disk.value[basketURL])
        #expect(try JSONDecoder().decode(Basket.self, from: stored) == saved)

        let relaunched = LockIsolated(disk.value)
        let restored = withDependencies {
            $0.defaultFileStorage = .inMemory(fileSystem: relaunched)
        } operation: {
            @Shared(.basket) var basket
            return basket
        }
        #expect(restored == saved)
    }

    @Test(arguments: ["not json", #"{"items":[]}"#])
    func unreadableStoredBasketStartsEmpty(stored: String) {
        let disk = LockIsolated([basketURL: Data(stored.utf8)])

        withDependencies {
            $0.defaultFileStorage = .inMemory(fileSystem: disk)
        } operation: {
            @Shared(.basket) var basket
            #expect(basket == Basket())
            #expect($basket.loadError != nil)
        }
    }

    private func decimal(_ text: String) throws -> Decimal {
        try #require(Decimal(string: text))
    }
}
