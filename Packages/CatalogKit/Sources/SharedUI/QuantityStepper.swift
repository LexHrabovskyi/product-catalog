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
        // One adjustable element: VoiceOver hears "Quantity, 5" and can't step past either bound.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Quantity")
        .accessibilityValue("\(quantity)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: quantity = min(quantity + 1, range.upperBound)
            case .decrement: quantity = max(quantity - 1, range.lowerBound)
            @unknown default: break
            }
        }
    }
}

#Preview {
    QuantityStepper(quantity: .constant(48), range: 48...99).padding()
}
