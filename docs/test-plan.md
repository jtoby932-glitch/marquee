# Test plan

Written before each milestone. Journeys run as XCUITests in CI on every push; everything else is a unit test or a screenshot check.

## Milestone 1 (0.1.0) — shell, design system, search, add, library grid

**Journeys (MARQUEEUITests/JourneyTests.swift)**
1. Fresh install → Home empty state → quick add (+) → Search opens with the keyboard up → type "dune" → results appear after the 300 ms debounce → + → Want to watch → toast with Undo → Library shows the poster → open detail → More → Remove → confirm → toast → Undo → poster is back.
2. Swipe right on a book result adds it to Want to read in one gesture.
3. Offline (`-offline`): Search says "You're offline. Searching your library instead." and finds library titles.
4. About → tap the version 7 times → Diagnostics opens; 6 taps doesn't.
5. Settings → pick the Paper Look → it's selected.

**Accessibility**: `performAccessibilityAudit()` on Home, Library, Search, Detail, Settings, About, plus Library at the largest accessibility text size.

**Performance tripwires**: launch (3 iterations), scrolling the 294-item demo grid with memory, and building a 2,000-item snapshot (unit test).

**Risky areas and pass criteria**
| Area | Risk | Pass when |
|---|---|---|
| Duplicates | Adding the same title twice | `uid` is unique; second add refused (unit test) |
| Data safety | Remove loses data | Remove = soft delete; restore, re-add and 30-day purge tested |
| Undo of add | Leaves a ghost in Recently deleted | `discardJustAdded` leaves nothing (unit test) |
| Missing TMDB key | Crash or broken build | Build passes without the secret; search shows the friendly notice; books still work (`-noKey` screenshot) |
| Network | Timeouts, 5xx, 429 | 2 retries with backoff; Retry-After honoured; friendly messages (unit tests with URLProtocol) |
| Offline | Blank screens | Search falls back to library; cached JSON served stale |
| Contrast | A Look fails AA | Every text role ≥ 4.5:1 on every surface; chart palettes colour-blind checked (unit tests) |
| Motion | Ignores Reduce Motion | Policy forces Reduced; intro ≤ 1.6 s and skippable (unit tests) |
| Demo data | Touches the real store | `-demoData` always in-memory (unit test) |
| Layout | Clipping at SE size / AX3 | Screenshots on SE, standard, Pro Max and AX3 reviewed |

**Hostile paths covered by design (to verify on device)**: double-tapping + (sheet is single), tapping during the intro (tap skips), backgrounding mid-search (task cancels), very long titles (2-line clamp in rows, full on detail).
