import SwiftUI

/// Applies the Look and motion policy, hosts the tabs, the toast and the intro.
struct RootView: View {
    let options: LaunchOptions
    @Environment(PreferencesStore.self) private var preferences
    @Environment(Router.self) private var router
    @Environment(ToastCenter.self) private var toasts
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showIntro: Bool

    init(options: LaunchOptions) {
        self.options = options
        _showIntro = State(initialValue: !options.skipIntro)
    }

    var body: some View {
        let theme = Theme(look: preferences.look.look, posterRadius: CGFloat(preferences.posterRadius))
        let motion = MotionPolicy(level: preferences.animationLevel, systemReduceMotion: reduceMotion)
        ZStack {
            theme.background.ignoresSafeArea()
            TabsView()
            if showIntro {
                OpeningAnimation { showIntro = false }
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .environment(\.theme, theme)
        .environment(\.motion, motion)
        .tint(theme.accent)
        .preferredColorScheme(theme.colorScheme)
        .onAppear {
            if let screen = options.screen { router.applyScreenshotScreen(screen) }
        }
    }
}

/// One navigation stack per tab under a custom tab bar styled to the Look.
struct TabsView: View {
    @Environment(\.theme) private var theme
    @Environment(Router.self) private var router
    @Environment(ToastCenter.self) private var toasts

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.tab) {
            ForEach(FeatureFlags.visibleTabs) { tab in
                NavigationStack(path: router.path(tab)) {
                    root(for: tab)
                        .navigationDestination(for: Route.self) { route in
                            destination(route)
                        }
                }
                .tag(tab)
                .toolbar(.hidden, for: .tabBar)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: Space.xs) {
                if let toast = toasts.current {
                    ToastView(toast: toast) { toasts.undo() }
                        .padding(.horizontal, Space.margin)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                MarqueeTabBar()
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: toasts.current)
        }
    }

    @ViewBuilder private func root(for tab: AppTab) -> some View {
        switch tab {
        case .home: HomeView()
        case .library: LibraryView()
        case .search: SearchView()
        case .stats, .profile: EmptyView()
        }
    }

    @ViewBuilder private func destination(_ route: Route) -> some View {
        switch route {
        case .title(let uid): TitleDetailView(uid: uid)
        case .settings: SettingsView()
        case .about: AboutView()
        case .diagnostics: DiagnosticsView()
        case .recentlyDeleted: RecentlyDeletedView()
        }
    }
}

/// The tab bar: the selected icon fills with a quick spring; tapping the current
/// tab again scrolls to the top; long-pressing Search opens quick add.
struct MarqueeTabBar: View {
    @Environment(\.theme) private var theme
    @Environment(\.motion) private var motion
    @Environment(Router.self) private var router

    var body: some View {
        HStack(spacing: 0) {
            ForEach(FeatureFlags.visibleTabs) { tab in
                let selected = router.tab == tab
                Button {
                    withMotion(motion, MotionPolicy.pressSpring) { router.select(tab) }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: selected ? tab.selectedSymbol : tab.symbol)
                            .font(.system(size: 20, weight: selected ? .semibold : .regular))
                            .symbolRenderingMode(.hierarchical)
                            .scaleEffect(selected && motion.allowsMovement ? 1.06 : 1)
                        Text(tab.title)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(selected ? theme.accent : theme.textTertiary)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .simultaneousGesture(LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                    guard tab == .search else { return }
                    Haptics.selection()
                    router.quickAdd()
                })
                .accessibilityIdentifier("tab.\(tab.rawValue)")
                .accessibilityLabel(Text(tab.title))
                .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(.horizontal, Space.xs)
        .padding(.top, Space.xxs)
        .background {
            Rectangle()
                .fill(theme.background.opacity(0.92))
                .background(.ultraThinMaterial)
                .overlay(alignment: .top) { Rectangle().fill(theme.stroke).frame(height: 1) }
                .ignoresSafeArea(edges: .bottom)
        }
    }
}
