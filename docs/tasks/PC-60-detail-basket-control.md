# PC-60 — Detail: floating basket control, folded description, gallery preload

| | |
|---|---|
| Kind | implement |
| Depends on | PC-50 |
| Authority | spec §7, AC-017, AC-019 to AC-021, AC-025 (detail logs), AC-026 (detail), A6. D30 to D32. ADR-0003 and ADR-0004 with their 2026-11-03 amendments. |
| Owns | `Packages/CatalogKit/Sources/ProductDetailFeature/`, and `Packages/CatalogKit/Sources/SharedUI/RemoteImage.swift` for a load priority (additive; existing callers unchanged) |
| Budget | 6 files / ~350 lines |
| Simulator | iPhone 17 Pro Max |
| Detail | ready |

## Goal

The detail screen always shows what the basket holds for this product, and one control at the bottom adds it and changes its quantity. The description no longer pushes the facts off screen, and the gallery is loaded before the merchant swipes.

## Requirements

- **R1. One basket control** (AC-019 to AC-021, A6, D30). It's the screen's only floating control. Its state comes from `@Shared(.basket)` and the product on screen, checked in this order:
  1. The refresh answered 404: disabled, "This product is no longer available".
  2. The product has a line in the basket: the stepper, reading "N in basket".
  3. Available: "Add to basket", or "Add N to basket" when the minimum N is above 1.
  4. Stock 0: disabled, "Out of stock".
  5. 0 < stock < minimum: disabled, "Only N in stock — minimum order is M".
- **R2. Add.** A tap adds the minimum with `Basket.add(_:quantity:)`, which also refreshes the line's snapshot (D19). The control turns into the stepper with an animation.
- **R3. Stepper.** It edits the product's line in the shared basket with `setQuantity` and `remove`, within the line's `quantityRange`.
  - + adds one, and is disabled at the top of the range.
  - − removes one. At the minimum it becomes delete (a trash symbol, destructive tint), which removes the line without confirmation. The control turns back into Add with an animation.
  - A change made in the Basket tab shows here at once.
  - The screen keeps no quantity of its own: `quantity`, `addOutcome` and `addMessage` go.
- **R4. Floating style**, shared with PC-70 so the two screens match:
  - pinned with `safeAreaBar(edge: .bottom)`, so content scrolls under it with the system's scroll-edge effect;
  - a capsule 16 pt from the screen edges, with no full-width bar background;
  - Add, enabled or disabled, uses `.buttonStyle(.glassProminent)`; the stepper uses `glassEffect`.
- **R5. Description** (AC-017, D31).
  - Longer than 3 lines: it's folded, the third line ends in "…", and a "Show more" button with a down chevron follows.
  - Tapping it expands the text with an animation, and the button becomes "Show less" with an up chevron.
  - Text that fits in 3 lines has no button, at every Dynamic Type size.
- **R6. Gallery** (AC-017, D32).
  - Every image (up to 6) starts loading when the screen opens, not when its page is swiped to.
  - The first starts first and at a higher priority than the rest.
  - Each image is requested once: swiping never starts another request.
  - Leaving the screen cancels whatever is still loading.
  - The page indicator and the adjustable "Product images" element stay.
- **R7. Accessibility and logs.**
  - VoiceOver labels: "Add to basket" (or the disabled reason), "Increase quantity", "Decrease quantity", "Remove from basket", and the count "N in basket".
  - Adds and removals are announced: "Added, N in basket" and "Removed from basket".
  - Adds, quantity changes and removals are logged with the product id and quantity in the `detail` category (AC-025).

## Accessibility identifiers

- `detail.gallery`.
- `detail.description` and `detail.description.toggle`.
- `detail.updateNotice` (plus `.retry`).
- `detail.addToBasket`: Add, and every disabled state.
- `detail.quantity`: the "N in basket" count.
- `detail.quantity.increment`, `detail.quantity.decrement` and `detail.quantity.remove`.

`detail.unavailable` and `detail.addMessage` go.

## Not in this task

- The catalog toolbar and the Basket tab (PC-70).
- The UI journey (PC-80).
- `Basket` rules: the module is frozen. Use `add`, `setQuantity`, `remove` and `line(forProduct:)`.

## Exit evidence

- **Build:** the app builds with no warnings.
- **Tests:** `scripts/test` may fail to compile only where tests use the removed add flow (`ProductDetailFeatureTests`). List those in `notes.md` for the reviewer, who owns the tests.
- **Screenshots in `notes.md`:** live API, `-scenario journey` for the 404 and `slow` for loading, and previews where the live data has no such product.
  - Not in the basket: a minimum of 1, and a minimum above 1.
  - In the basket: at the minimum, above it, and at stock.
  - Out of stock, below the minimum, and gone.
  - A product already in the basket when the screen opens.
  - The description folded and expanded.
  - Gallery page 2 already loaded on the first swipe.

## Review focus

- The control follows the shared basket both ways, including for a product already in the basket when the screen opens.
- Delete at the minimum, and Add coming back.
- The order of states: gone wins over in the basket.
- A refresh while the product is in the basket.
- The gallery: request order, one request per image, and cancellation on leaving.
- VoiceOver labels and announcements.
