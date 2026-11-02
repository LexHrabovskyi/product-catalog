# ADR-0003: The DataTransfer seam, failure policy and image loading

- Status: Accepted (2026-11-02)
- Date: 2026-11-02
- Specification: [product-catalog.md](../specs/product-catalog.md) §6, §7, §8
- Acceptance criteria: AC-001–AC-009, AC-012, AC-016, AC-018, AC-019, AC-027, AC-028
- Decided by: operator (proper DI, a `DataTransfer` networking protocol, the scripted UI journey, the 15 s timeout with no automatic retry, the image cache). The error taxonomy follows from the spec's copy.

## Context

Slow connections, zero results, 4xx and 5xx errors, missing images and 1,000+ rows are required cases. One UI journey has to script failures, delays and a 404 without touching the network. DummyJSON has only 194 products, its CDN serves images with `Cache-Control: no-store`, and it rate-limits at 100.

## Decision drivers

- Every network path is deterministic in tests, UI tests included. High.
- Waits are bounded and honest: the merchant always knows what's happening and what to do next. High.
- One place maps transport failures to what the merchant sees. High.
- No new dependency. Medium.

## Considered options

1. **A `DataTransfer` protocol registered as a dependency.** It turns a `URLRequest` into data plus an HTTP response. The live implementation uses URLSession, and a Debug-only scripted implementation is chosen by launch argument. `ProductsClient` owns the endpoints, decoding and error mapping on top of it.
2. **`URLProtocol` stubs inside the live session.** No new seam, but global registration, awkward scripting per request, and nothing in the dependency graph shows it.
3. **A fixture `ProductsClient` in UI tests.** That skips the decoding and error mapping the journey is meant to prove.
4. **Automatic retry with backoff.** It rides out blips, but the worst wait grows to 30–60 s before the merchant can act.
5. **Images through `AsyncImage`.** With `no-store`, every scroll-back re-downloads and flashes the placeholder. **Images through Nuke:** a second third-party dependency for a disk cache v1 doesn't need.

## Decision

Option 1.
- **Transport.** Live: URLSession with a 15 s request timeout. No automatic retry; every failure offers an explicit retry.
- **Slow hint.** "Slow connection…" appears after 3 s, driven by the injected clock.
- **Errors.** `ProductsClient` maps failures to one error type: offline, timeout, server (5xx), client (4xx, with 404 kept distinct) and unreadable (decoding). Each carries its HTTP status when there is one. Cancellation is never an error.
- **Images.** `SharedUI`'s remote image loads through `DataTransfer` into a bounded in-memory `NSCache`. The view's task cancels the load when the row leaves the screen. The placeholder shows while loading and on failure.
- **Debug scenarios.** `journey`, `large`, `slow` and `offline` select a scripted `DataTransfer` (spec §6). Its code is compiled only with `DEBUG`.

## Consequences

### Positive

- Every path the spec names (503, 404, delay, offline, a 1,200-product catalog) can be produced on demand, in UI tests and in live demos.
- Decoding and error mapping run in the UI journey exactly as in production.

### Negative

- The scripted transport is production code (Debug only) that has to track the API.
- Thumbnails re-download after a cold launch, since there's no disk cache.

### Risks and mitigations

- Scripted fixtures drift from the real payload → they're built from a real response captured on 2026-11-02, and the live decoding is unit-tested against that capture.
- A burst of image requests hits the rate limit → loads follow visible rows and are cancelled when a row leaves the screen.

## Follow-up

- Add one automatic retry for idempotent requests if production metrics show transient failures.
- Add a disk image cache if image traffic matters.
