# Product catalog

An iOS app for merchants who run their business from their phone. It scans the [DummyJSON](https://dummyjson.com/docs/products) catalog for price and stock, searches and filters it, opens a product, and builds an order basket that survives a relaunch.

## Run it

Open `Product catalog.xcodeproj` in **Xcode 26.6 or later**, pick an iPhone simulator and press Run. The first open fetches the Swift packages, and Xcode asks once to trust the Composable Architecture's macros (**Trust & Enable**). There are no keys and no other setup.

- **Tests:** ⌘U, or `scripts/test` (62 unit and feature tests) and `scripts/test --ui` (the UI journey, about 3 min).
- **Scripted demos, Debug only:** add `-scenario journey`, `large`, `slow` or `offline` under *Edit Scheme → Run → Arguments*. Each swaps the network for a script:
  - `journey`: failures and delays on cue;
  - `large`: 1,200 products;
  - `slow`: 4 s responses;
  - `offline`: no connection.

## Main decisions, and what I considered instead

| Decision | Instead of | Why |
|---|---|---|
| **TCA 1.26 with one feature per module** in a local SwiftPM package (9 modules). A root `TabView` with a navigation stack. swift-dependencies as the DI container. [ADR-0001](docs/adr/0001-tca-modular-architecture.md) | MVVM with `@Observable`; TCA in one module; Factory for DI | One state model with exhaustive `TestStore` tests. Features build and test on their own. TCA already ships a DI container. |
| **Swift 6 everywhere, with MainActor by default only in the app target.** The package modules are nonisolated, with Approachable Concurrency on. [ADR-0002](docs/adr/0002-concurrency-isolation.md) | MainActor by default everywhere | TCA 1.x breaks under default MainActor isolation, and its store and views run on the main actor anyway. |
| **A `DataTransfer` protocol is the only way onto the network.** 15 s per request in total, no automatic retry, an explicit Retry, and "Slow connection…" after 3 s. One error taxonomy with specific copy. [ADR-0003](docs/adr/0003-networking-and-failure-policy.md) | `URLProtocol` stubs; retry with backoff | Every failure the spec names can be produced on demand, in tests, the UI journey and demos, through the real decoding and error mapping. A wait never exceeds 15 s. |
| **Images go through the same seam into a bounded memory cache.** | `AsyncImage`; Nuke | The CDN sends `Cache-Control: no-store`, so nothing else caches them, and a row scrolled back into view mustn't flash its placeholder. |
| **The basket is one shared value, persisted to a file** (`@Shared(.fileStorage)`), with minimum-order and stock rules. [ADR-0004](docs/adr/0004-shared-persisted-basket.md) | SwiftData; UserDefaults; DummyJSON carts, which store nothing | Every screen sees the same basket at once, and the rules are plain, unit-tested functions. |
| **Product calls:**<br>- rows lead with price, discount and stock;<br>- search spans the whole catalog, and the category filter steps aside while it's active (the API ignores the category during a search);<br>- the API's stock label is shown as-is, with the count;<br>- iPhone only, iOS 26. | Stock levels derived from counts; filtering search results on the device; an iPad layout | The job is checking stock and price fast, on a phone. |

All 27 decisions are in [docs/decisions.md](docs/decisions.md). The confirmed specification, with 29 acceptance criteria, is [docs/specs/product-catalog.md](docs/specs/product-catalog.md).

## Left out on purpose, and next

- **iPad and iPhone Duo layouts.** From April 2027 uploads need the iOS 27 SDK, and apps built with it resize on the Duo's inner display, so a regular-width layout becomes due then.
- **An offline catalog and a disk image cache.** Only the basket persists. Without signal, a merchant sees a clear offline state and Retry.
- **Automatic retry** for idempotent requests. Worth adding if production data shows transient failures.
- **Basket freshness.** A line keeps the price and stock from when it was added. Next: re-sync it when its product is opened, and version the stored format before it ever changes.
- **Ordering, product editing, sign-in, localization and analytics** were out of scope for v1.
- **Known small limits** from the reviews are listed in D26. For example, VoiceOver is silent for the first 3 s of a load.

## How I'd know it works for merchants

The app already logs every request, outcome and duration with `os.Logger`, with no search text and no personal data. Once shipped, I'd turn those into events and watch:

- **Time to first products** (p50/p90), and how often the slow hint appears: the first impression on a phone network.
- **Search success:** searches that end with a product opened, and the zero-result rate.
- **Errors by kind** (offline, timeout, 5xx, 4xx), and how often a Retry then succeeds.
- **Detail refresh outcomes:** updated, failed or gone. This shows how often a merchant would have acted on stale stock.
- **Basket use:** adds per session, and how often an add is capped or refused by stock or minimum order.
- **Stability:** crash-free sessions, plus hitches and memory from MetricKit.

## How I used AI

**Tools.**
- **Coordination:** Claude Code coordinated the work.
- **Parallel builds:** separate Claude Code sessions built the four features in parallel, each in its own git worktree and on its own simulator.
- **Independent review:** every card went to a separate reviewer session. A hook in my `claude-workflow` setup made it write its test strategy before it could read the code.
- **Skills:** the spec interview, Swift implementation, testing, and an over-engineering pass.
- **Research agents:** they checked Xcode 27 compatibility and current TCA practice.
- **XcodeBuildMCP:** it built and ran the app and took screenshots.

**Where it helped.**
- **The spec:** the interview turned the brief into 29 testable acceptance criteria and four ADRs.
- **Real defects caught by the independent reviews:**
  - a `+` in a search reached DummyJSON as a space;
  - a status notice scrolled away during a slow refresh, so stale stock looked current;
  - VoiceOver read the quantity twice, and read the slow hint's icon as "Decrease Speed";
  - a timing test passed only on an idle machine.

**Where I changed or rejected its output.**
- **Factory:** I didn't add it, because TCA's dependency system already is the container.
- **Default isolation:** I reverted MainActor by default in the package after research showed TCA 1.x breaks under it.
- **Its product suggestions:** I kept the API's stock label instead of derived thresholds, chose storefront order for the detail screen over inventory-first, and dropped sort-by-stock. I added the persisted basket, and widened the final review to cover the whole merged app.
- **Process:**
  - I stopped a reviewer that was running inside the coordinator's session and restarted it clean. A review is always its own session.
  - I caught slips such as a commit made after a failing test run.

The rules the agents worked under are in [CLAUDE.md](CLAUDE.md), and the task cards are in [docs/tasks](docs/tasks/README.md).
