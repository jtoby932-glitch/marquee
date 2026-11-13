import Foundation

/// An sRGB colour as a hex value, with the WCAG maths the design tests rely on.
struct RGB: Hashable, Codable {
    let hex: UInt32

    init(_ hex: UInt32) { self.hex = hex }

    /// Parses "#RRGGBB" or "RRGGBB". Returns nil for anything else.
    init?(string: String) {
        let trimmed = string.hasPrefix("#") ? String(string.dropFirst()) : string
        guard trimmed.count == 6, let value = UInt32(trimmed, radix: 16) else { return nil }
        self.hex = value
    }

    var red: Double { Double((hex >> 16) & 0xFF) / 255 }
    var green: Double { Double((hex >> 8) & 0xFF) / 255 }
    var blue: Double { Double(hex & 0xFF) / 255 }

    var hexString: String { String(format: "#%06X", hex) }

    /// Linear-light channels, used for luminance and colour-blindness simulation.
    var linear: [Double] {
        [red, green, blue].map { $0 <= 0.04045 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
    }

    /// WCAG 2.1 relative luminance.
    var luminance: Double {
        let c = linear
        return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
    }

    /// WCAG contrast ratio between two colours (1…21).
    static func contrast(_ a: RGB, _ b: RGB) -> Double {
        let la = a.luminance, lb = b.luminance
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// Mixes towards another colour; `amount` 0 keeps self, 1 gives `other`.
    func mixed(with other: RGB, amount: Double) -> RGB {
        func channel(_ shift: UInt32) -> UInt32 {
            let a = Double((hex >> shift) & 0xFF), b = Double((other.hex >> shift) & 0xFF)
            return UInt32(max(0, min(255, (a + (b - a) * amount).rounded())))
        }
        return RGB((channel(16) << 16) | (channel(8) << 8) | channel(0))
    }
}

/// Colour-vision deficiencies we check chart palettes against.
enum ColorDeficiency: CaseIterable {
    case deuteranopia, protanopia

    /// Machado et al. (2009) matrices at full severity, applied in linear RGB.
    var matrix: [[Double]] {
        switch self {
        case .deuteranopia:
            return [[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]]
        case .protanopia:
            return [[0.152286, 1.052583, -0.204868], [0.114503, 0.786281, 0.099216], [-0.003882, -0.048116, 1.051998]]
        }
    }
}

enum ColorMath {
    /// Distance between two colours as seen with a deficiency (nil means normal vision), in linear RGB.
    static func perceivedDistance(_ a: RGB, _ b: RGB, as deficiency: ColorDeficiency? = nil) -> Double {
        let pa = simulate(a, deficiency), pb = simulate(b, deficiency)
        return sqrt(zip(pa, pb).map { ($0 - $1) * ($0 - $1) }.reduce(0, +))
    }

    static func simulate(_ color: RGB, _ deficiency: ColorDeficiency?) -> [Double] {
        let c = color.linear
        guard let m = deficiency?.matrix else { return c }
        return (0..<3).map { i in m[i][0] * c[0] + m[i][1] * c[1] + m[i][2] * c[2] }
    }

    /// The smallest pairwise distance in a palette across normal vision and every deficiency.
    static func minimumSeparation(_ palette: [RGB]) -> Double {
        var best = Double.greatestFiniteMagnitude
        let visions: [ColorDeficiency?] = [nil] + ColorDeficiency.allCases.map { $0 }
        for i in palette.indices {
            for j in palette.indices where j > i {
                for d in visions {
                    best = min(best, perceivedDistance(palette[i], palette[j], as: d))
                }
            }
        }
        return best
    }
}
