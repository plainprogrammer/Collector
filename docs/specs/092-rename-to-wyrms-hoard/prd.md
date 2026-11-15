# PRD: Rename the Application to Wyrm's Hoard

**Date:** 2026-11-14
**Feature:** 092-rename-to-wyrms-hoard
**Issues:** [#433](https://github.com/plainprogrammer/Collector/issues/433) (tracking), [#434](https://github.com/plainprogrammer/Collector/issues/434) to [#440](https://github.com/plainprogrammer/Collector/issues/440), [#445](https://github.com/plainprogrammer/Collector/issues/445)

## Problem

The application is called Collector, its repository `plainprogrammer/Collector` and its image `ghcr.io/plainprogrammer/collector`. The maintainer has decided the name is Wyrm's Hoard and the repository `wyrmshoard`. The old name is in the interface, the code's module and directories, every operator setting and command, the deployment files, the image's name and the documentation (about 950 tracked files on `main` at `50435ba3`, by `git grep -il collector`), so the change has to be made in an order that leaves the repository, CI and the published image working at every step.

## Users & Context

- **The maintainer**, who is the only operator of an instance (stated 2026-11-14; it runs 0.3.0) and the person who renames the repository, checks the new package is public and upgrades that instance.
- **A collector** (a person who uses the application), who sees the new name in the interface and whose collection, exports and backups are unaffected.
- **A contributor or an agent** working in the repository, who reads the living documentation and the code's names.

It touches the Rails application's module and `lib/` namespace, the asset directories, the environment variables and build arguments, the operator's rake task, `compose.yaml`, `config/deploy.yml`, the `Dockerfile`, `ci.yml` and the cleanup script and workflow, the backup's file names and messages, the upgrade proof, the build facts and the footer's source link, the interface's names for the application, and the living documentation. It renames the GitHub repository and creates a new container package.

## Goals

1. **The application calls itself Wyrm's Hoard** wherever it names itself to a person:
   - page titles, the footer's licence line and the collectible extension's notice in it ("Collector is unofficial Fan Content…"), `<meta name="application-name">`, the web app manifest's `name` and `description`, and the app bar's labels ("Collector home", "Collector search");
   - the app bar's wordmark, which becomes the words "Wyrm's Hoard" as live text in the design system's display type, shown beside the mark and replacing the two SVGs that draw the old name (`collector-wordmark.svg` and its reversed copy); the mark, which is also the favicon, keeps its drawing, and its files' names, `aria-label` and `alt` text take the new name;
   - every message that names the application to a person: those the backup, the restore and the start check print ("Start Collector now", "isn't a Collector backup"), the import's refusal ("Collector can't show prices in …"), and any other the spec finds;
   - the titles and descriptions of the export format's schemas (ADR 0032 decision 4), and the design tokens' `name` in `docs/design-system/tokens.json`, from which `tokens.css` is generated;
   - `README.md`, the image's description, the YARD site's title, and the User-Agents the code sends (Scryfall, the OCR engine's fetch, the registry cleanup).
2. **The code's own names follow** ([ADR 0032](../../adr/0032-the-rename-is-a-clean-break.md) decision 2): `WyrmsHoard` for the module; `wyrms_hoard` for `lib/collector/`, `spec/lib/collector/`, `lib/tasks/collector.rake` and the asset directories `app/assets/{stylesheets,fonts,images}/collector/`, with the font URLs in the tokens, the keys in `config/third_party_licences.yml` the specs that assert those paths, and the references to those paths in `docs/design-system/` (its previews link the stylesheets) and in the design system's skill. The file `lib/tasks/collector.rake` is renamed here; the task's namespace is the operator's and changes with goal 3. What follows the module's name goes with it: `.claude/hooks/pre_push_ci.rb`, which requires `lib/collector/push_scope`; `config/brakeman.ignore`, whose fingerprints include the module's name and are regenerated, not edited as text; and `db/prices_structure.sql`, whose dump carries the application's name in comments.
3. **The operator contract is renamed as a clean break** (ADR 0032 decision 1), with no aliases:
   - the `COLLECTOR_*` variables and build arguments become `WYRMS_HOARD_*`. The spec lists them in two groups: the operator's settings (which the upgrade notes list) and the developer-only ones (`ART_AGREEMENT`, `MISE_SEARCH`, `DEV_CERT_DIR`, `REQUEST_LOG`, the three `SCANNER_*`). The developer's other names go with them: the certificate's directory and file, and the smoke and measurement scripts' container and volume names;
   - the volume, in Compose and in Kamal, becomes `wyrms_hoard_storage`; Kamal's `service` becomes `wyrms-hoard` and its `image` `plainprogrammer/wyrmshoard`; the documented backup directory `/srv/collector-backups` becomes `/srv/wyrms-hoard-backups`;
   - the operator's command `bin/rails "collector:user[EMAIL]"` becomes `wyrms_hoard:user`;
   - new backups are named `wyrms-hoard-backup-<time>.tar.gz`, and the restore's temporary files and the refusal's hint follow.
4. **Data made before the rename is still read** (ADR 0032 decisions 4 and 5):
   - a backup made by 0.3.0 restores under the new release. Restore judges a file by its contents, never its name's prefix, so this needs no new code; it needs the proof that it stays so;
   - `backup:create`'s sweep of stale partial files removes leftovers under both the old and the new prefix, so an interrupted 0.3.0 backup in the same directory is still cleaned up;
   - exports of format versions 1 to 4 import unchanged. The export identifier `collector-export`, the schemas' ids, the format's version and the download's file name `collector-export-<date>.json` do not change.
5. **The repository is `plainprogrammer/wyrmshoard`,** and the code's links to it (the build facts' upstream source, the YARD links, the User-Agents) say so.
6. **The image is published at `ghcr.io/plainprogrammer/wyrmshoard`,** public, starting with release 0.4.0; the old package is left frozen ([ADR 0033](../../adr/0033-the-image-moves-to-a-new-package.md)). The cleanup script's registry constants and its workflow name the new package.
7. **The upgrade from 0.3.0 is proven and documented:** the upgrade proof passes from the previous release's image under the old name to a build under the new one. The proof takes a backup on the previous release, so it expects the old backup prefix from a release of 0.3.0 or earlier and the new one from any later release, by the same rule as the image (ADR 0033 decision 4); the spec says what a previous build given by ref, which has no version, expects. And upgrade notes tell an operator each operator setting to rename, the renamed command, how to copy the volume, how to move the Kamal service and the backup directory, and the one exception of ADR 0032 decision 7 (an instance older than 0.3.0 upgrades to 0.3.0 first).
8. **The living documentation uses the new name.** Living: `README.md`, `CLAUDE.md`, `docs/architecture/`, `docs/design-system/` (its previews, component pages and `logos.md` show the wordmark's SVGs, so those parts change with goal 1), `docs/roadmap.md`, `docs/north-star.md`, `docs/releasing.md`, `docs/backup-restore.md`, the prose of `docs/export-format/`, the READMEs of `docs/adr/` and `docs/specs/`, `.claude/rules/`, `.claude/integrations.md`, `.claude/memory/foundation.md` and the steering files, the design system's skill (renamed from `collector-design-system`), and a memory file where it states a current name or command. Records, left as they are: shipped specs, accepted ADRs, `docs/lessons/`, `docs/superpowers/`, and what a memory file says happened.
9. **The old name can't come back unnoticed in the code:** a check in the suite fails when the application's old name appears in code or configuration outside a list of exclusions written in the check.
   - **It reads code and configuration, not prose:** `app/`, `bin/`, `config/`, `db/` (the structure files included), `lib/`, `script/`, `spec/`, `.github/`, `.githooks/`, `.claude/hooks/`, and the root's deployment and tool files (`Dockerfile`, `compose.yaml`, `.dockerignore`, `.yardopts`, `orca.yaml` and the like). The documents (`README.md`, `CLAUDE.md`, `docs/`, the Markdown under `.claude/`) are checked by reading, recorded in the spec's `verification.md`, as `.claude/rules/testing.md` requires of prose. Several of them must name the old forms anyway: the upgrade notes in `docs/releasing.md`, the two-package rule in the release and deploy area doc, the sweep of both prefixes in `docs/backup-restore.md`.
   - **It matches the name's forms, not the word:** `Collector` as a capitalised word that isn't the person or a card term, `Collector::`, `COLLECTOR_`, `collector_storage`, `collector:` as a rake namespace or an image tag, `plainprogrammer/collector` in either case, a path under a `collector/` directory, the hyphenated names (`collector-backup`, `collector-restore`, `collector-ghcr-cleanup`, `collector-dev`, `collector-mark`, `collector-wordmark`, `collector-design-system`, `collector-smoke`, `collector-measure`, `collector-db`), and the bare lowercase name where it is the application's: Kamal's `service: collector`, a container's `--name collector`, `_collector_session`, `collector.git`, `collector_rake`. These are examples; the spec lists the forms in full, from a search of the directories the check reads, and gives the rule that tells the capitalised name from a card's label ("Collector number"). No form matches `collector-export` or `urn:collector:`, which stay.
   - **It does not match** the person ("a collector", `collector?`) or the card's collector line (`collector_number`, `collector_text`, `collector_line`, `CollectorLine` and their kin).
   - **Excluded, each by path:** `db/migrate/` and the released currency migration's spec; `spikes/`; the upgrade proof's rules for a previous release of 0.3.0 or earlier (the old image, and the old backup prefix that release prints), with the specs and fakes of those rules; and the places goal 4 needs the old backup prefix, which are the sweep's pattern and the examples that prove an old backup restores and an old partial file is swept; and the check's own file and spec, with the examples that prove an old name is gone (that `collector:user` is no task, that no `COLLECTOR_*` setting is read).
10. **The spec records what it supersedes** (`.claude/rules/documentation.md`), in itself and in `docs/specs/README.md`, both directions, and the area docs follow. At least: spec 012's and spec 013's package name, spec 030's archive name and its not-a-backup message, spec 031's repository for the previous release, spec 084's wording of the licence line where it names the application, every spec that names a renamed setting or the renamed command, and every criterion that fixes the display name in a title, a label, a notice or a message (spec 004's wordmark in the header, spec 018's notice, spec 023's "Collector search", spec 066's page title and the titles like it, spec 086's start message among them). The spec lists them by criterion.
11. **The work lands in an order in which every step can be checked before the next:**
    1. The repository is renamed ([#435](https://github.com/plainprogrammer/Collector/issues/435)); CI still publishes to the old image.
    2. The missing summary comments are written on every object the comment ratchet will judge in the rename ([#445](https://github.com/plainprogrammer/Collector/issues/445)), under the old name. The comment ratchet (spec 056) judges an object as added when its qualified name is new and as changed when its text changes, so it judges every object under `lib/collector/` (94 have no summary, by the ratchet's own reading on `main`) and the few outside it whose text names the module or an old form (four today, in `app/helpers/scanners_helper.rb` and `spec/support/backup_helpers.rb`). The spec lists them from the ratchet's judgement. With the summaries in place the rename is mechanical and the ratchet is unchanged (the maintainer, 2026-11-14).
    3. The code changes in three pull requests, each carrying the documents of what it changes (`.claude/rules/documentation.md`; `README.md` stays in step with the deployment files):
       - the internal names of goal 2 ([#436](https://github.com/plainprogrammer/Collector/issues/436)), with the path references that would otherwise break, and with no change an operator or a collector can see but one: Rails names the session cookie after the module, so the flash and the tokens of forms open during the upgrade reset once; sign-in survives, as it uses its own cookie;
       - the operator contract, the image's name and the upgrade proof, goals 3, 4, 6 and 7 ([#437](https://github.com/plainprogrammer/Collector/issues/437)), with the parts of `README.md`, the release and deploy area doc, `docs/backup-restore.md` and `docs/releasing.md` that describe them, the upgrade notes among them;
       - the display name and the repository's links, goals 1 and 5, the rest of the living documentation, the check of goal 9 and the supersessions of goal 10 ([#438](https://github.com/plainprogrammer/Collector/issues/438)).
    4. The new package, which the second of those pull requests creates when it merges, is checked to be public and made so if it isn't ([#439](https://github.com/plainprogrammer/Collector/issues/439)).
    5. Release 0.4.0 is tagged and the maintainer's instance is upgraded by the notes ([#440](https://github.com/plainprogrammer/Collector/issues/440)).

## Non-Goals

- **No compatibility with the old operator names:** no alias, fallback or deprecation notice for a `COLLECTOR_*` variable, the old volume, the old service or the old command (ADR 0032).
- **No change to what names the person or the card's collector line** (goal 9, "It does not match"), and none to the `c-` prefix of the design system's classes.
- **No new export format version** and no change to the export identifier, the schemas' ids or the download's file name.
- **No edit to a released migration.** `db/migrate/20261103100002_set_account_currency_from_the_instance.rb` reads `COLLECTOR_CURRENCY` and stays as it is (ADR 0032 decision 7).
- **No edit to a shipped spec, an accepted ADR, a lesson or a design record** (`.claude/rules/documentation.md`); GitHub's redirect keeps their links working.
- **No copy, rebuild, retag or deletion of a published image** (ADR 0033).
- **No change to `spikes/`,** a record of past experiments, unless the suite loads code from it; the spec settles that by looking.
- **No drawn wordmark or new mark.** The text wordmark of goal 1 stands until a design task replaces it.
- **No change of behaviour** beyond names: no feature, schema or migration.

## Success Criteria

- Every page's title, app bar and footer say Wyrm's Hoard, no page draws the old name or gives it as a label or an image's text, and the footer's source link opens `plainprogrammer/wyrmshoard` at the running build.
- `bin/ci` passes on each of the four pull requests, and after each merge the documents on `main` describe the deployment files on `main`.
- An instance started from the new image with only `WYRMS_HOARD_*` settings behaves as the last build before the rename did with the `COLLECTOR_*` ones, and the running application reads no `COLLECTOR_*` setting (the released migration aside).
- `bin/rails "wyrms_hoard:user[EMAIL]"` does what `collector:user` did, and `collector:user` is no task.
- `backup:create` writes `wyrms-hoard-backup-<time>.tar.gz` and sweeps stale partial files of both prefixes; `backup:restore` restores that file and a backup made by 0.3.0.
- An export downloaded from 0.3.0 previews and applies on the new release, and a new export is `collector-export-<date>.json` with `"format": "collector-export"`, version 4.
- `bin/upgrade-smoke` passes from release 0.3.0's image, pulled from `ghcr.io/plainprogrammer/collector`, to a build of the renamed code.
- `ghcr.io/plainprogrammer/wyrmshoard:edge`, then `:0.4.0` and `:latest`, pull without credentials and pass `bin/image-smoke`; nothing was pushed to or deleted from the old package after the pull request that renames the image merged.
- The old repository URL redirects to the new one, and a push and a CI run work under the new name.
- The suite's check finds none of the old name's forms in code or configuration outside its exclusions, and fails when a test adds one; the documents were read and the reading is recorded.
- `docs/specs/README.md` shows, in both directions, each shipped criterion the rename supersedes.
- The maintainer's instance, upgraded from 0.3.0 by following the upgrade notes alone, shows the collection it had before.

## Architecture Decisions

- [0032: The rename is a clean break](../../adr/0032-the-rename-is-a-clean-break.md) — one spelling per context (`WyrmsHoard`, `wyrms_hoard`, `WYRMS_HOARD_`, `wyrms-hoard`; `wyrmshoard` only for the repository and the image), no aliases for the old operator names because the maintainer's is the only instance, the export identifier stays because it names the person, and one released migration keeps reading the old currency setting.
- [0033: The image moves to a new package](../../adr/0033-the-image-moves-to-a-new-package.md) — new releases only at `ghcr.io/plainprogrammer/wyrmshoard`; the old package is frozen, nothing is copied or deleted, and the upgrade proof pulls 0.3.0 and earlier from the old name. It changes ADR 0008's consequence that the old package name is a public contract.

Decided here, without an ADR, because each is cheap to change:

- **The order of work** (goal 11): the repository first, so every URL the code PRs write is true when they merge and each step can be undone before the next.
- **Backup file names** (goals 3 and 4): new backups take the new name; nothing about restore depends on a name's prefix.
- **The wordmark** is live text for now (the maintainer, 2026-11-14).
- **The developer's certificate directory** (`~/.local/share/collector-dev-https`) is renamed with the rest; a developer runs `bin/dev-certificate` again.
- **The release is 0.4.0.**

## Out of Scope

- **Renaming the local checkout directory.** The maintainer's choice and their step; Claude Code's per-project memory directory is keyed to that path and would move with it.
- **Deleting the old package** later (ADR 0033, Follow-up).
- **A drawn wordmark, a new mark or any change to the design system's look** beyond goal 1's text wordmark.
- **A domain, a hosted service's naming or anything outside this repository and its package.** `COLLECTOR_HOSTED` exists only in the hosted service's design record and is named when that lane is built.
- **Announcing the rename** anywhere but the release's upgrade notes.
- **The flaky backup example** ([#432](https://github.com/plainprogrammer/Collector/issues/432)); it is its own issue, though the rename edits the same file.
