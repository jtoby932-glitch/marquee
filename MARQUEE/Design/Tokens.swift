import SwiftUI

/// Spacing on a 4 pt grid (§5.4).
enum Space {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let s: CGFloat = 12
    static let m: CGFloat = 16
    static let l: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 40
    /// Screen edge margin.
    static let margin: CGFloat = 20
    /// Padding inside cards.
    static let card: CGFloat = 16
}

/// Corner radii. All corners are continuous.
enum Radius {
    static let card: CGFloat = 20
    static let sheet: CGFloat = 28
    static let poster: CGFloat = 10
    static let posterRange: ClosedRange<CGFloat> = 4...16
    static let bubble: CGFloat = 10
}

enum AspectRatio {
    /// Posters and covers are 2:3 (width ÷ height).
    static let poster: CGFloat = 2.0 / 3.0
    /// Backdrops and episode stills are 16:9.
    static let backdrop: CGFloat = 16.0 / 9.0
}

/// Minimum touch target.
enum Touch {
    static let minimum: CGFloat = 44
}
