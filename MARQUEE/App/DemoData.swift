import Foundation
import SwiftData

/// Seeds an in-memory store with a realistic library for screenshots and tests.
/// Only ever called with `-demoData`, which never opens the real store.
enum DemoData {
    struct Record: Decodable {
        let uid: String
        let kind: String
        let name: String
        let year: Int?
        let creators: [String]
        let genres: [String]
        let runtime: Int?
        let pages: Int?
        let status: String
        let rating: Int?
        let addedDaysAgo: Int
        let finishedDaysAgo: Int?
        let currentPage: Int?
        let overview: String?
    }

    static func records(bundle: Bundle = .main) -> [Record] {
        guard let url = bundle.url(forResource: "demo-library", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let records = try? JSONDecoder().decode([Record].self, from: data) else {
            AppLog.error(.data, "Demo data missing from bundle")
            return []
        }
        return records
    }

    static func seed(into context: ModelContext, now: Date, bundle: Bundle = .main) {
        let calendar = AppCalendar.calendar()
        for record in records(bundle: bundle) {
            guard let kind = MediaKind(rawValue: record.kind) else { continue }
            let title = Title(uid: record.uid, kind: kind, name: record.name)
            title.year = record.year
            title.creators = record.creators
            title.genres = record.genres
            title.runtimeMinutes = record.runtime
            title.pageCount = record.pages
            title.overview = record.overview ?? ""
            let added = calendar.date(byAdding: .day, value: -record.addedDaysAgo, to: now) ?? now
            let entry = LibraryEntry(status: EntryStatus(rawValue: record.status) ?? .wantTo, addedAt: added)
            entry.rating = Rating.normalised(record.rating)
            entry.currentPage = record.currentPage
            if let days = record.finishedDaysAgo {
                entry.finishedAt = calendar.date(byAdding: .day, value: -days, to: now)
            }
            context.insert(title)
            title.entry = entry
        }
        do {
            try context.save()
        } catch {
            AppLog.error(.data, "Demo seed failed")
        }
    }
}
