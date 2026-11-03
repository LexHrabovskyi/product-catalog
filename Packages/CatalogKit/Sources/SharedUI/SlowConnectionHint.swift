import SwiftUI

/// Shown beside a loading state that has run for 3 s; the timing belongs to the caller.
public struct SlowConnectionHint: View {
    public init() {}

    public var body: some View {
        Label("Slow connection…", systemImage: "tortoise")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Slow connection…")
            .accessibilityIdentifier("slowConnectionHint")
    }
}

#Preview {
    SlowConnectionHint()
}
