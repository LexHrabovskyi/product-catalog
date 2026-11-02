import Foundation
import Networking
import Synchronization
import Testing

/// A `DataTransfer` that answers each request with `respond` and records every request it was sent.
final class StubDataTransfer: DataTransfer {
    private let respond: @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)
    private let sent = Mutex<[URLRequest]>([])

    init(respond: @escaping @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)) {
        self.respond = respond
    }

    /// Every request sent so far, oldest first.
    var requests: [URLRequest] {
        sent.withLock { $0 }
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        sent.withLock { $0.append(request) }
        return try await respond(request)
    }
}

extension StubDataTransfer {
    /// Answers every request with `status` and `body`.
    static func answering(_ status: Int, _ body: String) -> StubDataTransfer {
        StubDataTransfer { request in
            try (Data(body.utf8), response(to: request, status: status))
        }
    }

    /// Fails every request with `error`, as the transport would.
    static func failing(with error: any Error) -> StubDataTransfer {
        StubDataTransfer { _ in throw error }
    }

    static func response(to request: URLRequest, status: Int) throws -> HTTPURLResponse {
        let url = try #require(request.url)
        return try #require(HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil))
    }
}
