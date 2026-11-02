# Product catalog

An iOS app for merchants who run their business from their phone. It browses the [DummyJSON products API](https://dummyjson.com/docs/products) and opens a product to check stock, price and details. It's a take-home assignment for a senior iOS role: a small app, built to ship, where every line can be explained in a live review.

Where things are defined. Read only what your card cites.
- Specification: `docs/specs/product-catalog.md` (acceptance criteria `AC-NNN`). Accepted ADRs override it.
- Decisions: `docs/decisions.md` (the log: one row per decision) and `docs/adr/` (records for decisions that had real alternatives).
- Tasks: `docs/tasks/README.md` (index and lanes) and `docs/tasks/PC-NN-*.md` (cards; a card is the reviewer's ticket).
- `README.md` faces the hiring team. Only the coordinator edits it.

## Hard rules

- **Roles.** The session that writes production code never writes, edits or deletes tests. The session that writes tests never edits production code. One session works on one card.
- **Commits.** Implementers and reviewers never commit, push or merge. The coordinator commits a card as `PC-NN: <title>` on its branch once its review passes, then merges it into `main`. Nothing is pushed without the operator.
- **Authority files.** `docs/`, `CLAUDE.md`, `AGENTS.md`, `scripts/`, `Package.swift`, `Package.resolved` and `project.pbxproj` change only in coordinator or spec sessions. An implementer that disagrees with its card writes the disagreement in its `notes.md` and carries on with the card as written.
- **Project file.** Never hand-edit `project.pbxproj`. App folders are synchronized groups, so a new file in an existing folder needs no project change.
- **Dependencies.** The Composable Architecture and the Point-Free packages it brings are the only third-party code. Adding anything else needs an ADR first.
- **No silent failure.** No `try?`, `try!`, force unwraps or empty `catch`. Handle an error where it can be handled and log it there with `os.Logger`, or rethrow it. `CancellationError` is an outcome, not a failure: don't show it and don't log it as an error.
- **No ids in code.** Never cite AC, ADR or card ids in code or comments. Comments state behaviour. Task reasoning goes in the task's `notes.md`.
- **Tests never touch the network.** Clients are injected. UI tests launch the app against bundled fixtures.
- **Privacy.** Never log or display reviewer e-mail addresses. They are in the payload, but the app doesn't need them.

## Toolchain

Build with Xcode 26.6 (iOS 26.5 SDK). The code has to stay clean under Xcode 27, where Swift 6.4 turns `@State` into a macro.
- TCA must be ≥ 1.26.2. Older versions don't compile under Swift 6.4, and `Package.resolved` pins the version.
- Never give an `@State` property both a default value and an assignment in `init`. Never combine `@State` with another property wrapper or macro. Give every `@State` an explicit type.
- Previews use `#Preview`, never `PreviewProvider`.

## Concurrency

Swift 6 language mode, approachable concurrency: everything is `MainActor` unless it says otherwise (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`).
- `async` means "can suspend", not "runs in the background". Network waits suspend, so they stay on the main actor.
- Leave the main actor only for measured CPU-heavy work, with `@concurrent` on the function. Never use `Task.detached`, `DispatchQueue` or `MainActor.run`.
- Don't add actors. Add `Sendable` only where data crosses an isolation boundary. `@unchecked Sendable` needs a lock and a comment saying which one.
- Work belongs to its owner: a TCA effect, or `.task`/`.task(id:)` in a view. No unstructured `Task {}` whose result nobody observes.
- Cancellation propagates. Never swallow it.

## Modules

```text
Product catalog/              app target: @main, the root store, app-wide setup; nothing else
Packages/CatalogKit/
  Sources/
    Models/                   Product, Category, ProductPage, query and sort types; pure values, no I/O
    ProductsClient/           DummyJSON client: interface, live URLSession implementation, errors, fixtures
    SharedUI/                 remote image with placeholder and cache, price and stock views
    ProductListFeature/       list: paging, search, category, sort, loading/empty/error states
    ProductDetailFeature/     detail: gallery, inventory facts, policies, reviews, states
    AppFeature/               root: navigation from the list to a detail
  Tests/CatalogKitTests/<Area>/   reviewer-owned unit and feature tests
Product catalogUITests/       reviewer-owned UI tests, against fixtures
scripts/test                  test runner
```

| Module | May import | Must not |
|---|---|---|
| `Models` | Foundation | anything else |
| `ProductsClient` | Models, Dependencies | SwiftUI, ComposableArchitecture |
| `SharedUI` | Models, SwiftUI | ProductsClient, ComposableArchitecture |
| `ProductListFeature`, `ProductDetailFeature` | Models, ProductsClient, SharedUI, ComposableArchitecture | each other |
| `AppFeature` | both features, ComposableArchitecture | ProductsClient internals |
| app target | AppFeature | anything else |

## Commands

| Command | Does |
|---|---|
| `scripts/test` | every CatalogKit test on the simulator; prints a summary and writes the full log to `.build/logs/` |
| `scripts/test <Suite>…` | only the named test suites |
| `scripts/test --ui` | the app's UI tests |
| XcodeBuildMCP `build_run_sim` | build and run the app (scheme `Product catalog`, iPhone 17 Pro) |

Read log ranges, never whole logs. To see slow responses by hand, append `delay=<ms>` (≤ 5000) to a DummyJSON request.

## Session protocol

**Implement** (`/start-task PC-NN`, in the lane's own worktree):
1. Read this file, the card and what the card cites. Find code by symbol with `rg` and read ranges. Give broad sweeps to a subagent, and repeat these hard rules in its prompt, because subagents don't load this file.
2. Plan mode. List the files (inside the card's `Owns`), the types and their jobs, and the decisions to record. The operator approves before any edit.
3. Implement inside `Owns` and the card's budget. Crossing either is a scope event: stop, write the reason in `notes.md` and propose a split.
4. Record each material decision in `notes.md` as `AGENT_DECISION` or `AGENT_ASSUMPTION`, with the reason. Material means it touches behaviour, architecture, a dependency, concurrency, scope or the budget.
5. Self-verify. The build is clean with no new warnings and `scripts/test` is green. Read the whole diff plus untracked files as the reviewer would. Delete dead code, debug output and comments that restate code.
6. Write the handoff in `notes.md`: files changed, how to exercise the change, known limits, open questions. Then stop and report "ready for review" to the coordinator.

**Review** (`/review-task PC-NN`, a fresh context that never sees the implementer's): write `strategy.md` before reading any code; the gate enforces this. Load `ios-testing`. Pick the cheapest test layer that catches the regression: models and client as unit tests, reducers with `TestStore`, one UI journey against fixtures. `review.md` holds the AC ledger, findings each with their `Wrong if:` line, and what couldn't be verified.

**Rework:** `findings.md` goes back to the implementer, who fixes only what it lists and records the cycle in `notes.md`. Then the reviewer re-runs. After three failures of the same class the coordinator escalates to the operator.

**Close-out** (coordinator): read `review.md`, then the whole diff. Commit, merge, copy material decisions from `notes.md` into `docs/decisions.md`, and update the task index.

**Parallel lanes.** One worktree per lane. The authority files above are serialization points, and only the coordinator touches them. Only one review runs at a time across all repositories, because the gate marker `~/.claude/work/.review-session` is shared. If a tool call is denied by `review-task gate`, another review is writing its strategy: wait and retry, and never route around it.

Task artifacts live in `~/.claude/work/ProductCatalog/PC-NN/`: `task.json`, `spec.md` (the card and its hash), `branch.json`, `notes.md`, `strategy.md`, `findings.md` and `review.md`. They're never committed.
