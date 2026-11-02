import Models

extension CatalogError {
    public var message: String {
        switch self {
        case .offline: "You're offline. Check your connection and try again."
        case .timeout: "The catalog is taking too long to respond."
        case .server: "The catalog service isn't responding. Try again in a moment."
        case .notFound: "This product is no longer available"
        case .client, .unreadable, .unexpected: "Something went wrong loading products."
        }
    }

    /// "Error 503" for HTTP failures, for support; `nil` otherwise.
    public var caption: String? {
        status.map { "Error \($0)" }
    }

    var systemImage: String {
        switch self {
        case .offline: "wifi.slash"
        case .timeout: "clock.badge.exclamationmark"
        case .server: "server.rack"
        case .notFound: "shippingbox"
        case .client, .unreadable, .unexpected: "exclamationmark.triangle"
        }
    }
}
