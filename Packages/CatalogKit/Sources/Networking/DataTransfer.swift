import Dependencies
import Foundation

/// The app's only way onto the network. Tests and Debug scenarios swap it for a scripted transport.
public protocol DataTransfer: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionDataTransfer: DataTransfer {
    private let session: URLSession

    /// Every request fails after 15 s in total, including a response that trickles in.
    public init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 15
        session = URLSession(configuration: configuration)
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, http)
    }
}

private struct UnimplementedDataTransfer: DataTransfer {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        reportIssue("Unimplemented: DataTransfer.send(\(request.url?.absoluteString ?? "no URL"))")
        throw URLError(.unsupportedURL)
    }
}

private enum DataTransferKey: DependencyKey {
    static let liveValue: any DataTransfer = URLSessionDataTransfer()
    static let testValue: any DataTransfer = UnimplementedDataTransfer()
}

extension DependencyValues {
    public var dataTransfer: any DataTransfer {
        get { self[DataTransferKey.self] }
        set { self[DataTransferKey.self] = newValue }
    }
}
