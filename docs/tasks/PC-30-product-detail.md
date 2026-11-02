# PC-30 — Product detail and add to basket

| | |
|---|---|
| Kind | implement |
| Depends on | PC-01 |
| Authority | spec §5, §7. AC-005 (the detail refresh), AC-016 to AC-021, AC-025 (detail logs), AC-026 (detail). ADR-0003, ADR-0004. |
| Owns | `Packages/CatalogKit/Sources/ProductDetailFeature/` |
| Budget | 8 files / ~450 lines |
| Simulator | iPhone 17 Pro Max |
| Detail | ready |

## Goal

A product's full story in storefront order, with current stock and price, and a way to add it to the basket within its minimum order and stock.

## Requirements

- **R1. Open and refresh.** The screen opens with `State(product:)` and shows that product at once. It then requests `product(id:)`, and the answer replaces the shown product in place (AC-016).
- **R2. Layout** (AC-017), top to bottom:
  1. A gallery: paged, up to 6 images, with a page indicator, `RemoteImage` in `.fit`, and the placeholder for missing images.
  2. Title and brand.
  3. `PriceView(.detail)`.
  4. Rating: stars, the average and the review count.
  5. Description.
  6. Inventory facts: `StockBadge`, "Minimum order N", SKU, barcode, category name, shipping, warranty, return policy and tags.
  7. Reviews: name, medium-style date, stars and comment.
- **R3. Failures and slow loads.**
  - A failed refresh shows `InlineRetryNotice` with "Couldn't update" (AC-018).
  - A 404 shows "This product is no longer available" and disables adding (AC-019).
  - The slow-connection hint appears after 3 s (AC-005).
- **R4. Bottom bar** (A6).
  - A `QuantityStepper` over the product's availability range, starting at the minimum order quantity.
  - "Add to basket" adds to `@Shared(.basket)`. Its outcomes:
    - added: "Added · N in basket";
    - capped: "Only N in stock".
  - Disabled states follow AC-021: "Out of stock", and "Only N in stock — minimum order is M".
- **R5. Re-clamp.** When a refresh changes the stock or the minimum, the stepper re-clamps.
- **R6. Accessibility.** VoiceOver labels for the gallery, rating, stepper and button. Dynamic Type up to accessibility sizes.

## Accessibility identifiers

`detail.gallery`, `detail.updateNotice` (plus `.retry`), `detail.unavailable`, `detail.quantity`, `detail.addToBasket`, `detail.addMessage`.

## Not in this task

Navigation (`AppFeature`), the Basket tab (PC-40), and image loading (PC-10).

## Exit evidence

- `scripts/test` is green, and the build has no warnings.
- Live checks, with screenshots in `notes.md`:
  - a discounted product;
  - a product without a brand;
  - an out-of-stock product;
  - adding the same product twice to see the cap.

## Review focus

- A refresh replaces the product in place without losing the stepper's value.
- The 404 path versus the 5xx path.
- Added, capped and refused outcomes against the shared basket.
- The stepper re-clamps after a refresh.
- Leaving the screen cancels its requests.
