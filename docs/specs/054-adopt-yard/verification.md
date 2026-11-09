# Verification: Spec 054, Browsable API Documentation for the Ruby Code (YARD)

Evidence for each criterion of [spec.md](spec.md) (v1.2.1). Commands were run at the commits named; documents are verified by reading, per `.claude/rules/testing.md`. "CI" rows are filled from the pull request's run.

## Criteria

### Story 1: A reader browses the Ruby API

| AC | Evidence |
|---|---|
| AC-1.1 | `bin/yard doc --no-cache; echo "exit=$?"` at `1f58484f`: no `[warn]` line, no Ruby "already initialized constant" line, `exit=0`; `doc/index.html` written. Stats: 197 files, 61 modules, 210 classes, 301 constants, 169 attributes, 838 methods, 53.70% documented |
| AC-1.2 | `doc/Account.html`, `doc/Catalog/Entry.html`, `doc/Collector/Backup.html`, `doc/Lot.html`, `doc/MTG/Art/Operation.html` exist; `ls doc \| grep -i -E 'YardLinks\|Upgrade'` prints nothing; `doc/class_list.html` has 272 entries = 61 modules + 210 classes + the root namespace, matching `bin/yard stats` |
| AC-1.3 | `ls doc \| grep -c '^file\.'` = 35 = `ls docs/adr/0*.md docs/architecture/*.md \| wc -l` (8 files in `docs/architecture/`, 27 ADRs with 0027); `docs/adr/README.md` has no page; `grep -c '<table' doc/file.release-and-deploy.html` = 4 (tables render). New page picked up: a probe `docs/architecture/zz-probe.md` (`# Probe`) gave `doc/file.zz-probe.html` on the next run with no option change and no warning, then was deleted. Note: the spec's Glossary says "7 area docs (including `docs/architecture/README.md`)"; there are 7 area docs plus the README, 8 files |
| AC-1.4 | `doc/file.README.html` is the area map (`<h1 id="Architecture">`); `doc/index.html` shows the area table (Area, Doc, Specs it covers, Reference docs) |
| AC-1.5 | `grep -o 'href="file.0024[^"]*"' doc/file.release-and-deploy.html` prints `href="file.0024-backup-with-vacuum-into.html"`; `grep -o 'href="file.catalog-core.html"' doc/index.html` prints one match (the front page's links); fragment mapping to YARD's heading ids is checked in `spec/script/yard/links_spec.rb` and `spec/script/yard/site_spec.rb` (`file.beta.html#What_it_keeps` with `id="What_it_keeps"` in the target page, and the reverse link with punctuation in the heading). No included page links to a heading of another included page today (the one fragment link, `release-and-deploy.md` to `../releasing.md#…`, leaves the site) |
| AC-1.6 | a link to a spec reads `href="https://github.com/plainprogrammer/Collector/blob/main/docs/specs/README.md"`; `grep -o 'href="[^h#"][^"]*\.md[^"]*"' doc/file.*.html \| head` prints nothing (no relative `.md` link left); `site_spec.rb`: `notes/outside.md#…` becomes `…/blob/main/notes/outside.md#…` and `https://example.com/page` is unchanged |
| AC-1.7 | `git status --short` after the run: no change under `docs/`; `site_spec.rb` "leaves the documents on disk as they were" |
| AC-1.8 | a second run without `--no-cache` at the branch's head (after the follow-up commit): same statistics, `exit=0`, `grep -c warn` = 0 (first checked at `034b0fdf`, before the extension) |
| AC-1.9 | `lib/collector/backup.rb` carries `@see file:release-and-deploy.md` (`abefc4de`); `grep -o 'href="../file.release-and-deploy.html"' doc/Collector/Backup.html` prints one match (the href is relative to the class page); `bin/yard doc --no-cache` after it: `exit=0`, no warning; `site_spec.rb` checks the top-level fixture class the same way |

### Story 2: A comment that warns is caught

| AC | Evidence |
|---|---|
| AC-2.1 | `bin/yard doc --no-cache` before the fix: `[warn]` at `app/models/scanner/measurement_run.rb:4`, `lib/collector/ghcr_cleanup.rb:107` and `:120`, `exit=1`; after (`034b0fdf`): none, `exit=0`. Both `ghcr_cleanup.rb` warnings came from the one `{id}` on line 120. The scanner comment now renders `<code>file,set,number,foil[,era]</code>` |
| AC-2.2 | At `e6172933`: with `# See {nothing_here}.` above `class Lot < ApplicationRecord` (`app/models/lot.rb`): `bin/yard doc --no-cache` printed `[warn]: In file `app/models/lot.rb':4: Cannot resolve link to nothing_here from text: ...{nothing_here}...` and `exit=1`; `bin/ci checks` printed `❌ Docs: YARD builds without warnings failed in 6.06s` with those lines and `❌ Continuous Integration failed`; with the line removed (Edit tool; `git status --short` clean for `lot.rb`) `bin/ci checks` passed: `✅ Docs: YARD builds without warnings passed in 9.28s`, `✅ Continuous Integration passed in 25.66s` |
| AC-2.3 | `config/ci.rb:30` is in the `unless selection.group == :rspec` block, after the style step and before Brakeman; `spec/config/ci_definition_spec.rb` asserts the order and the block bound |
| AC-2.4 | `git status --ignored --short \| grep -E 'doc\|yardoc'` prints `!! .yardoc/` and `!! doc/` only; `spec/project_config_spec.rb` checks both are ignored |
| AC-2.5 | Local: 9.28 s for the step. CI: **pending**, read from the `checks` job log of the pull request's run |
| AC-2.6 | the `bin/ci checks` run of AC-2.2 contains the warning lines with file and line, not only the exit status |
| AC-2.7 | `spec/script/yard/site_spec.rb` "fails the run, naming the page and the link, when a link points at a missing file" (output includes `docs/bad.md`, `missing.md`, `doesn't exist`; exit non-zero); `links_spec.rb` covers a missing file and a link out of the repository; with `--fail-on-warning` in `.yardopts` and the step in `bin/ci checks`, a dead link fails the step the same way as AC-2.2 |
| AC-2.8 | The step runs `bin/yard doc --no-cache` (the option clears the parse database first); the AC-2.2 failure happened with a `.yardoc/` from the clean run present. YARD's default already doesn't reuse the cache; the option guards against a `-c` added to `.yardopts` |

### Story 3: Nothing generated is committed or shipped

| AC | Evidence |
|---|---|
| AC-3.1 | `spec/project_config_spec.rb` "ignores the generated site and its cache"; `.gitignore` has `/doc/` and `/.yardoc/` |
| AC-3.2 | `.dockerignore` has `/doc`, `/.yardoc`, `/.yardopts`, `/bin/yard` under a comment saying why; the extension is under `/script`, already ruled out; `bin/yard` is the only binstub (written by hand, no `bin/yardoc` or `bin/yri`); checked in `spec/image_publishing_spec.rb` |
| AC-3.3 | `bin/image-smoke`'s `for path in …` list ends `… lib/collector/push_scope.rb doc .yardoc .yardopts bin/yard` and holds `script`, which holds the extension (by reading); `spec/image_publishing_spec.rb` "keeps YARD's output… out of the image" checks the rules and the list agree |
| AC-3.4 | Deviation: the extension's specs don't all `require "yard"` themselves: `links_spec.rb` runs without YARD and `site_spec.rb` runs YARD in a subprocess, which keeps the `defined?(YARD)` check in `project_config_spec.rb` independent of test order. `Gemfile`: `gem "yard", require: false` in `group :development` only; the `Dockerfile` has `BUNDLE_WITHOUT="development"`; `spec/project_config_spec.rb` checks the group, `autorequire` and the `Dockerfile` line |
| AC-3.5 | `Gemfile` edited, `bundle install` run (`Gemfile.lock` gained `yard 0.9.45`); `bin/bundler-audit`: no vulnerabilities; `bin/ci checks`'s "Security: Gem audit" passed |
| AC-3.6 | CI: **pending**, the pull request's image job (`bin/image-smoke`, both architectures) |
| AC-3.7 | `bin/rails zeitwerk:check`: "All is good!"; `spec/project_config_spec.rb` "keeps the extension and YARD out of the app's boot" (`Rails.autoloaders.main.dirs` has no `script/` path, `YARD` undefined) |

### Story 4: The documentation

| AC | Evidence |
|---|---|
| AC-4.1 | `CLAUDE.md` line 22 (the `bin/yard doc` line: what it writes, that a warning fails it and the step) and line 24 (`bin/ci`'s steps now list YARD); the Project Status paragraph is unchanged |
| AC-4.2 | `docs/adr/0027-yard-for-api-documentation.md`: sections Status, Context, Decision, Consequences in order; Status Accepted (2026-11-09); RDoc, no generated docs, the extension alternatives and coverage are weighed; decisions 1, 2 and 6 as ruled; `docs/adr/README.md` has `### Documentation` with the 0027 row and the Expected paragraph no longer names YARD |
| AC-4.3 | `docs/architecture/release-and-deploy.md`: the `bin/ci` steps line, "The image carries only what it runs", "`bin/image-smoke` fails an image", "The suite checks no prose document" (names `spec/project_config_spec.rb` and `spec/config/ci_definition_spec.rb`), Sources and Distillation log |
| AC-4.4 | `.claude/rules/conventions.md` lines 9–10: the `@see file:` form, Markdown comments, `{…}` in backticks, and that an unresolved `{…}` fails `bin/ci checks` |
| AC-4.5 | `docs/architecture/README.md`: a paragraph saying the area docs and ADRs are pages of the generated documentation (how to build it), with the known limits (an unmatched fragment is passed through, a dead `@see file:` isn't caught, `doc/` isn't cleared); its links stay plain relative ones |
| AC-4.6 | `docs/specs/README.md`: row 054, and spec 027's Superseded-by cell; `docs/roadmap.md`'s #103 line names spec 054 and ADR 0027 |
| AC-4.7 | spec 027's file is not edited (`git diff origin/main -- docs/specs/027-architecture-area-docs` is empty) |

## Observations

- YARD doesn't clear `doc/`: a page whose source was deleted leaves its generated file until `doc/` is removed (seen with the probe page). `doc/` is ignored and never shipped; recorded under the area doc's known limits.
- The fragment pass-through for a heading that matches none (plan review M4, coordinator's ruling) is a known limit, recorded in `docs/architecture/README.md`.
- `bin/yard` is not in `.claude/settings.json`'s allow list; workers run with permissions bypassed, so it prompted nowhere (coordinator, 2026-11-09).

## Implementation review

SPEC-ALIGNED WITH FOLLOW-UPS

Mode B review of the whole branch diff against origin/main (Opus, read-only), 2026-11-09, at `81d2397c`. No blocking or major findings. It ran `bin/yard doc --no-cache` into a scratch directory: exit 0, no `[warn]` line, 197 files, 61 modules, 210 classes, 838 methods, 53.70% documented, 35 file pages, every relative link of the included pages rewritten, `git status --ignored` unchanged. Open follow-ups (minor, none changes a verdict):

1. `release-and-deploy.md` Sources line: `#103` follows `#217`'s parenthesis with no separator.
2. `release-and-deploy.md` Distillation log row reads `spec 054: …`; the other rows read `Spec NNN (…)`.
3. `release-and-deploy.md` "The image carries only what it runs": the list lacks an "and" before the API documentation clause.
4. AC-3.4's clause that the extension's specs `require "yard"` themselves isn't literally met: `links_spec.rb` runs without YARD and `site_spec.rb` runs YARD in a subprocess, which keeps `project_config_spec.rb`'s `defined?(YARD)` check independent of test order. A deliberate deviation.
5. `script/yard/links.rb` leaves links with a title, angle-bracket targets, reference-style links and `~~~` fences untouched (none occurs in the docs today); a root-absolute link (`/foo.md`) is resolved against the filesystem root. Latent; list them as known limits or handle them.
6. `links_spec.rb` and `site_spec.rb` carry `type: :model`; the neighbouring script specs carry no type.
7. `ci_definition_spec.rb` finds the `unless` block's end by the first `end` line; also assert the step precedes `step "Security: Brakeman…"`.
8. ADR 0027 puts `### Options considered` inside Decision; ADRs 0020–0026 put `## Options considered` between Context and Decision.
9. The AC-1.8 row cites a second run before the extension existed; repeat it at the branch's head.
10. AC-2.5 and AC-3.6 are filled from the pull request's CI run.

### Follow-up disposition

Applied: 1, 2 and 3 (wording in `release-and-deploy.md`), 5 (the unsupported link forms are listed as known limits in `docs/architecture/README.md`; the regex is not widened, since none occurs in the docs and the spec doesn't ask for it), 7 (`ci_definition_spec.rb` also asserts the step precedes Brakeman), 9 (the AC-1.8 row). Recorded as deviation: 4 (AC-3.4 row). Skipped: 6 (the `type: :model` tags stay: `CLAUDE.md` says to tag spec types explicitly, and without the tag `RSpec/DescribeClass` fails the string `describe` of `site_spec.rb`); 8 (ADR 0027's `### Options considered` stays inside Decision; the ADR conventions in `docs/adr/README.md` fix the four sections and their order, which hold). Pending until CI: 10.
