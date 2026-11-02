import Models
import SwiftUI

/// A full-screen failure: what happened, the status for support, and a way out.
/// Identifiers: `identifier`, `identifier.caption`, `identifier.retry`.
public struct ErrorStateView: View {
    private let error: CatalogError
    private let identifier: String
    private let retry: (() -> Void)?

    public init(error: CatalogError, identifier: String, retry: (() -> Void)?) {
        self.error = error
        self.identifier = identifier
        self.retry = retry
    }

    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: error.systemImage)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(error.message)
                .font(.headline)
                .multilineTextAlignment(.center)
            if let caption = error.caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("\(identifier).caption")
            }
            if let retry {
                Button("Retry", action: retry)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("\(identifier).retry")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }
}

#Preview {
    ErrorStateView(error: .server(status: 503), identifier: "preview.error") {}
}
