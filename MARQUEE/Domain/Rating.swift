import Foundation

/// Ratings are stored as whole numbers 1…10, where each point is half a star.
/// Integers avoid rounding errors when averaging and comparing.
enum Rating {
    static let range = 1...10

    /// Clamps any input into the stored range; 0 or less means "no rating".
    static func normalised(_ value: Int?) -> Int? {
        guard let value, value > 0 else { return nil }
        return min(10, value)
    }

    /// Converts a star value (0.5…5, as Letterboxd exports) to the stored integer.
    static func fromStars(_ stars: Double) -> Int? {
        guard stars.isFinite, stars > 0 else { return nil }
        return normalised(Int((stars * 2).rounded()))
    }

    static func stars(_ value: Int) -> Double { Double(value) / 2 }

    /// "4½" style text, used on posters and in lists.
    static func starText(_ value: Int) -> String {
        let whole = value / 2
        return value % 2 == 0 ? "\(whole)" : (whole == 0 ? "½" : "\(whole)½")
    }

    /// "4.5" or "9/10" depending on the display setting.
    static func display(_ value: Int, style: RatingDisplay) -> String {
        switch style {
        case .stars: return starText(value)
        case .outOfTen: return "\(value)/10"
        }
    }

    /// How VoiceOver reads a rating: "rated 4 and a half stars".
    static func spoken(_ value: Int) -> String {
        let whole = value / 2
        if value % 2 == 0 {
            return whole == 1 ? String(localized: "rated 1 star") : String(localized: "rated \(whole) stars")
        }
        if whole == 0 { return String(localized: "rated half a star") }
        return String(localized: "rated \(whole) and a half stars")
    }
}

enum RatingDisplay: String, CaseIterable, Identifiable, Codable {
    case stars, outOfTen
    var id: String { rawValue }
    var displayName: String { self == .stars ? String(localized: "Stars") : String(localized: "Out of 10") }
}
