import SwiftUI
import UIKit

/// Hidden screen for helping fix problems without being a coder. "Copy
/// diagnostics" never includes reviews or notes.
struct DiagnosticsView: View {
    @Environment(\.theme) private var theme
    @Environment(\.services) private var services
    @Environment(LibraryStore.self) private var library
    @Environment(PreferencesStore.self) private var preferences
    @Environment(ToastCenter.self) private var toasts
    @State private var report: DiagnosticsReport?
    @State private var showingReport = false

    var body: some View {
        List {
            if let report {
                Section {
                    row("Version", "\(report.appVersion) (\(report.build))")
                    row("Data model", report.schemaVersion)
                    row("iOS", report.iOSVersion)
                    row("Films", "\(report.counts[.film, default: 0])")
                    row("Shows", "\(report.counts[.show, default: 0])")
                    row("Books", "\(report.counts[.book, default: 0])")
                    row("Recently deleted", "\(report.deletedCount)")
                    row("Artwork cache", ByteCountFormatter.string(fromByteCount: Int64(report.imageCacheBytes), countStyle: .file))
                    row("Last refresh", report.lastRefresh.map { AppCalendar.shortDate($0) } ?? String(localized: "Never"))
                    row("Last backup", report.lastBackup.map { AppCalendar.shortDate($0) } ?? String(localized: "Never"))
                } header: { Eyebrow(String(localized: "App")) }
                .listRowBackground(theme.surface1)

                Section {
                    row("TMDB key", report.tmdbKeyPresent ? String(localized: "Present") : String(localized: "Missing"))
                    row("TMDB", status(report.tmdbReachable))
                    row("Open Library", status(report.openLibraryReachable))
                } header: { Eyebrow(String(localized: "Connections")) }
                .listRowBackground(theme.surface1)

                Section {
                    Button(String(localized: "Copy diagnostics")) {
                        UIPasteboard.general.string = report.summary
                        toasts.show(String(localized: "Diagnostics copied. Paste them into a chat."))
                    }
                    .accessibilityIdentifier("diagnostics.copy")
                    Button(String(localized: "Report a problem")) { showingReport = true }
                        .accessibilityIdentifier("diagnostics.report")
                }
                .listRowBackground(theme.surface1)

                Section {
                    ForEach(Array(report.logLines.suffix(200).reversed().enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.caption2.monospaced())
                            .foregroundStyle(theme.textSecondary)
                            .textSelection(.enabled)
                    }
                } header: { Eyebrow(String(localized: "Recent log, newest first")) }
                .listRowBackground(theme.surface1)
            } else {
                ProgressView().frame(maxWidth: .infinity).listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.background.ignoresSafeArea())
        .navigationTitle(String(localized: "Diagnostics"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingReport) {
            if let report { ReportProblemView(report: report) }
        }
        .task { await build() }
        .refreshable { await build() }
    }

    private func row(_ label: LocalizedStringKey, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(theme.textPrimary)
            Spacer()
            Text(value).foregroundStyle(theme.textSecondary).monospacedDigit().multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }

    private func status(_ value: Bool?) -> String {
        switch value {
        case .some(true): return String(localized: "Working")
        case .some(false): return String(localized: "Not reachable")
        case .none: return String(localized: "Checking…")
        }
    }

    private func build() async {
        var r = DiagnosticsReport(
            appVersion: services.appVersion, build: services.build, schemaVersion: MarqueeStore.schemaVersion,
            iOSVersion: UIDevice.current.systemVersion, device: UIDevice.current.model,
            counts: library.counts(), deletedCount: library.recentlyDeleted.count,
            imageCacheBytes: await services.images.diskUsage(), lastRefresh: preferences.lastRefreshAt,
            tmdbKeyPresent: services.filmTV.hasKey, tmdbReachable: nil, openLibraryReachable: nil,
            lastBackup: preferences.lastBackupAt, logLines: AppLog.buffer.snapshot)
        report = r
        let filmTV = services.filmTV, books = services.books
        async let tmdb = filmTV.ping()
        async let ol = books.ping()
        r.tmdbReachable = await tmdb
        r.openLibraryReachable = await ol
        r.logLines = AppLog.buffer.snapshot
        report = r
    }
}

/// A short form: what happened, what I expected. Copies my answers plus diagnostics.
struct ReportProblemView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(ToastCenter.self) private var toasts
    let report: DiagnosticsReport
    @State private var happened = ""
    @State private var expected = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "What happened?"), text: $happened, axis: .vertical)
                        .lineLimit(3...8)
                        .accessibilityIdentifier("report.happened")
                } header: { Eyebrow(String(localized: "What happened")) }
                .listRowBackground(theme.surface1)
                Section {
                    TextField(String(localized: "What did you expect?"), text: $expected, axis: .vertical)
                        .lineLimit(2...6)
                        .accessibilityIdentifier("report.expected")
                } header: { Eyebrow(String(localized: "What you expected")) }
                .listRowBackground(theme.surface1)
            }
            .scrollContentBackground(.hidden)
            .background(theme.background.ignoresSafeArea())
            .navigationTitle(String(localized: "Report a problem"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Copy")) {
                        UIPasteboard.general.string = report.problemReport(whatHappened: happened, expected: expected)
                        toasts.show(String(localized: "Copied. Paste it into a chat."))
                        dismiss()
                    }
                    .disabled(happened.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("report.copy")
                }
            }
        }
        .presentationCornerRadius(Radius.sheet)
    }
}

#Preview("Diagnostics") {
    PreviewHost(demo: true) { DiagnosticsView() }
}
