/// Every way a catalog request can fail, as the merchant experiences it. Cancellation is not one of them.
public enum CatalogError: Error, Hashable, Sendable {
    case offline
    case timeout
    case server(status: Int)
    case client(status: Int)
    case notFound
    case unreadable
    case unexpected

    public var status: Int? {
        switch self {
        case let .server(status), let .client(status): status
        case .notFound: 404
        case .offline, .timeout, .unreadable, .unexpected: nil
        }
    }
}
