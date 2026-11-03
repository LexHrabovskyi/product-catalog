# PC-70 — Catalog filter and pinned basket totals

| | |
|---|---|
| Kind | implement |
| Depends on | PC-50 |
| Authority | spec AC-013, AC-014, AC-022, AC-023, AC-026 (list and basket), A1. D33 to D35. |
| Owns | `Packages/CatalogKit/Sources/ProductListFeature/`, `Packages/CatalogKit/Sources/BasketFeature/`, and in `Packages/CatalogKit/Sources/AppFeature/AppFeature.swift` only the route for the removed basket button |
| Budget | 6 files / ~200 lines |
| Simulator | iPhone Air |
| Detail | ready |

## Goal

The catalog's toolbar does one job, finding products, and the basket's totals stay in view.

## Requirements

- **R1. No basket button** (AC-022, D33).
  - Remove the catalog toolbar's basket button, its `basketButtonTapped` action and delegate case, and AppFeature's route for it.
  - The Basket tab's badge stays.
- **R2. Category filter** (AC-014, D33).
  - The category menu moves to the top right, next to sort, as an icon: `line.3.horizontal.decrease.circle` while all categories show, `line.3.horizontal.decrease.circle.fill` while one is selected.
  - Its contents don't change: "All categories", the categories, loading, and the failure with Retry.
  - The selected category's name is the screen's subtitle (`navigationSubtitle`). There's none for all categories.
  - VoiceOver: label "Category", and value the category's name or "All categories".
  - It's disabled while a search runs.
- **R3. A search resets the category** (AC-013, D34). When a search runs, the category resets to all categories, so clearing the search shows the whole catalog with the current sort.
- **R4. Pinned totals** (AC-023, D35).
  - "Subtotal", "Savings" and "Total" leave the list for a panel pinned to the bottom of the Basket tab, above the tab bar. The lines scroll under it.
  - The floating style is shared with PC-60, so the screens match:
    - `safeAreaBar(edge: .bottom)`;
    - a `glassEffect` rounded rectangle with 24 pt corners;
    - 16 pt from the screen edges;
    - no full-width bar background.
  - There's no panel when the basket is empty.
  - At accessibility sizes, amounts wrap rather than truncate.

## Accessibility identifiers

- **Unchanged:** `catalog.categoryMenu` (now the filter), `catalog.sortMenu`, `basket.subtotal`, `basket.savings` and `basket.total`.
- **Removed:** `catalog.basketButton`.

## Not in this task

- The detail screen (PC-60).
- The UI journey (PC-80).

## Exit evidence

- **Build:** the app builds with no warnings.
- **Tests:** `scripts/test` may fail to compile only where tests use the removed basket button or the old category rule (`ProductListFeatureTests`, `AppFeatureTests`). List those in `notes.md` for the reviewer, who owns the tests.
- **Screenshots in `notes.md`:**
  - the filter outlined, then filled with the subtitle;
  - a search running, with the filter disabled;
  - the catalog after clearing the search;
  - the basket with the panel, and lines scrolled under it;
  - the empty basket;
  - the panel at an accessibility size, and in dark mode.

## Review focus

- The category resets when a search runs, and clearing the search brings back the whole catalog with the current sort.
- The filter's icon and the subtitle follow the category through choose, search and clear.
- Nothing still routes to the removed button.
- The panel stays above the tab bar and never hides the last line.
