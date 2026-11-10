# Verification: spec 058, store each card's mana value from the catalog

Spec v1.0.3, plan `plan.md`, issue [#250](https://github.com/plainprogrammer/Collector/issues/250). Phases 1–4 are recorded here; Phase 5's commands and results are added in Phase 5 Step 5.

## Phase 1: the column (AC-1.1 to AC-1.5)

Commit `e1854f93` (a spacing fix in `9bf19c82`).

- **AC-1.1, AC-1.2:** `spec/models/mtg/card_spec.rb`, two examples. Failed first: `KeyError: key not found: "mana_value"` and `NoMethodError: undefined method 'mana_value='`. Now they pass (2 examples, 0 failures): the column is `float`, nullable, no default; a card made without one reads `nil`; `0.0`, `0.5` and `1_000_000.0` are kept exactly.
- **AC-1.3:** `script/worktree/with_mise bin/rails db:migrate:redo:primary` ran without error (remove, then add). After restoring `db/cable_schema.rb`, `db/cache_schema.rb` and `db/queue_schema.rb`, `db/schema.rb` differs from `main` by the version line (`2026_11_10_100001`) and `t.float "mana_value"` only. Plain `db:migrate:redo` aborts in this four-database app ("You're using a multiple database application"), so the `:primary` task is the command; spec v1.0.3 names it (plan review round 2, minor finding 1). No `db:rollback` was run.
- **AC-1.4:** the migration (`db/migrate/20261110100001_add_mana_value_to_mtg_cards.rb`, class `AddManaValueToMTGCards`: the MTG acronym inflection makes the file name camelize to that) is one `add_column` and references no model. `ruby script/upgrade/guard.rb` passed ("its 14 migrations are unchanged"). `git diff --stat script/upgrade/expected_changes.yml` is empty.
- **AC-1.5:** `spec/*_core_spec.rb` and `spec/backup_guards_spec.rb`: 27 examples, 0 failures. No core table gained a column.

## Phase 2: the mapper (AC-2.1 to AC-2.7)

Commit `17f8dfad`. `spec/models/mtg/scryfall/mapper_spec.rb` ("mana value (spec 058)", five examples) failed first (every failure was `mana_value` missing from the identity extension), with the 10 existing examples passing. Now 15 examples, 0 failures.

- **AC-2.1, AC-2.2:** recorded Scryfall objects `lightning_bolt_m10` (1.0), `little_girl_unh` (0.5), `gleemax_unh` (1000000.0).
- **AC-2.3:** `avatar_token_tm10` (a token, 0.0), kept as `0.0`.
- **AC-2.4:** `ajani_reversible_sld` has no top-level `cmc` (faces 4.0 and 4.0); it maps without raising and reads 4.0.
- **AC-2.5:** no `cmc` anywhere, no `card_faces` and no `cmc`, a front face without `cmc`, and `"x"`, `"3"`, `true` and `nil` all map to `nil` with the `mana_value` key present.
- **AC-2.6:** `cmc` `3` and `3.0` give the same value and the same digest. (The example uses `be(3.0)`, not `eql(3.0)`, because RuboCop's `RSpec/BeEql` flags `eql`; an Integer 3 still fails `be(3.0)`.)
- **AC-2.7:** the existing examples pass unchanged; the `scryfall_card` helper gained `"cmc" => 1.0`.

## Phase 3: the hook and the refresh (AC-3.1 to AC-3.8)

Commit `d2739aa5`. Before the change, `source_spec.rb` and `refresh_scryfall_spec.rb` ran 29 examples with exactly two failures: the new `reapply?` reason (AC-3.4) and AC-3.2 (the run was `skipped` and `mana_value` stayed `[nil, nil]`). The other new examples are guards that passed first, as the commit body says. After the change: `source_spec.rb` 21, `refresh_scryfall_spec.rb` 8, `refresh_spec.rb` 55, `mapper_spec.rb` 15, `spec/jobs` 54, `refresh_operation_spec.rb` 60, `spec/models/mtg` 353, `spec/models/catalog` 274, `spec/requests/admin` 100; 0 failures in each.

- **AC-3.1:** "fills cards that had no mana value, leaving their entries and ids as they were" (also compares each card's `mana_cost`, `type_line` and `oracle_text` before and after, and the card count).
- **AC-3.2:** "applies a scheduled refresh of an already-applied version while no card has a mana value", through `become_pre_upgrade` (cards' `mana_value` nulled and the identities' `content_digest` set to an old value, as a real upgraded instance holds them).
- **AC-3.3:** "skips a scheduled refresh of an already-applied version once a card has a mana value".
- **AC-3.4:** the three new `#reapply?` examples in `source_spec.rb` (cards only, some card with a value, either reason alone) and the existing spec 011 examples.
- **AC-3.5:** "applies a manual refresh of an already-applied version as always, and fills the column".
- **AC-3.6:** "changes nothing the second time over the same file": `MTG::Card` ids, values and `updated_at` unchanged, and `made_progress?` false.
- **AC-3.7:** "writes a reversible card with its front face's value and counts no malformed record".
- **AC-3.8:** the specs run under WebMock and stub only the bulk-data requests; `grep` for `mana_value` in `app` and `lib` finds it only in `mapper.rb` and `source.rb`, so no view, helper or controller reads it.

## Phase 4: the documents (AC-4.1 to AC-4.6, verified by reading)

- **AC-4.1:** `docs/architecture/catalog-core.md`: the Extension glossary entry now begins "`MTG::Card` holds mana cost, mana value, type line and rules text …" and continues "The mana value is Scryfall's `cmc`, a nullable float …, read from the card's own `cmc` or, for a reversible card that has none, its front face's, and never worked out from the mana cost …". "Decisions not in an ADR" has "**The mana value is Scryfall's number, read without failing.**" (the `fetch` trap and why it is not derived from `mana_cost`). Sources lists spec 058 and #250.
- **AC-4.2:** `docs/architecture/catalog-operations.md`: the Refresh's "Running" step has the sentence beginning "`MTG::Scryfall::Source#reapply?` says so for two reasons …"; "Accepted limits and open issues" has "A refresh that fails after some batches committed …"; Sources lists spec 058 decision 3.
- **AC-4.3:** `docs/releasing.md`, "Upgrade notes", first bullet, "**Mana value (spec 058).** One migration, `AddManaValueToMTGCards`, runs on boot …": names the weekly refresh, **Refresh now** and `bin/rails "catalog:refresh[mtg]"`, says nothing reads it yet and that the export format is unchanged (version 3). The migration's class name is `AddManaValueToMTGCards`, not the spelling the spec's AC-4.3 uses, because of the MTG acronym inflection.
- **AC-4.4:** `docs/architecture/data-portability.md` is not edited. Its version rule (line 42, "a new field of collector-owned data raises it") lists collector-owned tables and columns; `mtg_cards` is global catalog data, and `ExportFormat::Rules::VERSIONS` is `[1, 2, 3]` (its Named constants table).
- **AC-4.5:** `docs/specs/README.md` has the 058 row (status Approved until `distill-feature` moves it). Spec 058 supersedes nothing and no shipped spec is edited.
- **AC-4.6:** `bin/yard doc` builds without warnings (recorded in Phase 5); `Mapper.mana_value` and `Source#reapply?` carry why-comments, the first naming the missing top-level key, the front face and the no-`fetch` rule, the second naming both reasons.
