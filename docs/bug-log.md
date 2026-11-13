# Bug log

Severity: **P0** crash or data loss · **P1** broken feature · **P2** visual or UX flaw · **P3** nitpick. P0 and P1 block a release.

| # | Found | Severity | Description | Status |
|---|---|---|---|---|
| 1 | M1 self-review | P1 | Search row's + button was nested inside the row's button and merged into one accessibility element, so it couldn't be tapped or found by VoiceOver. | Fixed: sibling buttons |
| 2 | M1 self-review | P2 | `marquee://search?q=a & b` lost everything after "&". | Fixed: query values percent-encoded; round-trip test |
| 3 | M1 self-review | P2 | Brief's tertiary text colours (e.g. `#6E6C67` on Cinema) fail WCAG AA (3.7:1). | Fixed: lightened per Look; contrast test |
| 4 | M1 self-review | P2 | Neon's violet accent fails AA as text (4.0:1). | Fixed: solid accent `#A78BFA` for text, gradient unchanged |
| 5 | M1 self-review | P3 | Bulb icon concept crowded at the top corners of the M. | Fixed: bulbs placed explicitly |
