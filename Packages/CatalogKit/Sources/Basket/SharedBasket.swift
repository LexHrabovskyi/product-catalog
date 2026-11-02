import Foundation
import Sharing

extension SharedKey where Self == FileStorageKey<Basket>.Default {
    /// The one basket every screen reads and writes, kept in Application Support across launches.
    public static var basket: Self {
        Self[.fileStorage(.applicationSupportDirectory.appending(component: "basket.json")), default: Basket()]
    }
}
