import SwiftUI

/// Original line illustrations drawn in code (§5.15). One line weight, tinted
/// by the Look's accent. No stock art, no emoji.
struct Illustration: View {
    enum Kind { case projector, books, ticket, popcorn, television }

    @Environment(\.theme) private var theme
    let kind: Kind
    var lineWidth: CGFloat = 2.5

    var body: some View {
        GeometryReader { proxy in
            let rect = CGRect(origin: .zero, size: proxy.size)
            ZStack {
                path(in: rect)
                    .stroke(theme.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                accentPath(in: rect)
                    .fill(theme.accent.opacity(0.14))
            }
        }
        .accessibilityHidden(true)
    }

    private func path(in r: CGRect) -> Path {
        switch kind {
        case .projector: return Self.projector(r)
        case .books: return Self.books(r)
        case .ticket: return Self.ticket(r)
        case .popcorn: return Self.popcorn(r)
        case .television: return Self.television(r)
        }
    }

    /// The soft fill: a light beam, a book face, a ticket stub and so on.
    private func accentPath(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        switch kind {
        case .projector:
            p.move(to: CGPoint(x: w * 0.38, y: h * 0.42))
            p.addLine(to: CGPoint(x: w * 0.98, y: h * 0.10))
            p.addLine(to: CGPoint(x: w * 0.98, y: h * 0.62))
            p.closeSubpath()
        case .books:
            p.addRect(CGRect(x: w * 0.30, y: h * 0.20, width: w * 0.16, height: h * 0.70))
        case .ticket:
            p.addRect(CGRect(x: w * 0.66, y: h * 0.22, width: w * 0.22, height: h * 0.56))
        case .popcorn:
            p.addEllipse(in: CGRect(x: w * 0.28, y: h * 0.08, width: w * 0.44, height: h * 0.3))
        case .television:
            p.addRoundedRect(in: CGRect(x: w * 0.18, y: h * 0.24, width: w * 0.64, height: h * 0.48), cornerSize: CGSize(width: 8, height: 8))
        }
        return p
    }

    static func projector(_ r: CGRect) -> Path {
        let w = r.width, h = r.height
        var p = Path()
        p.addRoundedRect(in: CGRect(x: w * 0.06, y: h * 0.38, width: w * 0.34, height: h * 0.26), cornerSize: CGSize(width: 6, height: 6))
        p.addEllipse(in: CGRect(x: w * 0.06, y: h * 0.10, width: w * 0.2, height: w * 0.2))
        p.addEllipse(in: CGRect(x: w * 0.22, y: h * 0.06, width: w * 0.22, height: w * 0.22))
        p.move(to: CGPoint(x: w * 0.40, y: h * 0.44))
        p.addLine(to: CGPoint(x: w * 0.46, y: h * 0.42))
        p.move(to: CGPoint(x: w * 0.14, y: h * 0.64))
        p.addLine(to: CGPoint(x: w * 0.10, y: h * 0.92))
        p.move(to: CGPoint(x: w * 0.32, y: h * 0.64))
        p.addLine(to: CGPoint(x: w * 0.36, y: h * 0.92))
        p.move(to: CGPoint(x: w * 0.04, y: h * 0.92))
        p.addLine(to: CGPoint(x: w * 0.96, y: h * 0.92))
        return p
    }

    static func books(_ r: CGRect) -> Path {
        let w = r.width, h = r.height
        var p = Path()
        p.addRoundedRect(in: CGRect(x: w * 0.12, y: h * 0.28, width: w * 0.16, height: h * 0.62), cornerSize: CGSize(width: 3, height: 3))
        p.addRoundedRect(in: CGRect(x: w * 0.30, y: h * 0.20, width: w * 0.16, height: h * 0.70), cornerSize: CGSize(width: 3, height: 3))
        // A leaning book.
        p.move(to: CGPoint(x: w * 0.50, y: h * 0.90))
        p.addLine(to: CGPoint(x: w * 0.62, y: h * 0.24))
        p.addLine(to: CGPoint(x: w * 0.77, y: h * 0.27))
        p.addLine(to: CGPoint(x: w * 0.66, y: h * 0.92))
        p.move(to: CGPoint(x: w * 0.16, y: h * 0.40)); p.addLine(to: CGPoint(x: w * 0.24, y: h * 0.40))
        p.move(to: CGPoint(x: w * 0.34, y: h * 0.32)); p.addLine(to: CGPoint(x: w * 0.42, y: h * 0.32))
        p.move(to: CGPoint(x: w * 0.04, y: h * 0.92)); p.addLine(to: CGPoint(x: w * 0.96, y: h * 0.92))
        return p
    }

    static func ticket(_ r: CGRect) -> Path {
        let w = r.width, h = r.height
        let rect = CGRect(x: w * 0.08, y: h * 0.22, width: w * 0.84, height: h * 0.56)
        var p = Path()
        let notch = h * 0.08
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY - notch))
        p.addArc(center: CGPoint(x: rect.maxX, y: rect.midY), radius: notch, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: true)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY + notch))
        p.addArc(center: CGPoint(x: rect.minX, y: rect.midY), radius: notch, startAngle: .degrees(90), endAngle: .degrees(-90), clockwise: true)
        p.closeSubpath()
        // Perforation.
        var y = rect.minY + 6
        while y < rect.maxY - 4 {
            p.move(to: CGPoint(x: w * 0.66, y: y))
            p.addLine(to: CGPoint(x: w * 0.66, y: y + 4))
            y += 9
        }
        p.move(to: CGPoint(x: rect.minX + w * 0.08, y: rect.midY - h * 0.08)); p.addLine(to: CGPoint(x: w * 0.56, y: rect.midY - h * 0.08))
        p.move(to: CGPoint(x: rect.minX + w * 0.08, y: rect.midY + h * 0.06)); p.addLine(to: CGPoint(x: w * 0.44, y: rect.midY + h * 0.06))
        return p
    }

    static func popcorn(_ r: CGRect) -> Path {
        let w = r.width, h = r.height
        var p = Path()
        p.move(to: CGPoint(x: w * 0.28, y: h * 0.34))
        p.addLine(to: CGPoint(x: w * 0.36, y: h * 0.92))
        p.addLine(to: CGPoint(x: w * 0.64, y: h * 0.92))
        p.addLine(to: CGPoint(x: w * 0.72, y: h * 0.34))
        p.closeSubpath()
        for x in [0.44, 0.56] {
            p.move(to: CGPoint(x: w * x, y: h * 0.36)); p.addLine(to: CGPoint(x: w * x, y: h * 0.90))
        }
        for (x, y) in [(0.34, 0.24), (0.46, 0.16), (0.58, 0.18), (0.68, 0.26)] {
            p.addEllipse(in: CGRect(x: w * x - w * 0.07, y: h * y - h * 0.07, width: w * 0.14, height: h * 0.14))
        }
        return p
    }

    static func television(_ r: CGRect) -> Path {
        let w = r.width, h = r.height
        var p = Path()
        p.addRoundedRect(in: CGRect(x: w * 0.10, y: h * 0.20, width: w * 0.80, height: h * 0.60), cornerSize: CGSize(width: 12, height: 12))
        p.move(to: CGPoint(x: w * 0.38, y: h * 0.02)); p.addLine(to: CGPoint(x: w * 0.50, y: h * 0.18)); p.addLine(to: CGPoint(x: w * 0.64, y: h * 0.04))
        p.move(to: CGPoint(x: w * 0.24, y: h * 0.80)); p.addLine(to: CGPoint(x: w * 0.20, y: h * 0.94))
        p.move(to: CGPoint(x: w * 0.76, y: h * 0.80)); p.addLine(to: CGPoint(x: w * 0.80, y: h * 0.94))
        return p
    }
}
