import Dependencies
import Foundation
import Networking
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ProductCatalog", category: "network")

extension ProductsClient {
    static let live = ProductsClient(
        page: { query in
            let page = try await fetch(ProductPage.self, from: try DummyJSON.pageRequest(for: query))
            logger.info("Page at \(query.skip) loaded: \(page.products.count) of \(page.total)")
            return page
        },
        product: { id in
            try await fetch(Product.self, from: try DummyJSON.request(path: "/products/\(id)"), missingIsNotFound: true)
        },
        categories: {
            try await fetch([ProductCategory].self, from: try DummyJSON.request(path: "/products/categories"))
        }
    )
}

enum DummyJSON {
    static func pageRequest(for query: ProductQuery) throws -> URLRequest {
        var items = [
            URLQueryItem(name: "limit", value: String(query.limit)),
            URLQueryItem(name: "skip", value: String(query.skip)),
        ]
        if let sort = query.sort.parameters {
            items.append(URLQueryItem(name: "sortBy", value: sort.sortBy))
            items.append(URLQueryItem(name: "order", value: sort.order))
        }
        switch query.scope {
        case .all:
            return try request(path: "/products", items: items)
        case let .category(slug):
            return try request(path: "/products/category/\(slug)", items: items)
        case let .search(text):
            items.append(URLQueryItem(name: "q", value: text))
            return try request(path: "/products/search", items: items)
        }
    }

    static func request(path: String, items: [URLQueryItem] = []) throws -> URLRequest {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "dummyjson.com"
        components.path = path
        components.queryItems = items.isEmpty ? nil : items
        // URLComponents leaves "+" as is, and DummyJSON reads a raw "+" as a space.
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        guard let url = components.url else {
            logger.fault("Could not build a URL for \(path, privacy: .public)")
            throw CatalogError.unexpected
        }
        return URLRequest(url: url)
    }
}

/// Sends `request` and decodes the answer, mapping every failure to `CatalogError`.
/// `missingIsNotFound` turns a 404 into `.notFound`; elsewhere a 404 is just a client error.
private func fetch<Value: Decodable>(
    _ type: Value.Type,
    from request: URLRequest,
    missingIsNotFound: Bool = false
) async throws -> Value {
    @Dependency(\.dataTransfer) var dataTransfer
    let path = request.url?.path() ?? "?"
    let started = ContinuousClock.now
    logger.debug("GET \(path, privacy: .public) started")

    let data: Data
    let response: HTTPURLResponse
    do {
        (data, response) = try await dataTransfer.send(request)
    } catch {
        if error is CancellationError || (error as? URLError)?.code == .cancelled {
            logger.debug("GET \(path, privacy: .public) cancelled")
            throw CancellationError()
        }
        let failure = CatalogError(transportError: error)
        logger.error("GET \(path, privacy: .public) failed as \(String(describing: failure), privacy: .public): \(error.localizedDescription, privacy: .public)")
        throw failure
    }

    let elapsed = Int(started.duration(to: .now) / .milliseconds(1))
    let status = response.statusCode
    guard (200..<300).contains(status) else {
        let failure: CatalogError = switch status {
        case 404 where missingIsNotFound: .notFound
        case 400..<500: .client(status: status)
        case 500..<600: .server(status: status)
        default: .unexpected
        }
        logger.error("GET \(path, privacy: .public) answered \(status) in \(elapsed) ms")
        throw failure
    }

    do {
        let value = try JSONDecoder().decode(Value.self, from: data)
        logger.info("GET \(path, privacy: .public) answered \(status) in \(elapsed) ms")
        return value
    } catch {
        logger.error("GET \(path, privacy: .public) unreadable: \(String(describing: error), privacy: .public)")
        throw CatalogError.unreadable
    }
}

extension CatalogError {
    init(transportError error: any Error) {
        guard let urlError = error as? URLError else {
            self = .unexpected
            return
        }
        switch urlError.code {
        case .timedOut:
            self = .timeout
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff,
             .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            self = .offline
        default:
            self = .unexpected
        }
    }
}
