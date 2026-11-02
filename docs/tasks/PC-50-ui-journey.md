# PC-50 — UI journey and integration review

| | |
|---|---|
| Kind | review-first, in the coordinator's checkout, once every lane has merged. The coordinator makes any glue fixes. |
| Depends on | PC-10, PC-20, PC-30, PC-40 |
| Authority | The whole spec on the merged app: AC-001 to AC-029, and ADR-0001 to ADR-0004. Also the `journey` script in [PC-10](PC-10-images-scenarios.md), and the accessibility identifiers in the PC-20, PC-30 and PC-40 cards. |
| Owns | `Product catalogUITests/` (reviewer). Glue anywhere, coordinator only. |
| Budget | glue ≤ 5 files / ~100 lines |
| Simulator | iPhone 17 Pro |
| Detail | ready |

## Goal

The merged app is reviewed as one product, not card by card. One end-to-end journey proves the failure handling, filtering, search and the basket together, without the network. An integration pass then catches what no single card could see.

## Requirements

- **R1. The journey.** Replace the template UI tests with one XCUITest journey covering AC-027, then AC-029. Launch it with `-scenario journey` and the `en_US` locale, so prices read "$83.00".
- **R2. Release hygiene** (AC-028).
  - A Release build contains no scripted transport and no scenario code; check its symbols.
  - A Debug launch without `-scenario` uses the live transport.
- **R3. Integration review of the merged app** against every AC, on the live API and the four scenarios:
  - **The seams between features:**
    - list → detail → basket on the one shared basket;
    - the badge on the toolbar button and on the tab;
    - tab switching that keeps the catalog stack;
    - a relaunch that keeps the basket (live, real file).
  - **Copy** on every screen against the spec, including the additions accepted in D24.
  - **Accessibility across screens:**
    - Dynamic Type at accessibility sizes;
    - VoiceOver labels: the quantity stepper must be read once, and stock units must use correct grammar;
    - dark mode.
  - **Logs:** categories and privacy. No search text and no e-mail.
  - **Memory:** off-screen rows release their images while `large` is scrolled, as far as an agent can observe.
  - **Test stability:** `ScriptedDataTransferTests.cancellingADelayedRequestEndsItAtOnce` failed once under a parallel build (2.5 s against its 1 s wall-clock bound) and passes alone. Make it deterministic. If that needs the scripted delays on the injected clock, ask the coordinator for that production change.

  Findings go to the coordinator, who makes any glue fixes.
- **R4. Operator check** (AC-009). Launch an optimized Debug build with `-scenario large`, scroll from top to bottom by eye, and watch memory stay flat in the Xcode gauge.

## Exit evidence

- `scripts/test` and `scripts/test --ui` are green, and the journey passes twice in a row.
- `review.md` contains:
  - an AC ledger for AC-001 to AC-029 on the merged app;
  - the output of the Release symbol check;
  - the integration findings.
