import SwiftUI

/// Picks a quantity within `range`, e.g. minimum order quantity through stock.
public struct QuantityStepper: View {
    @Binding private var quantity: Int
    private let range: ClosedRange<Int>

    public init(quantity: Binding<Int>, range: ClosedRange<Int>) {
        _quantity = quantity
        self.range = range
    }

    public var body: some View {
        Stepper(value: $quantity, in: range) {
            Text("Qty \(quantity)").monospacedDigit()
        }
        .accessibilityLabel("Quantity")
        .accessibilityValue("\(quantity)")
    }
}

#Preview {
    QuantityStepper(quantity: .constant(48), range: 48...99).padding()
}
