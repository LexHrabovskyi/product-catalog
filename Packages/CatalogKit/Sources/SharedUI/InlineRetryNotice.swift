import Models
import SwiftUI

/// A failure that leaves the content in place, such as "Couldn't refresh" or "Couldn't update".
/// Identifiers: `identifier`, `identifier.retry`.
public struct InlineRetryNotice: View {
    private let title: String
    private let error: CatalogError
    private let identifier: String
    private let retry: () -> Void

    public init(title: String, error: CatalogError, identifier: String, retry: @escaping () -> Void) {
        self.title = title
        self.error = error
        self.identifier = identifier
        self.retry = retry
    }

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                if let caption = error.caption {
                    Text(caption).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Button("Retry", action: retry)
                .buttonStyle(.bordered)
                .accessibilityIdentifier("\(identifier).retry")
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }
}

#Preview {
    InlineRetryNotice(title: "Couldn't refresh", error: .server(status: 503), identifier: "preview.notice") {}
        .padding()
}
