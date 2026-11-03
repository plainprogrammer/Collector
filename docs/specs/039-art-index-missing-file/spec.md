# Feature 039: A Finished Art Build Whose Index File Is Missing Isn't "Ready"

**Status:** Draft
**Version:** 1.0.0
**Created:** 2026-11-03
**Last Updated:** 2026-11-03
**Branch:** `039-art-index-missing-file`
**Issue:** [#122](https://github.com/plainprogrammer/Collector/issues/122)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-11-03 | Written from issue #122; decisions 1 and 3 and the Non-Goal on settings drift ruled by the maintainer the same day |
| 1.0.1 | 2026-11-03 | Spec review (Opus, APPROVE WITH CHANGES, nothing blocking): the supersession names the right criterion (015 AC-4.1) and has its own section; AC-4.3 and the document criteria name the documents that hold the restore steps and the open limit (`README.md`, `release-and-deploy.md`); decision 3's claim about scripts settled; AC-3.2 needs ImageMagick; the examples that must change are listed; the line's wording for a row with no name and for a queued build; how a shell operator already rebuilds |

---

## Problem Statement

The art index is two things that can disagree: a row in the primary database (`mtg_art_builds`, written when a build ends) and a file on the volume (`storage/catalog/mtg/art/index/art-index-<version>-<digest>-<count>.bin.gz`, written last by the build; `MTG::Art::Index`). The **Art index** panel on `/admin/catalog` (`MTG::Art::Operation`) and the art line of `catalog:status[mtg]` (`MTG::Art.status_line`) read only the row: a latest build that is `finished` reads "Ready." and "ready; N artworks indexed", whatever the volume holds.

The two disagree after:

- a restore onto a fresh volume: a backup holds the primary database only, so the row comes back and the file doesn't (spec 030 decision 12, which found this and left it for a separate issue);
- the `storage/catalog/mtg/art/` directory lost or emptied by hand, or a volume restored from an older snapshot;
- the file removed by hand while a row still names it. (`MTG::Art::Index.write!` also prunes to the newest `KEEP` files, but it prunes only when a later build writes a new file, and that build becomes the latest; so pruning reaches the latest finished build's file only if that later build then fails.)

The scanner page already does the right thing: `MTG::Art.page_config` returns nil with no index file, so the page offers text recognition only. Nothing breaks; the operator is told "Ready." when art matching isn't offered, and isn't told what to do. The workaround exists, and a shell operator already has a route: `catalog:refresh[mtg]` (README) queues a build after a refresh skipped as already applied while no index file exists for that version and the settings (`MTG::Art.after_refresh`), though it asks Scryfall for its bulk-data version first. On the page, **Build art index** is the light one ( every artwork already holds its fingerprint, so the build writes the file without downloading an image: spec 030 AC-2.8), but nothing on the page points to it.

## Goals

- A finished build whose index file isn't on disk reads as that, on the admin panel and on the `catalog:status` art line, in place of "Ready.".
- The panel's **Build art index** button is available in that state, and the line says to press it.
- Once the file is written again (by that build), both read "Ready." again.

## Non-Goals

- **Settings drift** (ruled by the maintainer, 2026-11-03). A finished build whose `settings_digest` differs from the current settings, or whose catalog version is no longer the latest, still reads "Ready." if its file exists. A file is judged by being there, not by being current. A follow-up issue records it.
- An art-only rake task to rebuild from a shell (ruled: the line points to the admin button, decision 3). `catalog:refresh[mtg]` stays what it is.
- Judging a file's contents (a zero-byte or corrupt file). Present means a file of the right name exists (decision 4).
- Changing what the scanner page does (`MTG::Art.page_config`), what a build does, or what a backup holds. A restore still leaves the file behind (spec 030 decision 3).
- A second artwork-level check (rows in `mtg_artworks` against the file's record count).

## Decisions

### 1. Missing means the file the build names is not on disk (ruled)

**Ruling (maintainer, 2026-11-03).** The latest finished build's own `index_file` (the name it wrote last, `MTG::ArtBuild#index_file`) is the file that matters.

The alternative, "no index of any name" (`MTG::Art::Index.current` is nil), matches the moment the scanner offers no art matching exactly, but a latest build whose file was pruned or deleted while some other index remains would still read "Ready.". The ruled reading says what the row claims and whether it holds. The panel therefore can read "Index file missing" while the scanner is still serving an older index; the wording makes no claim about the scanner (decision 2).

### 2. What the panel shows

A new art index state, `:index_missing`, between "Finished" and "Failed" in `MTG::Art::Operation#state`: reached only for a latest build that is `finished` whose file isn't there, and only when nothing is in flight (the order of the existing states is unchanged: off, building and its variants, queued, never, then this).

- **Summary:** "Index file missing. Build the art index again." (the issue's words).
- **Facts:** "Finished" (the build's finish time), "Index file" (the name the build wrote, or "none recorded" when the row has none), then "Artworks indexed", "Without an image" and "Failed images" as for "Ready.". These are the build's counts as it ended.
- **Button:** "Build art index", enabled whenever nothing is in flight, as for a finished or failed build (`Catalog::Operation#startable?`). No meter, no link to the Failed list, no polling (the state is not in flight).

### 3. What the status line says (ruled: point to the admin button)

**Ruling (maintainer, 2026-11-03).** The line points to the admin page's button and adds no task.

`Art matching: index file missing (<name>); press Build art index on the admin catalog page to write it again. <counts as for ready>`. It starts "Art matching: index file missing" and never contains "ready". No script reads the art line: `bin/image-smoke` matches only the whole line `No mtg refresh runs yet.`, and `bin/backup-smoke`, `bin/upgrade-smoke` and `script/upgrade/harness.rb` neither run `catalog:status` nor fetch `/admin/catalog`. Its readers are specs (`spec/tasks/catalog_rake_spec.rb`, which match prefixes, none on "ready"; `spec/models/mtg/scryfall/source_spec.rb`, which compares against `MTG::Art.status_line` itself). With no name on the row the parenthesis reads "(no file name recorded)". The line always describes the latest build, as today, so with a build job queued it still says to press the button while the panel shows "Queued." with the button disabled; the same is true of the interrupted line's advice, and is accepted. Wording says "on the admin catalog page", the house phrase (`MTG::Art.status_line`, the restore's closing message).

### 4. A file is present when a file of its name is there

`MTG::Art::Index.file?(name)` is true when `name` matches `MTG::Art::Index::NAME` and `index/<name>` is a regular file. Blank, nil, a name that doesn't match `NAME` (a hand-edited row; a path with a separator) and a file that can't be examined are all missing. Nothing is opened or read: the build wrote the file whole under a temporary name and renamed it, so a present file is a complete one except after outside damage, which is not judged (Non-Goal). The check is one `stat` per render of the panel or run of the line, never cached beyond a request: the volume can change between renders.

### 5. Recovery is the build that already exists

The build's incremental rules are untouched: it fingerprints only artworks lacking one at the current settings and fetches only the images it needs (`MTG::Art::Build#call`), then writes the file last (`MTG::Art::Index.write!`, which returns the existing path when the name already exists). After a restore, with every artwork fingerprinted, it fetches nothing (spec 030 AC-2.8). This spec adds one end-to-end example that goes from "missing" to a build to "Ready." without a request.

### 6. The check applies only to a finished latest build

A running, stalled, interrupted, queued or failed state is never replaced by "missing": those say what the build is doing or did, and a failed build already shows "Index in use" (with `Index.current`, or "none"). A build skipped as `already running` or `waiting for another job's retry` isn't the latest (`MTG::ArtBuild.latest`), as today.

## User Stories

### Story 1: The panel says the index file is missing

**As an** admin of a restored or damaged instance
**I want** the Art index panel to say the file is missing, and let me build it again
**So that** I'm not told art matching is ready when the scanner offers text recognition only, and I know what to press

- [ ] **AC-1.1** Given art matching on, an applied catalog refresh, a finished latest build whose `index_file` names no file on disk, and nothing queued When `MTG::Art::Operation` is asked Then its state is `:index_missing` and its summary is "Index file missing. Build the art index again." (fails before the change, which gives `:ready` and "Ready.")
- [ ] **AC-1.2** Given the same When the facts are read Then they are "Finished", "Index file" (the name), "Artworks indexed", "Without an image" and "Failed images", in that order, with the build's counts
- [ ] **AC-1.3** Given the same When the operation is asked if it can start Then it can (`startable?`), and the section has no meter, no Failed-list link and doesn't poll
- [ ] **AC-1.4** Given a finished latest build whose named file exists in `MTG::Art::Index.dir` Then the state is `:ready` and the summary is "Ready.", as before (guard)
- [ ] **AC-1.5** Given a finished latest build whose row has no `index_file`, or one that doesn't match `MTG::Art::Index::NAME` (including one with a path separator) Then the state is `:index_missing`, and the "Index file" fact reads "none recorded" for the blank one and the stored text for the other; no file outside `index/` is ever looked at
- [ ] **AC-1.6** Given a finished latest build whose file is missing and a build job in the queue Then the state is `:queued` (a queue state wins, as it does over "Ready."), and with a build running it is the running state; given a failed latest build Then it is `:failed` with its wording unchanged (decision 6)
- [ ] **AC-1.7** Given art matching off Then the section reads "off" as before and no file is looked at. (A finished build with no applied catalog refresh can't arise: a build needs one, `MTG::Art::Build#call`; the not-loaded wording stays the `:never` state's.)
- [ ] **AC-1.8** Given `/admin/catalog` rendered for an admin in the missing state Then the Art index section shows the summary, the facts and an enabled "Build art index" button, and the page doesn't poll (request spec); a member still gets 404

### Story 2: `catalog:status` says so too

- [ ] **AC-2.1** Given art matching on and a finished latest build whose named file is missing When `MTG::Art.status_line` is called Then it starts "Art matching: index file missing", names the file, says to press **Build art index** on the admin catalog page, names "no file name recorded" for a row without one, and doesn't contain "ready" (fails before the change)
- [ ] **AC-2.2** Given a finished latest build whose file exists Then the line is as it was: "Art matching: ready; N artworks indexed, …; index <name>" (guard)
- [ ] **AC-2.3** Given a running, stalled, interrupted or failed latest build, art matching off, or no build Then each line is as it was (guard; the check is made in the finished branch only)

### Story 3: Building again restores "Ready."

- [ ] **AC-3.1** Given the missing state and an admin When they press **Build art index** Then one `MTG::Art::BuildJob` is queued, as for any start (`Admin::Catalogs::OperationStartsController`, request spec; nothing new in the controller)
- [ ] **AC-3.2** Given ImageMagick present (as the art specs already need; the example is tagged `:art_matching`), a catalog whose artworks all hold a fingerprint at the current settings, a finished latest build and no index file, with every HTTP request blocked When `MTG::Art::Build` runs Then it finishes without an image request, the named file now exists, and the panel's state is `:ready` and the line reads "ready" (the example spec 030 AC-2.8 has, taken one step further to the panel; the build's own code is unchanged)

### Story 4: The documents say so

- [ ] **AC-4.1** `docs/architecture/catalog-operations.md`: the art index panel table's "Finished" row has the "Index file missing" row beside it with its source; the status-line paragraph words the missing line; the glossary or invariants say what "ready" is judged by; Sources gets #122 and this spec (verified by reading)
- [ ] **AC-4.1a** `docs/architecture/release-and-deploy.md`: the open limit that lists #122 ("say the art index is 'ready' although its file was left behind") is removed or reworded as fixed, and the Neighbours line that points to #122 is brought up to date; spec 039 is added to its Sources (verified by reading)
- [ ] **AC-4.2** The specs index has the 039 row and records the supersession in the Supersedes and Superseded-by columns of the rows it names (015, 011, 030), as this spec's Supersedes section does; no shipped spec is edited (verified by reading)
- [ ] **AC-4.3** `README.md`'s restore steps (the two places that tell the operator to press **Build art index**) say that until it is done the admin page and `catalog:status` read "Index file missing" (verified by reading). `docs/backup-restore.md` has no such step and gains none; the restore's closing message (`lib/collector/backup/restore.rb`) already says to press the button and is unchanged

## Functional Requirements

- **FR-1** `MTG::Art::Index.file?(name)` (decision 4) and `MTG::ArtBuild#index_file_present?`, which asks it of the build's own name. No collectible-agnostic core code changes: both are MTG code.
- **FR-2** `MTG::Art::Operation#state` returns `:index_missing` for a finished latest build without its file (decision 6), with the summary and facts of decision 2.
- **FR-3** `MTG::Art.status_line` words that build as decision 3 does.
- **FR-4** `Catalog::Operation`, the admin controllers, the views and `AdminHelper` change not at all: the panel renders an operation's summary and facts generically (`spec/admin_catalog_core_spec.rb` keeps checking the core files).

## Non-Functional Requirements

- **Data.** No migration, no new column, no stored data. The export format and the backup are untouched (`bin/ci`'s coverage and `spec/backup_guards_spec.rb` need no change).
- **Cost.** One `stat` per panel render and per `catalog:status` run; no queue reads beyond those the state already makes; no network.
- **Tenancy.** The catalog and its index are global (no `account_id`); the admin pages answer 404 to a member as before.
- **Testability.** Examples write and remove files under the test catalog directory (`MTG::Art.root`, `tmp/catalog/…` in tests, as the existing `MTG::Art::Index` examples do); the existing "Ready." examples in `spec/models/mtg/art/operation_spec.rb`, `spec/models/mtg/art_spec.rb` and `spec/requests/admin/catalogs_spec.rb` gain a real index file in their setup, since a bare finished build row (the factory's `index_file` is nil) now reads as missing. Those that break, read from the code: `operation_spec.rb`'s "shows the build as it ended when the job finished before the queue was read", "shows a finished build's counts and finish time (AC-4.7)" and "ignores a build skipped…"; `art_spec.rb`'s "reports a finished build's counts and index"; and the first half of the request spec's art section around line 501. Each writes its file with `MTG::Art::Index.write!` and sets the build's `index_file` to its basename. Nothing else breaks: every other finished-build example is running, failed or skipped, or asserts no state.

## Error Scenarios

| Condition | Behaviour |
|---|---|
| The index directory doesn't exist (a restore onto a fresh volume; the directory deleted) | Missing: `file?` is false for an absent directory |
| The file exists but is empty or damaged | Not judged: reads "Ready." (Non-Goal; the scanner's download and search are where that fails) |
| The volume can't be examined (permission error) | Missing, with no error raised to the page or the task |
| A build finished, then a later build was skipped | The skipped one isn't the latest; the finished one is judged |
| The index is written between the build ending and a render | The next render reads "Ready."; nothing is cached |
| Two finished builds name the same file (a build that changed nothing writes nothing new) | Both are judged by the same file |
| A hand-edited `index_file` such as `../../x` | Missing, and nothing outside `index/` is looked at (decision 4) |

## Supersedes

- **Spec 015 AC-4.1, in part:** the list of the art index section's states (never built, queued, building, stalled, ready, failed or interrupted) gains "index file missing", and "ready" now means a finished latest build whose file is on disk. AC-4.7 (a finished build shows its counts and finish time) still holds for "ready" and for the new state.
- **Spec 011 AC-3.11, in part:** the art line's "ready" wording is said only when the build's file exists; otherwise the line of decision 3.
- **Spec 030 decision 12, in part:** "until then `catalog:status` and the admin page still say 'ready'… it is not fixed here". It is fixed here; the restore procedure and AC-2.8 are unchanged.

## Interactions

- **UI copy.** The summary and fact labels are admin page copy: the plan applies the `collector-design-system` skill's voice rules before it words them.
- **Upgrade seeds.** `script/upgrade/seeds/*.rb` store `index_file: "art-index-upgrade.bin.gz"`, which doesn't match `Index::NAME`; such a seeded instance now reads "missing". The upgrade proof checks neither page, so nothing changes there.

## Open Questions

None. Decisions 1 and 3 and the Non-Goal on settings drift were ruled on 2026-11-03.

## Out of Scope

Settings drift (a follow-up issue), an art-only rake task, judging a file's contents, a change to the scanner, the build or the backup, and the other states of the panel.
