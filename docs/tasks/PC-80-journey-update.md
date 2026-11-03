# PC-80 — UI journey update and integration check

| | |
|---|---|
| Kind | review-first, in the coordinator's checkout, once PC-60 and PC-70 have merged. The coordinator makes any glue fixes. |
| Depends on | PC-60, PC-70 |
| Authority | AC-027 and AC-029 as amended on 2026-11-03, and AC-019 to AC-023. Also the identifiers in the PC-60 and PC-70 cards, and the `journey` script in [PC-10](PC-10-images-scenarios.md). |
| Owns | `Product catalogUITests/` (reviewer). Glue anywhere, coordinator only. |
| Budget | glue ≤ 3 files / ~60 lines |
| Simulator | iPhone 17 Pro |
| Detail | ready |

## Goal

The journey proves the new basket control, filter and search on the merged app, and an integration pass checks the two lanes against each other.

## Requirements

- **R1. The journey** follows the amended AC-027 and AC-029:
  - add through the basket control;
  - open A again and find its stepper;
  - on C: +, −, delete at the minimum, then add again;
  - choose a category, search, then clear the search;
  - there's no toolbar basket button.
- **R2. Integration**, on the live API and the scenarios:
  - the detail control and the basket panel look alike (style, margins, glass) in light and dark mode;
  - the detail control and the Basket tab stay in step both ways;
  - VoiceOver across both screens;
  - Dynamic Type at accessibility sizes.
- **R3.** `scripts/test` and `scripts/test --ui` are green.

## Exit evidence

`review.md` with the AC ledger for the amended criteria.
