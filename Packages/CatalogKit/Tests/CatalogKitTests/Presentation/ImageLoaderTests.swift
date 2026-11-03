import Dependencies
import Foundation
@testable import Presentation
import Testing
import UIKit

/// The loader every `RemoteImage` uses: one request per image, a cache for scroll-back, the placeholder on failure.
struct ImageLoaderTests {
    struct FailedAnswer: Sendable, CustomTestStringConvertible {
        let status: Int
        let body: Data
        let testDescription: String
    }

    @Test func aSecondLoadOfTheSameURLComesFromTheCacheWithoutARequest() async throws {
        let url = try thumbnailURL()
        let transport = StubDataTransfer { request in
            try (pngBytes(), StubDataTransfer.response(to: request, status: 200))
        }
        let loader = freshLoader()

        let first = await loader.image(for: url, from: transport)
        // What a row scrolled back into view draws on its first frame.
        let firstFrame = loader.cachedImage(for: url)
        let second = await loader.image(for: url, from: transport)

        #expect(first != nil)
        #expect(firstFrame != nil)
        #expect(second != nil)
        #expect(transport.requests.map(\.url) == [url])
    }

    @Test(arguments: [
        FailedAnswer(status: 404, body: pngBytes(), testDescription: "404 carrying image bytes"),
        FailedAnswer(status: 200, body: Data("<html>not an image</html>".utf8), testDescription: "undecodable bytes"),
    ])
    func aFailedAnswerGivesThePlaceholderAndCachesNothing(_ answer: FailedAnswer) async throws {
        let url = try thumbnailURL()
        let transport = StubDataTransfer { request in
            try (answer.body, StubDataTransfer.response(to: request, status: answer.status))
        }
        let loader = freshLoader()

        let image = await loader.image(for: url, from: transport)

        #expect(image == nil)
        #expect(loader.cachedImage(for: url) == nil)
    }

    @Test func cancellingALoadCancelsItsRequestAndCachesNothing() async throws {
        let url = try thumbnailURL()
        let (requestStarted, started) = AsyncStream<Void>.makeStream()
        let requestSawCancellation = LockIsolated(false)
        let transport = StubDataTransfer { request in
            started.yield()
            do {
                // The answer would arrive after 5 s, unless the load is cancelled first.
                try await Task.sleep(for: .seconds(5))
            } catch {
                requestSawCancellation.setValue(error is CancellationError)
                throw error
            }
            return try (pngBytes(), StubDataTransfer.response(to: request, status: 200))
        }
        let loader = freshLoader()

        let load = Task { await loader.image(for: url, from: transport) }
        var iterator = requestStarted.makeAsyncIterator()
        _ = await iterator.next()
        load.cancel()

        #expect(await load.value == nil)
        #expect(requestSawCancellation.value)
        #expect(loader.cachedImage(for: url) == nil)
    }

    @Test func aURLThatFailedIsRequestedAgainByTheNextLoad() async throws {
        let url = try thumbnailURL()
        let attempts = LockIsolated(0)
        let transport = StubDataTransfer { request in
            let attempt = attempts.withValue { count in
                count += 1
                return count
            }
            guard attempt > 1 else { throw URLError(.notConnectedToInternet) }
            return try (pngBytes(), StubDataTransfer.response(to: request, status: 200))
        }
        let loader = freshLoader()

        let whileOffline = await loader.image(for: url, from: transport)
        let backOnline = await loader.image(for: url, from: transport)

        #expect(whileOffline == nil)
        #expect(backOnline != nil)
        #expect(transport.requests.count == 2)
    }
}

private func freshLoader() -> ImageLoader {
    ImageLoader(countLimit: 10, totalCostLimit: 10 * 1024 * 1024)
}

private func thumbnailURL() throws -> URL {
    try #require(URL(string: "https://cdn.dummyjson.com/product-images/beauty/essence-mascara-lash-princess/thumbnail.webp"))
}

private func pngBytes() -> Data {
    UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).pngData { context in
        UIColor.systemTeal.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
    }
}
