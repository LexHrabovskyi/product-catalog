import Dependencies
import Foundation
import Networking
import SwiftUI
import UIKit

/// A product image loaded through `DataTransfer`, with a neutral placeholder while loading or on failure.
public struct RemoteImage: View {
    private let url: URL?
    private let contentMode: ContentMode
    @State private var loaded: (url: URL, image: UIImage)? = nil
    @Dependency(\.dataTransfer) private var dataTransfer

    public init(url: URL?, contentMode: ContentMode = .fill) {
        self.url = url
        self.contentMode = contentMode
    }

    public var body: some View {
        Color.clear
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                        .accessibilityHidden(true)
                } else {
                    ImagePlaceholder()
                }
            }
            .clipped()
            // Leaving the screen cancels the load.
            .task(id: url) {
                guard let url, let image = await ImageLoader.shared.image(for: url, from: dataTransfer) else {
                    return
                }
                loaded = (url, image)
            }
    }

    /// A cached image shows on the first frame, so a row scrolled back into view never flashes the placeholder.
    private var image: UIImage? {
        guard let url else { return nil }
        if let loaded, loaded.url == url {
            return loaded.image
        }
        return ImageLoader.shared.cachedImage(for: url)
    }
}

/// One large product symbol, sized to the tile, for every product without a loaded image.
struct ImagePlaceholder: View {
    var body: some View {
        Rectangle()
            .fill(.quaternary)
            .overlay {
                GeometryReader { geometry in
                    let side = min(geometry.size.width, geometry.size.height) * 0.6
                    Image(systemName: "shippingbox")
                        .resizable()
                        .scaledToFit()
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                        .frame(width: side, height: side)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .accessibilityHidden(true)
    }
}

#Preview {
    RemoteImage(url: nil).frame(width: 56, height: 56)
    RemoteImage(url: nil, contentMode: .fit).frame(height: 320)
}
