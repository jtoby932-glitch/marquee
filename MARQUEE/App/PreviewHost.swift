import SwiftData
import SwiftUI

/// Wraps a view in a full in-memory environment for `#Preview`s.
/// Never touches the real store; network answers come from bundled fixtures.
struct PreviewHost<Content: View>: View {
    @State private var environment: AppEnvironment?
    @State private var router = Router()
    @State private var toasts = ToastCenter()
    let demo: Bool
    var look: LookID = .cinema
    var offline = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        Group {
            if let env = environment {
                NavigationStack { content() }
                    .environment(env.library)
                    .environment(env.preferences)
                    .environment(env.network)
                    .environment(router)
                    .environment(toasts)
                    .environment(\.services, env.services)
                    .environment(\.theme, Theme(look: look.look))
                    .preferredColorScheme(look.look.isLight ? .light : .dark)
            } else {
                Color.black
            }
        }
        .task {
            var args = ["-skipIntro", demo ? "-demoData" : "-freshStore", "-stubNetwork", "-look", look.rawValue]
            if offline { args.append("-offline") }
            environment = try? AppEnvironment(options: LaunchOptions(arguments: args))
        }
    }
}
