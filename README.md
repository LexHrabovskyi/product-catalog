# Product catalog

An iOS app for merchants who run their business from their phone. It checks price and stock across the [DummyJSON](https://dummyjson.com/docs/products) catalog, searches and filters it, opens a product, and builds an order basket that survives a relaunch.

## Run it

Open `Product catalog.xcodeproj` in **Xcode 26.6 or later**, pick an iPhone simulator (iOS 26 or later) and press Run. On first open, Xcode fetches the packages and asks once to trust the Composable Architecture's macros (**Trust & Enable**). There are no keys and no other setup.

Tests run with ⌘U; the UI journey alone takes about 3 minutes. Debug builds also accept a `-scenario` launch argument (*Edit Scheme → Run → Arguments*), which replays network conditions without touching the API:
- `journey`: scripted failures;
- `large`: 1,200 products;
- `slow`: 4 s responses;
- `offline`: no connection.

## Main decisions

| Decision | Instead of | Why |
|---|---|---|
| **TCA 1.26 in a local Swift package of five modules:** Networking, Catalog, Basket, Presentation, and AppFeature for the screens. swift-dependencies for DI. [ADR-0001](docs/adr/0001-tca-modular-architecture.md) | MVVM with `@Observable`; a module per screen; Factory | One state model with exhaustive `TestStore` tests. Each module boundary has one reason. TCA already ships a DI container. |
| **Swift 6 with approachable concurrency.** The package is nonisolated; only the app target defaults to the main actor. [ADR-0002](docs/adr/0002-concurrency-isolation.md) | MainActor by default everywhere | TCA 1.x breaks under default MainActor isolation. |
| **One `DataTransfer` protocol onto the network.** A 15 s limit, explicit Retry, and "Slow connection…" after 3 s. [ADR-0003](docs/adr/0003-networking-and-failure-policy.md) | `URLProtocol` stubs; automatic retry | Every failure can be replayed, in tests and demos, through the real decoding and error mapping. |
| **Images through the same seam,** into a bounded memory cache. | `AsyncImage`; Nuke | The CDN sends `Cache-Control: no-store`, so nothing else would cache them. |
| **One shared basket, persisted to a file,** with minimum-order and stock rules. [ADR-0004](docs/adr/0004-shared-persisted-basket.md) | SwiftData; DummyJSON carts, which store nothing | Every screen sees the same basket, and the rules are plain, unit-tested functions. |

Rows lead with price, discount and stock, and show the API's stock label as-is, because the job is checking stock and price fast. Every decision is in [docs/decisions.md](docs/decisions.md). The specification, with its acceptance criteria, is [docs/specs/product-catalog.md](docs/specs/product-catalog.md).

## Left out, and next

- **iPad and iPhone Duo layouts.** These become due once uploads need the iOS 27 SDK (April 2027), because apps built with it resize on the Duo's inner display.
- **An offline catalog and a disk image cache.** Only the basket persists. Without signal, the app shows a clear offline state and Retry.
- **Basket freshness.** A line keeps the price and stock from when it was added. Next, re-sync it when its product is opened.
- **Truly modular packages.** Today one local package, `CatalogKit`, holds five modules, and the three screens share `AppFeature`. With more time, I'd split it into separate Swift packages, one per layer and one per feature, so each builds, tests and evolves on its own.
- **Automatic retry,** if production data shows transient failures.
- **Out of scope for v1:** ordering, sign-in, localization and analytics.

## How I'd know it works for merchants

The app already logs each request's outcome and duration with `os.Logger`. Search text stays private, and there's no personal data. Once shipped, I'd turn those logs into events and watch:
- time to first products (p50/p90), and how often "Slow connection…" appears;
- searches that end with a product opened, and the zero-result rate;
- errors by kind, and how often Retry then succeeds;
- basket adds, and how often stock or the minimum order refuses one;
- crash-free sessions, plus hitches and memory from MetricKit.

## How I used AI

- **Tools.**
  - Claude Code coordinated the work. A spec interview produced the acceptance criteria, then the ADRs and task cards.
  - Separate sessions built the features in parallel, each in its own git worktree.
  - Each feature card was checked by an independent reviewer session, which wrote its tests before reading the code. To save time, the last round (the catalog filter, the module restructure and the journey update) went in on the full test suite and a run on my iPhone instead.
  - XcodeBuildMCP built and ran the app and took screenshots. Codex CLI drew the app icon in FYUL's colours.
- **Where it helped.** It turned the brief into testable acceptance criteria. The reviews caught real defects:
  - a `+` in a search reached the API as a space;
  - a status notice scrolled away during a slow refresh;
  - VoiceOver read the quantity twice;
  - a timing test passed only on an idle machine.
- **Where I changed or rejected it.**
  - I didn't add Factory, because TCA's dependency system is already the container.
  - I reverted MainActor-by-default in the package once research showed TCA 1.x breaks under it.
  - I overruled its product suggestions (derived stock levels, sort by stock, an inventory-first detail screen) and added the persisted basket.
  - I stopped a reviewer that was running inside the coordinator's session, and restarted it clean.
  - After using the app on my iPhone, I redesigned the detail screen's basket control (it ignored what was already in the basket), the category filter and the basket totals. I also cut the modules from nine to five.

The agents' rules are in [CLAUDE.md](CLAUDE.md), and the task cards are in [docs/tasks](docs/tasks/README.md).
