# Product catalog

An iOS app for merchants who run their business from their phone. It browses the [DummyJSON products API](https://dummyjson.com/docs/products), opens a product to check stock, price and details, and builds a basket. It's a take-home assignment for a senior iOS role: a small app, built to ship, where every line can be explained in a live review.

Where things are defined. Read only what your card cites.
- Specification: `docs/specs/product-catalog.md` (acceptance criteria `AC-NNN`). Accepted ADRs override it.
- Decisions: `docs/decisions.md` (the log: one row per decision) and `docs/adr/` (records for decisions that had real alternatives).
- Tasks: `docs/tasks/README.md` (index and lanes) and `docs/tasks/PC-NN-*.md` (cards; a card is the reviewer's ticket).
- `README.md` faces the hiring team. Only the coordinator edits it.

## Hard rules

- **Roles.** The agent that writes production code never writes, edits or deletes tests. The agent that writes tests never edits production code. One agent works on one card.
- **Commits.** Implementers and reviewers never commit, push or merge. The coordinator commits a card as `PC-NN: <title>` on its branch once its review passes, then merges it into `main`. Nothing is pushed without the operator.
- **Authority files.** These change only in coordinator or spec sessions: `docs/`, `CLAUDE.md`, `AGENTS.md`, `scripts/`, `Package.swift`, `Package.resolved`, `project.pbxproj`, the shared scheme and `Product catalog.xctestplan`. An implementer that disagrees with its card writes the disagreement in its `notes.md` and carries on with the card as written.
- **Frozen interfaces.** A module's public interface, as the foundation shipped it, changes only through the coordinator. Record the need in `notes.md`. A component that only one feature uses lives in that feature, not in `Presentation`.
- **Dependencies.** The Composable Architecture and the Point-Free packages it brings are the only third-party code. Adding anything else needs an ADR first.
- **No silent failure.** No `try?`, `try!`, force unwraps or empty `catch`. Handle an error where it can be handled and log it there with `os.Logger`, or rethrow it. `CancellationError` is an outcome, not a failure: don't show it and don't log it as an error.
- **No ids in code.** Never cite AC, ADR or card ids in code or comments. Comments state behaviour, one or two lines. Task reasoning goes in the task's `notes.md`.
- **Tests never touch the network.** Clients are injected. UI tests launch the app with a Debug `-scenario`.
- **Privacy.** Reviewer e-mails are never decoded. Search text is logged only as `.private`.

## Toolchain

Build with Xcode 26.6 (iOS 26.5 SDK). The code has to stay clean under Xcode 27, where Swift 6.4 turns `@State` into a macro.
- TCA must be ≥ 1.26.2 (`Package.resolved` pins it). Its `ComposableArchitecture2Deprecations` trait is on, so deprecation warnings are real work. Fix them; the build has none.
- Never give an `@State` property both a default value and an assignment in `init`. Never combine `@State` with another property wrapper or macro. Give every `@State` an explicit type.
- Previews use `#Preview`, never `PreviewProvider`.

## Concurrency

Swift 6 language mode everywhere.
- The **app target** defaults to `MainActor`. The **`CatalogKit` modules** are nonisolated, with `NonisolatedNonsendingByDefault` and `InferIsolatedConformances` on. Never add `.defaultIsolation` to `Package.swift`: TCA 1.x breaks under it. SwiftUI views and TCA's `Store` run on the main actor anyway.
- `async` means "can suspend", not "runs in the background". Network waits suspend; they don't need another actor.
- Leave the caller's actor only for measured CPU-heavy work, with `@concurrent` on the function. Never use `Task.detached`, `DispatchQueue` or `MainActor.run`.
- Don't add actors. Public types that cross into effects declare `Sendable`. `@unchecked Sendable` needs a lock and a comment saying which one.
- Work belongs to its owner: a TCA effect, or `.task`/`.task(id:)` in a view. Cancellation propagates. Never swallow it.

## TCA conventions

- One feature is one folder in `AppFeature`: an `@Reducer` with `@ObservableState` state, and its view taking `StoreOf<Feature>` (`@Bindable` when it binds).
- Scope with `store.scope(\.child, action: \.child)` and `Scope(\.child, action: \.child)`. The `state:` spellings are deprecated.
- Side effects run in `.run` effects through `@Dependency` clients: `productsClient`, `dataTransfer` and `continuousClock`. Reducers never read `Date()` or sleep for real.
- Debounce with `clock.sleep(for:)` inside an effect marked `.cancellable(id:cancelInFlight: true)`, never `Effect.debounce`. Give every cancellable effect its own `CancelID`.
- Long lists hold plain `IdentifiedArrayOf<Product>` rows. No store per row, and no `forEach` over rows.
- The basket is `@Shared(.basket)`: one value every feature reads and writes.
- A child talks to its parent through `Action.delegate(...)`. Only `AppFeature` knows how features connect.

## Modules

```text
Product catalog/              app target: @main, the root store, the launch bootstrap; nothing else
Packages/CatalogKit/Sources/
  Networking/                 DataTransfer protocol, live URLSession transport, Debug scripted transport
  Catalog/                    Product, Review, ProductPage, ProductCategory, ProductQuery, SortOption,
                              AvailabilityStatus, CatalogError, price math; the DummyJSON client:
                              endpoints, decoding, error mapping, request logs, preview fixtures
  Basket/                     Basket and BasketLine rules and totals; the shared `.basket` key
  Presentation/               StockBadge, PriceView, ErrorStateView, InlineRetryNotice, SlowConnectionHint,
                              QuantityStepper, RemoteImage, CatalogError copy
  AppFeature/                 the screens: TabView root, catalog stack, launch scenarios, and one folder
                              per feature: ProductList/, ProductDetail/, BasketTab/
Packages/CatalogKit/Tests/CatalogKitTests/<Area>/   reviewer-owned; shared helpers only in Support/
Product catalogUITests/       reviewer-owned UI journey
```

| Module | Imports | Must not |
|---|---|---|
| `Networking` | Dependencies | Catalog, SwiftUI |
| `Catalog` | Foundation, Networking, Dependencies | SwiftUI, ComposableArchitecture |
| `Basket` | Catalog, Sharing | SwiftUI, network |
| `Presentation` | Catalog, Networking, Dependencies, SwiftUI | ComposableArchitecture |
| `AppFeature` | Catalog, Basket, Networking, Presentation, ComposableArchitecture | — |
| app target | AppFeature | anything else |

## Commands

| Command | Does |
|---|---|
| `scripts/test` | every CatalogKit test; prints failures and the verdict, with the full log in `.build/logs/test.log` |
| `scripts/test <Suite>…` | only the named Swift Testing suites |
| `scripts/test --ui` | the UI tests |
| XcodeBuildMCP `build_run_sim` | build and run. Session defaults: project `Product catalog.xcodeproj`, scheme `Product catalog`, your simulator, `derivedDataPath` `<checkout>/.build/DerivedData`, `extraArgs` `["-skipMacroValidation"]`. Add `launchArgs` `["-scenario", "<name>"]` for a Debug scenario. |

- Every checkout runs on its own simulator, named in the gitignored `.build/simulator`; `scripts/test` reads it. Command-line builds need `-skipMacroValidation` (TCA ships macros), and the scripts pass it.
- Read log ranges, never whole logs. To see slow responses against the live API, append `delay=<ms>` (≤ 5000) to a DummyJSON request.

## Session protocol

**Implement** (`/start-task PC-NN`, in the lane's own worktree):
1. Read this file, the card and what the card cites. Find code by symbol with `rg` and read ranges. Give broad sweeps to a subagent, and repeat these hard rules in its prompt, because subagents don't load this file.
2. Plan mode. List the files (inside the card's `Owns`), the types and their jobs, and the decisions to record. The operator approves before any edit.
3. Implement inside `Owns` and the card's budget. Crossing either is a scope event: stop, write the reason in `notes.md` and propose a split.
4. Record each material decision in `notes.md` as `AGENT_DECISION` or `AGENT_ASSUMPTION`, with the reason. Material means it touches behaviour, architecture, a dependency, concurrency, scope or the budget.
5. Self-verify. The build is clean with no warnings and `scripts/test` is green. Read the whole diff plus untracked files as the reviewer would. Delete dead code, debug output and comments that restate code.
6. Write the handoff in `notes.md`: files changed, how to exercise the change, known limits, open questions. Then stop and report "ready for review" to the coordinator.

**Review** (`/review-task PC-NN`): always its own session, never a subagent of another session. The coordinator starts it in the checkout under review. Write `strategy.md` before reading any code; the gate enforces this. Load `ios-testing`. Pick the cheapest test layer that catches the regression: models, rules and client mapping as unit tests, reducers with `TestStore` and an injected clock, the one UI journey against the `journey` scenario. `review.md` holds the AC ledger, findings each with their `Wrong if:` line, and what couldn't be verified.

**Rework:** the coordinator relays `findings.md` to the implementer session. The implementer fixes only what it lists, records the cycle in `notes.md` and reports back. The coordinator then resumes the same review session to re-run. After three failures of the same class the coordinator escalates to the operator.

**Close-out** (coordinator): read `review.md`, then the whole diff. Commit, merge, copy material decisions from `notes.md` into `docs/decisions.md`, and update the task index.

**Parallel lanes.** One worktree and one simulator per lane. The authority files are serialization points, and only the coordinator touches them. **The coordinator starts review sessions one at a time**, across all repositories, because the gate marker `~/.claude/work/.review-session` is shared. If a tool call is denied by `review-task gate`, a review is writing its strategy: wait and retry, and never route around it.

Task artifacts live in `~/.claude/work/ProductCatalog/PC-NN/`: `task.json`, `spec.md` (the card and its hash), `branch.json`, `notes.md`, `strategy.md`, `findings.md` and `review.md`. They're never committed.
