import XCTest

/// A merchant's journey through the Debug `journey` scenario, whose scripted transport answers every request,
/// so nothing touches the network: failures and paging, category and search, then the detail screen and the basket.
final class CatalogJourneyUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testJourneyThroughScriptedFailuresSearchAndCategoryBuildsTheExpectedBasket() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-scenario", "journey", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let catalog = Catalog(app: app)

        // Page 1 answers 503 the first time; Retry loads it.
        let errorCaption = app.staticTexts["catalog.error.caption"]
        XCTAssertTrue(errorCaption.waitForExistence(timeout: 10), "page 1's 503 shows the error screen")
        XCTAssertEqual(errorCaption.label, "Error 503")
        XCTAssertTrue(app.staticTexts["The catalog service isn't responding. Try again in a moment."].exists)
        app.buttons["catalog.error.retry"].tap()
        XCTAssertTrue(catalog.row(1).waitForExistence(timeout: 10), "Retry loads page 1")
        XCTAssertFalse(errorCaption.exists)

        // Page 2 takes 2 s, and the footer spinner shows meanwhile. Row 26 asks for it four rows above the footer, and
        // XCUITest idles about 2 s before each gesture, so a single fling crosses both and polling catches the spinner.
        let spinner = app.activityIndicators["catalog.footer.spinner"]
        XCTAssertTrue(catalog.dragUp(until: catalog.row(12)))
        catalog.flingUp()
        XCTAssertTrue(spinner.waitForExistence(timeout: 2), "the footer spinner shows while page 2 is on its way")
        XCTAssertTrue(catalog.row(31).waitForExistence(timeout: 10), "page 2 arrives")

        // Page 3 fails the first time: the footer offers "Try again" instead of the spinner, and the rows stay.
        let tryAgain = app.buttons["catalog.footer.retry"]
        XCTAssertTrue(catalog.dragUp(until: tryAgain), "page 3's failure shows in the footer")
        XCTAssertEqual(tryAgain.label, "Try again")
        XCTAssertTrue(app.staticTexts["Couldn't load more"].exists)
        XCTAssertTrue(app.staticTexts["The catalog service isn't responding. Try again in a moment."].exists)
        XCTAssertFalse(spinner.exists)
        XCTAssertTrue(catalog.row(60).exists, "the loaded rows stay")
        tryAgain.tap()
        XCTAssertTrue(catalog.row(61).waitForExistence(timeout: 10), "Try again loads page 3")

        // Page 4 loads, and the footer counts every product.
        let end = app.staticTexts["catalog.footer.end"]
        XCTAssertTrue(catalog.dragUp(until: end), "page 4 completes the catalog")
        XCTAssertEqual(end.label, "All 120 products")

        // The first category lists only its own products, then "All categories" lists every category again.
        let categoryMenu = app.buttons["catalog.categoryMenu"]
        categoryMenu.tap()
        let beauty = app.buttons["Beauty"]
        XCTAssertTrue(beauty.waitForExistence(timeout: 5), "the menu lists the categories by name")
        XCTAssertLessThan(app.buttons["All categories"].frame.minY, beauty.frame.minY)
        XCTAssertLessThan(beauty.frame.minY, app.buttons["Fragrances"].frame.minY)
        XCTAssertLessThan(app.buttons["Fragrances"].frame.minY, app.buttons["Furniture"].frame.minY)
        beauty.tap()
        XCTAssertTrue(catalog.row(7).waitForExistence(timeout: 10), "page 1 of Beauty loads")
        XCTAssertEqual(categoryMenu.value as? String, "Beauty")
        var listed = catalog.visibleRows()
        while !end.exists, listed.count < 60 {
            catalog.dragUp()
            listed.merge(catalog.visibleRows()) { first, _ in first }
        }
        XCTAssertEqual(end.label, "All 40 products")
        XCTAssertEqual(listed.keys.sorted(), Array(stride(from: 1, through: 118, by: 3)), "every third product is Beauty")
        XCTAssertTrue(listed.values.allSatisfy { $0.contains(", Beauty, ") }, "every row reads Beauty: \(listed)")

        categoryMenu.tap()
        app.buttons["All categories"].tap()
        XCTAssertTrue(catalog.row(2).waitForExistence(timeout: 10), "all categories list Fragrances again")
        XCTAssertTrue(catalog.row(3).exists, "all categories list Furniture again")
        XCTAssertEqual(categoryMenu.value as? String, "All categories")

        // A search spans the whole catalog, and the category control reads "All categories" and is disabled.
        let search = app.searchFields["Search products"]
        if !search.isHittable {
            app.swipeDown()
        }
        search.tap()
        search.typeText("Product 11\n")
        XCTAssertTrue(catalog.row(110).waitForExistence(timeout: 10), "the search results load after the debounce")
        var found = Set(catalog.visibleRows().keys)
        while !end.exists, found.count < 30 {
            catalog.dragUp()
            found.formUnion(catalog.visibleRows().keys)
        }
        XCTAssertEqual(found, Set([11] + Array(110...119)))
        XCTAssertEqual(end.label, "All 11 products")
        XCTAssertEqual(categoryMenu.value as? String, "All categories")
        XCTAssertFalse(categoryMenu.isEnabled)

        // Clearing the search returns to browsing every product.
        search.buttons["Clear text"].tap()
        XCTAssertTrue(catalog.row(2).waitForExistence(timeout: 10), "browsing resumes")
        XCTAssertTrue(catalog.row(3).exists)
        XCTAssertTrue(categoryMenu.isEnabled)
        XCTAssertEqual(categoryMenu.value as? String, "All categories")

        // Product A's refresh fails: "Couldn't update" shows, and adding still works.
        let updateNotice = app.descendants(matching: .any)["detail.updateNotice"]
        let unavailable = app.staticTexts["detail.unavailable"]
        let add = app.buttons["detail.addToBasket"]
        let addMessage = app.staticTexts["detail.addMessage"]
        let back = app.navigationBars.buttons["BackButton"]
        catalog.row(2).tap()
        XCTAssertTrue(updateNotice.waitForExistence(timeout: 10), "product A's failed refresh shows the notice")
        XCTAssertTrue(updateNotice.staticTexts["Couldn't update"].exists)
        XCTAssertTrue(updateNotice.staticTexts["Error 503"].exists)
        XCTAssertTrue(updateNotice.buttons["detail.updateNotice.retry"].exists)
        let quantity = app.descendants(matching: .any).matching(identifier: "detail.quantity").firstMatch
        XCTAssertEqual(quantity.label, "Quantity", "the stepper reads as one element")
        XCTAssertEqual(quantity.value as? String, "5", "the stepper starts at the minimum order")
        XCTAssertTrue(add.isEnabled)
        add.tap()
        XCTAssertEqual(addMessage.label, "Added · 5 in basket")
        back.tap()

        // Product B answers 404: it's no longer available, and adding is disabled.
        XCTAssertTrue(catalog.row(3).waitForExistence(timeout: 5))
        catalog.row(3).tap()
        XCTAssertTrue(unavailable.waitForExistence(timeout: 10), "product B's 404 shows it's gone")
        XCTAssertEqual(unavailable.label, "This product is no longer available")
        XCTAssertFalse(add.isEnabled)
        back.tap()

        // Product C loads normally, and adding works.
        XCTAssertTrue(catalog.row(4).waitForExistence(timeout: 5), "back navigation still works")
        catalog.row(4).tap()
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        XCTAssertEqual(addMessage.label, "Added · 2 in basket")
        XCTAssertFalse(updateNotice.exists)
        XCTAssertFalse(unavailable.exists)
        back.tap()

        // Both badges count the two lines, and the Basket tab holds A and C at their minimums.
        let basketButton = app.buttons["catalog.basketButton"]
        XCTAssertTrue(basketButton.waitForExistence(timeout: 5))
        XCTAssertEqual(basketButton.value as? String, "2")
        let basketTab = app.tabBars.buttons["Basket"]
        XCTAssertEqual(basketTab.value as? String, "2 products")
        basketButton.tap()
        XCTAssertTrue(basketTab.isSelected, "the toolbar button switches to the Basket tab")
        let lineA = app.descendants(matching: .any)["basket.line.2"]
        XCTAssertTrue(lineA.waitForExistence(timeout: 5))
        XCTAssertEqual(lineA.label, "Product 2, 5 × $9.00, $45.00")
        XCTAssertEqual(app.descendants(matching: .any)["basket.line.4"].label, "Product 4, 2 × $19.00, $38.00")
        XCTAssertEqual(app.descendants(matching: .any)["basket.subtotal"].label, "Subtotal, $90.00")
        XCTAssertEqual(app.descendants(matching: .any)["basket.savings"].label, "Savings, -$7.00")
        XCTAssertEqual(app.descendants(matching: .any)["basket.total"].label, "Total, $83.00")
    }
}

/// The Catalog tab's rows, found by their `catalog.row.<id>` identifiers, and the drags that scroll them.
@MainActor
private struct Catalog {
    let app: XCUIApplication

    func row(_ id: Int) -> XCUIElement {
        app.buttons["catalog.row.\(id)"]
    }

    /// The rows on screen, by product id, with what VoiceOver reads for each.
    func visibleRows() -> [Int: String] {
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "catalog.row."))
        return Dictionary(
            rows.allElementsBoundByIndex.compactMap { row in
                Int(row.identifier.dropFirst("catalog.row.".count)).map { ($0, row.label) }
            },
            uniquingKeysWith: { first, _ in first }
        )
    }

    /// Scrolls the list and holds before lifting, so it stops where the drag ends instead of decelerating.
    func dragUp() {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -450)), withVelocity: .default, thenHoldForDuration: 0.1)
    }

    func dragUp(until element: XCUIElement, maxDrags: Int = 40) -> Bool {
        var drags = 0
        while !element.exists, drags < maxDrags {
            dragUp()
            drags += 1
        }
        return element.exists
    }

    /// A fast swipe that leaves the list scrolling. SpringBoard owns the coordinate, so XCUITest returns as soon as
    /// the finger lifts instead of waiting for the app to settle.
    func flingUp() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let start = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
        start.press(forDuration: 0.01, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -400)), withVelocity: XCUIGestureVelocity(rawValue: 6000), thenHoldForDuration: 0)
    }
}
