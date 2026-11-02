import Basket
import ComposableArchitecture
import Models
import ProductsClient
import SharedUI
import SwiftUI

private let usd = Decimal.FormatStyle.Currency(code: "USD")

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
            Section {
                ForEach(store.basket.lines) { line in
                    BasketLineRow(
                        line: line,
                        quantity: Binding(
                            get: { line.quantity },
                            set: { store.send(.quantityChanged(id: line.id, quantity: $0)) }
                        )
                    )
                    .swipeActions {
                        Button("Remove", systemImage: "trash", role: .destructive) {
                            store.send(.removeButtonTapped(id: line.id))
                        }
                    }
                }
            }
            // Amounts in primary rather than the list's secondary gray, which is too faint for the totals.
            Section {
                LabeledContent("Subtotal") {
                    Text(store.basket.subtotal, format: usd).foregroundStyle(.primary)
                }
                .accessibilityIdentifier("basket.subtotal")
                LabeledContent("Savings") {
                    Text(-store.basket.savings, format: usd).foregroundStyle(.primary)
                }
                .accessibilityIdentifier("basket.savings")
                LabeledContent("Total") {
                    Text(store.basket.total, format: usd).foregroundStyle(.primary)
                }
                .font(.headline)
                .accessibilityIdentifier("basket.total")
            }
        }
        .accessibilityIdentifier("basket.list")
        .toolbar {
            Button("Clear basket", systemImage: "trash", role: .destructive) {
                store.send(.clearButtonTapped)
            }
            .accessibilityIdentifier("basket.clear")
        }
    }
}

private struct BasketLineRow: View {
    let line: BasketLine
    @Binding var quantity: Int
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            summary
            QuantityStepper(quantity: $quantity, range: line.quantityRange)
        }
    }

    /// One VoiceOver element; the stepper after it stays separately adjustable.
    private var summary: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        let unitPrice = line.unitPrice.formatted(usd)
        let lineTotal = line.lineTotal.formatted(usd)
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
