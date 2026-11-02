# Tasks

How the work is cut, who runs it and where it stands. The session rules are in [CLAUDE.md](../../CLAUDE.md) § Session protocol.

| Card | Title | Owns | Depends on | Simulator | Status |
|---|---|---|---|---|---|
| [PC-01](PC-01-foundation.md) | Foundation: package, contracts, app shell | every module (skeleton and contract) | — | iPhone 17 Pro | done |
| [PC-10](PC-10-images-scenarios.md) | Image loading and Debug scenarios | `SharedUI/RemoteImage*`, `Networking/Scripted*`, `AppFeature/LaunchScenario.swift` | PC-01 | iPhone 17 | ready |
| [PC-20](PC-20-product-list.md) | Product list | `ProductListFeature/` | PC-01 | iPhone Air | ready |
| [PC-30](PC-30-product-detail.md) | Product detail and add to basket | `ProductDetailFeature/` | PC-01 | iPhone 17 Pro Max | ready |
| [PC-40](PC-40-basket-tab.md) | Basket tab | `BasketFeature/` | PC-01 | iPhone 17e | ready |
| [PC-50](PC-50-ui-journey.md) | UI journey | `Product catalogUITests/` | PC-10 to PC-40 | iPhone 17 Pro | ready |

Waves:
1. PC-01.
2. PC-10, PC-20, PC-30 and PC-40 in parallel, one worktree and one session each.
3. PC-50.
4. Close-out.

Every review is its own session, never a subagent. The coordinator starts review sessions one at a time.

## Implementer brief

The coordinator starts each lane with `/start-task PC-NN` and this brief:

1. First, run `mkdir -p .build && echo "<simulator>" > .build/simulator`.
2. When start-task offers a branch, accept it and name it `pc-NN-<slug>`. Review needs the `branch.json` this writes.
3. After the handoff, stop and report "PC-NN ready for review". Never review your own work, and never spawn a reviewer.
4. When the coordinator relays findings, fix only what they list, note the cycle in `notes.md`, and report "PC-NN fixed, ready for re-review".
5. Never commit.

## Reviewer brief

The coordinator starts a separate session in the lane's checkout with `/review-task PC-NN` and this brief:

- Tests go in `Packages/CatalogKit/Tests/CatalogKitTests/<Area>/`. Reuse `Support/`, and keep any new helpers private.
- No test touches the network. Run tests only with `scripts/test`.
- Never edit production code, and never commit.
- Finish exactly as review-task says: with `findings.md` (then stop; the coordinator relays it and resumes you after the fix), or with `review.md` and a verdict.
