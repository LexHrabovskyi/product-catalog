# PC-10 — Image loading and Debug scenarios

| | |
|---|---|
| Kind | implement |
| Depends on | PC-01 |
| Authority | spec §6 (Debug scenarios), §7 (missing or failed image; maximum), §8. AC-009 (image half), AC-025 (image and scenario logs), AC-028. ADR-0003. |
| Owns | `SharedUI/RemoteImage.swift` and new `SharedUI/Image*.swift`; new `Networking/Scripted*.swift`; `AppFeature/LaunchScenario.swift` (all under `Packages/CatalogKit/Sources/`) |
| Budget | 8 files / ~450 lines |
| Simulator | iPhone 17 |
| Detail | ready |

## Goal

Product images load through the app's network seam, use a bounded memory cache, and never flicker when the merchant scrolls back. Debug builds can replace the network with scripted scenarios, for demos and for the UI journey.

## Requirements

- **R1. Loading.** `RemoteImage(url:contentMode:)` keeps its signature.
  - It loads through `@Dependency(\.dataTransfer)` and caches decoded images in a bounded `NSCache` (count and cost limits).
  - A view that leaves the screen cancels its pending load.
  - While loading, and on any failure (no URL, 404, undecodable data), it shows the existing placeholder.
  - Failures log at debug level only.
- **R2. Cache hits.** A second view for the same URL uses the cache and makes no request.
- **R3. Bootstrap.** `AppFeature.bootstrap(launchArguments:)` keeps its signature.
  - In Debug, `-scenario <name>` installs the scenario's `ScriptedDataTransfer` as the `dataTransfer` dependency and switches basket storage to memory (`defaultFileStorage = .inMemory`).
  - An unknown name logs and falls back to live.
  - Release builds compile none of it: the scripted transport, the scenarios and the parsing all sit under `#if DEBUG`.
- **R4. `ScriptedDataTransfer`.**
  - It answers with DummyJSON-shaped JSON, so the live `ProductsClient` decodes it unchanged.
  - It covers the product list with skip/limit, search (case-insensitive title contains), category, categories, product by id, and images.
  - Any request it has no script for answers 404. It never touches the network.
  - Delays are real time, because the UI journey waits on them.
- **R5. Scenarios.**
  - **`journey`:**
    - **Catalog:** 120 products, "Product 1" to "Product 120", spread over 3 categories. Product N defaults to price N.00, no discount, stock 50, minimum order 1, "In Stock".
    - **Pages:**
      - `skip=0` answers 503 the first time, then OK;
      - `skip=30` answers after 2 s;
      - `skip=60` answers 500 the first time, then OK;
      - `skip=90` answers OK.
    - **Product 2:** price 10.00, discount 10, stock 50, minimum 5. Its detail request always answers 503.
    - **Product 3:** its detail request answers 404.
    - **Product 4:** price 20.00, discount 5, stock 10, minimum 2. Answers OK.
    - **Images:** products whose id is divisible by 10 answer 404; the rest return a small generated PNG.
    - **Expected basket** after adding products 2 and 4 at their minimums: subtotal $90.00, savings $7.00, total $83.00.
  - **`large`:** 1,200 products, all answering OK.
  - **`slow`:** the journey catalog without its failures, with every response after 4 s.
  - **`offline`:** every request fails with `URLError(.notConnectedToInternet)`.
- **R6. Logs:** the scenario installed (name), any unscripted request (path), and image failures (debug level). Scenario logs use their own `scenario` category.

## Not in this task

Screens, the UI test itself (PC-50), a disk cache, and prefetching.

## Exit evidence

- `scripts/test` is green, and the build has no warnings.
- Launches with `-scenario journey`, `large`, `slow` and `offline` behave as described. Screenshots go in `notes.md`.
- A Release build compiles without the scripted transport.

## Review focus

- A row that leaves the screen never completes its image request.
- A cache hit avoids a request.
- The placeholder shows on a 404 and on garbage bytes.
- The scripted page counters reset on each launch.
- An unscripted request gets a 404, not the network.
- Release builds exclude the scripted code.
