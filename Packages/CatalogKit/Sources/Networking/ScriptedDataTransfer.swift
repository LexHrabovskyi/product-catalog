#if DEBUG
import Foundation
import os
import Synchronization

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ProductCatalog", category: "scenario")

/// Answers DummyJSON requests from a script, for Debug demos and the UI journey. It never touches the network.
/// Request counts belong to the instance, so every launch plays its scenario from the start.
public final class ScriptedDataTransfer: DataTransfer {
    public enum Scenario: String, Sendable {
        /// 120 products, with the failures and delays the UI journey walks through.
        case journey
        /// 1,200 products, all answering OK.
        case large
        /// The journey catalog without its failures, every response after 4 s.
        case slow
        /// Every request fails as offline.
        case offline
    }

    private let scenario: Scenario
    private let catalog: ScriptedCatalog
    /// Product-list requests so far, by `skip`.
    private let pageRequests = Mutex<[Int: Int]>([:])

    public init(scenario: Scenario) {
        self.scenario = scenario
        catalog = ScriptedCatalog(productCount: scenario == .large ? 1_200 : 120)
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        guard let url = request.url else { throw URLError(.badURL) }
        switch scenario {
        case .offline:
            throw URLError(.notConnectedToInternet)
        case .slow:
            try await Task.sleep(for: .seconds(4))
        case .journey, .large:
            break
        }
        let (status, body) = try await answer(url)
        guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil) else {
            throw URLError(.badServerResponse)
        }
        return (body, response)
    }

    private func answer(_ url: URL) async throws -> (status: Int, body: Data) {
        let journey = scenario == .journey
        let path = url.path()
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { query.first { $0.name == name }?.value }
        let skip = value("skip").flatMap { Int($0) } ?? 0
        let limit = value("limit").flatMap { Int($0) } ?? 30

        if let id = path.wholeMatch(of: /\/product-images\/(\d+)\/[^\/]+/).flatMap({ Int($0.1) }) {
            if journey && id.isMultiple(of: 10) {
                return Self.message(404, "Image not found")
            }
            return (200, try ScriptedCatalog.png(forProduct: id))
        }
        if let id = path.wholeMatch(of: /\/products\/(\d+)/).flatMap({ Int($0.1) }) {
            if journey && id == 2 {
                return Self.message(503, "Service Unavailable")
            }
            guard !(journey && id == 3), let product = try catalog.product(id) else {
                return Self.message(404, "Product with id '\(id)' not found")
            }
            return (200, product)
        }
        if let slug = path.wholeMatch(of: /\/products\/category\/([^\/]+)/)?.1 {
            return (200, try catalog.page(catalog.products.filter { $0.category == slug }, skip: skip, limit: limit))
        }
        switch path {
        case "/products":
            if journey, let failure = try await journeyPageFailure(skip: skip) {
                return failure
            }
            return (200, try catalog.page(catalog.products, skip: skip, limit: limit))
        case "/products/search":
            let text = value("q") ?? ""
            let matches = catalog.products.filter { text.isEmpty || $0.title.localizedCaseInsensitiveContains(text) }
            return (200, try catalog.page(matches, skip: skip, limit: limit))
        case "/products/categories":
            return (200, try catalog.categories())
        default:
            logger.error("Unscripted request \(path, privacy: .public) answered 404")
            return Self.message(404, "Not scripted")
        }
    }

    /// Page 1 answers 503 and page 3 answers 500 the first time; page 2 always takes 2 s.
    private func journeyPageFailure(skip: Int) async throws -> (status: Int, body: Data)? {
        let attempt = pageRequests.withLock { counts in
            counts[skip, default: 0] += 1
            return counts[skip, default: 0]
        }
        switch (skip, attempt) {
        case (0, 1):
            return Self.message(503, "Service Unavailable")
        case (60, 1):
            return Self.message(500, "Internal Server Error")
        case (30, _):
            try await Task.sleep(for: .seconds(2))
            return nil
        default:
            return nil
        }
    }

    private static func message(_ status: Int, _ text: String) -> (status: Int, body: Data) {
        (status, Data(#"{"message":"\#(text)"}"#.utf8))
    }
}
#endif
