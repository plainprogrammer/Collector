# Feature 092: Rename the Application to Wyrm's Hoard

**Status:** Draft
**Version:** 0.3.0
**Created:** 2026-11-14
**Last Updated:** 2026-11-14
**Depends on:** nothing unshipped. It changes names fixed by shipped specs; they are listed under [Supersedes](#supersedes).
**Branch:** `092-rename-to-wyrms-hoard` (the documents); each pull request of decision 1 has its own branch
**Issues:** [#433](https://github.com/plainprogrammer/Collector/issues/433) (tracking), [#434](https://github.com/plainprogrammer/Collector/issues/434) to [#440](https://github.com/plainprogrammer/Collector/issues/440), [#445](https://github.com/plainprogrammer/Collector/issues/445) (the 1.0 milestone, housekeeping lane)
**PRD:** [prd.md](prd.md) (approved by the maintainer, 2026-11-14, after five read-only reviews)
**ADRs:** [0032](../../adr/0032-the-rename-is-a-clean-break.md) (the rename is a clean break), [0033](../../adr/0033-the-image-moves-to-a-new-package.md) (the image moves to a new package); both Accepted 2026-11-14

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.3.0 | 2026-11-14 | Spec review round 2 (Fable, read-only, APPROVE WITH CHANGES, 0 blocking, 6 major, 11 minor) fixed. Decision 17 says it replaces the PRD's and ADR 0032's "copy the volume", and the notes say what a backup doesn't carry and how to recover from a start on the empty volume; decision 14 rules the four-link header; decision 10's rule passes `MimeResponds::Collector` and AC-7.3 says which kinds pass by exclusion; decision 15 keeps dated entries; decision 18 says when the spec is shipped; each pull request fills its own index cells; the brand app bar, the Kamal order, the hosted-door line and the minor findings |
| 0.2.0 | 2026-11-14 | Spec review round 1 (Opus, read-only, APPROVE WITH CHANGES, 0 blocking, 9 major, 14 minor) fixed. AC-1.4 allows the ratchet's comments to change; AC-2.1 and AC-2.2 say what pull request B searches and removes; a person's name in an example and the two `MimeResponds` comments are settled (decisions 10 and 11, FR-2); decision 14 measures the header at 720px and 640px, where the wordmark shows; the User-Agents take the hyphenated spelling (decision 9, AC-6.10); AC-5.7 drops the `0` tag; decision 15 rules on issue links and quoted titles; the upgrade notes move the data by backup and restore (decision 17, AC-8.2); and the minor findings |
| 0.1.0 | 2026-11-14 | First draft from the approved PRD and ADRs 0032 and 0033, with two inventories taken on `main` at `50435ba3`: the forms of the old name in code and configuration, and the criteria of shipped specs the rename supersedes. Decisions 1 to 6 are the maintainer's, from the brainstorm; decisions 7 to 18 are the author's, each marked *(author's)*, for the maintainer to rule |

## Problem Statement

The application is called Collector, its repository `plainprogrammer/Collector` and its image `ghcr.io/plainprogrammer/collector`. The maintainer has decided the name is Wyrm's Hoard and the repository `wyrmshoard`. The old name is in the interface, the code's module and directories, every operator setting and command, the deployment files, the image's name and the documentation: 2,080 lines of code and configuration hold the word in some form, and more than half of those are not the application's name at all (a card's collector line, or the person who uses the application). The change has to tell the two apart, and has to land in an order that leaves the repository, CI and the published image working at every step.

> **Terms.** *The old name*: the application's name in any of the forms of [decision 9](#decisions). *The person*: a collector, the documentation's and the interface's word for someone who uses the application; it stays. *The collector line*: the printed line on a card that carries its number, and what the scanner reads of it (`collector_number`, `collector_text` and their kin); it stays. *Living document*: one that states what is true now, and so takes the new name. *Record*: a document that states what was decided or done at a time (a shipped spec, an accepted ADR, a lesson, a design record), and so keeps the old one. *The check*: the suite's guard against the old name (FR-9). *The upgrade proof*: `bin/upgrade-smoke` (spec 031). *The ratchet*: `bin/ci checks`' step that requires a summary comment on public code a branch adds or changes (spec 056).

## Goals

- The application calls itself Wyrm's Hoard wherever it names itself to a person.
- The code's own names, the operator's settings, command, volume and service, and the image follow, each in the one spelling its context has (ADR 0032 decision 2).
- No old operator name keeps working (ADR 0032 decision 1), and no data made before the rename stops being readable (ADR 0032 decisions 4 and 5).
- The image is published at `ghcr.io/plainprogrammer/wyrmshoard` from release 0.4.0, and the old package is left as it is (ADR 0033).
- The upgrade from 0.3.0 is proven by the upgrade proof and described by upgrade notes an operator can follow without reading the code.
- The living documents use the new name, and the shipped criteria the rename changes are recorded as superseded, both directions.
- The old name can't return to the code unnoticed.
- Every step leaves `main` green and can be checked before the next.

## Non-Goals

- **No compatibility with the old operator names:** no alias, fallback or deprecation notice for a `COLLECTOR_*` variable, the old volume, the old service or the old command.
- **No change to the person or the collector line** (decision 10), and none to the `c-` prefix of the design system's classes.
- **No new export format version** and no change to the export identifier `collector-export`, the schemas' ids `urn:collector:export-format:vN` or the download's file name `collector-export-<date>.json`.
- **No edit to a released migration.** `db/migrate/20261103100002_set_account_currency_from_the_instance.rb` keeps reading `COLLECTOR_CURRENCY` (ADR 0032 decision 7).
- **No edit to a record:** a shipped spec or its contracts, an accepted ADR, a file under `docs/lessons/` or `docs/superpowers/`.
- **No copy, rebuild, retag or deletion of a published image.**
- **No change under `spikes/`.** The suite reads one spike file as data (`spikes/card_scanner/phase2/settings.json`) and loads no spike code.
- **No drawn wordmark and no new mark.**
- **No change of behaviour beyond names:** no feature, no schema change, no migration.

## Users and Context

**Primary users:** the maintainer, who is the only operator of an instance (it runs 0.3.0), renames the repository, checks the new package and upgrades that instance.
**Secondary users:** a collector, who sees the new name and whose collection, exports and backups are unaffected; a contributor or an agent, who reads the code's names and the living documents.
**Usage context:** four pull requests on a renamed repository, then a release. The operator meets the rename once, in the upgrade notes of 0.4.0.
**User mental model:** "Wyrm's Hoard" is what the application is called; "a collector" is still who uses it.

## Decisions

Decisions 1 to 6 are the maintainer's (the brainstorm of 2026-11-14, the PRD and the ADRs). Decisions 7 to 18 are the author's, to be ruled with this spec.

1. **The order of work.** Each step is checked before the next.
   1. The repository is renamed to `plainprogrammer/wyrmshoard` ([#435](https://github.com/plainprogrammer/Collector/issues/435)). CI still publishes to the old image.
   2. **Pull request A** ([#445](https://github.com/plainprogrammer/Collector/issues/445)): the missing summary comments, under the old name (FR-1).
   3. **Pull request B** ([#436](https://github.com/plainprogrammer/Collector/issues/436)): the internal names (FR-2).
   4. **Pull request C** ([#437](https://github.com/plainprogrammer/Collector/issues/437)): the operator contract, the image's name, the data made before the rename and the upgrade proof (FR-3 to FR-6), with the documents that describe them.
   5. **Pull request D** ([#438](https://github.com/plainprogrammer/Collector/issues/438)): the display name, the repository's links, the rest of the living documents, the check and the supersessions (FR-7 to FR-11).
   Between pull requests C and D the new package's `edge` is an image that still calls itself Collector in its pages; that is accepted, as `edge` is not a release.
   6. The new package is checked to be public ([#439](https://github.com/plainprogrammer/Collector/issues/439)), release 0.4.0 is tagged and the maintainer's instance is upgraded by the notes ([#440](https://github.com/plainprogrammer/Collector/issues/440)).
2. **The spellings** (ADR 0032 decision 2): `Wyrm's Hoard` for display, with a straight apostrophe as the interface's other copy has; `WyrmsHoard` for Ruby constants; `wyrms_hoard` for file and directory names, Ruby identifiers, the rake namespace and the volume; `WYRMS_HOARD_` for environment variables and build arguments; `wyrms-hoard` for hyphenated names; `wyrmshoard` for the repository and the image, and nothing else. No inflection rule is added.
3. **A clean break** (ADR 0032 decision 1). No old operator name is read.
4. **The export identifier stays** (ADR 0032 decision 4).
5. **New releases only in the new package; the old one is frozen** (ADR 0033).
6. **The wordmark is live text for now**, shown beside the mark; the mark keeps its drawing.
7. *(author's)* **Each pull request carries the documents of what it changes** (`.claude/rules/documentation.md`; `README.md` stays in step with the deployment files). So pull request B changes the path references in the living documents, C the operator's documents and the upgrade notes, and D the rest.
8. *(author's)* **The operator's settings are these twelve; the developer's are these seven.** Each keeps its suffix.

   | Kind | Old name | New name |
   |---|---|---|
   | Operator | `COLLECTOR_CURRENCY` | `WYRMS_HOARD_CURRENCY` |
   | Operator | `COLLECTOR_HTTPS` | `WYRMS_HOARD_HTTPS` |
   | Operator | `COLLECTOR_MTG_LANGUAGES` | `WYRMS_HOARD_MTG_LANGUAGES` |
   | Operator | `COLLECTOR_MTG_ART_MATCHING` | `WYRMS_HOARD_MTG_ART_MATCHING` |
   | Operator | `COLLECTOR_PUBLIC_CATALOG` | `WYRMS_HOARD_PUBLIC_CATALOG` |
   | Operator | `COLLECTOR_TRUSTED_PROXIES` | `WYRMS_HOARD_TRUSTED_PROXIES` |
   | Operator | `COLLECTOR_PASSWORD` (the user command's) | `WYRMS_HOARD_PASSWORD` |
   | Operator, Compose only | `COLLECTOR_IMAGE` | `WYRMS_HOARD_IMAGE` |
   | Operator, Compose only | `COLLECTOR_PORT` | `WYRMS_HOARD_PORT` |
   | Build fact | `COLLECTOR_VERSION` | `WYRMS_HOARD_VERSION` |
   | Build fact | `COLLECTOR_REVISION` | `WYRMS_HOARD_REVISION` |
   | Build fact | `COLLECTOR_SOURCE_URL` | `WYRMS_HOARD_SOURCE_URL` |
   | Developer | `COLLECTOR_ART_AGREEMENT`, `COLLECTOR_MISE_SEARCH`, `COLLECTOR_DEV_CERT_DIR`, `COLLECTOR_REQUEST_LOG`, `COLLECTOR_SCANNER_MANIFEST`, `COLLECTOR_SCANNER_RUN_DIR`, `COLLECTOR_SCANNER_KEEP_FRAMES` | the same with `WYRMS_HOARD_` |

   The upgrade notes list the first nine; a build fact is set by whoever builds an image. `COLLECTOR_HOSTED` exists only in a design record and is not part of this.
9. *(author's)* **The old name's forms**, which the rename removes and the check matches. Counts are lines on `main` at `50435ba3`, in the directories the check reads.

   | Form | Lines | Renamed by |
   |---|---|---|
   | `module Collector`, `Collector::`, `::Collector::` | 267 | B |
   | Paths and requires under `lib/collector/`, `spec/lib/collector/`; the autoload ignore list's `collector/…` entries | 85 | B |
   | Asset paths under `app/assets/{stylesheets,fonts,images}/collector/`; `"collector/tokens"`, `url("/collector/…")`, the manifest keys `collector/….woff2` | 36 | B |
   | `lib/tasks/collector.rake`, `spec/tasks/collector_rake_spec.rb` and mentions of them | 4 | B |
   | `_collector_session` | 1 | B |
   | `/*application='Collector'*/` in the prices structure file and its spec | 6 | B |
   | `namespace :collector`, `collector:user` | 10 | C |
   | `COLLECTOR_` | 141 | C |
   | `collector_storage` | 5 | C |
   | `service: collector`, `collector-db` | 2 | C |
   | `/srv/collector-backups` | 3 | C |
   | `collector-backup-` | 39 | C (decision 12 keeps some) |
   | `collector-restore.partial`, `collector-restore-prices.partial` | 8 | C (decision 12 keeps some) |
   | Image tags `collector:smoke`, `collector:local`; `--name collector`. They become `wyrms-hoard:smoke`, `wyrms-hoard:local` and `--name wyrms-hoard`: a local tag is a name of the developer's, not the published image, so it is hyphenated | 13 | C |
   | `collector-smoke-`, `collector-backup-smoke-`, `collector-measure`, `collector-backup-spec` | 7 | C |
   | `collector-dev-https`, `collector-dev.crt`, `CN=Collector dev` | 7 | C |
   | `plainprogrammer/collector` as an image or a package (`ghcr.io/…`, `image:`, `packages/container/collector`, the pull token's scope) | 17 | C (decision 13 keeps some) |
   | `https://github.com/plainprogrammer/Collector` | 19 | D |
   | `collector.git` and checkout paths in fixtures (`/home/a/Collector/wt-1`, `/srv/orca/Collector/feature`, `/no/such/place/for/collector`) | 6 | D |
   | `collector-mark`, `collector-wordmark` | 5 and 4 file names | D |
   | User-Agents: `Collector/1.0 (+…)` (and the spec's `%r{\ACollector/}`), `collector-ghcr-cleanup (+…)`, `Collector OCR engine fetch`. They become `wyrms-hoard/1.0 (+https://github.com/plainprogrammer/wyrmshoard)`, `wyrms-hoard-ghcr-cleanup (+…)` and `wyrms-hoard OCR engine fetch`: a User-Agent's product is one token, so it is hyphenated (ADR 0032 decision 2) | 5 | D |
   | `Collector` as a capitalised whole word, in a string, a view or a comment, that isn't one of decision 10's | about 190 | D |

   The last row covers the title suffix `· Collector` (56 lines), the name alone (`"Collector"`, `alt`, `aria-label`, `content`, `--title`), "Collector home", "Collector search", the licence line's "Collector 0.3.0 (…)", the notice "Collector is unofficial Fan Content…", "Collector is free software", "Collector export" in messages and the schemas' titles and descriptions, the backup's, restore's and start check's messages, "Set up Collector", "Collector needs at least one admin.", "Collector can't show prices in …", "a newer version of Collector", and prose in comments.
10. *(author's)* **What is not the old name, and stays.**
    - **The collector line:** `collector_number`, `collector_text`, `collector_line`, `collector_line_corrected`, `collector_confidence`, `collector_strip`, `collector_status`, `collector_match`, `collector_entries`, `collectorText`, `collector-line`, `MTG::CollectorLine`, `MTG::CollectorNumber` and their files; the strip's key `collector` (`STRIPS.collector`, `text.collector`, `collector.png`, `%w[name collector]`); "collector number", "collector line" and "collector strip" in any case, plural or not.
    - **The person:** "a collector" and its kin in prose; `collector?`; a variable, a factory or a value named for a person (`let(:collector)`, `sign_in_as(collector)`, `"collector#{n}@example.test"`); a person's name in a factory or an example, `"Collector #{n}"` or `"Collector #{i}"`.
    - **Others' names:** Rails' `ActionController::MimeResponds::Collector`; a card set's name ("… Commander Collector Showcase Extras").
    - **The export identifier:** `collector-export`, `urn:collector:`.

    In code and configuration no capitalised `Collector` is the person at the start of a sentence, so the rule is: a capitalised whole word `Collector` is the old name unless the next word is `number`, `numbers`, `line`, `lines` or `strip`, or it is preceded by `MimeResponds::`, or the line is one of the excluded places of decision 11. A person's name (`"Collector #{n}"`) and the card set's name have the same shape as the old name (`"Collector #{version}"`), so they pass as exclusions of decision 11, not by this rule. "Whole word" is judged so that `\ACollector/` in a pattern still counts as the name. Rails' `MimeResponds::Collector` is named today only by two comments that explain why the code writes `::Collector::`; pull request B removes them with the need for them (FR-2), so it is a kind the check must pass, not a place it excludes.
11. *(author's)* **The check's exclusions**, each written in the check with its reason:
    - `db/migrate/` (released migrations) and `spec/migrations/set_account_currency_from_the_instance_spec.rb`;
    - `spikes/`;
    - the upgrade proof's rules for a previous release of 0.3.0 or earlier, and the specs and fakes of those rules (decision 13);
    - the old backup and restore prefixes where decision 12 keeps them;
    - the two lines that name a person `"Collector #{n}"` or `"Collector #{i}"` (`spec/factories/accounts.rb`, `spec/migrations/backfill_households_spec.rb`) and the line that names the card set;
    - the check's own file and spec, and the examples that prove an old name is gone (FR-3's proofs that `collector:user` is no task and that no `COLLECTOR_*` setting is read).

    The check reads `app/`, `bin/`, `config/`, `db/`, `lib/`, `public/`, `script/`, `spec/`, `.github/`, `.githooks/`, `.claude/hooks/` and these root files: `.dockerignore`, `.rubocop.yml`, `.yardopts`, `.worktreeinclude`, `Dockerfile`, `compose.yaml`, `orca.yaml`, `Gemfile`, `Gemfile.lock`, `Rakefile`, `config.ru`. It judges every tracked file's path, a trailing `…/collector` with no slash included, and the contents of every file that is text; a binary file is judged by its path only. It does not read documents (decision 15).
12. *(author's)* **Old backup and restore names where old data is read.** New backups are `wyrms-hoard-backup-<time>.tar.gz`, and the restore's temporary files are `wyrms-hoard-restore.partial` and `wyrms-hoard-restore-prices.partial`. `backup:create`'s sweep of stale partial files, and the restore's removal of a stopped run's temporary files, match both the old and the new prefix, so what an interrupted run of 0.3.0 left is still cleaned up. Restore never judged a backup by its name's prefix and still doesn't; an example proves a backup named `collector-backup-<time>.tar.gz` restores.
13. *(author's)* **The upgrade proof across the rename** (ADR 0033 decision 4). It pulls a previous release of 0.3.0 or earlier from `ghcr.io/plainprogrammer/collector` and a later one from `ghcr.io/plainprogrammer/wyrmshoard`; the `UPGRADE_IMAGE_REPOSITORY` override still wins. When it takes a backup on the previous build it accepts either backup prefix in that build's output, so a previous build given by ref, which has no version, needs no rule of its own.
14. *(author's)* **The text wordmark keeps the app bar's rules, re-measured.** It is shown where the wordmark SVGs were, beside the mark, in the design system's display type and colours for each theme, in the signed-in app bar and in the brand app bar of the sign-in, first-run and licences pages. Below 640px the app bar already shows the mark alone, so the text is never on screen there. Spec 057 decision 19 put the swap between the wordmark and the mark at 720px for a header of five links, from a wordmark 138px wide: the first width at which the links and the wordmark fit, plus 25px. The mark with the text is measured, and:
    - the five-link swap point is set by the same rule from the new width; it moves only if the measurement moves it;
    - a header of four links (which the real header never has; spec 057 AC-1.6 keeps it as a guard) is measured at 640px. If the text fits, the swap stays conditional on five links as it is; if it doesn't, the swap applies whatever the number of links, and spec 057 AC-1.6 is superseded in full;
    - 320px and 360px stay as a guard that nothing overflows.

    The measurements and the outcome are recorded in `verification.md`, and AC-6.3 is asserted against them.
15. *(author's)* **Living documents and records.**
    - **Living, renamed:** `README.md`, `CLAUDE.md`, `docs/architecture/`, `docs/design-system/`, `docs/roadmap.md`, `docs/north-star.md`, `docs/releasing.md`, `docs/backup-restore.md`, `docs/git-convention.md`, the prose of `docs/export-format/`, the READMEs of `docs/adr/` and `docs/specs/`, `.claude/CLAUDE.md`, `.claude/rules/`, `.claude/integrations.md`, `.claude/memory/foundation.md` and `.claude/memory/steering/`, the design system's skill (its directory becomes `wyrms-hoard-design-system`), and a memory file where it states a current name or command.
    - **Records, kept:** shipped specs and their contracts, accepted ADRs, `docs/lessons/`, `docs/superpowers/`, and what a memory file says happened.
    - A living document may still name an old form where it describes the rename or what stays: the upgrade notes, the two-package rule, the sweep of both prefixes, the released migration.
    - **A dated entry keeps the names of its time:** the upgrade notes of releases up to 0.3.0 in `docs/releasing.md` (which tell an instance older than 0.3.0 to set `COLLECTOR_CURRENCY`, still true by ADR 0032 decision 7), and a dated row of a decision log such as the roadmap's.
    - `docs/screenshots/` holds records of how pages looked and is left; `.kamal/` is not read by the check or by an agent (`.kamal/secrets` is off-limits), so the maintainer confirms by eye that it names no old image or setting.
    - **Links to issues, pull requests and commits stay as written** (345 in the living documents, `https://github.com/plainprogrammer/Collector/…`): GitHub redirects them, and they cite a place, they don't name the application. A link to the repository's front page or its source is rewritten.
    - **A record's title quoted in an index stays** as the record has it ("012 Build and Publish Collector Images").
    - **Memory files:** the plan lists, from a search, each file under `.claude/memory/` that states a current name, path, command or image, and those statements are brought up to date; the rest of each file is left.
    - Documents are verified by reading, recorded in `verification.md` (`.claude/rules/testing.md`).
16. *(author's)* **A shipped spec that only mentions an internal name is not superseded.** 44 shipped specs name `Collector::…`, `lib/collector/…`, an asset path or the design system's skill as the place something lives. Those are pointers of their time, and the area docs hold the current paths. A criterion is superseded when it fixes a value a person or an operator meets: a setting, a command, a file name, an image, a message, a title or a label. The [Supersedes](#supersedes) table lists those.

17. *(author's)* **The upgrade moves the data by backup and restore, not by copying a volume.** This replaces the wording of PRD goal 7 ("how to copy the volume") and of ADR 0032's Cost consequence ("copy the volume"); ADR 0032's decision 1 asks only that the notes "say how to move the data", which this meets, and the accepted ADR is not edited. The notes tell an operator, in order: take a backup on 0.3.0 with `backup:create` once nothing is writing (or accept that later writes are lost); stop the old service, under Kamal with the old configuration, before `service` changes; restore the backup onto the new, empty volume with `backup:restore` from the new image; start the new service. This is the path the upgrade proof runs (AC-5.2, AC-5.4): 0.3.0 writes a backup of the primary database, the new release restores it, and its first start creates an empty prices database. A copy of a volume whose database is in use can be inconsistent, and a Compose volume's real name carries the project's prefix. The notes also say what a backup doesn't carry, which a volume copy would have kept: everyone signs in again; pending Undos and bulk selections are gone; queued jobs and a previewed import are not carried; catalog downloads are fetched again at the next refresh; and the art index is rebuilt from Admin where art matching is on. The old volume is left untouched until the operator removes it.
18. *(author's)* **The spec is shipped when pull request D merges.** Its implementation review is taken then, over pull requests A to D. AC-5.6 to AC-5.8 (the package is public, release 0.4.0, the maintainer's instance) are steps of the release, checked by hand; `verification.md` lists them as owed at the review and records their evidence when [#439](https://github.com/plainprogrammer/Collector/issues/439) and [#440](https://github.com/plainprogrammer/Collector/issues/440) close. The other criteria checked by hand (AC-5.1, AC-5.5, AC-8.6) are recorded there too, with the command and its output.

**Hosted door** (`docs/north-star.md`): the rename adds no setting, renames the existing ones, and has no per-account cost or limit; it neither opens nor closes anything for a hosted service.

## User Stories

### Story 1: The comments the rename needs are written first (pull request A)

**As a** maintainer reviewing the rename
**I want** the missing summary comments written before any name changes
**So that** the rename's pull request is mechanical and the ratchet passes it unchanged

**Acceptance criteria:**

- [ ] **AC-1.1** Given `main` before pull request A When the ratchet's judgement is run over every public object under `lib/collector/` as though each were added Then pull request A's branch reports none without a summary (94 lack one on `main` at `50435ba3`).
- [ ] **AC-1.2** Given the four objects outside `lib/collector/` whose text names the module or an old form (`ScannersHelper#ocr_engine_path`; `BackupHelpers#release_versions`, `#restore_backup` and `#scratch_root`) When pull request A is merged Then each has a summary comment.
- [ ] **AC-1.3** Given pull request A's diff When it is read Then it changes comments only: no line of code, no name, and `bin/ci` passes.
- [ ] **AC-1.4** Given pull request B's branch, made after A merges When `bin/ci checks` runs Then the step "Docs: new and changed public code has a comment" passes, as it does on pull request C's and D's branches, with no change to the ratchet's rules or scope; a comment in `script/yard/comment_ratchet.rb` that names the module changes with it.

### Story 2: The code's own names say Wyrm's Hoard (pull request B)

**As a** contributor or an agent
**I want** the module, the directories and the asset paths to carry the new name
**So that** the code I read matches what the application is called

**Acceptance criteria:**

- [ ] **AC-2.1** Given pull request B is merged When the check's directories (decision 11) and the living documents (decision 15) are searched Then no file holds `module Collector`, `Collector::` or `::Collector::` outside decision 11's exclusions, and the application's module is `WyrmsHoard`.
- [ ] **AC-2.2** Given pull request B is merged When the tree is listed Then `lib/wyrms_hoard/`, `spec/lib/wyrms_hoard/`, `lib/tasks/wyrms_hoard.rake`, `spec/tasks/wyrms_hoard_rake_spec.rb` and `app/assets/{stylesheets,fonts,images}/wyrms_hoard/` exist, and none of `lib/collector/`, `spec/lib/collector/`, `lib/tasks/collector.rake`, `spec/tasks/collector_rake_spec.rb` or an asset directory named `collector/` does. The four logo files keep their names (`collector-mark….svg`, `collector-wordmark….svg`) until pull request D.
- [ ] **AC-2.3** Given a page of the running application after pull request B When it loads Then its stylesheets, its fonts and its logo images load from the renamed paths with no failed request, and the third-party licences page lists the same fonts as before.
- [ ] **AC-2.4** Given pull request B is merged When `bin/rails "collector:user[EMAIL]"` is run Then it still works: the rake file is renamed, the namespace is not.
- [ ] **AC-2.5** Given pull request B's branch When `bin/ci` runs Then every step passes, among them Zeitwerk's check, RuboCop, the YARD build, the ratchet, Brakeman with a regenerated ignore file that ignores what it ignored before and nothing more; and CI's image job passes its smoke tests.
- [ ] **AC-2.6** Given the image built from pull request B When `bin/image-smoke` runs Then the development files it guards against are absent under their new paths (`lib/wyrms_hoard/ghcr_cleanup.rb`, `lib/wyrms_hoard/ci_groups.rb`, `lib/wyrms_hoard/ci_shard.rb`, `lib/wyrms_hoard/push_scope.rb`), and `.dockerignore` names those paths.
- [ ] **AC-2.7** Given a signed-in collector with a session from before pull request B When they load a page after it Then they are still signed in; a form they had open before it is refused once as stale and works after a reload.
- [ ] **AC-2.8** Given pull request B is merged When the design system's preview pages under `docs/design-system/previews/` are opened from the checkout Then each loads its stylesheets from the renamed directory, and the design system's skill and documents name the renamed paths.
- [ ] **AC-2.9** Given pull request B is merged When a plain `git push` of a documentation-only branch is made Then the pre-push hook runs, having loaded the push-scope rules from their renamed path.
- [ ] **AC-2.10** Given pull request B is merged When `db/prices_structure.sql` is read Then it holds no `application='Collector'`, and loading it gives the schema it gave before.
- [ ] **AC-2.11** Given pull request B is merged When the shards' run-time log is read Then every path in it exists.
- [ ] **AC-2.12** Given pull request B is merged When an operator's or a collector's view of the application is compared with the build before it Then every setting, command, message, title and file an operator writes or reads is as it was. What differs is AC-2.7, the assets' URLs, and the console's prompt, which shows the application's name.
- [ ] **AC-2.13** Given pull request B is merged When the design system's skill is listed Then its directory and name are `wyrms-hoard-design-system`, and `CLAUDE.md` points to it.

### Story 3: An operator runs Wyrm's Hoard with its own settings (pull request C)

**As an** operator
**I want** every setting, the command, the volume, the service and the backup's name to carry the new name
**So that** what I configure matches the application I run

**Acceptance criteria:**

- [ ] **AC-3.1** Given an instance started with each operator setting of decision 8 under its new name When it runs Then it behaves as the build before the rename did with the old names: the currency of a new account, the extra languages, art matching, the open catalog, HTTPS and the trusted proxies each take effect.
- [ ] **AC-3.2** Given an instance started with a `COLLECTOR_*` setting and no `WYRMS_HOARD_*` one When it runs Then the setting has no effect and the default applies, with no warning.
- [ ] **AC-3.3** Given the application's code outside decision 11's exclusions When it is searched Then no line reads an environment variable whose name begins `COLLECTOR_`.
- [ ] **AC-3.4** Given a running instance When `bin/rails "wyrms_hoard:user[EMAIL]"` is run with `WYRMS_HOARD_PASSWORD` Then it does what `collector:user` did; and `bin/rails "collector:user[EMAIL]"` fails as an unknown task.
- [ ] **AC-3.5** Given `compose.yaml` When it is read Then its image default is `ghcr.io/plainprogrammer/wyrmshoard:latest` under `WYRMS_HOARD_IMAGE`, its port is `WYRMS_HOARD_PORT`, it passes the six pass-through settings under their new names, and its volume is `wyrms_hoard_storage`.
- [ ] **AC-3.6** Given `config/deploy.yml` When it is read Then `service` is `wyrms-hoard`, `image` is `plainprogrammer/wyrmshoard`, the volume is `wyrms_hoard_storage`, the commented settings carry their new names and the commented backup directory is `/srv/wyrms-hoard-backups`.
- [ ] **AC-3.7** Given an image built with the build arguments `WYRMS_HOARD_VERSION`, `WYRMS_HOARD_REVISION` and `WYRMS_HOARD_SOURCE_URL` When it runs Then the footer shows that version and short SHA and links that source; and `bin/image-smoke` fails an image built without them.
- [ ] **AC-3.8** Given a running instance When `backup:create[DIRECTORY]` is run Then it writes `wyrms-hoard-backup-<time>.tar.gz` and prints that name; and given a file that isn't a backup is given to `backup:restore` Then the refusal's hint names a `wyrms-hoard-backup-….tar.gz` file.
- [ ] **AC-3.9** Given a developer's checkout after pull request C When they use a developer setting of decision 8, `bin/dev-certificate`, `bin/image-smoke`, `bin/backup-smoke` or the backup measurement script Then each works under the new names: the certificate is made in a `wyrms-hoard-dev-https` directory, and the scripts' images, containers and volumes are named `wyrms-hoard…`.
- [ ] **AC-3.10** Given pull request C is merged When `README.md`'s deployment sections, the release and deploy area doc and `docs/backup-restore.md` are read Then every setting, command, volume, service, image and backup name they give is the one the deployment files and the code use on that commit.

### Story 4: What was made before the rename is still read (pull request C)

**As a** collector or an operator with files from 0.3.0
**I want** my export and my backup to work on the renamed release
**So that** the rename costs me no data

**Acceptance criteria:**

- [ ] **AC-4.1** Given a backup made by 0.3.0, named `collector-backup-<time>.tar.gz` When `backup:restore[FILE]` is run on the renamed release Then it restores as it would have on 0.3.0.
- [ ] **AC-4.2** Given a backup made by the renamed release When it is renamed to any other file name ending `.tar.gz` and restored Then it restores: no prefix is required.
- [ ] **AC-4.3** Given a backup directory holding stale partial files of an interrupted backup under the old prefix and under the new one When `backup:create` runs there Then it removes both kinds by the same age rule as before, and leaves a file that matches neither pattern.
- [ ] **AC-4.4** Given a volume holding a stopped restore's temporary file under the old name or the new one When `backup:restore` runs Then it removes it as it removed the old-named one before.
- [ ] **AC-4.5** Given an export downloaded from 0.3.0 When it is previewed and applied on the renamed release Then the preview and the result are what 0.3.0 would have given.
- [ ] **AC-4.6** Given a collector on the renamed release When they download an export Then the file is `collector-export-<date>.json`, its `format` is `collector-export`, its `format_version` is 4, and the schemas' `$id`s are unchanged.
- [ ] **AC-4.7** Given an instance on 0.3.0, which has run the currency migration When it is upgraded to the renamed release Then no account's currency changes.

### Story 5: The image is published under the new name and the upgrade is proven (pull request C, then the release)

**As a** maintainer
**I want** CI to publish to the new package and to prove the upgrade from 0.3.0
**So that** the first release of Wyrm's Hoard is one an instance can move to

**Acceptance criteria:**

- [ ] **AC-5.1** Given pull request C is merged When `main`'s CI finishes Then `ghcr.io/plainprogrammer/wyrmshoard:edge` exists for amd64 and arm64, and no tag or version of `ghcr.io/plainprogrammer/collector` was added, changed or removed by that run or any later one up to the release of 0.4.0, when the package's versions are compared with a listing taken before pull request C merged.
- [ ] **AC-5.2** Given the upgrade proof asked for the previous release automatically, with 0.3.0 the newest tag When it runs Then it pulls `ghcr.io/plainprogrammer/collector:0.3.0`, and the proof passes against a build of the renamed code.
- [ ] **AC-5.3** Given the upgrade proof asked for a previous release later than 0.3.0 When it resolves the image Then it names `ghcr.io/plainprogrammer/wyrmshoard:<version>`; and given `UPGRADE_IMAGE_REPOSITORY` is set Then that repository is used for any version.
- [ ] **AC-5.4** Given a previous build whose `backup:create` prints either backup prefix When the proof takes its backup Then the proof accepts the output and goes on.
- [ ] **AC-5.5** Given the weekly cleanup When it runs after pull request C Then it lists and deletes versions of the package `wyrmshoard` only, and reads manifests and its pull token for that package.
- [ ] **AC-5.6** Given the new package after pull request C's merge When an anonymous pull of `:edge` is tried Then it succeeds; if it doesn't, the maintainer makes the package public and the pull is tried again before any tag is pushed.
- [ ] **AC-5.7** Given tag `v0.4.0` is pushed When CI finishes Then `ghcr.io/plainprogrammer/wyrmshoard` has `0.4.0`, `0.4` and `latest` (ADR 0009: no major-only tag below 1), each pulls anonymously and passes `bin/image-smoke`, its footer's licence line begins "Wyrm's Hoard 0.4.0", and the old package's `latest` is still 0.3.0.
- [ ] **AC-5.8** Given the maintainer's instance on 0.3.0 When it is upgraded by following `docs/releasing.md`'s upgrade notes for 0.4.0 and nothing else Then it starts on the new image and shows the collection, the locations and the decks it had.

### Story 6: The application calls itself Wyrm's Hoard (pull request D)

**As a** collector
**I want** every page to use the application's name
**So that** I know what I'm using

**Acceptance criteria:**

- [ ] **AC-6.1** Given any page with a title When it loads Then the title ends `· Wyrm's Hoard` where it ended `· Collector`, and a page with no title of its own is titled `Wyrm's Hoard`.
- [ ] **AC-6.2** Given a signed-in page, and a page with the brand app bar (sign-in, first run, the licences page), at a width where the wordmark shows When it loads Then the app bar shows the mark and the words "Wyrm's Hoard" as text, in both themes, and no image on the page draws the word "Collector".
- [ ] **AC-6.3** Given the swap points decision 14's measurement gives When the app bar loads at each and one pixel under it Then the mark and the text show at it and the mark alone under it; with five links at 720px and with four at 640px the header's links fit on one line with the brand state the measurement recorded for that case; and at 320px and 360px nothing in either app bar overflows or wraps.
- [ ] **AC-6.4** Given any page When its accessible names are read Then the brand link is "Wyrm's Hoard home" (or "Wyrm's Hoard search" on the open catalog), the brand is named once (the mark's `alt` is empty wherever visible text or a labelled link names it, and "Wyrm's Hoard" where the mark stands alone with no label), and no `alt`, `aria-label` or `title` says "Collector" as the application's name.
- [ ] **AC-6.5** Given the mark's files When they are listed Then they are `wyrms-hoard-mark.svg` and `wyrms-hoard-mark-reversed.svg` with `aria-label="Wyrm's Hoard"`, their drawing is unchanged, the favicon is the mark, and the two wordmark SVGs are gone.
- [ ] **AC-6.6** Given the footer When it renders Then the licence line begins "Wyrm's Hoard <version> (<short SHA>)" in the forms of spec 084's table with the name replaced, the collectible's notice begins "Wyrm's Hoard is unofficial Fan Content", and the source link opens `https://github.com/plainprogrammer/wyrmshoard` at the running build.
- [ ] **AC-6.7** Given the web app manifest and the page head When they are read Then the manifest's `name` is "Wyrm's Hoard", its `description` names it, and `application-name` is "Wyrm's Hoard".
- [ ] **AC-6.8** Given each message of decision 9's last row When the condition that shows it occurs Then it says "Wyrm's Hoard" where it said "Collector" and is otherwise word for word the same: the backup's, restore's and start check's messages, the import's refusals and its "newer version" message, "Set up Wyrm's Hoard", "Wyrm's Hoard needs at least one admin.", the third-party licences page's first sentence.
- [ ] **AC-6.9** Given the export format's schemas When they are read Then each `title` and `description` says "Wyrm's Hoard export" and each `$id` and the `format` constant are unchanged.
- [ ] **AC-6.10** Given a request the application sends to Scryfall, the OCR engine's fetch and the registry cleanup When its User-Agent is read Then it is the string decision 9 gives for it.
- [ ] **AC-6.11** Given `bin/yard doc` When it builds Then the site's title is "Wyrm's Hoard", its links to the source open the renamed repository, and it builds with no warning.
- [ ] **AC-6.12** Given a build with no upstream source set When the footer's source link is read Then it is `https://github.com/plainprogrammer/wyrmshoard`.

### Story 7: The old name can't come back unnoticed (pull request D)

**As a** maintainer
**I want** the suite to fail when the old name returns to the code
**So that** a later change, or an agent working from an old memory, doesn't bring it back

**Acceptance criteria:**

- [ ] **AC-7.1** Given `main` after pull request D When the check runs Then it passes: no form of decision 9 is in a file's contents or name under the directories of decision 11, outside its exclusions.
- [ ] **AC-7.2** Given a file under those directories to which one form of decision 9 is added When the check judges it Then it fails and names the file, the line and the form; this holds for each row of decision 9's table, proved on injected text.
- [ ] **AC-7.3** Given text holding each kind of decision 10 that passes by rule (the collector line; the person in prose, `collector?` and lowercase names; `MimeResponds::Collector`; the export identifier) When the check judges it Then it passes; and given a person's name `"Collector #{n}"` or the card set's name outside an excluded place Then it fails, as those pass only by decision 11's exclusions.
- [ ] **AC-7.4** Given a file whose name or directory is a form of decision 9 When the check judges the tree Then it fails and names the path.
- [ ] **AC-7.5** Given the check's exclusions When they are read Then each is a path or a path and pattern with a written reason, and an exclusion whose path no longer exists, or whose pattern no longer matches anything in it, fails the check.
- [ ] **AC-7.6** Given the check When it is read Then it names no directory of documents: `docs/`, `README.md`, `CLAUDE.md` and the Markdown under `.claude/` are not read by it.

### Story 8: The documents say what is true, and the records say what changed (each pull request, completed in D)

**As a** contributor or an agent
**I want** the living documents to use the new name and the index to show what the rename superseded
**So that** I'm not told to set a variable or run a command that no longer exists

**Acceptance criteria:**

- [ ] **AC-8.1** Given `main` after pull request D When each living document of decision 15 is read Then it calls the application Wyrm's Hoard and gives the names of decision 2, and it names an old form only where it describes the rename or what stays; the reading is recorded per document in `verification.md`.
- [ ] **AC-8.2** Given `docs/releasing.md` after pull request C When its upgrade notes for 0.4.0 are read Then they give, in order: that an instance older than 0.3.0 upgrades to 0.3.0 first; each of the nine operator settings with its old and new name; the new image name; the renamed user command; the procedure of decision 17 for Compose, command by command (back up on 0.3.0, stop it, restore onto the new volume from the new image, start); the same for Kamal, where the old service is stopped with the old configuration before `service` is changed, with the backup directory's new name; what a backup doesn't carry (decision 17's list); how to recover from having started 0.4.0 on the empty volume first (stop it, remove the new volume, start 0.3.0 again on the old volume with the old file, then follow the procedure); that the old volume is left untouched until the operator removes it; and, for an operator who builds the image, the three build arguments' new names.
- [ ] **AC-8.3** Given the release and deploy area doc after pull request C When it is read Then it states the rule of two packages for the upgrade proof, the sweep of both prefixes and the frozen old package, each with its source (this spec's criterion or the ADR).
- [ ] **AC-8.4** Given `docs/specs/README.md` after pull request D When row 092 and the rows of the specs in the [Supersedes](#supersedes) table are read (each pull request having filled the cells of what it supersedes: C for specs 012, 013, 030, 031 and the settings, D for the rest) Then row 092's Supersedes cell names each spec and criterion of that table, and each of those rows' Superseded by cell names 092 with the criteria.
- [ ] **AC-8.5** Given the records of decision 15 When `git diff` from before pull request A to after pull request D is taken over them Then it is empty, but for the lines `.claude/rules/documentation.md` allows.
- [ ] **AC-8.6** Given the GitHub repository after step 1 of decision 1 When `https://github.com/plainprogrammer/Collector` is opened Then it redirects to `plainprogrammer/wyrmshoard`, and a push and a CI run on the renamed repository succeed before pull request A is opened; pull request A's merge is the first `main` build there, and it publishes `edge` to the old package as before.

## Functional Requirements

### FR-1: The comments come first

Pull request A writes a summary comment on every public object the ratchet will judge in the rename: those under `lib/collector/`, and those outside it whose text the rename changes.

**Must:**
- Follow `.claude/rules/code-documentation.md`: the why, `@param` and `@return` for reusable code, `@api private` where a helper has one caller.
- Take its list from the ratchet's own judgement, not from an estimate.

**Must not:**
- Change the ratchet, a name or a line of code.
- Name the new name: the comments are written for the code as it is, and a comment that names the module is renamed with it in pull request B.

### FR-2: Internal names

Pull request B renames the module to `WyrmsHoard` and the directories and files of decision 9's rows marked B to `wyrms_hoard`, with everything that refers to them: requires, the autoload ignore list, `.dockerignore`, `bin/image-smoke`'s path list, RuboCop's configuration, `.yardopts`' paths if any, the font URLs, the third-party manifest's keys, the pre-push hook, the specs that assert paths, the shards' run-time log, and the path references in the living documents.

**Must:**
- Regenerate `config/brakeman.ignore` and show, in the pull request, that it ignores the same warnings as before.
- Regenerate `db/prices_structure.sql` from a prices database created after the rename, so its comments carry the new name; state in the pull request that a developer recreates their development prices database once.
- Keep the rake namespace `collector`, every `COLLECTOR_*` variable, every message, title and file name as they are (AC-2.12).

- Remove the two comments that explain `::Collector::` beside Rails' `MimeResponds::Collector` (`licences_controller.rb`, `ocr_assets_controller.rb`), and the leading `::` they explain, there and in `app/helpers/scanners_helper.rb`, since `WyrmsHoard` collides with nothing.
- Rename the design system's skill directory to `wyrms-hoard-design-system` (AC-2.13).

**Must not:**
- Add an inflection rule.
- Change the session cookie's name by configuration to hide AC-2.7; the one reset is accepted.

### FR-3: The operator contract

Pull request C renames the settings of decision 8, the rake namespace to `wyrms_hoard`, the volume to `wyrms_hoard_storage`, Kamal's service to `wyrms-hoard`, the documented backup directory, the backup's and restore's file names (decision 12), and the developer's names of decision 9.

**Must:**
- Prove by example that `collector:user` is no task and that a `COLLECTOR_*` setting has no effect.
- Change the settings in every place that sets or passes them: `compose.yaml`, `config/deploy.yml`, the `Dockerfile`, `ci.yml`, `bin/image-smoke`.

**Must not:**
- Read an old name as a fallback, or print a notice about one.
- Edit the released currency migration or its spec's use of `COLLECTOR_CURRENCY`.

### FR-4: Data made before the rename

**Must:**
- Restore a backup whatever its file name's prefix (AC-4.1, AC-4.2).
- Sweep stale partial backups, and remove a stopped restore's temporary files, under both prefixes (AC-4.3, AC-4.4).
- Leave the export identifier, the schemas' ids, the format's version and the download's file name unchanged (AC-4.6).

**Must not:**
- Write any file under an old prefix.

### FR-5: The image

**Must:**
- Name `ghcr.io/plainprogrammer/wyrmshoard` in `ci.yml`, `compose.yaml`, `config/deploy.yml`, the cleanup script and its workflow.
- Keep spec 012's tag rules and spec 013's cleanup rules, applied to the new package.

**Must not:**
- Push to, delete from or clean up the old package.

### FR-6: The upgrade proof

**Must:**
- Choose the previous release's repository by its version (decision 13), with the rule and its reason written beside the repository constant.
- Accept either backup prefix from the previous build.
- Pass from 0.3.0 to a build of the renamed code, in CI, on both architectures.

**Must not:**
- Name the old package anywhere but in that rule and its specs.

### FR-7: The display name

Pull request D replaces the old name with "Wyrm's Hoard" in every place of decision 9's last row and in the mark's files and labels, and replaces the wordmark SVGs with text (decisions 6 and 14).

**Must:**
- Change only the name in each message, title and label; the rest of the wording stays.
- Add the text wordmark as a design system pattern, with its component document, and update `docs/design-system/logos.md`, the previews and `tokens.json`'s `name`.
- Carry screenshots of the app bar at desktop and phone widths in both themes in the pull request.
- Have every check that reads raw HTML for the name (`bin/image-smoke`'s licence line, request specs) match the escaped form or the parsed text: the apostrophe is written `&#39;` in a page's source.
- Leave the image's description label as it is; it doesn't name the application.

**Must not:**
- Hard-code a colour, a size or a font for the text wordmark; it uses the design system's tokens.
- Change the mark's drawing.

### FR-8: The repository's links

**Must:**
- Set the build facts' upstream source, the YARD links' base and the User-Agents' link to `https://github.com/plainprogrammer/wyrmshoard`.
- Rename the fixtures' checkout paths and `collector.git` to the new name.

### FR-9: The check

A spec in the suite that reads the tracked files of decision 11's directories and fails on a form of decision 9 outside the exclusions.

**Must:**
- Match the forms of decision 9, pass the kinds of decision 10, and judge file names as well as contents.
- Hold its forms and its exclusions as data in one place, each exclusion with a reason, and fail on a stale exclusion (AC-7.5).
- Prove each form and each kind by injection on small text, and show the real tree passes.

**Must not:**
- Read a document (`.claude/rules/testing.md`).
- Match the word `collector` case-insensitively.

### FR-10: The documents

**Must:**
- Rename the living documents of decision 15, each with the pull request that makes its statement true (decision 7).
- Write the upgrade notes of AC-8.2 in pull request C.
- Record the reading of each living document in `verification.md`.

**Must not:**
- Edit a record.

### FR-11: The supersessions

**Must:**
- Keep row 092 of `docs/specs/README.md` (added with this draft) in step with this spec's status, and fill its Supersedes cell and the other rows' Superseded by cells from the [Supersedes](#supersedes) table, each in the pull request that supersedes it (decision 7), complete by pull request D.
- Update the area doc where one covers a superseded criterion.

## Non-Functional Requirements

### Performance

- The check adds no more than 5 seconds to the suite on the development machine; its time is recorded in `verification.md`.
- No page, job or request gets slower: the rename changes names only.

### Security

- The repository rename and the new package grant no new access: the workflow's permissions are unchanged, and the new package is public for pulls only.
- The registry credentials in `.kamal/secrets` and the master key are not read or changed by any pull request.
- The session cookie's new name (AC-2.7) leaves the sign-in cookie and its signing as they were.

### Reliability

- After each merge `main`'s CI is green, an image is published, and the upgrade proof passes.
- The old volume, the old package and every backup and export made before the rename are left intact by the upgrade.
- Each step of decision 1 can be undone before the next without loss: the repository can be renamed back, and pull requests A, B and D reverted. A revert of pull request C would publish `edge` to the old package again, against ADR 0033 decision 3, so a fault in C is fixed forward.

### Accessibility

- The text wordmark meets the design system's contrast rules in both themes, and the brand link has one accessible name (AC-6.4).

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| An operator upgrades to 0.4.0 without renaming a setting | The setting is ignored and its default applies, with no warning (AC-3.2). The upgrade notes say so first. |
| An operator upgrades to 0.4.0 without moving the data | The instance starts on an empty `wyrms_hoard_storage` volume and shows first-run setup. The old volume is untouched. Restore refuses the new volume, which is no longer empty, and 0.4.0 can't back up the old one, so the operator stops 0.4.0, removes the new volume, starts 0.3.0 again on the old volume and follows the procedure (AC-8.2). |
| An instance older than 0.3.0 is upgraded straight to 0.4.0 with only `WYRMS_HOARD_CURRENCY` set | The currency migration runs with its default, USD. The upgrade notes say to go through 0.3.0 first (ADR 0032 decision 7). |
| `collector:user` is run on 0.4.0 | It fails as an unknown task (AC-3.4). |
| A backup named `collector-backup-….tar.gz` is restored on 0.4.0 | It restores (AC-4.1). |
| A file that isn't a backup is given to restore | It is refused as before, and the hint names a `wyrms-hoard-backup-….tar.gz` file. |
| The new package is private after pull request C merges | The anonymous pull of `:edge` fails; the maintainer makes it public; no tag is pushed until the pull succeeds (AC-5.6). |
| The upgrade proof can't pull 0.3.0 from the old package | It fails as it does today for a missing previous image; nothing falls back to the new package. |
| A later change adds the old name to code | The check fails and names the file, the line and the form (AC-7.2). |
| A later change removes the last use of an excluded place | The check fails on the stale exclusion (AC-7.5). |
| A developer's prices database from before pull request B is dumped | The structure file would carry the old name again and the check, once it exists, fails; the developer recreates the development prices database (FR-2). |
| A developer has a certificate under the old directory | `bin/dev-certificate` makes a new one under the new directory; the old one is left where it is. |

## Supersedes

Criteria of shipped specs that fix a value the rename changes (decision 16). Each is superseded in the part named; the area docs hold the current value. This table is the source of the index's cells (FR-11).

| Spec | Criteria | What changes |
|---|---|---|
| 001 | AC-1.3 | `/` contains the text "Wyrm's Hoard" |
| 004 | AC-1.1 and its FR text; AC-2.1; AC-2.5 | Two logo files, not four; the skill's name; the header's wordmark is text; the reversed swap applies to the mark |
| 005 | Constraints note | `WYRMS_HOARD_MTG_LANGUAGES` |
| 011 | AC-1.2, AC-1.3 | `WYRMS_HOARD_MTG_ART_MATCHING`, `WYRMS_HOARD_MTG_LANGUAGES` |
| 012 | Goals, AC-1.1, AC-1.2, AC-1.3, AC-1.4, AC-1.5, AC-2.1, AC-5.1, AC-5.2, AC-6.3, AC-7.3, FR-4, FR-5, Error Scenarios | The package `ghcr.io/plainprogrammer/wyrmshoard`; `WYRMS_HOARD_IMAGE`; the volume; the local tag `wyrms-hoard:local`; `wyrms_hoard:user` and `WYRMS_HOARD_PASSWORD` |
| 013 | Non-Goals, FR-1, FR-3 | The cleanup's package, registry and token scope are the new package's |
| 018 | AC-1.1, FR-1 | The notice's first words and the fallback title |
| 020 | AC-1.1, Glossary; AC-4.2 | The README's heading and first sentence; `WYRMS_HOARD_MTG_ART_MATCHING` in both deployment files |
| 023 | Decision 1, AC-1.1, AC-1.3; decision 3, AC-5.1 | `WYRMS_HOARD_PUBLIC_CATALOG`; the label "Wyrm's Hoard search" |
| 025 | Decision 10's table | The import's messages name Wyrm's Hoard |
| 030 | Decisions 3, 4, 5; AC-1.1, AC-3.3, AC-4.1; Error Scenarios; `contracts/archive.md`; `contracts/tasks.md` | The user command and settings; the backup directory, volume and image in the procedures; the backup's file name and the partial files' names (the sweep in part: it keeps the old prefix beside the new); the restore's temporary files; every message that names the application |
| 031 | Terms, decision 2, AC-1.3, AC-7.1; `contracts/harness.md` | The previous release's repository, in part: the old package only for 0.3.0 and earlier; the built image's tag |
| 032 | `contracts/api.md`'s "newer version" message; `contracts/export-v3.md`'s schema title | The name in the message and the title; the `$id` stays |
| 038 | Decision 2, Glossary, AC-3.1, AC-3.3, AC-3.4, Error Scenarios, its documents table; decision 7, AC-6.6 | `WYRMS_HOARD_CURRENCY` as the boot setting; "Wyrm's Hoard can't show prices in XYZ." Not AC-4.1: the released migration still reads `COLLECTOR_CURRENCY` |
| 049 | Context | `WYRMS_HOARD_REQUEST_LOG` |
| 057 | Decision 19, AC-1.2 to AC-1.6 in part (AC-1.6 in full if decision 14's measurement says so) | The wordmark is text; its measured width and the swap point by the same rule (decision 14) |
| 062 | AC-4.2 in part | The wordmark's measured width (decision 14) |
| 064, 066, 068, 071 | AC-1.2; AC-1.1; AC-1.2; AC-2.1 | The titles end `· Wyrm's Hoard` |
| 081 | Decisions 7 and 8, AC-4.4, Error Scenarios | The messages name Wyrm's Hoard |
| 084 | Decision 2's table, AC-2.1 to AC-2.5, AC-2.9, AC-2.14, Error Scenarios; decisions 3, 7 and 9, AC-3.1, AC-3.3, AC-3.6, FR-2; decision 5 | The licence line's name; the build facts' three names; the smoke test's line; `WYRMS_HOARD_IMAGE`; the upstream source URL |
| 086 | AC-3.1, AC-4.3, FR-3, FR-4, decision 4 | The messages name Wyrm's Hoard; the CI step's image tag |
| 087 | Decision 1, AC-1.4 | The licence line's substring and the page's first sentence |
| 089 | Error Scenarios | `WYRMS_HOARD_MTG_LANGUAGES` |
| 090 | Decision 8 | `bin/rails wyrms_hoard:user` |

Looked at and not superseded: spec 038 AC-4.1 and its error row (the released migration); spec 014 AC-1.4 (it names release 0.1.0's image, which exists only in the old package); spec 012 AC-3.5 (it fixes no name); and the 44 specs of decision 16.

## Open Questions

None open. Decisions 7 to 18 are the author's and are put to the maintainer with this spec; a ruling against one changes the criteria that cite it.

## Out of Scope (Future Considerations)

- **Renaming the local checkout directory.** The maintainer's step; Claude Code's per-project memory directory is keyed to that path and would move with it.
- **Deleting the old package** (ADR 0033, Follow-up).
- **A drawn wordmark, a new mark or any other change to the design system's look.**
- **A domain, a hosted service's naming** (`COLLECTOR_HOSTED` in the design record) or anything outside this repository and its package.
- **Announcing the rename** anywhere but the release's upgrade notes.
- **The flaky backup example** ([#432](https://github.com/plainprogrammer/Collector/issues/432)), though pull request B moves its file.
- **Attestations for the image,** which ADR 0008 leaves for when the repository is public.
