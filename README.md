# Product catalog

An iOS app for merchants who run their business from their phone. It browses the [DummyJSON](https://dummyjson.com/docs/products) catalog so a merchant can find a product fast and open it to check stock, price and details.

## Run it

Open `Product catalog.xcodeproj` in Xcode 26.6 or later, choose an iPhone simulator and press Run. Xcode fetches the Swift packages the first time the project opens. There's nothing else to set up.

`scripts/test` runs the unit and feature tests on the simulator. `scripts/test --ui` runs the UI tests against bundled fixtures.

## Where the decisions are

- The specification is [docs/specs/product-catalog.md](docs/specs/product-catalog.md).
- Every decision is in the log, [docs/decisions.md](docs/decisions.md).
- Decisions that had real alternatives have an ADR in [docs/adr/](docs/adr/).
