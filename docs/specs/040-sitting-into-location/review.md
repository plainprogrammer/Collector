# Spec 040 review

## Round 1 (independent, Opus, read-only, 2026-11-03)

Verdict: **NEEDS REVISION**, then fixed in spec version 0.2.0.

| # | Finding | Resolution |
|---|---|---|
| M1 | AC-1.8 and decision 2 said the panel hides, against AC-1.1's control-only panel | Reworded: the page returns to AC-1.1's state |
| M2 | No control in the response to Done (the summary takes the panel's id) | AC-5.2 rewritten: summary plus the control |
| M3 | A sitting opened by choosing a place would read "Everything added … was undone." | AC-1.2 gives the copy for a sitting with no entries |
| M4 | AC-5.2 overrode spec 009 AC-3.5 ("Added 0 cards") unrecorded | Dropped the override; 009's wording stays |
| M5 | A "reversible" migration can cascade-delete entries on SQLite | NFR names the spec 032 pattern; new AC-6.0 proves up and down keep entries |
| M6 | Enter in a native select doesn't submit | Clause dropped; keyboard path is Tab to Set |
| m1–m13 | Index both ways, supersessions (009 AC-1.3, AC-3.2, FR-2), citation (034 decision 3), replay place, races, empty sitting after the last location is removed, import removing a location, 400/422 statuses, Undo label, Undo redraw and preload, design-system classes, AC-4.2 wording, area doc lines | Applied in 0.2.0 (the index's 009 and 032 rows are updated in the implementation PR, as the spec's "Documents that change" says) |
