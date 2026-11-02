import Foundation
import Networking
import os
import UIKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ProductCatalog", category: "images")

/// Loads images through `DataTransfer` and keeps them decoded in a bounded memory cache.
/// `@unchecked Sendable` because its only state, the `NSCache`, does its own locking.
final class ImageLoader: @unchecked Sendable {
    /// The cache every `RemoteImage` shares.
    static let shared = ImageLoader(countLimit: 200, totalCostLimit: 50 * 1024 * 1024)

    private let cache = NSCache<NSURL, UIImage>()

    /// `totalCostLimit` counts decoded bytes.
    init(countLimit: Int, totalCostLimit: Int) {
        cache.countLimit = countLimit
        cache.totalCostLimit = totalCostLimit
    }

    func cachedImage(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    /// The decoded image, from the cache when it's there; `nil` once a failure or cancellation is logged.
    func image(for url: URL, from transfer: any DataTransfer) async -> UIImage? {
        if let image = cachedImage(for: url) {
            return image
        }
        let path = url.path()
        let started = ContinuousClock.now
        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transfer.send(URLRequest(url: url))
        } catch {
            if error is CancellationError || (error as? URLError)?.code == .cancelled {
                logger.debug("Image \(path, privacy: .public) cancelled")
            } else {
                logger.debug("Image \(path, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            }
            return nil
        }
        guard (200..<300).contains(response.statusCode) else {
            logger.debug("Image \(path, privacy: .public) answered \(response.statusCode)")
            return nil
        }
        // Decodes off the main thread, so the first draw of a row doesn't stall scrolling.
        guard let image = await UIImage(data: data)?.byPreparingForDisplay() else {
            logger.debug("Image \(path, privacy: .public) is unreadable (\(data.count) bytes)")
            return nil
        }
        let pixels = image.size.width * image.scale * image.size.height * image.scale
        cache.setObject(image, forKey: url as NSURL, cost: Int(pixels) * 4)
        logger.debug("Image \(path, privacy: .public) loaded in \(Int(started.duration(to: .now) / .milliseconds(1))) ms")
        return image
    }
}
