# Spec 042: Independent Reviews

Three read-only pre-plan reviews (`sdd-review` Mode A, on Fable), each by a fresh reviewer, on 2026-11-06. Every finding was checked against the code and the neighbouring specs before it was applied; none was rejected.

## Round 1 (v0.1.0): NEEDS REVISION, 0 blocking, 2 major, 9 minor

- **Major:** the copy built by `scanner_copy` (add notice, Undo announcement, accessible names): which names the condition. Applied: the add notice and the entry line do; Undo and the accessible names don't (decision 3).
- **Major:** an entry-less sitting with neither choice would read "Cards you scan now: ."; "Nothing added yet." kept (decision 3).
- **Minor:** supersessions of spec 009 FR-1 and spec 040 decision 2, AC-3.2 and AC-5.2; `Scanner.md`'s row made unconditional; `c-scanner__place` has no style rule (AC-7.1 reworded); decision 5's citations corrected and where the collectible type may be named; a core guard spec (FR-3); every status-line variant written out; the no-finish notice; the rollback with a condition (AC-6.2).
- **Confirmed:** Rails 8.1's SQLite `remove_column` copies the table, so the migration needs spec 040's `disable_ddl_transaction!` pattern; the export claim; tenancy.

## Round 2 (v0.2.0): NEEDS REVISION, 0 blocking, 1 major, 7 minor

- **Major:** spec 040 Goals, decision 4's "condition (none)" and FR-1's "set a condition" superseded for condition, in the spec, the index rows and the area doc's update.
- **Minor:** roadmap 21a's "21b and 21c keep the order" amended; the condition check ahead of `Lot.add!` (the controller maps `RecordInvalid` to the cap message); the short label from the printing's vocabulary (no query per entry); two error rows; the legend renamed "This sitting's cards" so it doesn't repeat the empty-state line; AC-1.2's string scoped; the helper under the core guard.

## Round 3 (v0.3.0): READY TO PLAN, 0 blocking, 0 major, 5 minor

- **Minor, all applied in v0.3.1:** the condition check runs after the replay check; "Set" that clears both choices with no sitting clears the status line; the guard's pattern is number entry's without its finish words (the helper's comments quote "Foil"); the hook `c-scanner__place` keeps its name; the entry line with no finish.
