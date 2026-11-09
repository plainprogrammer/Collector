# Feature 053: An Art Index Built With Other Settings or For an Older Catalog Isn't Plain "Ready"

**Status:** Approved by the coordinator under the maintainer's delegation on 2026-11-09
**Version:** 1.0.1
**Created:** 2026-11-09
**Last Updated:** 2026-11-09
**Branch:** `176-art-index-drift`
**Issue:** [#176](https://github.com/plainprogrammer/Collector/issues/176)
**Frozen:** the current rules are in [`catalog-operations.md`](../../architecture/catalog-operations.md) and [`scanner.md`](../../architecture/scanner.md) (whole spec); see the [specs index](../README.md)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-11-09 | Written from issue #176 and the maintainer's rulings of 2026-11-09 (confirm what the scanner does first; its own state where the scanner can't use the index, a warning fact where it keeps using it; catalog drift by the same test) |
| 1.0.1 | 2026-11-09 | Spec review (Fable, APPROVE WITH CHANGES, nothing blocking): AC-5.1 drops a Neighbours line that doesn't exist and adds the Glossary's "Ready (art index)" entry; AC-5.2 names Sources and the page-side rules; AC-1.7 is per blank; AC-3.2 has its applied refresh; AC-4.1 and AC-4.2 say art matching is on and how the fixture is made; one statement of the blank version; the cost; the Supersedes wording |

---

## Problem Statement

The **Art index** panel on `/admin/catalog` (`MTG::Art::Operation`) and the art line of `catalog:status[mtg]` (`MTG::Art.status_line`) say "Ready." and "ready; N artworks indexed" for a latest build that is `finished` and whose file is on the volume (spec 039). They never compare the build with what the instance runs now, though each build records both (`settings_digest`, `catalog_version`). Two kinds of drift follow:

- **Settings drift:** the build's `settings_digest` differs from the current `MTG::Art::Settings.digest` (a release changed `config/art_fingerprint.json`).
- **Catalog drift:** the build's `catalog_version` is not the latest applied refresh's `source_version` (a refresh applied while art matching was off, or its queued rebuild was lost or discarded).

**What the scanner does today, per kind** (the maintainer's first question; each answered from the code and an example run, not assumed):

| Drift | What the scanner does | Evidence |
|---|---|---|
| Settings | **Refuses it, in the browser, after downloading it.** `MTG::Art.page_config` offers the newest file of any digest (`MTG::Art::Index.current`), and the page carries the current digest; `GET /scanner/art/:name` serves the file (200). `parseIndex` (`app/javascript/scanner/art.js`) compares the header's digest with the page's, throws, and the page says "Artwork matching isn't available. The scanner is reading text only." and sends text only | A model and request example (settings-drifted build and file: `page_config` is present, the file is served with 200, its header digest is not the page's, the panel reads `:ready`); the existing system example `spec/system/scanner_art_spec.rb` "says art matching isn't available, and sends text only, when the index doesn't match the page" (spec 011 AC-5.2, AC-5.4) |
| Catalog | **Keeps using it.** Nothing on the scanner path reads the catalog version: the file's header holds no version, so the digest matches and the page searches the older index. Artworks added by later refreshes are not in it, so they get no art evidence (text recognition is unaffected) | The same example run (a build and file for `default-cards-1`: `page_config` present, served with 200, the header digest equals the page's) |

So the panel and the line say "Ready." for an index the scanner refuses (settings drift), and say a plain "Ready." for one it uses but which lacks newer cards (catalog drift). Nothing breaks and the scanner stays usable (text recognition); the operator isn't told art matching is off or stale, nor what to do. **Build art index** fixes both: after catalog drift it is incremental (it fingerprints only artworks lacking one at the current settings); after settings drift every artwork lacks a fingerprint at the new settings, so it fingerprints all of them from the cached images in `storage/catalog/mtg/art/small/` and fetches only images that cache lacks. A release that changes the settings queues no rebuild by itself: `MTG::Art.after_refresh` queues one only after a refresh, so until the next refresh the scanner reads text only without anything on the admin page saying so.

## Goals

- A finished build whose index the scanner can't use (settings drift) reads as its own state, on the panel and on the `catalog:status` art line, in place of "Ready.", worded like spec 039's "Index file missing", with the button available and the line saying to press it.
- A finished build whose index the scanner still uses but which was built for an older catalog keeps "Ready." and adds a warning fact saying so, on the panel and the line.
- Once a build at the current settings and catalog finishes, both read plain "Ready." again.

## Non-Goals

- Changing what the scanner page does (`MTG::Art.page_config`, `art.js`, its message), what a build does, or what a backup holds.
- A build queued by a release that changes the settings, or by anything but a refresh (`MTG::Art.after_refresh` stays as it is). The state tells the operator to press the button.
- Judging the file by its header. The settings digest is in the file's name and header alike; the panel judges the build's row, as it reads that row already (decision 1).
- The failed state's "Index in use" fact, which may name a file of other settings.
- A damaged or empty file (spec 039 Non-Goal stays), and an art-only rake task.
- A claim about which file the scanner serves: the page uses the newest file (`Index.current`), the panel judges the latest finished build's. They are the same file unless files were removed by hand or a later build failed (spec 039 decision 1 accepts the same).

## Decisions

### 1. The tests, and where each applies (ruled)

**Ruling (maintainer, 2026-11-09).** Settings drift: the latest finished build's `settings_digest` differs from `MTG::Art::Settings.digest`. Catalog drift: its `catalog_version` is not the latest applied refresh's `source_version` (`Catalog::RefreshRun.for_type("mtg").last_applied`, the version a build reads at its start). A blank on either side isn't judged: a build row with no `settings_digest` or `catalog_version`, or whose latest applied refresh has no `source_version`, reads as before (the *latest* applied refresh's version, not the latest one that has a version). The settings test is the one the scanner enforces (it refuses a digest it doesn't hold); the catalog test is one it doesn't, which is why the first gets a state and the second a fact.

Both are judged only for a finished latest build whose file is on disk and only once nothing is in flight: spec 039's missing state comes first (no file, nothing to compare), the in-flight and failed states are unchanged (spec 039 decision 6). **The weekly refresh's queued rebuild doesn't excuse a wrong panel** (ruled): while that build is queued or running the panel says so, as always; the moment nothing is in flight the panel judges the finished build in front of it, so a rebuild that was lost, discarded or never queued (art matching was off, or the settings changed with no refresh) shows as drift. The status line describes the latest build whatever the queue holds, as it does for "missing".

### 2. Settings drift is a state: `:out_of_date`

Between `:index_missing` and the ready state in `MTG::Art::Operation#state`.

- **Summary:** "Out of date. Built with other settings, so the scanner can't use it. Build the art index again." (The design system's rule for the summary: a state word first, one sentence, then what you can do. The ruling's example, "Out of date: built with other settings. Rebuild.", is the shape.)
- **Facts:** "Finished", "Index file" (the name), "Built with settings" (the build's digest), "Current settings" (the instance's digest), then "Artworks indexed", "Without an image" and "Failed images" as for "Ready.".
- **Button:** "Build art index", enabled whenever nothing is in flight. No meter, no Failed-list link, no polling.
- With catalog drift as well, this state shows and says nothing of the catalog: one build fixes both.

### 3. Catalog drift is a fact under "Ready."

State `:ready` and summary "Ready." as before; one more fact after the counts, "Warning": "Built from catalog <built version>; the latest refresh is <latest version>. Cards added since may be missing from it. Build the art index again." The label is the word that carries the status (the design system's rule), and a long value wraps as "Technical detail" does. The button is enabled as for any finished build.

### 4. What the status line says

- Settings drift: `Art matching: out of date (built with settings <digest>, current <digest>); the scanner reads text only. Press Build art index on the admin catalog page to build it again. <N> artworks indexed, <N> without an image, <N> failed images; index <name>`. Never contains "ready".
- Catalog drift: the ready line as it is, then ` Warning: built from catalog <built>, the latest refresh is <latest>; press Build art index on the admin catalog page to build it again.`
- The check is made in the finished branch, after missing; every other line is as it was. No script reads the art line (spec 039 decision 3); its readers are specs.

### 5. Where the comparison lives

`MTG::ArtBuild#settings_drift?` and `#catalog_drift(latest_version)`-style readers on the build, with the latest applied version read once per render or run and passed in, so the panel and the line share one statement of each test (as `#left_behind?` is shared). No collectible-agnostic core code changes.

### 6. Recovery is the build that exists

No change to the build. Its end-to-end behaviour for each kind is one example (Story 3).

## User Stories

### Story 1: The panel says the index is out of date

**As an** admin after a release that changed the art settings
**I want** the Art index panel to say the index is out of date and let me build it again
**So that** I'm not told art matching is ready while the scanner reads text only

- [ ] **AC-1.1** Given art matching on, an applied refresh, a finished latest build whose `settings_digest` is not the current digest and whose named file is on disk, and nothing queued When `MTG::Art::Operation` is asked Then its state is `:out_of_date` and its summary is "Out of date. Built with other settings, so the scanner can't use it. Build the art index again." (fails before the change: `:ready`, "Ready.")
- [ ] **AC-1.2** Given the same When the facts are read Then they are "Finished", "Index file", "Built with settings", "Current settings", "Artworks indexed", "Without an image" and "Failed images", in that order, with the build's digest and the instance's
- [ ] **AC-1.3** Given the same Then the operation can start (`startable?`), has no meter, no Failed-list link and doesn't poll
- [ ] **AC-1.4** Given a finished latest build at the current digest and the latest applied refresh's version, with its file on disk Then the state is `:ready`, the summary "Ready." and there is no "Warning" fact (guard)
- [ ] **AC-1.5** Given a finished latest build at the current digest whose `catalog_version` is not the latest applied refresh's `source_version`, with its file on disk When the operation is asked Then the state is `:ready`, the summary "Ready." and the last fact is "Warning" with the value of decision 3 naming both versions (fails before the change: no such fact)
- [ ] **AC-1.6** Given both drifts Then the state is `:out_of_date` and no "Warning" fact appears; given a missing file and a drifted build Then the state is `:index_missing` (spec 039's, first)
- [ ] **AC-1.7** Given a finished build with no `settings_digest`, or with no `catalog_version`, or an applied refresh whose latest has no `source_version` (each its own example) Then that comparison isn't made: `:ready` with no "Warning" fact for the first and the others' catalog side, and no `:out_of_date` for a blank digest
- [ ] **AC-1.8** Given a drifted finished build and a build job queued, or a build running, or a failed latest build Then the state is `:queued`, the running state or `:failed`, worded as before (decision 1)
- [ ] **AC-1.9** Given art matching off Then the section reads "off" as before and no comparison is made
- [ ] **AC-1.10** Given `/admin/catalog` rendered for an admin in each of the two drifted states Then the Art index section shows the summary, the facts (the "Warning" fact for the catalog case) and an enabled "Build art index" button, and the page doesn't poll (request spec); a member still gets 404

### Story 2: `catalog:status` says so too

- [ ] **AC-2.1** Given art matching on and a finished latest build with another settings digest and its file on disk When `MTG::Art.status_line` is called Then it starts "Art matching: out of date", names both digests, says the scanner reads text only and to press **Build art index** on the admin catalog page, shows the counts and the index name, and doesn't contain "ready" (fails before the change)
- [ ] **AC-2.2** Given a catalog-drifted build at the current settings Then the line is the ready line followed by " Warning: built from catalog …" naming both versions and the button (fails before the change)
- [ ] **AC-2.3** Given a build with neither drift, a running, stalled, interrupted or failed build, a missing file, art matching off, or no build Then each line is as it was (guard)

### Story 3: Building again clears it

- [ ] **AC-3.1** Given the out of date state and an admin When they press **Build art index** Then one `MTG::Art::BuildJob` is queued, as for any start (request spec; the controller is unchanged)
- [ ] **AC-3.2** Given ImageMagick present (tag `:art_matching`), an applied refresh with a version, artworks fingerprinted at another digest, their images in the art cache, every HTTP request blocked, and a finished latest build recorded at that digest When `MTG::Art::Build` runs Then it finishes without an image request, the new file for the current digest exists, and the panel's state is `:ready` with no "Warning" fact and the line reads "ready"
- [ ] **AC-3.3** Given a finished latest build for an older catalog version, every artwork fingerprinted at the current settings and an applied refresh at a newer version, with every HTTP request blocked When `MTG::Art::Build` runs Then it finishes, and the panel reads `:ready` with no "Warning" fact

### Story 4: What the scanner does with each kind is pinned

- [ ] **AC-4.1** Given art matching on, a finished build and file at another settings digest (the file written with the digest stubbed, or its header patched as `spec/system/scanner_art_spec.rb` does, since `MTG::Art::Index.write!` always writes the current one) When `MTG::Art.page_config` is read and the file fetched from the scanner art route Then the page is offered it (present), it is served with 200, and its header digest is not the page config's digest (the Problem Statement's first row; the browser's refusal is the existing system example, spec 011 AC-5.2)
- [ ] **AC-4.2** Given art matching on, a finished build and file for an older catalog version at the current digest Then the page is offered it, it is served with 200 and its header digest is the page config's (the second row)

### Story 5: The documents say so

- [ ] **AC-5.1** `docs/architecture/catalog-operations.md`: the art index panel table gains the "Out of date" row and the "Ready." row's warning fact with their sources; the status-line paragraph words both lines; the Glossary's "Ready (art index)" entry says what ready is judged by now (a finished build whose file is on the volume and which was built at the current settings, with the catalog version carried as a warning) instead of "judged by its name only"; the accepted limit "a damaged file, or one built for older settings or an older catalog version, still reads Ready." is reworded to the damaged file only; Sources gets #176 and this spec (verified by reading)
- [ ] **AC-5.2** `docs/architecture/scanner.md`: the open-issues line for #176 is removed or reworded as fixed and #176 is added to Sources; the page-side rules (the digest paragraph and the art-status table's mismatch row: a digest that isn't the page's is refused, an older catalog's index is used) say that the admin page shows the first as out of date and the second as a warning, with the source (verified by reading)
- [ ] **AC-5.3** The specs index has the 053 row and records the supersession in the Supersedes and Superseded-by columns of the rows it names (039, 015, 011), as this spec's Supersedes section does; no shipped spec is edited (verified by reading; both were written with this spec and are checked unchanged at distillation, the status word moving from Draft as the spec progresses)

## Functional Requirements

- **FR-1** `MTG::ArtBuild` answers whether its settings differ from the current digest and whether its catalog version differs from a given latest version (decisions 1 and 5); blank on either side is "not judged".
- **FR-2** `MTG::Art::Operation#state` returns `:out_of_date` after `:index_missing` and before `:ready`, with decision 2's summary and facts; `:ready` carries decision 3's fact.
- **FR-3** `MTG::Art.status_line` words both as decision 4 does.
- **FR-4** `Catalog::Operation`, the admin controllers and views, `AdminHelper`, the scanner and its JavaScript, the build, the CSS and the design-system components change not at all: the panel renders an operation's summary and facts generically (`spec/admin_catalog_core_spec.rb`).

## Non-Functional Requirements

- **Data.** No migration, no new column, no stored data; the export format and the backup are untouched.
- **Cost.** One more query per panel render and per `catalog:status` run, for the latest applied refresh's version, only in the finished branch (the panel's `catalog_loaded?` is an `exists?` already; the plan may fold the two into one read); no network, no file read.
- **Tenancy.** The catalog and its index are global; the admin pages answer 404 to a member as before.
- **UI.** Summary and fact labels are admin page copy, worded under the `collector-design-system` skill: sentence case, "you", no emoji, a state word first, numbers exact. No new component, class or token.
- **Testability.** The existing "Ready." examples (`operation_spec.rb`, `art_spec.rb`, `admin/catalogs_spec.rb`) build finished builds at the current digest, and their applied refresh has no `source_version`, so they stay "Ready." with no warning (AC-1.7); the plan checks each. A drifted fixture takes a build row at another `settings_digest` or `catalog_version` and, for settings drift, a file whose header digest is another (stub the digest while writing, or patch the header bytes).

## Error Scenarios

| Condition | Behaviour |
|---|---|
| A build row with no settings digest or catalog version | Not judged (AC-1.7) |
| The latest applied refresh has no `source_version` (or none is applied) | Catalog drift isn't judged; with none applied the panel is `:never` or off as before |
| Settings drift and the file is missing | Missing (spec 039); the rebuild writes a file at the current digest |
| A newer refresh applies while the page is open | The next render shows the warning; nothing is cached |
| A build for the current settings fails after drifted ones | The latest build is `failed`, which reads as before; the drifted file is still "Index in use" (Non-Goal) |

## Supersedes

- **Spec 039 Non-Goals, settings drift (the Non-Goal's "a follow-up issue records it" is this issue):** a finished build whose settings digest differs, or whose catalog version is no longer the latest, no longer reads plain "Ready.". Spec 039 decision 1 and the file test stand.
- **Spec 015 AC-4.1, in part (again):** the art index states gain "out of date", and "ready" can carry a warning fact.
- **Spec 011 AC-3.11, in part (again):** the art line says "ready" plainly only for a build at the current settings and catalog; the other lines are decision 4's.

## Interactions

- **Upgrade seeds.** `script/upgrade/seeds/*.rb` seed a build with `settings_digest: "upgrade-seed"` and a file name that doesn't match `Index::NAME`; such an instance reads "missing" first (spec 039), so nothing changes there.

## Open Questions

None.

## Out of Scope

A rebuild queued by a settings change, a change to the scanner or its message, the "Index in use" fact, a damaged file, and an art-only rake task.
