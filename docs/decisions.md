# Decisions

| Date | Decision | Why | Alternatives considered |
|---|---|---|---|
| 2026-11-13 | Bundle ID `com.savonstudios.marquee`, display name MARQUEE | Matches PRIME's pattern; fixed forever so reinstalls keep data | `com.toby.marquee` |
| 2026-11-13 | Recommend a **public** repo | Free accounts get ~200 macOS CI minutes a month on private repos (10× multiplier), shared with PRIME; public repos are unlimited. Secrets stay secret either way | Private repo with fewer screenshot runs |
| 2026-11-13 | SwiftData models nested in `SchemaV1` with typealiases | Lets future schemas keep old model definitions for migrations | Top-level models (can't migrate cleanly) |
| 2026-11-13 | Core models plus watch-detail and soft-delete fields all in V1 | Avoids a migration in milestone 2/4 for fields we already know we need | Add them later via V2 |
| 2026-11-13 | Enums stored as raw strings on models | SwiftData predicates on enum properties have been unreliable | Codable enum properties |
| 2026-11-13 | Tertiary text and Neon text accent lightened | Brief's values fail WCAG AA; brief says adjust | Keep values, fail contrast |
| 2026-11-13 | Chart palettes: Okabe-Ito-based for dark Looks, a darker distinct-hue set for Paper | Tested ≥ 3:1 against background and separable under deuteranopia/protanopia | Brand-tinted palettes (not colour-blind safe) |
| 2026-11-13 | Default icon: film-frame bookmark; alternates Bulbs and Ticket | Strongest silhouette at small sizes; one shape for films and books | Bulb "M" as default |
| 2026-11-13 | Removing a title is a soft delete, and Recently deleted ships in 0.1.0 (from Library's ••• menu) | "Never delete anything permanently without Recently deleted" applies from the first build | Wait for milestone 4 |
| 2026-11-13 | Undo of an add made < 2 minutes ago removes it outright | Undoing my own just-made action isn't data loss, and avoids clutter in Recently deleted | Send it to Recently deleted |
| 2026-11-13 | Home avatar opens Settings until Profile exists (milestone 9) | No dead buttons; Profile tab hidden by feature flag | Hide the avatar |
| 2026-11-13 | Custom tab bar over a hidden system one | Look-styled, long-press on Search for quick add, reselect scrolls to top | System tab bar (can't do long-press) |
| 2026-11-13 | Search rows: TMDB multi-search doesn't return directors, so film/TV rows show the year only until details load | One extra request per result would blow the 600 ms budget | Fetch credits for every result |
| 2026-11-13 | `-stubNetwork` serves bundled fixtures for screenshots and UI tests | Repeatable, no network on CI, no token needed | Live API on CI (flaky, rate limits) |
| 2026-11-13 | Recent searches kept in UserDefaults | Small, disposable, never leaves the phone | SwiftData model (needs a migration) |
| 2026-11-13 | UI journeys run on the standard simulator; all three sizes are covered by screenshots | Running every journey three times would triple CI time | Matrix of three simulators |
| 2026-11-13 | CI runs on `macos-15-intel` | The arm64 `macos-15` pool hit capacity limits on the first run (job never acquired a runner); the Intel pool is separate and has 4 cores | Wait and re-run on arm64 |
| 2026-11-13 | Repo made public (was private) | Private repos share ~200 free Mac minutes a month with PRIME and the first runs used nearly all of November's; public repos have unlimited minutes. No secrets or personal data are in the repo | Pay per minute, or wait for 1 December |
| 2026-11-13 | Accessibility audits run in their own non-blocking CI job | `performAccessibilityAudit()` times out ("Audit failed to complete in time") on GitHub's Intel simulators even with a 40-title library; findings are logged in docs/bug-log.md and fixed per milestone | Block every build on audits that can't finish |
