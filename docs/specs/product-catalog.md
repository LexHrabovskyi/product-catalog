# Technical Specification: Product catalog v1

- Status: Confirmed by the operator, 2026-11-02
- Date: 2026-11-02
- Decisions: [decisions.md](../decisions.md) D1–D10; [ADR-0001](../adr/0001-tca-modular-architecture.md), [ADR-0002](../adr/0002-concurrency-isolation.md), [ADR-0003](../adr/0003-networking-and-failure-policy.md), [ADR-0004](../adr/0004-shared-persisted-basket.md)

## 1. Problem and context

A merchant runs their business from their phone. They need to find a product fast, check its price and stock, and put together an order. v1 is the first version of that catalog, built on the [DummyJSON products API](https://dummyjson.com/docs/products). The app has to stay usable on slow or failing connections and with catalogs far larger than DummyJSON's 194 products. It's a take-home that gets extended live in a review call, so every behaviour below stays small and explicit.

## 2. Scope and ownership

- Product area: catalog browsing, product detail and the order basket.
- Modules (local SwiftPM package `CatalogKit`; see ADR-0001):
  - Pure values and rules: `Models`, `Basket`.
  - Data access: `Networking`, `ProductsClient`.
  - Shared views: `SharedUI`.
  - Features: `ProductListFeature`, `ProductDetailFeature`, `BasketFeature`.
  - Root: `AppFeature`.
- Integration boundary: DummyJSON over HTTPS through the `DataTransfer` seam (ADR-0003). The device's file system holds the basket only (ADR-0004).

## 3. Goals

- P0: paged catalog list; product detail; every loading, empty and failure state below.
- P0: search, category filter and sort; a basket that persists across launches.
- P0: one UI journey test against a scripted transport, plus unit and feature tests. No test touches the network.
- P1: Dynamic Type and VoiceOver for every screen; structured logs.

## 4. Non-goals

- Offline catalog: product data isn't stored between launches; only the basket is.
- Editing products, placing or paying for orders, sending the basket anywhere.
- iPad and iPhone Duo regular-width layouts (D8), landscape-specific layouts.
- Localization beyond English; analytics SDKs; sign-in; deep links.
- Sorting by stock (offered and declined).
- Disk image cache, image prefetching, barcode or QR rendering.
- Weight and dimensions: the API gives no units, so v1 doesn't show them.

## 5. User stories and flows

- As a merchant, I want to scan prices and stock levels in a long list, so that I spot what needs attention.
- As a merchant, I want to search the whole catalog, or browse a category in a sort order of my choice, so that I find a product fast.
- As a merchant, I want a product's current details, so that I quote the right price and stock.
- As a merchant, I want to build a basket that respects minimum order quantities and stock, and that is still there tomorrow, so that I can prepare an order.

**Primary flow:**
1. Launch: the Catalog tab shows skeleton rows, then page 1.
2. Scroll: further pages load.
3. Search, or pick a category and sort.
4. Tap a row: the detail screen opens with the row's data, then refreshes.
5. Pick a quantity and add the product to the basket.
6. Open the Basket tab: review the lines, adjust quantities, see the totals.

Leaving a screen cancels its requests. Retry is always explicit; nothing retries automatically.

## 6. Data and contracts

### DummyJSON (verified against the live service, 2026-11-02)

| Request | Notes |
|---|---|
| `GET /products?limit&skip&sortBy&order` | Envelope `{products, total, skip, limit}`. Default limit 30; `limit=0` returns everything. A skip past the end returns `products: []` with the real `total`. |
| `GET /products/search?q=&limit&skip&sortBy&order` | Searches the whole catalog. **Ignores any category parameter.** No matches → `{products: [], total: 0, skip: 0, limit: 0}`. |
| `GET /products/category/{slug}?limit&skip&sortBy&order` | An unknown slug returns 200 with an empty list. |
| `GET /products/categories` | 24 × `{slug, name, url}`. |
| `GET /products/{id}` | An unknown id returns 404 with `{"message": "Product with id 'N' not found"}`. |

- `sortBy` works on every listing endpoint (`price`, `title`, `rating` verified). An unknown `sortBy` is silently ignored.
- `x-ratelimit-limit: 100`.
- A page of 30 full products is 44 KB raw and 7.8 KB gzipped, so the list fetches full products.
- Images are WebP on `cdn.dummyjson.com`, served with `Cache-Control: no-store`. Thumbnails are ~10 KB. A wrong path returns 404.
- Testing aids: `?delay=<ms>` (≤ 5000; above that returns 400) and `/http/<code>`.

### Product (all 194 products profiled)

| Field | Type | Notes |
|---|---|---|
| `id` | Int | 1…194 |
| `title` | String | ≤ 41 characters |
| `description` | String | |
| `category` | String | A slug. Its display name is the slug's words capitalised ("home-decoration" → "Home Decoration"). |
| `brand` | String? | **Missing on 92 products.** Rows show the category instead. |
| `price` | Decimal | USD (assumed, A5). At most 2 decimals; 0.79…36999.99. |
| `discountPercentage` | Decimal | 0.04…19.61 |
| `rating` | Double | 0…5 |
| `stock` | Int | 0…100 |
| `availabilityStatus` | String | "In Stock", "Low Stock" or "Out of Stock". **Shown as-is**, even where it disagrees with `stock`. |
| `minimumOrderQuantity` | Int | 1…50 |
| `sku` | String | |
| `warrantyInformation`, `shippingInformation`, `returnPolicy` | String | |
| `tags` | [String] | |
| `meta.barcode` | String | |
| `images` | [URL] | 1…6 per product |
| `thumbnail` | URL | |
| `reviews` | [{rating Int, comment, date, reviewerName, reviewerEmail}] | 3 each. `reviewerEmail` is never decoded into the model, shown or logged. |

### Derived values

- Discounted unit price = `price × (1 − discountPercentage / 100)`, rounded half-up to cents.
- Rows show the discount as a whole percent ("−13%"). Detail shows it with up to two decimals ("−12.91%").
- Prices are formatted as USD for the device locale. Review dates use the locale's medium date style.

### Basket (persisted; ADR-0004)

- `Basket.lines`: an ordered list of `BasketLine`. Each line holds the product id, title, thumbnail, price, discount percentage, stock, minimum order quantity and quantity, snapshotted when the product is added (A3).
- Line total = discounted unit price × quantity.
- Subtotal = Σ price × quantity. Savings = subtotal − total. Total = Σ line totals.
- The badge counts lines, not units (A1).
- Stored as JSON in Application Support through TCA's shared file storage. Every screen reads the same shared value.

### Debug scenarios (ADR-0003)

Debug builds accept a `-scenario <name>` launch argument. It swaps the live transport for a scripted one, and the basket for an in-memory one. Release builds contain neither.

| Scenario | Behaviour |
|---|---|
| `journey` | The AC-027 script |
| `large` | 1,200 synthetic products, paged like the API |
| `slow` | Every response arrives after 4 s |
| `offline` | Every request fails as offline |

In every scenario, image requests get a generated image, except for products the script marks as image-less, which get a 404.

## 7. States and edge cases

| Situation | Required behaviour |
|---|---|
| First load | 8 skeleton rows; after 3 s, "Slow connection…" (AC-001, AC-005) |
| Empty | No matches, empty category or empty catalog each have their own copy (AC-008) |
| Success | Rows; footer "All N products" at the end (AC-001, AC-002) |
| Partial: next page fails | Rows stay; the footer offers "Try again" (AC-003) |
| Recoverable error: page 1 | Full-screen message, code caption, Retry (AC-004) |
| Recoverable error: refresh | Rows stay; banner "Couldn't refresh · Retry" (AC-007) |
| Recoverable error: detail refresh | Data stays; "Couldn't update · Retry" (AC-018) |
| Terminal: product gone | "This product is no longer available"; adding is disabled (AC-019) |
| Offline, timeout, 5xx, other 4xx, unreadable data | Specific copy, caption "Error <status>" for HTTP failures (AC-006, AC-004) |
| Permission denied | N/A: the app asks for no permissions |
| Cancellation | Leaving a screen, a new query, category or sort, or a new refresh cancels the request it replaces. Cancellation is never shown or logged as an error. |
| Repeated action | At most one next-page request in flight per list. Duplicate product ids are dropped when pages are appended. Each "Add to basket" tap adds once, capped at stock. |
| Maximum | 1,000+ rows render lazily, and image loads follow visible rows (AC-009). Quantity is capped at stock. Titles wrap to 2 lines in rows. |
| Unknown availability label | Shown as-is in a neutral style (AC-010) |
| Missing brand | The category is shown (AC-001) |
| Missing or failed image | A neutral placeholder with a photo symbol, never a broken image (AC-001, AC-017) |
| Unreadable stored basket | Start empty, log a warning, don't crash (AC-024) |
| Stock below minimum order | Adding is disabled with an explanation (AC-021) |

## 8. Observability and privacy

- `os.Logger`, subsystem = bundle id. Categories: `network`, `list`, `detail`, `basket`, `images`.
- **Network:** every request logs start (path), completion (status, duration, item count) and failure (error kind, status). Cancellation is logged at debug level only.
- **Errors and warnings:** decoding failures, basket load or save failures, and image failures (debug level, so they don't flood the log).
- **Never logged:** search text (unless marked `.private`) and reviewer e-mail. Reviewer e-mails are never decoded, so they can't leak anywhere.

## 9. Acceptance criteria

### List

- [ ] **AC-001** Given the network works, when the Catalog tab first appears, then 8 skeleton rows show until page 1 (30 products, catalog order) arrives. Each row shows the thumbnail, the title (up to 2 lines), the brand (the category's name when the brand is missing), the price, the discount badge, and the stock badge with its label and count.
- [ ] **AC-002** Given more products exist, when one of the last 5 loaded rows appears, then the next 30 load with a footer spinner. Rows are appended without duplicate ids, and at most one page request is in flight. When everything has loaded, the footer reads "All N products".
- [ ] **AC-003** Given a next-page request fails, then the footer shows "Couldn't load more" with "Try again" instead of the spinner, and every loaded row stays. "Try again" requests that same page.
- [ ] **AC-004** Given page 1 fails, then the screen shows the failure's copy, the caption "Error <status>" for HTTP failures, and a "Retry" button that reloads page 1. The copy:
  - offline: "You're offline. Check your connection and try again."
  - 5xx: "The catalog service isn't responding. Try again in a moment."
  - any other 4xx, or unreadable data: "Something went wrong loading products."
- [ ] **AC-005** Given any visible loading state (skeleton, footer, refresh, detail refresh) has lasted 3 s, then "Slow connection…" appears beside it, and it disappears when the request ends.
- [ ] **AC-006** Given a request hasn't completed after 15 s, then it fails as a timeout with "The catalog is taking too long to respond." and the same retry affordance as its context. Nothing retries automatically.
- [ ] **AC-007** Given rows are shown, when the merchant pulls to refresh, then page 1 reloads with the current query, category and sort. The rows stay until the answer arrives and are then replaced. If the refresh fails, the rows stay and a banner shows "Couldn't refresh" with "Retry".
- [ ] **AC-008** Given an answer with zero products, then the empty state matches the context:
  - search: "No products match “<query>”" with "Clear search";
  - category: "No products in <Category>";
  - otherwise: "No products yet".
- [ ] **AC-009** Given a catalog of 1,200 products (`large` scenario), when the merchant scrolls from top to bottom, then every row appears in order. Rows are created lazily. Image requests are made only for rows that come on screen, and a row that leaves the screen cancels its pending image request. Manual check, Release build: no visible hitch while scrolling.
- [ ] **AC-010** The stock badge shows the API's `availabilityStatus` label and the count ("Low Stock · 3"):
  - "In Stock" green;
  - "Low Stock" orange;
  - "Out of Stock" red;
  - any other label as-is, in a neutral style.
- [ ] **AC-011** Prices are USD formatted for the device locale. Discounted prices and totals are exact to the cent, following the rounding in §6.

### Search, category and sort

- [ ] **AC-012** Given the merchant types in "Search products", when typing pauses for 300 ms, then page 1 of the whole catalog's results for the trimmed query loads. A changed query cancels the previous query's request. Results page like the list. An empty or whitespace query returns to browsing.
- [ ] **AC-013** Given a query is active, then the category control shows "All categories" and is disabled. When the query is cleared, browsing resumes with the previously selected category and the current sort.
- [ ] **AC-014** Given the category menu opens, then it lists "All categories" plus the API's categories by name. Choosing one loads page 1 of that category with the current sort. If the categories request fails, the menu shows "Couldn't load categories" with "Retry", and the list keeps working.
- [ ] **AC-015** The sort menu offers Default, "Price: low to high", "Price: high to low", "Title: A–Z" and "Rating: highest first". Changing it reloads page 1 for the current query or category and cancels any request in flight. The choice holds across search and category changes for the session.

### Detail

- [ ] **AC-016** Given the merchant taps a row, then the detail screen opens showing that row's product immediately and requests `/products/{id}`. When the answer arrives, the screen updates in place.
- [ ] **AC-017** The detail screen shows, in this order:
  1. a swipeable gallery of the product's images with a page indicator, and placeholders for missing or failed images;
  2. title and brand, then price, discount and discounted price;
  3. rating (stars, average, review count);
  4. description;
  5. inventory facts: stock badge, minimum order quantity, SKU, barcode, category, shipping, warranty, return policy, tags;
  6. reviews: name, date, stars and comment, never e-mail.

  A bottom bar holds the quantity stepper and "Add to basket" (A6).
- [ ] **AC-018** Given the refresh fails for any reason except 404, then the shown data stays and an inline notice says "Couldn't update" with the code caption and "Retry".
- [ ] **AC-019** Given the refresh returns 404, then the screen shows "This product is no longer available", and adding to the basket is disabled. Back navigation still works.

### Basket

- [ ] **AC-020** Given a product whose stock ≥ its minimum order quantity, then the stepper starts at the minimum and is bounded by stock. "Add to basket" adds that quantity. Adding a product already in the basket raises its quantity, capped at stock; when the cap applies, the screen says "Only N in stock".
- [ ] **AC-021** Given stock is 0, then the button is disabled and reads "Out of stock". Given 0 < stock < the minimum, it's disabled and reads "Only N in stock — minimum order is M".
- [ ] **AC-022** The Basket tab's badge shows the number of lines. The catalog's toolbar has a basket button with the same badge, and it switches to the Basket tab (A1). Every screen reads one shared basket, so a change anywhere shows everywhere at once.
- [ ] **AC-023** The Basket tab:
  - lists each line with thumbnail, title, discounted unit price, a stepper bounded by minimum…stock, and the line total;
  - supports swipe to remove;
  - offers "Clear basket", which confirms first;
  - shows "Subtotal", "Savings" and "Total";
  - when empty, shows "Your basket is empty" and "Add products from the catalog."
- [ ] **AC-024** Given the app quits and relaunches, then the basket comes back with the same lines and quantities. Given the stored basket can't be read, the app starts with an empty basket and logs a warning.

### Cross-cutting

- [ ] **AC-025** Logs follow §8. Search text appears only as private, and reviewer e-mail never appears in the UI or logs.
- [ ] **AC-026** Every screen supports Dynamic Type up to accessibility sizes, and rows reflow vertically at those sizes. VoiceOver reads a row as one element: "<title>, <brand or category>, <price>, <discount> off, <status>, <count> units". Every button has a label. Light and dark mode both work.
- [ ] **AC-027** UI journey, Debug `journey` scenario, no network. Each step ends with an assertion:
  1. Launch: page 1 fails with 503 → the error screen shows "Error 503" → Retry loads page 1.
  2. Scroll: page 2 arrives after a 2 s delay, with the footer spinner visible meanwhile.
  3. Scroll on: page 3 fails → the footer shows "Try again" instead of the spinner → "Try again" loads page 3.
  4. Scroll on normally: page 4 loads.
  5. Open product A: its refresh fails → "Couldn't update" shows and adding still works → add A.
  6. Open product B: it answers 404 → "This product is no longer available" shows and adding is disabled.
  7. Open product C: it loads normally → add C.
  8. The basket badge shows 2. The Basket tab lists A and C at their minimum quantities with the expected total.
- [ ] **AC-028** Release builds contain no scripted transport and no scenario handling. A Debug build launched without `-scenario` uses the live network and the real basket file.

## 10. Architecture decisions

- [ADR-0001](../adr/0001-tca-modular-architecture.md): TCA 1.26 in a modular package, with tab and stack navigation and swift-dependencies as the DI container (no Factory).
- [ADR-0002](../adr/0002-concurrency-isolation.md): isolation. MainActor by default in the app target only; package modules nonisolated with Approachable Concurrency on.
- [ADR-0003](../adr/0003-networking-and-failure-policy.md): the `DataTransfer` seam, timeout and retry policy, error taxonomy, image loading and cache, the Debug scripted transport.
- [ADR-0004](../adr/0004-shared-persisted-basket.md): the basket as one shared persisted value, and its rules.
- No ADR for sort options, copy or layout: they're product choices, recorded here and easy to change.

## 11. Open questions and assumptions

No open questions. These assumptions were confirmed by the operator on 2026-11-02:
- **A1:** The badge counts lines. The basket button sits in the catalog toolbar *and* the Basket tab carries the same badge.
- **A2:** Products whose stock is below their minimum order can't be added (AC-021).
- **A3:** A basket line keeps the product data from the moment it was added. Prices and stock in the basket aren't re-synced in v1, so the basket shows prices as of when the product was added.
- **A4:** If the stored basket's format changes or the file is corrupt, the basket starts empty. v1 has no migration.
- **A5:** Prices are USD; the API doesn't say.
- **A6:** The detail screen's quantity stepper and "Add to basket" live in a bottom bar that's always visible.
