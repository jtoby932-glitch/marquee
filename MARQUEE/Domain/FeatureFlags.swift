import Foundation

/// Hides anything unfinished from release builds, so `main` can always ship.
/// Each flag turns on in the milestone that finishes the feature.
enum FeatureFlags {
    /// Stats tab (milestone 5).
    static let stats = false
    /// Profile tab (milestone 9). Until then the Home avatar opens Settings.
    static let profile = false
    /// Up Next, Reading now and This week on Home (milestone 3).
    static let homeTracking = false
    /// Rating, review, diary and the rest of the full detail page (milestone 2).
    static let fullDetail = false
    /// Onboarding (milestone 9).
    static let onboarding = false

    /// Tabs that are switched on, in order.
    static var visibleTabs: [AppTab] {
        AppTab.allCases.filter { tab in
            switch tab {
            case .stats: return stats
            case .profile: return profile
            default: return true
            }
        }
    }
}

enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case home, library, search, stats, profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return String(localized: "Home")
        case .library: return String(localized: "Library")
        case .search: return String(localized: "Search")
        case .stats: return String(localized: "Stats")
        case .profile: return String(localized: "Profile")
        }
    }

    var symbol: String {
        switch self {
        case .home: return "house"
        case .library: return "square.grid.2x2"
        case .search: return "magnifyingglass"
        case .stats: return "chart.bar"
        case .profile: return "person.crop.circle"
        }
    }

    /// The filled variant shown when selected (Search has no filled glyph).
    var selectedSymbol: String { self == .search ? symbol : symbol + ".fill" }
}
