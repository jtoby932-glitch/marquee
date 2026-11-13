# MARQUEE

A beautiful, personal record of every film, show and book: fast to log, lovely to browse, fun to look back on. Native SwiftUI + SwiftData for iPhone (iOS 17+). Everything stays on the phone.

Built entirely by CI: every push to `main` runs the tests, builds an unsigned `MARQUEE.ipa` (GitHub Releases) for Sideloadly/AltStore, and pushes screenshots to the `ci-screenshots` branch.

## What's where

| Path | What it holds |
|---|---|
| `MARQUEE/App` | App entry, environment, router, launch options, demo data, preview host |
| `MARQUEE/Design` | Looks (colour tokens), theme, spacing, type, motion policy, haptics, components |
| `MARQUEE/Domain` | Pure, tested logic: types, ratings, sorting/filtering, search ranking, dates, deep links, flags |
| `MARQUEE/Models` | SwiftData `SchemaV1` and the migration plan |
| `MARQUEE/Services` | TMDB and Open Library clients, HTTP with retries, caches, library and preferences stores, logging |
| `MARQUEE/Features` | Screens: Home, Search, Detail, Library, Settings, About, Diagnostics, opening animation |
| `MARQUEE/Resources` | Asset catalog (icons), string catalog, demo library, network fixtures |
| `MARQUEETests` | Unit and service tests |
| `MARQUEEUITests` | Journeys, accessibility audits, performance tripwires |
| `docs/` | Requirements checklist, test plan, bug log, design review, decisions, feedback |
| `tools/` | Project generator, secrets writer, icons, demo data, simulator picker, screenshots, lint |

## Building

CI does everything. To regenerate the project after adding or removing files: `python3 tools/gen_xcodeproj.py`. The TMDB token comes from the `TMDB_READ_TOKEN` Actions secret into a gitignored `Secrets.swift`; without it the app still builds and books still work.

## Credits

This product uses the TMDB API but is not endorsed or certified by TMDB. Where-to-watch data from JustWatch. Book data from Open Library.
