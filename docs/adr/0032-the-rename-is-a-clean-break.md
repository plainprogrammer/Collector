# 0032: The rename to Wyrm's Hoard is a clean break: one spelling per context, no aliases, and the export identifier stays

## Status

Proposed (2026-11-14). Written with the PRD of spec 092; the maintainer chose each option below in the brainstorm of 2026-11-14 ([#433](https://github.com/plainprogrammer/Collector/issues/433), [#434](https://github.com/plainprogrammer/Collector/issues/434)). It becomes Accepted with the maintainer's approval of the PRD.

**Date:** 2026-11-14
**Feature:** 092-rename-to-wyrms-hoard

## Context

The application's name changes from Collector to Wyrm's Hoard, and its repository from `plainprogrammer/Collector` to `plainprogrammer/wyrmshoard`. The old name is in four kinds of place (on `main` at `50435ba3`, about 950 tracked files contain it in any case, by `git grep -il collector`):

- **The display name:** page titles (`… · Collector`), the footer, `README.md`, the image's description.
- **Internal code:** `module Collector` and `Collector::…` (about 330 uses), `lib/collector/`, `spec/lib/collector/`, the asset directories `app/assets/{stylesheets,fonts,images}/collector/`.
- **The operator contract:** the `COLLECTOR_*` environment variables and build arguments (19 in code, 7 of them developer-only), the command `bin/rails "collector:user[EMAIL]"` (`lib/tasks/collector.rake`), the Compose volume `collector_storage`, Kamal's `service: collector`, backup files named `collector-backup-<time>.tar.gz`. A renamed setting that an operator doesn't also rename is silently ignored, and a renamed volume starts the application on an empty one.
- **The data contract:** every export file begins with `"format": "collector-export"`, and the four schemas are identified as `urn:collector:export-format:v1` to `v4` (`ExportFormat::Rules::FORMAT`, `app/models/export_format/`).

One released migration, `db/migrate/20261103100002_set_account_currency_from_the_instance.rb`, reads `COLLECTOR_CURRENCY` to set each account's currency. It first shipped in 0.3.0, and a released migration is never edited (`.claude/rules/sqlite-and-migrations.md`).

The same letters also name things that are not the application: `collector_number`, `collector_text` and `collector_line` are a card's printed collector line and what the scanner reads of it, "a collector" is the documentation's and the interface's word for a person who uses the application, and `collector?` is the view helper that asks whether one is signed in.

The display name has an apostrophe and a space, so every machine-facing place needs a derived spelling. The maintainer fixed one: the repository is `wyrmshoard`.

Foundation principle 1 asks that every release upgrade in place, and principle 2 that users own their data. Releases 0.1.0 to 0.3.0 are published. The maintainer stated on 2026-11-14 that no instance other than their own runs the application.

## Options considered

**For existing instances (the operator contract):**

- **A. A clean break (chosen).** One release renames every setting, the volume and the service; no old name is read. Upgrade notes list what to change by hand. Costs: the upgrade from 0.3.0 is not unattended, which principle 1 would otherwise ask for.
- **B. Old names keep working for a release or more, with a deprecation notice.** The upgrade stays unattended, at the cost of an alias layer for every setting, its tests, and a later release that removes it, for an audience of one instance whose operator is the maintainer. Not chosen.
- **C. Old names keep working until 1.0 or indefinitely.** Right if unknown operators existed; the maintainer says none do. Not chosen.

**For the spelling in code and configuration:**

- **A. Two words, by Rails' default inflection (chosen):** `WyrmsHoard`, `wyrms_hoard`, `WYRMS_HOARD_`, `wyrms-hoard`; the repository and the image stay `wyrmshoard`. Costs: two lowercase spellings exist, so a search for one misses the other.
- **B. One token with an inflector acronym:** `wyrmshoard` everywhere lowercase and `WyrmsHoard` as the constant, through `inflect.acronym "WyrmsHoard"`, as `MTG` is. One lowercase spelling, at the cost of an inflection rule a reader must know. Not chosen.
- **C. One token, plain constant:** `Wyrmshoard`. No rule to know, but the constant reads as one word. Not chosen.

**For the export identifier:**

- **A. Keep `collector-export` and the `urn:collector:…` schema ids (chosen).** It reads as "a collector's export", the word the application keeps for its users, so it is not a leftover of the old name. No format version changes and every existing file stays valid.
- **B. Rename it as format version 5,** identical to version 4 but for the identifier, with versions 1 to 4 still read under the old one. A schema, a document section and import tests for a change that carries no data. Not chosen.
- **C. Rename it and stop reading old files.** Breaks principle 2 for every file already downloaded. Not chosen.

## Decision

1. **The rename is a clean break.** From the release that carries it (0.4.0), the running application reads no `COLLECTOR_*` variable (decision 7 is the one exception), has no `collector:user` task, mounts no `collector_storage` volume by default and is no Kamal service named `collector`. No alias, fallback or deprecation notice is written. The release ships upgrade notes that name each renamed setting, the volume and the service, and say how to move the data.
2. **One spelling per context:**

   | Context | Spelling |
   |---|---|
   | Display (titles, prose, the image's description) | Wyrm's Hoard |
   | Ruby constants | `WyrmsHoard` |
   | File and directory names, Ruby identifiers, the rake namespace, the Compose volume | `wyrms_hoard` |
   | Environment variables and build arguments | `WYRMS_HOARD_` |
   | Hyphenated names (Kamal's service, backup files, a User-Agent) | `wyrms-hoard` |
   | The repository and the image, and nothing else | `wyrmshoard` |

   No inflection rule is added.
3. **What names the person or the card's collector line stays:** "a collector" in prose and interface copy, the `collector?` helper, and `collector_number`, `collector_text`, `collector_line` and their kin. The `c-` prefix of the design system's classes stays too; it is a prefix, not the name.
4. **The export identifier stays `collector-export`,** with its `urn:collector:export-format:vN` schema ids and the download's file name `collector-export-<date>.json`, and the format's version stays 4. Only the prose of the format's document and the schemas' titles and descriptions say Wyrm's Hoard.
5. **Data made before the rename is still read.** A backup made by an earlier release restores under the new one (restore judges a file by its contents, never its name's prefix), and every export of versions 1 to 4 imports as before.
6. **Shipped specs and accepted ADRs are not edited** (`.claude/rules/documentation.md`); they keep the old name as the record of their time.
7. **The released currency migration keeps reading `COLLECTOR_CURRENCY`.** It is not edited. An instance on 0.3.0 has already run it, so the rename changes nothing for it. An instance older than 0.3.0 that went straight to 0.4.0 with only the new setting would run it with the default, USD; the upgrade notes therefore say to upgrade to 0.3.0 first.

## Consequences

- **Good:** no alias layer exists to test, document or remove later, and after the release a search for the old name finds only what decisions 3, 4, 6 and 7 leave, the old backup prefix where old data is still read, the upgrade proof's rules for 0.3.0 ([ADR 0033](0033-the-image-moves-to-a-new-package.md)) and `spikes/`.
- **Cost:** the upgrade from 0.3.0 to 0.4.0 needs an operator: rename the settings, copy the volume (Docker has no volume rename) and, under Kamal, move to the new service. An operator who upgrades without the notes gets an instance on an empty volume with default settings; the old volume is untouched, so nothing is lost, but nothing warns them. This is an accepted exception to principle 1, taken because the only instance is the maintainer's.
- **Cost:** the upgrade proof (`bin/upgrade-smoke`, spec 031) must drive this one upgrade across the rename; spec 092 says how, and [ADR 0033](0033-the-image-moves-to-a-new-package.md) covers where it pulls the previous release from.
- **Limit:** two lowercase spellings (`wyrms_hoard`, `wyrmshoard`) and one hyphenated one exist. A guard against the old name is cheap; a wrong new spelling is for review to catch.
- **Limit:** if an unknown operator does exist, decision 1 breaks their upgrade. The upgrade notes are the only mitigation.
- **Follow-up:** the old name remains in shipped specs, accepted ADRs, the export identifier and the old image; a reader who finds it there is reading history or decision 4, not an omission.
