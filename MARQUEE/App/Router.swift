import Observation
import SwiftUI

/// Screens that can be pushed onto a tab's navigation stack.
enum Route: Hashable {
    case title(uid: String)
    case settings
    case about
    case diagnostics
    case recentlyDeleted
}

/// Tab selection and one navigation path per tab.
@MainActor @Observable
final class Router {
    var tab: AppTab = .home
    var paths: [AppTab: NavigationPath] = [:]
    /// Bumped to ask Search to focus its field (quick add).
    var searchFocusRequest = 0
    var pendingSearchQuery: String?
    /// Bumped when the current tab is tapped again, to scroll it to the top.
    var scrollToTopRequest: [AppTab: Int] = [:]

    func path(_ tab: AppTab) -> Binding<NavigationPath> {
        Binding(get: { self.paths[tab] ?? NavigationPath() }, set: { self.paths[tab] = $0 })
    }

    /// Search results opened before they're in the library, so detail shows instantly.
    private(set) var seeds: [String: SearchResult] = [:]

    func openResult(_ result: SearchResult, on tab: AppTab) {
        seeds[result.uid] = result
        push(.title(uid: result.uid), on: tab)
    }

    func push(_ route: Route, on tab: AppTab? = nil) {
        let target = tab ?? self.tab
        var path = paths[target] ?? NavigationPath()
        path.append(route)
        paths[target] = path
    }

    func select(_ newTab: AppTab) {
        if newTab == tab {
            if (paths[newTab]?.count ?? 0) > 0 {
                paths[newTab] = NavigationPath()
            } else {
                scrollToTopRequest[newTab, default: 0] += 1
            }
        }
        tab = newTab
    }

    /// Opens Search with the keyboard up, from anywhere.
    func quickAdd() {
        tab = .search
        paths[.search] = NavigationPath()
        searchFocusRequest += 1
    }

    func open(_ link: DeepLink) {
        switch link {
        case .title(let uid):
            push(.title(uid: uid), on: tab)
        case .search(let query):
            pendingSearchQuery = query
            quickAdd()
        case .season(let uid, _):
            push(.title(uid: uid), on: tab)
        case .timer, .decide:
            // Reading timer (milestone 7) and Decide for me (milestone 6) aren't built yet.
            AppLog.info(.ui, "Ignored link for a feature that isn't switched on")
        }
    }

    /// For CI screenshots: `-screen <name>` opens a screen directly.
    func applyScreenshotScreen(_ name: String) {
        switch name {
        case "home": tab = .home
        case "library": tab = .library
        case "search", "search-results", "search-offline", "search-nokey": tab = .search
        case "detail":
            tab = .library
            push(.title(uid: "tmdb-movie-693134"), on: .library)
        case "detail-book":
            tab = .library
            push(.title(uid: "ol-OL893415W"), on: .library)
        case "settings":
            tab = .home
            push(.settings, on: .home)
        case "about":
            tab = .home
            push(.settings, on: .home)
            push(.about, on: .home)
        case "diagnostics":
            tab = .home
            push(.settings, on: .home)
            push(.diagnostics, on: .home)
        case "deleted":
            tab = .library
            push(.recentlyDeleted, on: .library)
        default:
            break
        }
        if name == "search-results" { pendingSearchQuery = "dune" }
    }
}
