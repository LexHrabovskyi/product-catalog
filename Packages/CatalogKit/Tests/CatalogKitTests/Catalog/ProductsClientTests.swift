import Catalog
import Dependencies
import Foundation
import Networking
import Testing

struct ProductsClientTests {
    struct PageRequest: Sendable, CustomTestStringConvertible {
        let query: ProductQuery
        let path: String
        let parameters: [String: String]

        var testDescription: String { "\(query.scope), \(query.sort)" }
    }

    @Test(arguments: [
        PageRequest(
            query: ProductQuery(),
            path: "/products",
            parameters: ["limit": "30", "skip": "0"]
        ),
        PageRequest(
            query: ProductQuery(sort: .priceAscending, skip: 30),
            path: "/products",
            parameters: ["limit": "30", "skip": "30", "sortBy": "price", "order": "asc"]
        ),
        PageRequest(
            query: ProductQuery(scope: .category(slug: "home-decoration"), sort: .priceDescending),
            path: "/products/category/home-decoration",
            parameters: ["limit": "30", "skip": "0", "sortBy": "price", "order": "desc"]
        ),
        PageRequest(
            query: ProductQuery(scope: .search("phone"), sort: .titleAscending),
            path: "/products/search",
            parameters: ["q": "phone", "limit": "30", "skip": "0", "sortBy": "title", "order": "asc"]
        ),
        PageRequest(
            query: ProductQuery(scope: .search("c++ & co"), sort: .ratingDescending),
            path: "/products/search",
            parameters: ["q": "c++ & co", "limit": "30", "skip": "0", "sortBy": "rating", "order": "desc"]
        ),
    ])
    func pageRequestReachesDummyJSONAsSpecified(_ expected: PageRequest) async throws {
        let transport = StubDataTransfer.answering(200, Payloads.emptySearch)

        _ = try await withDependencies {
            $0.dataTransfer = transport
        } operation: {
            try await ProductsClient.liveValue.page(expected.query)
        }

        #expect(transport.requests.count == 1)
        let request = try #require(transport.requests.first)
        let url = try #require(request.url)
        #expect(request.httpMethod == "GET")
        #expect(url.scheme == "https")
        #expect(url.host() == "dummyjson.com")
        #expect(url.path() == expected.path)
        #expect(try parametersAsTheServerReadsThem(url) == expected.parameters)
    }

    @Test func eachEndpointRequestsItsPathAndDecodesItsCapturedAnswer() async throws {
        let transport = StubDataTransfer { request in
            let body = switch request.url?.path() {
            case "/products/1": Payloads.product
            case "/products/categories": Payloads.categories
            default: Payloads.emptySearch
            }
            return try (Data(body.utf8), StubDataTransfer.response(to: request, status: 200))
        }

        try await withDependencies {
            $0.dataTransfer = transport
        } operation: {
            let client = ProductsClient.liveValue
            let product = try await client.product(1)
            let categories = try await client.categories()
            let noMatches = try await client.page(ProductQuery(scope: .search("zzzz")))

            #expect(product.id == 1)
            #expect(product.price == Decimal(string: "9.99"))
            #expect(categories.count == 24)
            #expect(categories.first == ProductCategory(slug: "beauty", name: "Beauty"))
            #expect(noMatches.products.isEmpty)
            #expect(noMatches.total == 0)
        }
        #expect(transport.requests.map { $0.url?.path() } == ["/products/1", "/products/categories", "/products/search"])
    }

    struct Failure: Sendable, CustomTestStringConvertible {
        enum Answer: Sendable {
            case status(Int)
            case transportError(URLError.Code)
            case unreadableBody
            case foreignError
        }

        enum Endpoint: Sendable {
            case page, product, categories
        }

        let answer: Answer
        let endpoint: Endpoint
        let expected: CatalogError

        var testDescription: String { "\(answer) from \(endpoint) → \(expected)" }
    }

    @Test(arguments: [
        Failure(answer: .transportError(.notConnectedToInternet), endpoint: .page, expected: .offline),
        Failure(answer: .transportError(.networkConnectionLost), endpoint: .product, expected: .offline),
        Failure(answer: .transportError(.timedOut), endpoint: .page, expected: .timeout),
        Failure(answer: .status(500), endpoint: .page, expected: .server(status: 500)),
        Failure(answer: .status(503), endpoint: .product, expected: .server(status: 503)),
        Failure(answer: .status(404), endpoint: .product, expected: .notFound),
        Failure(answer: .status(404), endpoint: .page, expected: .client(status: 404)),
        Failure(answer: .status(404), endpoint: .categories, expected: .client(status: 404)),
        Failure(answer: .status(400), endpoint: .product, expected: .client(status: 400)),
        Failure(answer: .status(429), endpoint: .page, expected: .client(status: 429)),
        Failure(answer: .unreadableBody, endpoint: .page, expected: .unreadable),
        Failure(answer: .unreadableBody, endpoint: .product, expected: .unreadable),
        Failure(answer: .transportError(.badURL), endpoint: .page, expected: .unexpected),
        Failure(answer: .foreignError, endpoint: .categories, expected: .unexpected),
    ])
    func failureMapsToTheCatalogErrorTheMerchantSees(_ failure: Failure) async {
        let transport: StubDataTransfer = switch failure.answer {
        case let .status(status): .answering(status, Payloads.notFound)
        case let .transportError(code): .failing(with: URLError(code))
        case .unreadableBody: .answering(200, "<html>Service Unavailable</html>")
        case .foreignError: .failing(with: CocoaError(.fileReadUnknown))
        }

        await withDependencies {
            $0.dataTransfer = transport
        } operation: {
            await #expect(throws: failure.expected) {
                try await call(failure.endpoint)
            }
        }
    }

    @Test(arguments: [CancellationError() as any Error, URLError(.cancelled)])
    func cancellationSurfacesAsCancellationError(_ error: any Error) async {
        await withDependencies {
            $0.dataTransfer = StubDataTransfer.failing(with: error)
        } operation: {
            await #expect(throws: CancellationError.self) {
                try await call(.page)
            }
        }
    }

    private func call(_ endpoint: Failure.Endpoint) async throws {
        let client = ProductsClient.liveValue
        switch endpoint {
        case .page: _ = try await client.page(ProductQuery())
        case .product: _ = try await client.product(1)
        case .categories: _ = try await client.categories()
        }
    }

    /// DummyJSON reads the query as a form: `+` is a space, then percent escapes are decoded.
    private func parametersAsTheServerReadsThem(_ url: URL) throws -> [String: String] {
        let query = try #require(url.query(percentEncoded: true))
        var parameters: [String: String] = [:]
        for pair in query.split(separator: "&") {
            let parts = try pair.split(separator: "=", maxSplits: 1).map {
                try #require($0.replacing("+", with: " ").removingPercentEncoding)
            }
            parameters[parts[0]] = parts.dropFirst().first ?? ""
        }
        return parameters
    }
}
