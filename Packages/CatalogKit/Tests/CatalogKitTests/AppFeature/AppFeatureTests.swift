import AppFeature
import Basket
import Catalog
import ComposableArchitecture
import Foundation
@_spi(Internals) import Sharing
import SwiftUI
import Testing

@MainActor
struct AppFeatureTests {
    private let lamp = Product(id: 7, title: "Lamp", category: "furniture", price: 20, stock: 7, minimumOrderQuantity: 2)
    private let mug = Product(id: 8, title: "Mug", category: "kitchen-accessories", price: 5, stock: 9)

    @Test func tappingAProductPushesItsDetail() async {
        let store = TestStore(initialState: AppFeature.State()) { AppFeature() }

        await store.send(.catalog(.delegate(.productTapped(lamp)))) {
            $0.path[id: 0] = .detail(ProductDetailFeature.State(product: self.lamp))
        }
    }

    @Test func basketBadgeCountsLinesOfTheBasketEveryScreenShares() {
        let store = TestStore(initialState: AppFeature.State()) { AppFeature() }
        #expect(store.state.basket.lineCount == 0)

        store.state.basketTab.$basket.withLock {
            _ = $0.add(lamp, quantity: 3)
            _ = $0.add(mug, quantity: 2)
        }

        #expect(store.state.basket.lineCount == 2)
    }

    @Test func movingToTheBackgroundWritesTheBasketAtOnce() async throws {
        let disk = LockIsolated<[URL: Data]>([:])
        // Coalesced writes never flush by themselves, as when the app is suspended first.
        let storage = FileStorage.inMemory(fileSystem: disk, asyncAfter: { _, _ in })
        let basket: Shared<Basket> = withDependencies {
            $0.defaultFileStorage = storage
        } operation: {
            Shared(.basket)
        }
        basket.withLock { _ = $0.add(lamp, quantity: 2) }
        basket.withLock { _ = $0.add(mug, quantity: 1) }
        #expect(try storedProductIDs(disk) == [7])

        let store = TestStore(initialState: AppFeature.State()) { AppFeature() } withDependencies: {
            $0.defaultFileStorage = storage
        }
        await store.send(.scenePhaseChanged(.background))
        await store.finish()

        #expect(try storedProductIDs(disk) == [7, 8])
    }

    private func storedProductIDs(_ disk: LockIsolated<[URL: Data]>) throws -> [Int] {
        let data = try #require(disk.value[URL.applicationSupportDirectory.appending(component: "basket.json")])
        return try JSONDecoder().decode(Basket.self, from: data).lines.map(\.productID)
    }
}
