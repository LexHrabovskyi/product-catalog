# PC-50 — UI journey

| | |
|---|---|
| Kind | review-first, in the coordinator's checkout. The coordinator makes any glue fixes. |
| Depends on | PC-10, PC-20, PC-30, PC-40 |
| Authority | AC-027, AC-028, AC-009 (manual). The `journey` script in [PC-10](PC-10-images-scenarios.md), and the accessibility identifiers in the PC-20, PC-30 and PC-40 cards. |
| Owns | `Product catalogUITests/` (reviewer). Glue anywhere, coordinator only. |
| Budget | glue ≤ 3 files / ~60 lines |
| Simulator | iPhone 17 Pro |
| Detail | ready |

## Goal

One end-to-end journey proves the app's failure handling and the basket together, without the network. Release builds carry no test scaffolding.

## Requirements

- **R1. The journey.** Replace the template UI tests with one XCUITest journey that follows AC-027, launched with `-scenario journey`.
- **R2. Release hygiene** (AC-028).
  - A Release build contains no scripted transport and no scenario code; check its symbols.
  - A Debug launch without `-scenario` uses the live transport.
- **R3. Operator check** (AC-009). Launch an optimized Debug build with `-scenario large` and scroll from top to bottom by eye.

## Exit evidence

- `scripts/test --ui` is green twice in a row.
- The output of the Release symbol check is in `review.md`.
