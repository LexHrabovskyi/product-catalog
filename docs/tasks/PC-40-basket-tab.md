# PC-40 — Basket tab

| | |
|---|---|
| Kind | implement |
| Depends on | PC-01 |
| Authority | spec §6 Basket, §7. AC-022 (the tab screen), AC-023, AC-025 (basket logs), AC-026 (basket). ADR-0004. |
| Owns | `Packages/CatalogKit/Sources/BasketFeature/` |
| Budget | 6 files / ~350 lines |
| Simulator | iPhone 17e |
| Detail | ready |

## Goal

The merchant reviews the order: each line with its quantity and total, the savings and the grand total, all editable in place.

## Requirements

- **R1. Lines** (AC-023), in basket order. Each shows a `RemoteImage` thumbnail, the title, the discounted unit price, a `QuantityStepper` bounded by the line's minimum…stock, and the line total.
- **R2. Removing.** Swipe a line to remove it. "Clear basket" asks first: "Clear basket?", "Remove all N products?", with a destructive "Clear" and a "Cancel".
- **R3. Summary.** "Subtotal", "Savings" and "Total", all from `Basket`.
- **R4. Empty state.** "Your basket is empty" with "Add products from the catalog."
- **R5. One shared value.** Everything reads and writes `@Shared(.basket)`, so a change made in another tab shows immediately (AC-022).
- **R6. Accessibility.**
  - VoiceOver reads a line as "<title>, <quantity> × <unit price>, <line total>".
  - The totals are readable.
  - Dynamic Type is supported.

## Accessibility identifiers

`basket.list`, `basket.line.<id>`, `basket.subtotal`, `basket.savings`, `basket.total`, `basket.clear`, `basket.empty`.

## Not in this task

Adding products (PC-30), and persistence and badges (PC-01).

## Exit evidence

- `scripts/test` is green, and the build has no warnings.
- Screenshots from a Debug build with two lines added: the basket, the basket after a quantity change, and the empty basket.

## Review focus

- Totals after quantity changes.
- Removing a line, and the confirmation before clearing.
- Clamping at both ends of the range.
- The shared value round-trips with another feature in the same `TestStore`.
