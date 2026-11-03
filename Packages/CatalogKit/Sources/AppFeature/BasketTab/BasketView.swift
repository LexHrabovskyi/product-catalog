import Basket
import Catalog
import ComposableArchitecture
import Presentation
import SwiftUI

public struct BasketView: View {
    @Bindable var store: StoreOf<BasketFeature>

    public init(store: StoreOf<BasketFeature>) {
        self.store = store
    }

    public var body: some View {
        Group {
            if store.basket.lines.isEmpty {
                ContentUnavailableView(
                    "Your basket is empty",
                    systemImage: "basket",
                    description: Text("Add products from the catalog.")
                )
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("basket.empty")
            } else {
                lines
            }
        }
        .navigationTitle("Basket")
        .alert($store.scope(\.alert, action: \.alert))
    }

    private var lines: some View {
        List {
            ForEach(store.basket.lines) { line in
                BasketLineRow(
                    line: line,
                    quantity: Binding(
                        get: { line.quantity },
                        set: { store.send(.quantityChanged(id: line.id, quantity: $0)) }
                    ),
                    open: { store.send(.lineTapped(id: line.id)) }
                )
                .swipeActions {
                    Button("Remove", systemImage: "trash", role: .destructive) {
                        store.send(.removeButtonTapped(id: line.id))
                    }
                }
            }
        }
        .accessibilityIdentifier("basket.list")
        .safeAreaBar(edge: .bottom) { totals }
        .toolbar {
            Button("Clear basket", systemImage: "trash", role: .destructive) {
                store.send(.clearButtonTapped)
            }
            .accessibilityIdentifier("basket.clear")
        }
    }

    private var totals: some View {
        VStack(alignment: .leading, spacing: 8) {
            TotalRow(title: "Subtotal", amount: store.basket.subtotal)
                .accessibilityIdentifier("basket.subtotal")
            TotalRow(title: "Savings", amount: -store.basket.savings)
                .accessibilityIdentifier("basket.savings")
            TotalRow(title: "Total", amount: store.basket.total)
                .font(.headline)
                .accessibilityIdentifier("basket.total")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

/// One VoiceOver element. The amount sits beside its title while both fit, and otherwise wraps under it.
private struct TotalRow: View {
    let title: LocalizedStringKey
    let amount: Decimal

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                Spacer()
                Text(amount, format: .usd)
            }
            VStack(alignment: .leading) {
                Text(title)
                Text(amount, format: .usd)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct BasketLineRow: View {
    let line: BasketLine
    @Binding var quantity: Int
    let open: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: open) { summary }
                .buttonStyle(.plain)
            QuantityStepper(quantity: $quantity, range: line.quantityRange)
        }
    }

    /// One VoiceOver button that opens the product; the stepper after it stays separately adjustable.
    private var summary: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        let unitPrice = line.unitPrice.formatted(.usd)
        let lineTotal = line.lineTotal.formatted(.usd)
        return layout {
            RemoteImage(url: line.thumbnail)
                .frame(width: 56, height: 56)
                .clipShape(.rect(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 4) {
                Text(line.title)
                    .font(.headline)
                Text("\(unitPrice) each")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Text(lineTotal)
                .font(.headline)
                .layoutPriority(1)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(line.title), \(line.quantity) × \(unitPrice), \(lineTotal)")
        .accessibilityIdentifier("basket.line.\(line.id)")
    }
}

#Preview("Two lines") {
    let _ = Shared(.basket).withLock {
        $0 = Basket(lines: [
            BasketLine(product: Product.fixtures[0], quantity: 48),
            BasketLine(product: Product.fixtures[1], quantity: 2),
        ])
    }
    NavigationStack {
        BasketView(store: Store(initialState: BasketFeature.State()) { BasketFeature() })
    }
}

#Preview("Empty") {
    let _ = Shared(.basket).withLock { $0.removeAll() }
    NavigationStack {
        BasketView(store: Store(initialState: BasketFeature.State()) { BasketFeature() })
    }
}
