import Foundation
import SwiftData

/// The first shipped data model. Never edit these classes once 0.1.0 is installed:
/// add `SchemaV2` alongside and a stage in `MarqueeMigrationPlan` instead.
enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Title.self, LibraryEntry.self, DiaryEntry.self, EpisodeWatch.self, SeasonCache.self,
         ActivityEvent.self, ShelfList.self, ListItem.self, Goal.self, MilestoneUnlock.self, Preferences.self]
    }

    /// The work itself: a film, show or book.
    @Model final class Title {
        @Attribute(.unique) var uid: String
        var kindRaw: String
        var name: String
        var originalName: String?
        var year: Int?
        var overview: String
        var genres: [String]
        var runtimeMinutes: Int?
        var pageCount: Int?
        var creators: [String]
        var posterPath: String?
        var backdropPath: String?
        var paletteHex: [String]
        var tvStatusRaw: String?
        var seasonCount: Int?
        var nextAirDate: Date?
        var lastRefreshed: Date?
        /// True when it was added offline and details still need fetching.
        var detailsPending: Bool
        @Relationship(deleteRule: .cascade, inverse: \LibraryEntry.title) var entry: LibraryEntry?

        init(uid: String, kind: MediaKind, name: String) {
            self.uid = uid
            self.kindRaw = kind.rawValue
            self.name = name
            self.overview = ""
            self.genres = []
            self.creators = []
            self.paletteHex = []
            self.detailsPending = false
        }
    }

    /// My relationship with a Title.
    @Model final class LibraryEntry {
        var statusRaw: String
        var rating: Int?
        var review: String
        var reviewHasSpoilers: Bool
        var tags: [String]
        var isFavourite: Bool
        var favouriteSlot: Int?
        var addedAt: Date
        var startedAt: Date?
        var finishedAt: Date?
        var currentPage: Int?
        var formatRaw: String?
        /// Set when removed; purged 30 days later unless restored.
        var deletedAt: Date?
        var title: Title?
        @Relationship(deleteRule: .cascade, inverse: \DiaryEntry.entry) var diary: [DiaryEntry]

        init(status: EntryStatus, addedAt: Date) {
            self.statusRaw = status.rawValue
            self.review = ""
            self.reviewHasSpoilers = false
            self.tags = []
            self.isFavourite = false
            self.addedAt = addedAt
            self.diary = []
        }
    }

    /// One watch or read on a date, with optional watch details.
    @Model final class DiaryEntry {
        var date: Date
        var rating: Int?
        var isRewatch: Bool
        var note: String
        var whereRaw: String?
        var cinemaName: String?
        var screenFormatRaw: String?
        var ticketPricePence: Int?
        var watchedWith: String?
        var entry: LibraryEntry?

        init(date: Date, rating: Int?, isRewatch: Bool) {
            self.date = date
            self.rating = rating
            self.isRewatch = isRewatch
            self.note = ""
        }
    }

    @Model final class EpisodeWatch {
        var titleUID: String
        var season: Int
        var episode: Int
        var watchedAt: Date
        var runtimeMinutes: Int?

        init(titleUID: String, season: Int, episode: Int, watchedAt: Date, runtimeMinutes: Int?) {
            self.titleUID = titleUID
            self.season = season
            self.episode = episode
            self.watchedAt = watchedAt
            self.runtimeMinutes = runtimeMinutes
        }
    }

    @Model final class SeasonCache {
        /// "tmdb-tv-1399#2"
        @Attribute(.unique) var key: String
        var titleUID: String
        var seasonNumber: Int
        var episodesData: Data
        var fetchedAt: Date

        init(titleUID: String, seasonNumber: Int, episodesData: Data, fetchedAt: Date) {
            self.key = "\(titleUID)#\(seasonNumber)"
            self.titleUID = titleUID
            self.seasonNumber = seasonNumber
            self.episodesData = episodesData
            self.fetchedAt = fetchedAt
        }
    }

    /// Powers stats, the heatmap and streaks.
    @Model final class ActivityEvent {
        var date: Date
        var kindRaw: String
        var amount: Int
        var titleUID: String

        init(date: Date, kindRaw: String, amount: Int, titleUID: String) {
            self.date = date
            self.kindRaw = kindRaw
            self.amount = amount
            self.titleUID = titleUID
        }
    }

    @Model final class ShelfList {
        @Attribute(.unique) var shelfID: UUID
        var name: String
        var icon: String
        var isRanked: Bool
        var createdAt: Date
        @Relationship(deleteRule: .cascade, inverse: \ListItem.shelf) var items: [ListItem]

        init(name: String, icon: String, isRanked: Bool, createdAt: Date) {
            self.shelfID = UUID()
            self.name = name
            self.icon = icon
            self.isRanked = isRanked
            self.createdAt = createdAt
            self.items = []
        }
    }

    @Model final class ListItem {
        var titleUID: String
        var position: Int
        var note: String
        var shelf: ShelfList?

        init(titleUID: String, position: Int) {
            self.titleUID = titleUID
            self.position = position
            self.note = ""
        }
    }

    @Model final class Goal {
        var year: Int
        var kindRaw: String
        var target: Int

        init(year: Int, kindRaw: String, target: Int) {
            self.year = year
            self.kindRaw = kindRaw
            self.target = target
        }
    }

    @Model final class MilestoneUnlock {
        @Attribute(.unique) var milestoneID: String
        var unlockedAt: Date

        init(milestoneID: String, unlockedAt: Date) {
            self.milestoneID = milestoneID
            self.unlockedAt = unlockedAt
        }
    }

    /// A single record of my settings.
    @Model final class Preferences {
        var lookRaw: String
        var accentOverrideHex: String?
        var gridColumns: Int
        var posterRadius: Double
        var ratingDisplayRaw: String
        var animationLevelRaw: String
        var hapticsOn: Bool
        var homeSectionOrder: [String]
        var hiddenHomeSections: [String]
        var enabledKindsRaw: [String]
        var spoilerShield: Bool
        var specialsCount: Bool
        var notifyNewEpisodes: Bool
        var notifyReadingReminder: Bool
        var displayName: String
        var lastBackupAt: Date?
        var lastRefreshAt: Date?

        init() {
            lookRaw = "cinema"
            gridColumns = 3
            posterRadius = 10
            ratingDisplayRaw = RatingDisplay.stars.rawValue
            animationLevelRaw = "full"
            hapticsOn = true
            homeSectionOrder = []
            hiddenHomeSections = []
            enabledKindsRaw = MediaKind.allCases.map(\.rawValue)
            spoilerShield = true
            specialsCount = false
            notifyNewEpisodes = false
            notifyReadingReminder = false
            displayName = ""
        }
    }
}

typealias Title = SchemaV1.Title
typealias LibraryEntry = SchemaV1.LibraryEntry
typealias DiaryEntry = SchemaV1.DiaryEntry
typealias EpisodeWatch = SchemaV1.EpisodeWatch
typealias SeasonCache = SchemaV1.SeasonCache
typealias ActivityEvent = SchemaV1.ActivityEvent
typealias ShelfList = SchemaV1.ShelfList
typealias ListItem = SchemaV1.ListItem
typealias Goal = SchemaV1.Goal
typealias MilestoneUnlock = SchemaV1.MilestoneUnlock
typealias Preferences = SchemaV1.Preferences

enum MarqueeMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
