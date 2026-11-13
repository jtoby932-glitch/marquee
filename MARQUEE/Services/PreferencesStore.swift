import Foundation
import Observation
import SwiftData

/// Reads and writes the single `Preferences` record.
@MainActor @Observable
final class PreferencesStore {
    private let context: ModelContext
    private let record: Preferences

    private(set) var look: LookID
    private(set) var animationLevel: AnimationLevel
    private(set) var hapticsOn: Bool
    private(set) var posterRadius: Double
    private(set) var gridColumns: Int
    private(set) var ratingDisplay: RatingDisplay
    private(set) var enabledKinds: Set<MediaKind>
    private(set) var displayName: String
    private(set) var lastBackupAt: Date?
    private(set) var lastRefreshAt: Date?

    init(context: ModelContext, overrideLook: LookID? = nil) {
        self.context = context
        let existing = (try? context.fetch(FetchDescriptor<Preferences>()))?.first
        let record = existing ?? Preferences()
        if existing == nil {
            context.insert(record)
            try? context.save()
        }
        self.record = record
        look = overrideLook ?? LookID(rawValue: record.lookRaw) ?? .cinema
        animationLevel = AnimationLevel(rawValue: record.animationLevelRaw) ?? .full
        hapticsOn = record.hapticsOn
        posterRadius = min(16, max(4, record.posterRadius))
        gridColumns = min(4, max(2, record.gridColumns))
        ratingDisplay = RatingDisplay(rawValue: record.ratingDisplayRaw) ?? .stars
        let kinds = Set(record.enabledKindsRaw.compactMap(MediaKind.init(rawValue:)))
        enabledKinds = kinds.isEmpty ? Set(MediaKind.allCases) : kinds
        displayName = record.displayName
        lastBackupAt = record.lastBackupAt
        lastRefreshAt = record.lastRefreshAt
        Haptics.enabled = hapticsOn
    }

    func setLook(_ value: LookID) {
        look = value
        record.lookRaw = value.rawValue
        save()
    }

    func setAnimationLevel(_ value: AnimationLevel) {
        animationLevel = value
        record.animationLevelRaw = value.rawValue
        save()
    }

    func setHaptics(_ value: Bool) {
        hapticsOn = value
        Haptics.enabled = value
        record.hapticsOn = value
        save()
    }

    func setGridColumns(_ value: Int) {
        gridColumns = min(4, max(2, value))
        record.gridColumns = gridColumns
        save()
    }

    func setDisplayName(_ value: String) {
        displayName = String(value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        record.displayName = displayName
        save()
    }

    func markRefreshed(_ date: Date) {
        lastRefreshAt = date
        record.lastRefreshAt = date
        save()
    }

    private func save() {
        do {
            try context.save()
        } catch {
            AppLog.error(.data, "Preferences save failed")
        }
    }
}
