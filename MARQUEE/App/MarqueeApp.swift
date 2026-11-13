import SwiftData
import SwiftUI

@main
struct MarqueeApp: App {
    private let environment: Result<AppEnvironment, Error>
    @State private var router = Router()
    @State private var toasts = ToastCenter()

    init() {
        let options = LaunchOptions.current
        environment = Result { try AppEnvironment(options: options) }
        if case .failure = environment {
            AppLog.error(.data, "Store failed to open")
        }
    }

    var body: some Scene {
        WindowGroup {
            switch environment {
            case .success(let env):
                RootView(options: env.options)
                    .environment(env.library)
                    .environment(env.preferences)
                    .environment(env.network)
                    .environment(router)
                    .environment(toasts)
                    .environment(\.services, env.services)
                    .modelContainer(env.container)
                    .task { await env.afterFirstFrame() }
                    .onOpenURL { url in
                        if let link = DeepLink(url: url) { router.open(link) }
                    }
            case .failure(let error):
                StoreErrorView(detail: UserFacingError.map(error))
            }
        }
    }
}

/// Shown only if the library can't be opened. Nothing is deleted or reset.
struct StoreErrorView: View {
    let detail: AppError
    private let theme = Theme.cinema

    var body: some View {
        VStack(spacing: Space.m) {
            Illustration(kind: .projector)
                .frame(width: 132, height: 104)
            Text("MARQUEE couldn't open your library")
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.textPrimary)
                .multilineTextAlignment(.center)
            Text("Nothing has been deleted. Close the app completely and open it again. If this keeps happening, free up some storage on your iPhone.")
                .font(.body)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Space.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background.ignoresSafeArea())
        .environment(\.theme, theme)
        .preferredColorScheme(.dark)
    }
}
