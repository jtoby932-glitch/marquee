import Foundation

/// Launch arguments used by CI screenshots and UI tests. None of them touch my
/// real library: `-demoData` and `-freshStore` both use an in-memory store.
struct LaunchOptions {
    var demoData = false
    /// A 40-title demo library, so accessibility audits finish in time.
    var demoSmall = false
    var freshStore = false
    var stubNetwork = false
    var offline = false
    /// Simulates a missing TMDB key, for the screenshot of that state.
    var noKey = false
    var skipIntro = false
    var screen: String?
    var look: LookID?
    var animationLevel: AnimationLevel?

    static let current = LaunchOptions(arguments: ProcessInfo.processInfo.arguments)

    init(arguments: [String]) {
        func value(after flag: String) -> String? {
            guard let i = arguments.firstIndex(of: flag), i + 1 < arguments.count else { return nil }
            return arguments[i + 1]
        }
        demoSmall = arguments.contains("-demoSmall")
        demoData = arguments.contains("-demoData") || demoSmall
        freshStore = arguments.contains("-freshStore")
        stubNetwork = arguments.contains("-stubNetwork") || demoData
        offline = arguments.contains("-offline")
        noKey = arguments.contains("-noKey")
        screen = value(after: "-screen")
        skipIntro = arguments.contains("-skipIntro") || (screen != nil && screen != "launch")
        look = value(after: "-look").flatMap(LookID.init(rawValue:))
        animationLevel = value(after: "-animation").flatMap(AnimationLevel.init(rawValue:))
    }

    /// True when the app must not open or change the real store on disk.
    var usesInMemoryStore: Bool { demoData || freshStore }
}
