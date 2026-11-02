# PC-01 — Foundation: package, contracts and app shell

| | |
|---|---|
| Kind | implement (by the coordinator) |
| Depends on | — |
| Authority | spec §2, §6, §7, §8. AC-004 and AC-006 (error taxonomy, copy, the 15 s limit), AC-010, AC-011, AC-016 (the push only), AC-020 and AC-021 (the rules only), AC-022 (the shared value, the tab badge, switching to the Basket tab), AC-024, AC-025 (request logs), AC-026 (shared views and the tab bar). ADR-0001 to ADR-0004. |
| Owns | `Packages/CatalogKit/` (every module, as skeleton and contract), `Product catalog/`, the project file, the shared scheme, `Product catalog.xctestplan`, `scripts/test` |
| Budget | Exception: this card creates every module and contract |
| Simulator | iPhone 17 Pro |
| Detail | ready |

## Goal

Every module exists with the public interface the lanes build against. The live client talks to DummyJSON, the basket rules hold, and the app launches into a Catalog / Basket tab shell.

## Requirements

- **R1. Decoding.** Models decode the live payload per spec §6:
  - `brand` is optional;
  - the review e-mail is never decoded;
  - review dates carry fractional seconds;
  - price and discount are `Decimal`, rounded to cents;
  - an unknown availability label is kept as it is.
- **R2. Price math.** The discounted unit price is price × (1 − discount / 100), rounded half-up to cents.
- **R3. The live `ProductsClient`.** It builds URLs per §6: `limit`, `skip`, `sortBy`/`order`, `q`, and the category path. It maps failures:
  - offline-class URL errors → `offline`;
  - timed out → `timeout`;
  - 5xx → `server(status)`;
  - 404 on a single product → `notFound`;
  - any other 4xx, including a 404 elsewhere → `client(status)`;
  - an undecodable body → `unreadable`;
  - anything else → `unexpected`.

  Cancellation surfaces as `CancellationError`, never as a catalog error. It logs each request's start, its outcome with status and duration, and the page's item count, but never the query text.
- **R4. Timeout.** The live transport bounds a request at 15 s in total, including a body that arrives slowly.
- **R5. Basket rules.**
  - **Availability:** `.outOfStock` at stock 0, `.belowMinimumOrder` when stock is below the minimum order quantity, and otherwise minimum…stock.
  - **`add`:** starts at the minimum, merges with an existing line, caps at stock and reports the cap.
  - **`setQuantity`:** clamps to minimum…stock.
  - **Totals per §6:** subtotal at list prices, total at discounted prices, savings as the difference, plus the line count.
- **R6. Persistence.** There is one shared basket, kept in Application Support. On launch, an unreadable store logs a warning and the basket starts empty. When the app moves to the background, the basket is saved immediately.
- **R7. `AppFeature`.**
  - It has Catalog and Basket tabs, and the Basket tab's badge shows the line count.
  - The list's `productTapped` pushes a detail for that product.
  - `basketButtonTapped` selects the Basket tab.
- **R8. SharedUI shows the spec's copy:**
  - `ErrorStateView`: the message, an "Error <status>" caption for HTTP failures, and Retry.
  - `InlineRetryNotice` and `SlowConnectionHint`.
  - `StockBadge`: "<label> · <count>", colours per AC-010, VoiceOver "<label>, <count> units".
  - `PriceView`: the row shows the list price and a whole-percent badge; the detail shows the discounted price, the struck-through list price and the exact percent.
  - `QuantityStepper`.
  - `RemoteImage` shows the placeholder.

## Keep (frozen for the lanes)

- Everything public in the modules above.
- `ProductListFeature.Action.delegate(.productTapped(Product))` and `.delegate(.basketButtonTapped)`.
- `ProductDetailFeature.State(product:)` and `BasketFeature.State()`.
- `AppFeature.bootstrap(launchArguments:)` and `AppFeature.makeStore()`.

## Not in this task

The feature screens (PC-20, PC-30, PC-40), image loading and scenarios (PC-10), and the UI journey (PC-50).

## Exit evidence

`scripts/test` is green, the build has no warnings, and the app launches into the tab shell.

## Review focus

- **Shared test support.** The reviewer also creates `Tests/CatalogKitTests/Support/` for later reviewers:
  - a stub `DataTransfer` that answers per request and records what it was asked;
  - payloads captured from the live API, as string literals.
- **Tests to cover:**
  - decoding against a captured page;
  - rounding at half-cent boundaries;
  - basket merge and cap;
  - the error-mapping table, including cancellation and the 404 distinction;
  - the badge, tab switching and the save on background, with `TestStore`.
