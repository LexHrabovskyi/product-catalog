import Foundation
import SwiftUI

/// A product image loaded through `DataTransfer`, with a neutral placeholder while loading or on failure.
public struct RemoteImage: View {
    private let url: URL?
    private let contentMode: ContentMode

    public init(url: URL?, contentMode: ContentMode = .fill) {
        self.url = url
        self.contentMode = contentMode
    }

    public var body: some View {
        // Loading and caching arrive with the image work; until then every image is the placeholder.
        ImagePlaceholder()
    }
}

struct ImagePlaceholder: View {
    var body: some View {
        Rectangle()
            .fill(.quaternary)
            .overlay {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
            .accessibilityHidden(true)
    }
}

#Preview {
    RemoteImage(url: nil).frame(width: 56, height: 56)
}
