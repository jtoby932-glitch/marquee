# Handoff

Read this first in a new chat, then `docs/requirements.md`, `docs/decisions.md` and the task list.

## Where things stand (13 Nov 2026)

- **Milestone 1 (0.1.0): code written, not yet compiled.** The GitHub repo `jtoby932-glitch/marquee` doesn't exist yet, so nothing has been pushed, built or released. Asked Toby to create it (public, for unlimited CI minutes), confirm the bundle ID, and add the `TMDB_READ_TOKEN` secret.
- The full working tree is ready to push as the first commit. Expect the first CI run to surface compile errors: Swift was written without a compiler. Fix every error from the full log in one go (§4.3).
- After the first green run: open every screenshot on `ci-screenshots`, run the design critique (§1.5), score `docs/design-review.md`, bug bash, then release 0.1.0 and report.

## What's built

Tab shell (Home, Library, Search; Stats and Profile flagged off), opening animation, five Looks with contrast tests, motion policy, components, SwiftData `SchemaV1`, library store with soft delete / Recently deleted / 30-day purge, TMDB + Open Library clients with retries and disk cache, image cache, search with debounce and offline fallback, add (2 taps or swipe) with Undo, library grid, basic detail page, settings (Look, animation, haptics, grid columns, icon, cache), About with credits, hidden Diagnostics with copy and report-a-problem, three icon concepts, demo data (294 titles), fixtures, unit tests, UI journeys, accessibility audits, CI with three jobs.

## Next

1. Push, get CI green, review screenshots, release 0.1.0.
2. Milestone 2: full detail page (rating, review, diary with watch details, tags, favourites, cast, trailers, where to watch, paste a link, ISBN scanner). Google Books fallback. Palette extraction.

## Known issues

- Not compiled yet (see above).
- Navigation bar titles use the system font; serif large titles for Bookshop/Paper come with the Appearance work in milestone 9.
- Film/TV search rows show no director until details load (see decisions).
