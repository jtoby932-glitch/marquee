import XCTest
@testable import MARQUEE

/// Every Look must meet WCAG AA for text and have a usable chart palette.
final class LookContrastTests: XCTestCase {
    private func surfaces(_ look: Look) -> [RGB] { [look.background, look.surface1, look.surface2] }

    func testTextMeetsAA() {
        for look in Look.all.values {
            for (name, text) in [("primary", look.textPrimary), ("secondary", look.textSecondary), ("tertiary", look.textTertiary)] {
                for surface in surfaces(look) {
                    XCTAssertGreaterThanOrEqual(RGB.contrast(text, surface), 4.5, "\(look.id) \(name) on \(surface.hexString)")
                }
            }
        }
    }

    func testAccentAndStatusColoursAreReadable() {
        for look in Look.all.values {
            for surface in surfaces(look) {
                XCTAssertGreaterThanOrEqual(RGB.contrast(look.accent, surface), 4.5, "\(look.id) accent text")
                for (name, colour) in [("success", look.success), ("warning", look.warning), ("danger", look.danger)] {
                    XCTAssertGreaterThanOrEqual(RGB.contrast(colour, surface), 4.5, "\(look.id) \(name)")
                }
            }
            for stop in look.accentGradient {
                XCTAssertGreaterThanOrEqual(RGB.contrast(look.onAccent, stop), 4.5, "\(look.id) text on accent \(stop.hexString)")
            }
        }
    }

    func testChartPalette() {
        for look in Look.all.values {
            XCTAssertEqual(look.chartPalette.count, 6)
            XCTAssertEqual(Set(look.chartPalette).count, 6)
            for colour in look.chartPalette {
                XCTAssertGreaterThanOrEqual(RGB.contrast(colour, look.background), 3, "\(look.id) chart \(colour.hexString)")
            }
            // Distinguishable with normal vision, deuteranopia and protanopia.
            XCTAssertGreaterThan(ColorMath.minimumSeparation(look.chartPalette), 0.09, "\(look.id) chart separation")
        }
    }

    func testSerifLooks() {
        XCTAssertTrue(Look.bookshop.usesSerif)
        XCTAssertTrue(Look.paper.usesSerif)
        XCTAssertFalse(Look.cinema.usesSerif)
    }

    func testRGBParsingAndMixing() {
        XCTAssertEqual(RGB(string: "#F2C66D"), RGB(0xF2C66D))
        XCTAssertNil(RGB(string: "nope"))
        XCTAssertEqual(RGB(0x000000).mixed(with: RGB(0xFFFFFF), amount: 0.5).hex, 0x808080)
        XCTAssertEqual(RGB.contrast(RGB(0x000000), RGB(0xFFFFFF)), 21, accuracy: 0.01)
    }
}

final class MotionPolicyTests: XCTestCase {
    func testReduceMotionForcesAtLeastReduced() {
        XCTAssertEqual(MotionPolicy(level: .full, systemReduceMotion: true).level, .reduced)
        XCTAssertEqual(MotionPolicy(level: .off, systemReduceMotion: true).level, .off)
        XCTAssertEqual(MotionPolicy(level: .full, systemReduceMotion: false).level, .full)
    }

    func testCapabilities() {
        XCTAssertTrue(MotionPolicy(level: .full).allowsMovement)
        XCTAssertFalse(MotionPolicy(level: .reduced).allowsMovement)
        XCTAssertTrue(MotionPolicy(level: .reduced).allowsAnimation)
        XCTAssertNil(MotionPolicy(level: .off).animation())
        XCTAssertNil(MotionPolicy(level: .reduced).imageFade)
    }

    func testStaggerIsCapped() {
        XCTAssertEqual(MotionPolicy.staggerDelay(index: 0), 0)
        XCTAssertEqual(MotionPolicy.staggerDelay(index: 2), 0.06, accuracy: 0.0001)
        XCTAssertEqual(MotionPolicy.staggerDelay(index: 50), 0.3)
    }

    func testIntroFitsItsBudget() {
        XCTAssertLessThanOrEqual(OpeningAnimation.totalDuration, 1.6)
    }
}
