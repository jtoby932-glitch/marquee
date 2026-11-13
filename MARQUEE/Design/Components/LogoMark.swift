import SwiftUI

/// The app's mark: a film frame that is also a bookmark (films and books in one
/// shape). Matches the default app icon drawn by tools/make_icons.py.
struct FrameBookmarkOutline: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + w, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + w, y: rect.minY + h))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.minY + h * 0.825))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + h))
        p.closeSubpath()
        return p
    }
}

/// The sprocket holes and frame window punched out of the mark.
struct FrameBookmarkCutouts: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        let holeW = w * 0.0875, holeH = h * 0.0675
        var y = h * 0.054
        while y < h * 0.80 - holeH {
            for x in [w * 0.1125, w * 0.8875] {
                p.addRoundedRect(in: CGRect(x: rect.minX + x - holeW / 2, y: rect.minY + y, width: holeW, height: holeH),
                                 cornerSize: CGSize(width: holeW * 0.28, height: holeW * 0.28))
            }
            y += h * 0.115
        }
        p.addRoundedRect(in: CGRect(x: rect.minX + w * 0.2375, y: rect.minY + h * 0.135, width: w * 0.525, height: h * 0.35),
                         cornerSize: CGSize(width: w * 0.05, height: w * 0.05))
        return p
    }
}

/// The filled mark at any size.
struct LogoMark: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            FrameBookmarkOutline().fill(theme.accentGradient)
            FrameBookmarkCutouts().fill(theme.background)
        }
        .aspectRatio(0.54, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
