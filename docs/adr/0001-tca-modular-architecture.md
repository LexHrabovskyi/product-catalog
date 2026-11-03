# ADR-0001: TCA in a modular SwiftPM package

- Status: Accepted (2026-11-02)
- Date: 2026-11-02
- Specification: [product-catalog.md](../specs/product-catalog.md) §2, §10
- Acceptance criteria: AC-016, AC-022, AC-027, AC-028
- Decided by: operator (TCA, modular, standard approach). The navigation and DI choices were made in the spec interview.

## Context

The operator chose The Composable Architecture, used the standard documented way, and asked for an app split into features. The app has three screens: catalog list, product detail and basket. They sit in two tabs and share one basket. Several sessions build them in parallel, and a reviewer extends the app live.

As of November 2026:
- TCA 1.26.2 is the latest release. It supports Xcode 27 and Swift 6.4.
- TCA 2.0 is in private beta. Its migration guide recommends the `ComposableArchitecture2Deprecations` trait.
- The operator asked for "proper dependency injection", with Factory only if TCA lacks it. TCA ships swift-dependencies.

## Decision drivers

- One predictable state model, with side effects only through injected dependencies and exhaustive tests. High.
- Modules that parallel lanes own separately and a reviewer can extend in minutes. High.
- Standard, documented patterns over custom ones. High.
- As little third-party code as possible. Medium.

## Considered options

1. **TCA 1.26 in a local SwiftPM package.** A module per feature, a tab root with a navigation stack, and swift-dependencies as the only DI container.
2. **MVVM with `@Observable` view models and protocol DI.** Native, with no dependency. It contradicts the operator's choice and leaves effects and their tests to per-screen conventions.
3. **TCA in one module, as in SyncUps.** The fewest files, but features couple and parallel lanes collide.
4. **TCA with tree-based navigation** (`@Presents` detail in the list). Fewer types and previews that navigate, but the list module must import the detail module.
5. **Factory on top of TCA.** swift-dependencies already provides the container: `prepareDependencies` at launch, `withDependencies` per store and test traits. Two containers would disagree about which value is current.
6. **A Core/SwiftUI split per feature, as in TicTacToe.** It doubles the module count for no v1 benefit.

## Decision

Option 1.
- **Modules.**
  - Pure values and rules: `Models`, `Basket`.
  - Data access: `Networking`, `ProductsClient`.
  - Shared views: `SharedUI`.
  - Features: `ProductListFeature`, `ProductDetailFeature`, `BasketFeature`.
  - Root: `AppFeature`.

  Features never import each other. The app target links only `AppFeature`.
- **Navigation.** `AppFeature` holds a `TabView` with Catalog and Basket. The catalog tab is a `NavigationStack` driven by `StackState`. The list asks for a product through a delegate action, and the root pushes the detail.
- **Dependency injection.** swift-dependencies is the container. Clients are dependency keys: `DataTransfer`, `ProductsClient`, the image loader and TCA's clock. Each has live, preview and test values. Debug scenarios override them once at launch. There's no Factory.
- **Version.** TCA `from: "1.26.2"` with the `ComposableArchitecture2Deprecations` trait. `Package.resolved` is committed.

## Consequences

### Positive

- Every screen follows the same pattern: state, actions, reducer, effects. `TestStore` checks each state change and each effect.
- Lanes own whole folders. A new screen in the live session is one module plus one `Path` case.
- The deprecations trait keeps the code on the path to TCA 2.0.

### Negative

- Macro-heavy dependencies: swift-syntax lengthens clean builds, and Xcode asks once to trust the macros.
- The list's preview can't navigate (stack-based navigation).
- The project depends on Point-Free's release cadence.

### Risks and mitigations

- A TCA update breaks the build → the version is pinned in `Package.resolved` and upgraded deliberately.
- TCA 2.0 changes the core API → migrate one feature at a time with its compatibility shim.

## Follow-up

- Revisit when TCA 2.0 is public.
- Revisit isolation together with [ADR-0002](0002-concurrency-isolation.md).

## Amendments

- 2026-11-03 (D38): nine modules became five. `Models` and `ProductsClient` merged into `Catalog`, `SharedUI` became `Presentation`, and the three feature modules moved into `AppFeature`, one folder each. The feature boundaries are now folders and delegate actions, not separate modules.
