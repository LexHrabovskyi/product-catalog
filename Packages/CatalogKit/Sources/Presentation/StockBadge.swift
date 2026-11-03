import Catalog
import SwiftUI

/// The catalog's availability label with the unit count, e.g. "Low Stock · 3".
public struct StockBadge: View {
    private let status: AvailabilityStatus
    private let stock: Int

    public init(status: AvailabilityStatus, stock: Int) {
        self.status = status
        self.stock = stock
    }

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .foregroundStyle(tint)
            Text("\(status.label) · \(stock)")
        }
        .font(.caption.weight(.semibold))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(status.label), \(stock) \(stock == 1 ? "unit" : "units")")
    }

    private var tint: Color {
        switch status {
        case .inStock: .green
        case .lowStock: .orange
        case .outOfStock: .red
        case .other: .secondary
        }
    }
}

#Preview {
    VStack(alignment: .leading) {
        StockBadge(status: .inStock, stock: 99)
        StockBadge(status: .lowStock, stock: 3)
        StockBadge(status: .outOfStock, stock: 0)
        StockBadge(status: .other("Backorder"), stock: 0)
    }
}
