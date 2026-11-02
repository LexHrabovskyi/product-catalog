# ADR-0002: MainActor by default in the app target only

- Status: Accepted (2026-11-02)
- Date: 2026-11-02
- Specification: [product-catalog.md](../specs/product-catalog.md) §2
- Acceptance criteria: AC-012, AC-015 (cancellation), AC-005 (clock-driven hint)
- Supersedes: [decisions.md](../decisions.md) D3 for package modules
- Decided by: operator, in the spec interview

## Context

D3 chose Swift 6 with Approachable Concurrency and MainActor as the default isolation. The app target already has that setup (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`).

TCA 1.x's maintainers advise nonisolated mode for code that uses TCA until 2.0 (issues #3768, #3921 and #3713, swift-dependencies #395). Under default MainActor isolation:
- nested `@Reducer` enums fail with a `CaseReducerState` isolation error;
- `some ReducerOf<Self>` fails;
- `Equatable` models and `Hashable` cancel ids need `nonisolated`;
- dependency clients must be `nonisolated`.

SE-0466 itself calls MainActor "the wrong default" for library-style modules.

## Decision drivers

- Compiler-checked data-race safety (Swift 6 mode). High.
- Standard TCA code without workaround annotations. High.
- The approachable model: async/await, no hand-made actors, no detached tasks. High.

## Considered options

1. **MainActor by default everywhere**, with the workarounds: a top-level `Path` enum, `some Reducer<State, Action>`, and `nonisolated` on models, cancel ids and clients.
2. **The app target keeps MainActor by default. Package modules are nonisolated, with Approachable Concurrency's features on:** `NonisolatedNonsendingByDefault` and `InferIsolatedConformances`.
3. **Swift 5 mode or minimal checking.** No safety from the compiler.

## Decision

Option 2.
- Every target uses Swift 6 language mode.
- `CatalogKit` targets enable `NonisolatedNonsendingByDefault` and `InferIsolatedConformances`, and don't set a default isolation.
- Views and reducers still run on the main actor, because SwiftUI views and TCA's `Store` are main-actor isolated.
- The rules in `CLAUDE.md` § Concurrency apply in both places.

## Consequences

### Positive

- Reducers, clients and models are written exactly as in TCA's documentation.
- A nonisolated async function runs on its caller's actor, so network calls made from effects don't hop threads needlessly.

### Negative

- Two defaults in one app: code is MainActor in the app target and nonisolated in the package, so a reader has to know which module they're in.
- Public value types crossing into effects must declare `Sendable` explicitly. Public types don't infer it.

### Risks and mitigations

- Someone adds `.defaultIsolation(MainActor.self)` to a package target → `CLAUDE.md` says not to, and review checks `Package.swift`.

## Follow-up

- TCA 2.0 is expected to support default MainActor isolation fully. Revisit then, with a new ADR that supersedes this one.
