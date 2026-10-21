# Plan review: spec 029 (manage locations)

An independent read-only review (Opus) of the first plan (`c9810cb`) returned **NEEDS REVISION** (0 critical, 4 major, 12 minor). This file maps each finding to its fix. The maintainer ruled on rows 23 and 24 and on M2 on 2026-10-21; spec **v1.3.2** (`e7285b1`, a PATCH) records the rulings, and the plan was revised in `c7947b4`. Every finding was taken.

## Maintainer rulings (2026-10-21)

| Ruling | Spec | Plan |
|---|---|---|
| Row 23 / M4: the fingerprint holds no location ids: for a renamed location `[current name, file name]`, for a removed one `[name]`. Decision 11's "its id" is "its current name" | v1.3.2, decision 11 | `Locations#fingerprint_part`; Phase 4 and Phase 5 tests with a renamed, a removed and an unchanged location deleted and re-created; row 23 resolved |
| Row 24: the notice never ends with a period; zero location counts are left out, zero lot counts stay | v1.3.2, AC-9.14 | `notice_for` and its examples (Phase 5); row 24 resolved; Quickstart |
| M2: AC-9.15 holds once the example's location names are normalised to NFC | v1.3.2, AC-9.15 | `as_version_two` normalises names with `Location::Name.normalise`; the NFD example is described in the format document (Phase 2 edit 10); a note for `verification.md` (Phase 6) |

## Major

| # | Finding | Fix | Where |
|---|---|---|---|
| M1 | A missing or non-numeric `format_version` was judged by the newest schema, so two version 1 invalid examples gained a second problem | `schema_version` returns `VERSIONS.min` for a version the instance doesn't read; the `malformed_variants` line stays; the FR-8 example, the rules_spec expectations (version 3 maps to 1, missing and string versions) and the Phase 2 run (the two version 1 examples) are updated; the document's "Well-formed" paragraph says which schema judges such a file | Phase 2 |
| M2 | The AC-9.15 loop failed on the NFD example | Ruling 3 above | Phases 3 and 5 (`as_version_two`), Phase 2 (document), Phase 6 (note) |
| M3 | Phases 0 to 3 ended red | Phase 0 carries the Coverage rows and the document spec's expectations; Phase 2 carries the two newer-version spec edits; Phase 3 carries the round trip's AC-6.4 rewrite (version 1 examples; Phase 5 widens the loop); Phase 2 is one commit, not a red intermediate one; every phase ends with the whole `bin/rspec`, and a global constraint says so | Phases 0 to 5, Global Constraints |
| M4 | Row 23 was a conflict inside the spec, not "still true" | Ruling 1 above | Spec v1.3.2; row 23; Phases 4 and 5 |

## Minor

| # | Fix | Where |
|---|---|---|
| m1 | Both More expectations of `admin/navigation_spec` (admin and member) change | Phase 1 |
| m2 | Quickstart export order is `box`, then `Trade binder` | Quickstart |
| m3 | The signed-out GET loop also runs with the catalog open (`:public_catalog`), through a shared helper | Phase 1 |
| m4 | Targets are measured with `getBoundingClientRect()` (field via its `c-input` label) for every control in `main` plus the Locations link and back button; a second example tabs through and checks `:focus-visible` outline; other header targets are recorded, not changed | Phase 1 |
| m5 | A request example previews an NFD name against a held NFC one and reads `#renamed_locations` and the unchanged count | Phase 4 |
| m6 | The cascade comment and data-model.md now say "as for `import_uploads` and `number_entries`" | Phase 0, `data-model.md` |
| m7 | Row 7 reworded: `locations` is memoized on first use, first read inside `replan` in an apply | Spec 028 references |
| m8 | The view-only case asserts the bulk removal is still undoable | Phase 5 |
| m9 | The vacuous `be_persisted` is replaced by `Location.exists?(blue.id)` false and a new id for the re-added name | Phase 5 |
| m10 | The format document's "Names" says the schema pattern uses Unicode property escapes (ECMA-262, `u` flag) and the words are the definition | Phase 2 |
| m11 | The Locations section renders after "Lots removed", so its lists come after the apply form as the lots' do | Phase 4 |
| m12 | A miss of the 640px fit is stated in advance as a maintainer decision, with the measurements to record and the remedies to put to them | Phase 1 |

## Not taken

None.

## Also checked after the revision

- Rows 23 and 24 of "Spec 028 references" are current and marked resolved by ruling; row 17 and row 12 were updated to match.
- No application code, RSpec or migration was written or run; the plan was traced against the files it edits (`spec/export_format_document_spec.rb`, `spec/models/collection_import/round_trip_spec.rb`, `spec/requests/admin/navigation_spec.rb`, `app/views/collections/import_previews/show.html.erb`).
- Open point for the executor, not a finding: the Phase 0 Coverage mapping relies on `name` already being a field in the version 1 valid examples (it is: a profile's and an entry's `name`); if the mapping example disagrees when run, fix it in Phase 0.

Commits: spec PATCH `e7285b1`; plan revision `c7947b4`.
