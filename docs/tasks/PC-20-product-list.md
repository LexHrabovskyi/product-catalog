# PC-20 — Product list

| | |
|---|---|
| Kind | implement |
| Depends on | PC-01 |
| Authority | spec §5, §7, §8. AC-001 to AC-005, AC-007, AC-008, AC-009 (lazy rows), AC-012 to AC-015, AC-022 (the toolbar button), AC-025 (list logs; search text private), AC-026 (rows). ADR-0001, ADR-0003. |
| Owns | `Packages/CatalogKit/Sources/ProductListFeature/` |
| Budget | 10 files / ~550 lines |
| Simulator | iPhone Air |
| Detail | ready |

## Goal

The Catalog tab. A fast, paged list that a merchant scans for price and stock, can search, filter by category and sort, and that stays usable on slow and failing connections.

## Requirements

- **R1. First load.** Eight skeleton rows show until page 1 arrives. Rows follow AC-001 and use SharedUI: a 56 pt `RemoteImage`, `PriceView(.row)` and `StockBadge`.
- **R2. Paging** (AC-002 and AC-003).
  - The next page loads when one of the last five rows appears.
  - Only one page request is in flight at a time.
  - Duplicate ids are dropped.
  - The footer shows a spinner while loading, "Couldn't load more" with "Try again" on failure, and "All N products" at the end.
- **R3. First-page failure and slow loads.**
  - A first-page failure shows `ErrorStateView` (AC-004).
  - The slow-connection hint appears after 3 s on the `continuousClock` (AC-005).
  - The timeout copy comes from the client's error.
- **R4. Refresh.** Pull to refresh follows AC-007. A failed refresh shows `InlineRetryNotice` with "Couldn't refresh".
- **R5. Empty states** per AC-008.
- **R6. Search** (AC-012 and AC-013).
  - `.searchable` with the prompt "Search products".
  - A 300 ms debounce on the clock; the query is trimmed; a new query cancels the one in flight; an empty query returns to browsing.
  - While searching, the category control shows "All categories" and is disabled. Clearing the search restores the previous category.
- **R7. Category and sort.**
  - The category menu follows AC-014: categories load once, and a failure shows "Couldn't load categories" with "Retry" inside the menu while the list keeps working.
  - The sort menu follows AC-015, using `SortOption`.
- **R8. Taps and toolbar.**
  - The toolbar has a basket button whose badge is the shared basket's line count. Tapping it sends `.delegate(.basketButtonTapped)`.
  - Tapping a row sends `.delegate(.productTapped(product))`.
- **R9. Lazy rows.** `List` (or `LazyVStack`) over `IdentifiedArrayOf<Product>`, with no store per row.
- **R10. Accessibility.** VoiceOver reads a row as one element (AC-026), and rows reflow vertically at accessibility text sizes.

## Accessibility identifiers

- **List and rows:** `catalog.list`, `catalog.row.<id>`.
- **Footer:** `catalog.footer.spinner`, `catalog.footer.retry`, `catalog.footer.end`.
- **States:** `catalog.error` (plus `.caption` and `.retry` from `ErrorStateView`), `catalog.refresh` (plus `.retry`), `catalog.empty`.
- **Toolbar:** `catalog.basketButton`, `catalog.categoryMenu`, `catalog.sortMenu`.

## Not in this task

The detail screen, the Basket tab, the internals of image loading (PC-10), and navigation wiring (`AppFeature`).

## Exit evidence

- `scripts/test` is green, and the build has no warnings.
- Against live DummyJSON: paging to the end (194 products), searching "phone", one category, and each sort. Screenshots go in `notes.md`.

## Review focus

- Debounce and cancellation, with a test clock.
- De-duplication of the next page, and only one in flight at a time.
- A failed refresh keeps the rows.
- The category comes back after a search is cleared.
- Each context has its own empty state.
- When the slow hint appears.
- Footer retry asks for the same `skip` again.
