# Implementation Plan: Scan a Sitting into a Location

**Spec:** docs/specs/040-sitting-into-location/spec.md (v0.2.2, approved by the maintainer on 2026-11-03; 0.2.2 records the ruling on P1)
**Status:** Approved by the maintainer (2026-11-03) after the independent read-only plan review (`plan-review.md`: 4 major and 12 minor findings, each mapped there to its fix); P1 ruled for the narrower rule, the upgrade seed skipped
**Decisions:** none new. No ADR: the place on the sitting follows ADR 0025 (a lot's location is part of its identity) and spec 032's migration pattern. ADR 0028 stays unused.
**Created:** 2026-11-03 (on `origin/main` at `cbf79d1`)

## Global Constraints

Copied from the spec; each applies to every phase.

- One pull request, one outcome: a sitting's place. No condition, language, price or quantity (spec Non-Goals); no JavaScript change; no export change.
- **The place lives on `scanner_sittings.location_id`** (decision 2), read on the server inside the add's transaction (FR-2). An add carries nothing new in its request.
- **Unplaced stays real:** a sitting with no place adds exactly as today (AC-1.5, AC-3.1). An account with no locations sees the scanner unchanged (AC-3.1).
- Every location is found through `Current.account.locations`; a bad value is a 422 alert, a missing key a 400, never a 404 (AC-3.3, AC-4.1). No sitting id, account id or `permit!` (AC-4.2, `.claude/rules/security.md`).
- The migration copies no table and loses no entry (NFR Migration, AC-6.0): `disable_ddl_transaction!`, raw `ALTER TABLE … ADD COLUMN … REFERENCES locations (id) ON DELETE SET NULL`, guarded steps. No released migration is edited.
- Core code names no collectible type beyond what spec 009 already names (FR-3).
- UI uses only design-system tokens and `c-*` classes. Read `docs/design-system/README.md` and the `collector-design-system` skill before the view phase, and `components/Form.md` plus the scanner's component doc.
- Pages work from 360px wide, with the keyboard alone; no script is added to the panel (AC-7.1).
- Every phase ends green: its last step is the whole `bin/rspec` plus `bin/rubocop`; an existing expectation that a phase makes false is changed in that phase.
- **Specs run with `bin/rspec` one file at a time in a phase while writing, never in parallel with `bin/ci` in the same worktree** (they share one SQLite test database; `.claude/memory/worktree-shared-test-db.md`).
- TDD is the hard gate: a failing test precedes every implementation step. Prose documents are verified by reading and recorded in `verification.md`, never by RSpec (`.claude/rules/testing.md`).
- Small commits: one Conventional Commit per unit step, each ending with the attribution lines; stage files by name; `Gemfile.lock` stays uncommitted.
- After `bin/rails db:migrate` restore the other schemas: `git checkout -- db/cache_schema.rb db/queue_schema.rb db/cable_schema.rb`, and check `db/schema.rb` changes only `scanner_sittings`.

## Goal

A collector chooses a location for the scanner's sitting, changes it mid-sitting, and every card added in it goes into the lot of that printing and finish in that place.

## Scope Check and Gates

- **Simplicity (≤3 components):** (1) *the place on the sitting*: the column, `Scanner::Sitting.place!` and the add; (2) *the control*: one route and controller, one partial; (3) *the places named*: the notice, the header and the entry line.
- **Anti-abstraction:** no new service. `Sitting.place!` is the one class method that opens, sets, clears or drops a sitting, as `Sitting.add!` is the one for adds. The picker is one partial, used by the panel, the no-sitting state and the summary.
- **Integration-first:** the migration spec (Phase 1) precedes the model; request specs precede the controller; the system spec (Phase 5) proves the whole flow in a browser.

## Areas and Supersessions

- **Area doc to change** (`.claude/rules/documentation.md`): [`collection-and-lots.md`](../../architecture/collection-and-lots.md): scope line 23, "Only some ways of adding choose a place" (line 55), the open item at line 222, the locations rule that removing an empty location clears a sitting's place; source inline for each (spec 040 decisions, ACs). `data-portability.md`: checked, no change expected (the sitting stays left out).
- **Supersedes** (recorded in the spec's Supersedes section and `docs/specs/README.md`; neither old spec is edited): spec 009's Non-Goals for a location, AC-1.3's notice, AC-3.2's heading and FR-2; spec 032 decision 5 and AC-7.2 for the scanner. The index's 009 and 032 rows gain "Superseded by 040" in Phase 6.
- **Design system:** a new row of label, select and button may need a rule in `collector/additions.css` with its doc under `docs/design-system/components/`; decided in Phase 4 after reading `Form.md` (open item P2).

## Open Items

| # | Item | Plan-level ruling (to be confirmed at approval) | Source |
|---|---|---|---|
| P1 | AC-3.2 says a sitting that "holds no cards" (AC-1.8: none added, or all undone) is dropped when the scanner next renders after its place was cleared by a removed location. Dropping an all-undone sitting on a reload would also delete spec 009's own all-undone sittings. | **Ruled 2026-11-03: the narrower rule (spec 0.2.2 rewords AC-3.2).** a sitting with **no entries at all and no place** is dropped before the scanner renders (`Scanner::Sitting#pointless?`); a sitting with entries, even all undone, stays and shows "This sitting: 0 cards" with Done. Spec 0.2.2 rewords AC-3.2 to "a sitting with no entries at all" (the spec is approved, not shipped). | spec AC-3.2, AC-1.8 |
| P2 | Whether the picker row needs CSS | Decide in Phase 4 after reading `Form.md`; prefer existing `c-form`/`c-field` classes, else one additions rule with its component doc. | spec Design system NFR |
| P3 | `Location` needs no association to sittings: the database's `on delete set null` does the work and `Location has_many :lots, dependent: nil` stays | No `has_many :scanner_sittings`; a request spec proves removal through `LocationsController#destroy`. | spec decision 7 |

## Phase 0: Approval bookkeeping (done with this plan)

Spec status line, version 0.2.1 and the index row set to Approved with the plan present. Commit `docs(specs): approve spec 040`.

## Phase 1: The column (spec AC-6.0, NFR Migration)

Files: `db/migrate/<timestamp>_add_location_to_scanner_sittings.rb`, `spec/migrations/add_location_to_scanner_sittings_spec.rb`, `db/schema.rb`.

1. **Red.** Write the migration spec on the model of `spec/migrations/add_location_to_lots_spec.rb` (`:backup, :committed, type: :model`; down and up through `connection_pool.migration_context.run`, which wraps a migration in a transaction unless it turns that off): a sitting with an entry and a lot before; run down then up; assert the sitting, the entry (and its `lot_id`) are unchanged and `location_id` is nil on every sitting. Add: an `up` with a placed sitting then `down` is allowed (the place is working state: `down` only drops the column; no `IrreversibleMigration` guard). Run it; it fails (no migration). Also: its `ensure` resets `Scanner::Sitting.reset_column_information` as well as `Lot`; it includes the lots spec's "finishes a run that stopped between its steps" example; the migration's timestamp is later than 20261023100001.
2. **Green.** The migration:

```ruby
# Lets a scanner sitting hold a place for its adds (spec 040 decision 2). The sitting is working state, so every existing
# sitting has none. SQLite copies a table to remove a column from it or add a constraint to it, and with foreign keys
# enforced the copy's DROP TABLE would cascade-delete the sitting's entries; so no transaction, ADD COLUMN, guarded steps
# (db/migrate/20261023100001_add_location_to_lots.rb).
class AddLocationToScannerSittings < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    execute "ALTER TABLE scanner_sittings ADD COLUMN location_id integer REFERENCES locations (id) ON DELETE SET NULL" unless column_exists?(:scanner_sittings, :location_id)
    add_index :scanner_sittings, :location_id unless index_exists?(:scanner_sittings, :location_id)
  end

  def down
    remove_index :scanner_sittings, :location_id if index_exists?(:scanner_sittings, :location_id)
    remove_column :scanner_sittings, :location_id if column_exists?(:scanner_sittings, :location_id)
  end
end
```

   The `down` rebuilds `scanner_sittings`; the spec's down step proves entries survive it (the migrator runs a non-transactional migration with enforcement off for the copy). If the down spec shows entries lost, the fix is `PRAGMA foreign_keys` handling copied from the lots migration's tests, never leaving `down` unproved.
3. Run `bin/rails db:migrate`; restore the other three schemas; confirm `db/schema.rb` shows only the `version:` line, the `location_id` column (after `updated_at`), its index and `add_foreign_key "scanner_sittings", "locations", on_delete: :nullify`. Run `ruby script/upgrade/guard.rb` (no released migration touched).
4. `bin/rspec spec/migrations/add_location_to_scanner_sittings_spec.rb`, then the whole suite and `bin/rubocop`. Commit `feat(scanner): add a place to the sitting`.

## Phase 2: The sitting holds and uses a place (AC-1.3–1.6, AC-1.8, AC-4.3, FR-1, FR-2)

Files: `app/models/scanner/sitting.rb`, `spec/models/scanner/sitting_spec.rb`.

1. **Red** (extend `spec/models/scanner/sitting_spec.rb`):
   - `.add!` with a place on the sitting adds into the lot in that place: merges into an existing lot there, leaves the unplaced lot and another place's lot unchanged (AC-1.3, 1.4); with no place it is the existing unplaced add (AC-1.5, the existing example stays).
   - the place is read inside the transaction: set the sitting's `location_id` to nil by `update_column`-free means (delete the location through the database with the lots empty) between creating the sitting and `add!`; the add is unplaced and never raises on a deleted location (FR-2).
   - 9,999 in Blue binder refuses with `RecordInvalid` and records nothing; the same card with the place set to Long box is added (AC-1.6).
   - a replayed reading key returns the existing entry whatever place is set now (AC-4.3).
   - `.place!(account:, location:)`: with a location and no sitting it opens one holding the place; with a sitting it sets it; twice in a row is one sitting (the unique `account_id` index); `nil` with a sitting that has a kept entry keeps the sitting and clears the place; `nil` with a sitting that has no kept entry (none, or all undone) deletes it; `nil` with no sitting does nothing (AC-1.2, AC-1.8).
   - `#pointless?` is true only for no entries at all and no place (P1).
   - `#kept_entries` loads each entry's lot and its location with no query per entry (assert the query count with the `sql.active_record` subscriber pattern of `spec/models/collection_grid_spec.rb`, against a sitting with three entries in two places).
2. **Green.**

```ruby
belongs_to :location, optional: true

def self.add!(account:, printing:, finish:, reading_key:)
  # … guards unchanged …
  transaction do
    sitting = find_or_create_by!(account:)
    existing = sitting.entries.find_by(reading_key:)
    next Added.new(entry: existing, replayed: true) if existing

    lot = Lot.add!(account:, entry: printing, finish:, location: sitting.location)
    # …
  end
end

# Sets, changes or clears the account's sitting place (spec 040 decision 2). Choosing a place opens a sitting; clearing the
# place of a sitting that holds no kept card deletes it, so the page is as before any sitting.
def self.place!(account:, location:)
  transaction do
    if location
      find_or_create_by!(account:).tap { |sitting| sitting.update!(location:) }
    elsif (sitting = find_by(account:))
      sitting.entries.kept.exists? ? sitting.update!(location: nil) : sitting.destroy!
      sitting
    end
  end
end

def pointless? = location_id.nil? && !entries.exists?
def kept_entries = entries.kept.newest_first.includes(lot: :location, printing: :set)
```

   Check `belongs_to :location` against `Account`'s destroy order (lots, locations, then the sitting: the foreign key nulls the place, spec reviewed as safe). `Lot.add!` with `location: nil` is the existing call. `find_or_create_by!` can race to a unique violation; it is the one `add!` already uses, so reuse without a new retry.
3. Whole suite, `bin/rubocop`. Commits: `test(scanner): …`, `feat(scanner): a sitting adds into its place`.

## Phase 3: Choosing the place (Stories 1–4, FR-1)

This phase carries the whole plumbing, so it ends green by itself: the route, the controller, the locals every template takes, the strict-locals signatures and the picker partial. Phase 4 only changes how the panel reads (header, copy, entry line, styling).

Files: `config/routes.rb`, `app/controllers/scanner/sittings_controller.rb`, `app/controllers/concerns/scanner_sitting.rb`, `app/controllers/scanners_controller.rb`, `app/controllers/scanner/sittings/entries_controller.rb`, `app/views/scanners/_scanner.html.erb`, `_sitting.html.erb`, `_summary.html.erb`, `show.html.erb`, new `_picker.html.erb`, `spec/requests/scanner/sittings_spec.rb`, `spec/requests/scanner/sitting_entries_spec.rb`.

1. **Red.** Request specs (signed in; Turbo Stream `Accept`):
   - `PATCH /scanner/sitting` with `sitting[location_id]` of the account's location opens a sitting holding it and answers a Turbo Stream replacing `#scanner_sitting` (AC-1.2); with a sitting, changes the place and leaves count and entries (AC-2.1).
   - A blank value clears (AC-1.8): keeps a sitting with a kept card; deletes one without.
   - A missing `sitting` key, or a `sitting` with no `location_id`, answers 400 and changes nothing (AC-3.3). The field is `sitting[location_id]` (the spec's `location`).
   - Another account's location id, a removed id and `abc` and `12abc` answer 422, change nothing, redraw the panel as stored and carry the alert "That location isn't one of yours any more. Choose again." (AC-4.1). A stray `sitting_id`/`account_id` param is ignored (AC-4.2).
   - Signed-out is refused like the other scanner endpoints.
   - Tenant isolation: account B's sitting is untouched by account A's request.
   - Adds (`sitting_entries_spec.rb`): with a place the notice reads "Added 1 × … in Blue binder to your collection." and the lot is placed; with none, the existing notice (AC-1.3, AC-1.5); the answer's panel is redrawn with the select (FR-1); the 9,999 refusal is the existing "full" message (AC-1.6); a replayed add's "added" answer names the entry's lot's place, not the sitting's (AC-4.3); an add after the place's location was removed is unplaced and its notice names no place (AC-3.2).
   - Undo (`Scanner::Sittings::Entries::UndosController`): the redrawn panel includes the select (FR-1); Undo of an entry added before a place change removes the copy from its lot (AC-2.2).
   - `GET /scanner`: an account with locations and no sitting sees the picker and no "This sitting" heading (AC-1.1); with none, nothing but today's page (AC-3.1); a placed, entry-less sitting whose only location is removed through `DELETE /locations/:id` is gone after the render and the page shows `#scanner_sitting[hidden]` (P1, AC-3.2: assert the markup, not just the row count); the import case goes through a real apply: in `apply_spec.rb:314`'s example ("a file whose only change is a location … clearing no working state") place the sitting in the removed location and assert its place becomes nil and the sitting stays.
   - Done (a redirect with a flash, so the page after it renders the summary): the page shows the summary and, with locations, the picker on "No location" (AC-5.2); a placed sitting ends, the copies stay in their place, the sitting and its place go (AC-5.1); choosing a place while the summary shows replaces it. AC-5.3 is `spec/models/collection_import/apply_spec.rb:152`'s example, extended with a placed sitting that the apply destroys.
2. **Green.**
   - Route: `resource :sitting, only: :update do … end` inside `namespace :scanner` (the existing `only: []` becomes `only: :update`).
   - `Scanner::SittingsController#update`:

```ruby
class Scanner::SittingsController < ApplicationController
  include ScannerSitting

  GONE = "That location isn't one of yours any more. Choose again.".freeze

  def update
    value = params.expect(sitting: :location_id)[:location_id].to_s
    location = Current.account.locations.find_by(id: value) if value.match?(/\A\d+\z/) # "12abc" is refused, not read as 12
    return render turbo_stream: sitting_stream(GONE, alert: true), status: :unprocessable_content if value.present? && location.nil?

    sitting = Scanner::Sitting.place!(account: Current.account, location:)
    render turbo_stream: sitting_stream(place_message(location, sitting))
  end
end
```

     `place_message` reads "This sitting's cards now go into Blue binder." or "This sitting's cards now go in no location."; the status message is plain text (design-system voice). `params.expect` returns a present blank value as present and raises `ParameterMissing` (400) for a missing key.
   - `ScannerSitting#sitting_locals` returns `{ sitting:, entries:, locations:, added_any: }`: `locations` is `Current.account.locations.ordered.to_a` (one query per request), `added_any` is `sitting&.entries&.exists?` (so the view never queries). Every template with strict locals takes them: `_scanner.html.erb` `(sitting:, entries:, locations:, added_any:, summary: nil)` (through `show.html.erb`'s `**@sitting`), `_sitting.html.erb` `(sitting:, entries:, locations:, added_any:)`, `_summary.html.erb` `(count:, locations:)`. `sitting_stream` already redraws the panel after adds, Undo and now the place.
   - `ScannersController#show` drops a pointless sitting and renders without it (P1):

```ruby
sitting = Current.account.scanner_sitting
if sitting&.pointless?
  sitting.destroy!
  sitting = nil # the has_one reader keeps its destroyed target, so pass nil explicitly
end
@sitting = sitting_locals(sitting)
```
   - `Scanner::Sittings::EntriesController#message_for` appends " in #{name}" from `entry.lot&.location` after the card name, using `entry.lot` loaded once (replays too: the entry's lot's place now).
   - The Done path is unchanged (`endings#create` redirects with a flash); `_scanner.html.erb` passes `locations:` to `_summary`.
   - `_picker.html.erb` (locals `(location_id:, locations:)`) is the markup of Phase 4's step 3, with `location_id.to_s` so "No location" is `selected`; `_sitting.html.erb` renders it with the sitting's `location_id` when `locations.any?`, the no-sitting state is the panel with the picker only, and `_summary.html.erb` renders it on `""`. Status messages: set "This sitting's cards now go into Blue binder."; cleared with cards kept "This sitting's cards now go in no location."; cleared with the sitting deleted: no message.
3. Whole suite, `bin/rubocop`, `bin/brakeman`. Commits: `test(scanner): …`, `feat(scanner): choose a place for the sitting`.

## Phase 4: The panel (Stories 1, 2, 7; decision 3, 4)

Files: `app/views/scanners/_sitting.html.erb`, `_picker.html.erb`, `_sitting_entry.html.erb`, possibly `app/assets/stylesheets/collector/additions.css`, and `docs/design-system/components/Scanner.md` (lines 30–32 describe the panel and summary; update them for the control, the ", in <place>" heading, "in <place>" on each entry, the empty-sitting copy and the summary with the control).

1. Read `docs/design-system/README.md`, `components/Form.md` and the scanner component doc; settle P2.
2. **Red** (extend the request specs of Phase 3 with markup assertions, then the system spec of Phase 5): with locations and no sitting the panel has the labelled select ("Put this sitting in"), "No location" first and selected, locations in the order of `/locations`, a "Set" button, and no card count or Done link (AC-1.1); a placed sitting's heading is "This sitting: 3 cards, in Blue binder" and the select shows it (decision 3); the empty-list copy has three states, chosen from `entries` and `added_any`: no entry ever and a place shows "Cards you scan now go into Blue binder."; entries all undone keeps "Everything added in this sitting was undone."; no entry ever and no place (a redraw before the next render drops it) shows "Nothing added yet." (AC-1.2); each entry line shows "· in Blue binder" after the finish, from the lot's place now, nothing for a "Changed" entry (decision 4, AC-2.3); an account with no locations renders none of it (AC-3.1).
3. **Green.** The picker partial (locals `sitting_place`, `locations`) is:

```erb
<%# locals: (location_id:, locations:) %>
<%= form_with url: scanner_sitting_path, method: :patch, scope: :sitting, class: "c-form c-scanner__place" do |form| %>
  <div class="c-field">
    <%= form.label :location_id, "Put this sitting in", class: "c-field__label" %>
    <%= form.select :location_id, options_for_select([ [ "No location", "" ], *locations.map { |l| [ l.name, l.id ] } ], location_id.to_s) %>
  </div>
  <div class="c-form__actions"><%= form.submit "Set", class: "c-btn c-btn--secondary c-btn--sm" %></div>
<% end %>
```

   The markup copies `app/views/lots/_form.html.erb:32-35` (a select is a plain element inside a `c-field`; `c-select` belongs to the filter bar, `Form.md:5`); if the row at 360px needs a rule, it is one addition in `collector/additions.css` with its doc. The header text and the three-state empty copy are this phase's change to `_sitting.html.erb` (the picker, the control-only panel and the summary's picker were wired in Phase 3). The header text is `"This sitting: #{pluralize(n, "card")}#{", in #{place.name}" if place}"`. The entry partial appends the place to the meta line.
   Keep every `<%# locals: … %>` magic comment exact.
4. Whole suite, `bin/rubocop`. Commits: `feat(scanner): the sitting's place on the panel`.

## Phase 5: The flow in a browser (Stories 1, 2, 5; AC-1.7, AC-2.1)

Files: `spec/system/scanner_sitting_spec.rb` (extend; it already has the scanner's add flow and image helpers: `.claude/memory/browser-spec-image-and-window-gotchas.md`).

1. **Red then green** (headless Firefox; no `sleep`, Capybara waits): choose Blue binder with no sitting, add a card from a reading (the existing spec's route), see "in Blue binder" in the notice and the entry, switch to Long box, add another, see the first still in Blue binder; reload keeps the chosen place (AC-1.7); "No location" with cards keeps the sitting; Done shows the summary with the picker; the camera element and a reading on screen remain after choosing a place (AC-1.2; the Turbo form must not reload the page: mark `window` before and check the mark after); at the 360px frame of the file's narrow example (`scanner_sitting_spec.rb:46`) with a long location name, the label, select and button do not scroll the page sideways; the keyboard path (Tab to Set, Enter) is a system step.
2. Run only this file; then the whole suite and `bin/rubocop`. Commit `test(scanner): a sitting scanned into a location`.

## Phase 6: Documents and verification

1. `docs/architecture/collection-and-lots.md`: the four statements named under Areas and Supersessions, each with its spec 040 source inline; the scanner is still "no area doc".
2. `docs/roadmap.md`: item 21a "Built <date>, done when its pull request merges: [spec 040](…)" and the sentence that it ran before the spikes by ruling (decision 1); keep the other rows alone.
3. `docs/specs/README.md`: the 009 and 032 rows' "Superseded by" cells name 040 (both directions); the 040 row's status stays Approved until distillation.
4. `docs/specs/040-sitting-into-location/verification.md`: each AC with its evidence (spec, request spec or system spec by name); document criteria verified by reading; a screenshot of the panel at phone width in both themes (`.claude/memory/pr-screenshots-workflow.md`, `headless-firefox-narrow-frame.md`) in `screenshots/`; the `## Implementation review` heading is added by the review step later.
5. `bin/ci` in full (a push runs it as a hook: push in the background, `.claude/memory/push-in-background.md`).
6. Commits: `docs(…)`. Do not edit spec 009 or 032 (`.claude/rules/documentation.md`).

## Verification (before the pull request is ready)

- `bin/rspec` green, `bin/rubocop`, `bin/brakeman`, `bin/bundler-audit`, `ruby script/upgrade/guard.rb`.
- `git grep -n -i 'mtg\|scryfall' -- app/views/scanners/_picker.html.erb app/controllers/scanner/sittings_controller.rb` is empty (FR-3); the sitting model's existing references are unchanged.
- `db/schema.rb` diff is the one column, index and foreign key; the other three schemas are unchanged.
- The export is untouched: `git diff origin/main -- docs/export-format lib/export_format app/models/export*` is empty.
- Upgrade proof: the migration spec; CI's `bin/upgrade-smoke` runs in the image job.
- Per hosted-door rule 4: one integer column, no background work, the locations loaded once per request.

## Not in this plan

The upgrade seed's place (ruled out 2026-11-03). 
Condition (#57), language (#58), moving a sitting's cards (#48), a remembered place, naming the place in the Undo label, any capture or detection work.
