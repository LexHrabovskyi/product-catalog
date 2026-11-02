# ADR-0004: The basket is one shared, persisted value

- Status: Accepted (2026-11-02)
- Date: 2026-11-02
- Specification: [product-catalog.md](../specs/product-catalog.md) §6 Basket, §7
- Acceptance criteria: AC-020–AC-024, AC-027
- Decided by: operator (kept across launches, one source of truth for both tabs, minimum order and stock rules). The storage choice was made in the spec interview.

## Context

A merchant builds an order across launches. Three places show the same basket: the detail screen's add button and its "Only N in stock" cap, the badges on the catalog toolbar and the Basket tab, and the Basket tab itself. DummyJSON's cart endpoints are simulated and keep nothing. The data also allows a stock level below the minimum order quantity.

## Decision drivers

- One source of truth that every screen observes. High.
- Kept across launches without a database. High.
- Rules testable without UI or disk. High.

## Considered options

1. **TCA's shared state with file storage**, `@Shared(.fileStorage(url))`. It holds a `Codable` `Basket` value in Application Support, and the rules are pure methods on `Basket`.
2. **SwiftData.** A second state system beside TCA, plus migration machinery, for a short list of lines.
3. **`@Shared(.appStorage)` / UserDefaults.** Not meant for structured documents.
4. **DummyJSON carts.** They keep nothing, and they would add network failures to "Add to basket".
5. **`AppFeature` owns the basket and features send it delegate actions.** One owner, but every feature routes basket actions through the root.

## Decision

Option 1.
- **Values.** The `Basket` module holds `Basket` and `BasketLine`: add, set quantity, remove, clear and totals.
- **Rules.**
  - The quantity starts at the minimum order quantity and is capped at stock.
  - A product can't be added when its stock is 0 or below its minimum.
  - Adding a product already in the basket raises that line's quantity.
- **Storage.** The shared key `.basket` stores `basket.json` in Application Support.
- **Sharing.** Every feature declares `@Shared(.basket)`.
- **Debug scenarios** use in-memory storage. Tests do too, because swift-sharing's file storage is in-memory under test.
- **Snapshots.** A line keeps the product data from when it was added (assumption A3).
- **Unreadable file.** An unreadable or outdated file means an empty basket and a logged warning (assumption A4).

## Consequences

### Positive

- A change on any screen appears on every other one immediately, with no plumbing.
- The rules are plain functions on a value, so they're covered by fast unit tests.

### Negative

- Basket prices can go stale until v2 re-syncs lines.
- There's no migration: changing `BasketLine` empties existing baskets.

### Risks and mitigations

- A merchant loses a draft order on a format change → version the format before the first change to `BasketLine`.

## Follow-up

- Re-sync a line's price and stock when its product is opened.
- Add a versioned format before the first schema change.
