import SwiftUI

/// The five complete visual themes.
enum LookID: String, CaseIterable, Identifiable, Codable {
    case cinema, noir, bookshop, neon, paper

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cinema: return String(localized: "Cinema")
        case .noir: return String(localized: "Noir")
        case .bookshop: return String(localized: "Bookshop")
        case .neon: return String(localized: "Neon")
        case .paper: return String(localized: "Paper")
        }
    }

    var look: Look { Look.all[self] ?? Look.cinema }
}

/// Every colour role a Look defines (§5.11). Stored as hex so tests can check contrast.
/// Tertiary text is lighter than the brief's starting values so it passes WCAG AA.
struct Look: Equatable {
    let id: LookID
    let isLight: Bool
    let usesSerif: Bool
    let background: RGB
    let surface1: RGB
    let surface2: RGB
    let surface3: RGB
    let textPrimary: RGB
    let textSecondary: RGB
    let textTertiary: RGB
    /// A solid accent that is readable as text and icons.
    let accent: RGB
    let accentGradient: [RGB]
    /// Text and icons placed on the accent gradient.
    let onAccent: RGB
    let success: RGB
    let warning: RGB
    let danger: RGB
    let star: RGB
    let chartPalette: [RGB]

    static let darkChart = [RGB(0xE69F00), RGB(0x56B4E9), RGB(0x009E73), RGB(0xF0E442), RGB(0x3D8BD9), RGB(0xCC79A7)]
    static let lightChart = [RGB(0xD55E00), RGB(0x0072B2), RGB(0x00805C), RGB(0x3B3B3B), RGB(0x00727A), RGB(0x8A4E9E)]

    static let cinema = Look(
        id: .cinema, isLight: false, usesSerif: false,
        background: RGB(0x0B0B0D), surface1: RGB(0x141417), surface2: RGB(0x1C1C21), surface3: RGB(0x25252B),
        textPrimary: RGB(0xF5F3EE), textSecondary: RGB(0xA8A6A0), textTertiary: RGB(0x8C8A84),
        accent: RGB(0xF2C66D), accentGradient: [RGB(0xF2C66D), RGB(0xE39A3B)], onAccent: RGB(0x1A1206),
        success: RGB(0x5BD69A), warning: RGB(0xF2C66D), danger: RGB(0xFF6B6B), star: RGB(0xF2C66D),
        chartPalette: darkChart)

    static let noir = Look(
        id: .noir, isLight: false, usesSerif: false,
        background: RGB(0x000000), surface1: RGB(0x0E0E0E), surface2: RGB(0x1A1A1A), surface3: RGB(0x242424),
        textPrimary: RGB(0xFFFFFF), textSecondary: RGB(0xA6A6A6), textTertiary: RGB(0x8C8C8C),
        accent: RGB(0xD9D9D9), accentGradient: [RGB(0xD9D9D9), RGB(0x9A9A9A)], onAccent: RGB(0x000000),
        success: RGB(0x5BD69A), warning: RGB(0xE8C468), danger: RGB(0xFF6B6B), star: RGB(0xD9D9D9),
        chartPalette: darkChart)

    static let bookshop = Look(
        id: .bookshop, isLight: false, usesSerif: true,
        background: RGB(0x17110D), surface1: RGB(0x211913), surface2: RGB(0x2B2119), surface3: RGB(0x362A20),
        textPrimary: RGB(0xF3E7D3), textSecondary: RGB(0xBFAE95), textTertiary: RGB(0x9E8E78),
        accent: RGB(0xE08155), accentGradient: [RGB(0xE08155), RGB(0xD9774B)], onAccent: RGB(0x17110D),
        success: RGB(0x5BD69A), warning: RGB(0xE8B866), danger: RGB(0xFF6B6B), star: RGB(0xE08155),
        chartPalette: darkChart)

    static let neon = Look(
        id: .neon, isLight: false, usesSerif: false,
        background: RGB(0x0A0A14), surface1: RGB(0x12121F), surface2: RGB(0x1A1A2C), surface3: RGB(0x23233A),
        textPrimary: RGB(0xEDEBFF), textSecondary: RGB(0xA9A6C8), textTertiary: RGB(0x8A87AD),
        accent: RGB(0xA78BFA), accentGradient: [RGB(0x8B5CF6), RGB(0x22D3EE)], onAccent: RGB(0x0A0A14),
        success: RGB(0x5BD69A), warning: RGB(0xF5C451), danger: RGB(0xFF6B6B), star: RGB(0xA78BFA),
        chartPalette: darkChart)

    static let paper = Look(
        id: .paper, isLight: true, usesSerif: true,
        background: RGB(0xF7F4EE), surface1: RGB(0xFFFFFF), surface2: RGB(0xEFEAE2), surface3: RGB(0xE6E0D6),
        textPrimary: RGB(0x1B1A17), textSecondary: RGB(0x55524B), textTertiary: RGB(0x6B675F),
        accent: RGB(0xB3261E), accentGradient: [RGB(0xB3261E), RGB(0x8E1D17)], onAccent: RGB(0xFFFFFF),
        success: RGB(0x1B7044), warning: RGB(0x8A5A00), danger: RGB(0xB3261E), star: RGB(0xB3261E),
        chartPalette: lightChart)

    static let all: [LookID: Look] = [.cinema: cinema, .noir: noir, .bookshop: bookshop, .neon: neon, .paper: paper]
}
