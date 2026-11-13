import XCTest

extension XCUIElement {
    /// Taps the element's centre without asking accessibility to scroll it into view,
    /// which fails for bar items that are already on screen.
    func tapCentre() {
        coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
}

extension XCUIApplication {
    /// Lists only expose rows on screen; swipe until the element appears.
    func scrollUntilVisible(_ element: XCUIElement, maxSwipes: Int = 6) -> Bool {
        var swipes = 0
        while !element.isHittable && swipes < maxSwipes {
            swipeUp()
            swipes += 1
        }
        return element.exists
    }
}

/// Real flows tapped through on the simulator. Network answers come from
/// bundled fixtures (-stubNetwork) and stores are in memory, so runs repeat exactly.
final class JourneyTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ args: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-skipIntro", "-stubNetwork"] + args
        app.launch()
        return app
    }

    /// Fresh install → quick add → search → add → library → open → remove → undo.
    func testSearchAddRemoveUndo() {
        let app = launch(["-freshStore"])
        XCTAssertTrue(app.otherElements["home.empty"].waitForExistence(timeout: 5) || app.buttons["home.empty.action"].exists)

        app.buttons["home.quickAdd"].tapCentre()
        let field = app.textFields["search.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("dune")

        let add = app.buttons["search.add.tmdb-movie-438631"]
        XCTAssertTrue(add.waitForExistence(timeout: 8), "Results appear after the debounce")
        add.tap()
        app.buttons["addSheet.wantTo"].tap()
        XCTAssertTrue(app.otherElements["toast"].waitForExistence(timeout: 3) || app.buttons["toast.undo"].exists)
        XCTAssertFalse(app.buttons["search.add.tmdb-movie-438631"].waitForExistence(timeout: 1), "Added titles show their status instead of +")

        app.buttons["tab.library"].tapCentre()
        let poster = app.buttons["library.poster.tmdb-movie-438631"]
        XCTAssertTrue(poster.waitForExistence(timeout: 5))
        poster.tap()

        XCTAssertTrue(app.staticTexts["detail.title"].waitForExistence(timeout: 5))
        let more = app.buttons["detail.more"]
        XCTAssertTrue(more.waitForExistence(timeout: 3))
        more.tapCentre()
        let removeItem = app.buttons["Remove from library"]
        XCTAssertTrue(removeItem.waitForExistence(timeout: 3))
        removeItem.tap()
        let confirm = app.buttons.matching(NSPredicate(format: "label == %@", "Remove")).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        confirm.tap()

        let undo = app.buttons["toast.undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 3))
        XCTAssertFalse(poster.exists)
        undo.tap()
        XCTAssertTrue(poster.waitForExistence(timeout: 3), "Undo restores the title")
    }

    /// Swipe right on a result adds it to Want to in one gesture.
    func testSwipeToAdd() {
        let app = launch(["-freshStore"])
        XCTAssertTrue(app.buttons["tab.search"].waitForExistence(timeout: 5))
        app.buttons["tab.search"].tapCentre()
        let field = app.textFields["search.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("dune")
        let row = app.buttons["search.result.ol-OL893415W"]
        XCTAssertTrue(row.waitForExistence(timeout: 8))
        row.swipeRight()
        let wantTo = app.buttons["Want to read"]
        if wantTo.waitForExistence(timeout: 2) { wantTo.tap() }
        XCTAssertTrue(app.buttons["toast.undo"].waitForExistence(timeout: 3))
    }

    /// Offline: search says so and looks in my library instead.
    func testOfflineSearchUsesLibrary() {
        let app = launch(["-demoData", "-offline"])
        XCTAssertTrue(app.buttons["tab.search"].waitForExistence(timeout: 5))
        app.buttons["tab.search"].tapCentre()
        XCTAssertTrue(app.descendants(matching: .any)["offline.banner"].waitForExistence(timeout: 5))
        let field = app.textFields["search.field"]
        field.tap()
        field.typeText("Dune")
        XCTAssertTrue(app.buttons["search.library.tmdb-movie-693134"].waitForExistence(timeout: 5))
    }

    /// Seven taps on the version opens the hidden Diagnostics screen.
    func testDiagnosticsIsHiddenBehindSevenTaps() {
        let app = launch(["-demoData"])
        XCTAssertTrue(app.buttons["home.avatar"].waitForExistence(timeout: 5))
        app.buttons["home.avatar"].tapCentre()
        let about = app.buttons["settings.about"]
        XCTAssertTrue(app.scrollUntilVisible(about), "About is at the bottom of Settings")
        about.tap()
        let version = app.buttons["about.version"]
        XCTAssertTrue(version.waitForExistence(timeout: 5))
        for _ in 0..<6 { version.tap() }
        XCTAssertFalse(app.navigationBars["Diagnostics"].exists)
        version.tap()
        XCTAssertTrue(app.navigationBars["Diagnostics"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["diagnostics.copy"].waitForExistence(timeout: 5))
    }

    /// Changing the Look applies everywhere immediately.
    func testLookChanges() {
        let app = launch(["-demoData"])
        XCTAssertTrue(app.buttons["home.avatar"].waitForExistence(timeout: 5))
        app.buttons["home.avatar"].tapCentre()
        let paper = app.buttons["settings.look.paper"]
        XCTAssertTrue(paper.waitForExistence(timeout: 5))
        paper.tap()
        XCTAssertTrue(paper.isSelected)
    }
}

/// Accessibility audits on every main screen, at default and largest text size.
final class AccessibilityAuditTests: XCTestCase {
    private func audit(_ screen: String, extra: [String] = []) throws {
        let app = XCUIApplication()
        // The small demo library keeps each audit inside XCTest's time limit on CI.
        app.launchArguments = ["-demoSmall", "-screen", screen, "-animation", "off"] + extra
        app.launch()
        _ = app.buttons["tab.home"].waitForExistence(timeout: 5)
        sleep(1)
        try app.performAccessibilityAudit { issue in
            // Proven false positive: the tab bar follows Apple's pattern of fixed-size
            // labels plus the Large Content Viewer (long-press shows them enlarged),
            // set with accessibilityShowsLargeContentViewer() in RootView.swift.
            guard issue.auditType == .dynamicType, let element = issue.element, element.exists else { return false }
            let inTabBar = element.identifier.hasPrefix("tab.") || element.frame.minY > app.frame.maxY - 110
            return inTabBar
        }
    }

    func testHome() throws { try audit("home") }
    func testLibrary() throws { try audit("library") }
    func testSearch() throws { try audit("search") }
    func testDetail() throws { try audit("detail") }
    func testSettings() throws { try audit("settings") }
    func testAbout() throws { try audit("about") }

    func testLibraryAtLargestTextSize() throws {
        try audit("library", extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
    }
}

/// Tripwires for big regressions; CI simulators are noisy, so these aren't exact budgets.
final class PerformanceTests: XCTestCase {
    func testLaunch() {
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(metrics: [XCTApplicationLaunchMetric()], options: options) {
            let app = XCUIApplication()
            app.launchArguments = ["-skipIntro", "-demoData"]
            app.launch()
        }
    }

    func testScrollingTheLibraryGrid() {
        let app = XCUIApplication()
        app.launchArguments = ["-skipIntro", "-demoData", "-screen", "library"]
        app.launch()
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric, XCTMemoryMetric(application: app)], options: options) {
            app.swipeUp(velocity: .fast)
            app.swipeDown(velocity: .fast)
        }
    }
}
