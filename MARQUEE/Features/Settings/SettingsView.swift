import SwiftUI
import UIKit

/// Settings for milestone 1: Looks, motion, haptics, app icon, storage, About.
/// The full Appearance screen with live preview arrives in milestone 9.
struct SettingsView: View {
    @Environment(\.theme) private var theme
    @Environment(\.services) private var services
    @Environment(PreferencesStore.self) private var preferences
    @Environment(Router.self) private var router
    @Environment(ToastCenter.self) private var toasts
    @State private var cacheBytes: Int?
    @State private var name = ""

    var body: some View {
        Form {
            Section {
                TextField(String(localized: "Your first name"), text: $name)
                    .textContentType(.givenName)
                    .onSubmit { preferences.setDisplayName(name) }
                    .accessibilityIdentifier("settings.name")
            } header: {
                Eyebrow(String(localized: "You"))
            } footer: {
                Text("Used for the greeting on Home. It never leaves your phone.")
            }
            .listRowBackground(theme.surface1)

            Section {
                LookGallery()
                    .listRowInsets(EdgeInsets(top: Space.s, leading: 0, bottom: Space.s, trailing: 0))
                Picker(String(localized: "Animation"), selection: Binding(get: { preferences.animationLevel }, set: { preferences.setAnimationLevel($0) })) {
                    ForEach(AnimationLevel.allCases) { Text($0.displayName).tag($0) }
                }
                .accessibilityIdentifier("settings.animation")
                Toggle(String(localized: "Haptics"), isOn: Binding(get: { preferences.hapticsOn }, set: { preferences.setHaptics($0) }))
                    .accessibilityIdentifier("settings.haptics")
                Picker(String(localized: "Grid columns"), selection: Binding(get: { preferences.gridColumns }, set: { preferences.setGridColumns($0) })) {
                    ForEach(2...4, id: \.self) { Text("\($0)").tag($0) }
                }
                .accessibilityIdentifier("settings.columns")
                AppIconPicker()
            } header: {
                Eyebrow(String(localized: "Appearance"))
            }
            .listRowBackground(theme.surface1)

            Section {
                HStack {
                    Text("Artwork cache")
                    Spacer()
                    Text(cacheBytes.map { ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file) } ?? "…")
                        .foregroundStyle(theme.textSecondary)
                        .monospacedDigit()
                }
                Button(String(localized: "Clear artwork cache")) {
                    Task {
                        await services.images.clear()
                        cacheBytes = await services.images.diskUsage()
                        toasts.show(String(localized: "Artwork cache cleared. It downloads again as you browse."))
                    }
                }
                .accessibilityIdentifier("settings.clearCache")
            } header: {
                Eyebrow(String(localized: "Storage"))
            } footer: {
                Text("Clearing artwork never touches your library.")
            }
            .listRowBackground(theme.surface1)

            Section {
                NavigationLink(value: Route.about) {
                    Text("About MARQUEE").foregroundStyle(theme.textPrimary)
                }
                .accessibilityIdentifier("settings.about")
            } footer: {
                Text("Everything stays on your phone.")
            }
            .listRowBackground(theme.surface1)
        }
        .scrollContentBackground(.hidden)
        .background(theme.background.ignoresSafeArea())
        .navigationTitle(String(localized: "Settings"))
        .navigationBarTitleDisplayMode(.large)
        .task {
            name = preferences.displayName
            cacheBytes = await services.images.diskUsage()
        }
        .onDisappear { preferences.setDisplayName(name) }
    }
}

/// One-tap Look picker with a mini preview of each.
struct LookGallery: View {
    @Environment(PreferencesStore.self) private var preferences

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Space.s) {
                ForEach(LookID.allCases) { id in
                    LookSwatch(look: id.look, selected: preferences.look == id) {
                        Haptics.selection()
                        preferences.setLook(id)
                    }
                    .accessibilityIdentifier("settings.look.\(id.rawValue)")
                }
            }
            .padding(.horizontal, Space.margin)
        }
        .scrollIndicators(.hidden)
    }
}

struct LookSwatch: View {
    let look: Look
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(look.background.color)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 4) {
                            ForEach(0..<3, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(i == 0 ? look.surface3.color : look.surface2.color)
                                    .frame(width: 16, height: 24)
                            }
                        }
                        Capsule().fill(LinearGradient(colors: look.accentGradient.map(\.color), startPoint: .leading, endPoint: .trailing))
                            .frame(width: 40, height: 8)
                        Capsule().fill(look.textSecondary.color).frame(width: 30, height: 4)
                    }
                    .padding(8)
                }
                .frame(width: 76, height: 92)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(selected ? look.accent.color : Color.gray.opacity(0.35), lineWidth: selected ? 3 : 1)
                )
                Text(look.id.displayName)
                    .font(.footnote.weight(selected ? .bold : .medium))
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(Text(look.id.displayName))
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }
}

/// The two alternate app icons, set with `setAlternateIconName`.
struct AppIconPicker: View {
    @Environment(\.theme) private var theme
    @State private var current: String?
    @State private var failed = false

    struct Option: Identifiable {
        let name: String?
        let label: String
        let preview: String
        var id: String { preview }
    }

    private let icons: [Option] = [
        Option(name: nil, label: String(localized: "Frame"), preview: "AppIconPreview"),
        Option(name: "AppIcon-Bulbs", label: String(localized: "Bulbs"), preview: "AppIcon-BulbsPreview"),
        Option(name: "AppIcon-Ticket", label: String(localized: "Ticket"), preview: "AppIcon-TicketPreview"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("App icon")
            HStack(spacing: Space.m) {
                ForEach(icons) { icon in
                    Button {
                        set(icon.name)
                    } label: {
                        VStack(spacing: 4) {
                            Image(icon.preview)
                                .resizable()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .strokeBorder(current == icon.name ? theme.accent : .clear, lineWidth: 2.5))
                            Text(icon.label).font(.caption)
                        }
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel(Text("\(icon.label) icon"))
                    .accessibilityAddTraits(current == icon.name ? [.isSelected, .isButton] : .isButton)
                    .accessibilityIdentifier("settings.icon.\(icon.label)")
                }
            }
            if failed {
                Text("iOS didn't allow the icon change. Try again in a moment.")
                    .font(.footnote)
                    .foregroundStyle(theme.warning)
            }
        }
        .padding(.vertical, Space.xxs)
        .onAppear { current = UIApplication.shared.alternateIconName }
    }

    private func set(_ name: String?) {
        guard UIApplication.shared.supportsAlternateIcons, name != current else { return }
        UIApplication.shared.setAlternateIconName(name) { error in
            Task { @MainActor in
                if error == nil {
                    current = name
                    failed = false
                } else {
                    failed = true
                    AppLog.error(.ui, "Alternate icon change failed")
                }
            }
        }
    }
}

#Preview("Settings") {
    PreviewHost(demo: true) { SettingsView() }
}
