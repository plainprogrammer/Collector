# Plan: Spec 034, Choose a Location During Typed Entry

**Spec:** [spec.md](spec.md) 1.0.0 (approved 2026-10-26)

One phase, tests first.

1. `NumberEntry.add!` takes `location:` and passes it to `Lot.add!` (FR-2).
2. `NumberEntry::LineForm` gains `location`, `account`, `#locations`, `#location_record` and a validation (decision 5); `#add_attributes` carries the location.
3. The line form gains the Location select, only for an account with a location (decision 2); the choice rides in the URL, the language form and the pick buttons (decision 1).
4. The list preloads each lot's location; the line, the notice and the Undo label name the place (decision 3). No column, no migration, no export change (decision 4).
