# Implementation Plan: An Accurate README

**Spec:** docs/specs/020-readme-introduction/spec.md (v1.4.1, Approved, reviewed three times)
**Decisions:** no ADR. The spec's decisions 1 to 7 are the maintainer's rulings of 2026-10-12.
**Created:** 2026-10-12
**Status:** Draft, awaiting the maintainer's go-ahead.
**Revised:** 2026-10-12, after a read-only plan review (Opus, NEEDS REVISION, nothing blocking). The reviewer applied the Phase 0 diffs to scratch copies and ran them (25 then 22, 4, 9 and 25 examples, 0 failures; RuboCop clean apart from the path-based exclusion), ran the Phase 1 and Phase 3 check commands, and checked the introduction's claims against the app. Its findings, all applied: the environment-variable lookup searched `.kamal/secrets` and counted documents as readers; `tail -3` didn't show the example count; two diff hunks were cut two context lines short; the safety-warning check could false-alarm; the path check would have probed off-limits paths; the action table lacked three rows; four ordering slips.

**How this plan was made.** The three spec-file edits of Phase 0 were made on scratch copies and run from the worktree with the real `rails_helper`: `image_publishing_spec.rb` 22 examples, `design_system_files_spec.rb` 4, `export_format_document_spec.rb` 9, all `0 failures`. RuboCop reported only `RSpec/DescribeClass` on them, which is the path-based exclusion not matching a scratch path. The diffs below are those files' diffs. The introduction's text was counted (97 words) and its three section links checked against the README's headings. The sweep itself (Phase 3) is not done ahead: it is the work.

## Global Constraints

- No example is added that checks a prose document, and nothing replaces the ones removed (decision 7, FR-5).
- Outside the introduction, a README change is a listed correction and nothing else: only the words of the stale claim change, no paragraph is re-flowed, no heading changes (FR-2, AC-2.7, AC-2.8). The one allowed whitespace change is the padding before a trailing `#` comment in a code block.
- `CLAUDE.md` changes only where it repeats a README correction, plus the one Project Status sentence (FR-4, AC-2.9).
- The three safety warnings keep their text and position (Security, AC-3.8).
- Never read `.kamal/secrets`, `config/master.key`, `.env*` or `storage/`, by any tool. Claims about them are recorded as off-limits.
- A command is checked by reading its source. It is run only if it writes nothing outside `tmp/` and reads no off-limits file (glossary, Checkable). `bin/kamal` is not run. The suite (`bin/rspec`, `bin/ci`) is exempt: it writes the test database and `log/test.log`. `bin/rails -AT` and `bin/rails routes` write nothing.
- No search may reach an off-limits file. `.kamal/secrets` is tracked, so every `git grep` excludes it with `':!.kamal/secrets'`, and no `test -e`, `ls` or `grep` names `.kamal/secrets`, `config/master.key`, `.env*` or a path under `storage/`.
- Outputs kept for the record go to `tmp/020/` (ignored by git) until Phase 3 creates `verification.md`.
- No application code, configuration, other document under `docs/`, issue or roadmap line changes (Non-Goals, decision 6).
- Comparisons are against the merge base: `origin/main...HEAD` (`3ab9864` today). Run `git fetch origin` first.
- `bin/ci` passes at every commit. Commits are Conventional Commits, one per step that says "Commit", with the attribution trailer. Stage and commit in separate commands (the pre-commit hook reads the command text).

---

## Goal

`README.md` says what Collector is today and every checkable claim in it is true, `CLAUDE.md` no longer repeats its false claims, and no example in the suite checks a prose document.

**Pre-implementation gates.** Simplicity: no component is built; four spec files and three documents are edited. Anti-abstraction: nothing is wrapped. Integration-first: there is no contract; the two new examples are written and shown to fail before the file they replace is deleted.

**Facts established during planning, each checked in the worktree:**

- The suite has 1,219 examples (`bin/rspec --dry-run`). After Phase 0 it has 1,206: 8 + 3 + 2 + 2 removed, 2 added.
- `spec/image_publishing_spec.rb` asserts that `COLLECTOR_MTG_ART_MATCHING` is among the Compose service's environment keys (line 49) but not its value, and nothing asserts the commented line in `config/deploy.yml`, which `YAML.load_file` drops. So both of `readme_spec.rb`'s configuration expectations need a new example.
- Removing the examples leaves no unused `let`, helper or `require`. `.rubocop.yml` needs only its `spec/readme_spec.rb` line removed; its comment block names neither file.
- `spec/requests/home_spec.rb` doesn't exist. `spec/requests/health_check_spec.rb` does, and line 5 is inside its first example (lines 4 to 8).
- Catalog search needs sign-in: `Catalog::EntriesController` doesn't call `allow_unauthenticated_access`, and `Authentication` requires it by default.
- The README's headings give the anchors `#card-catalog`, `#card-scanner` (the `### Card scanner` under Self-hosting; the Development one is `#card-scanner-on-a-phone`) and `#accounts`.
- Local `main` in this worktree is behind `origin/main`, so every comparison names `origin/main`.
- Known before the sweep, from the spec reviews' samples: `COLLECTOR_PASSWORD` is in the Compose variable table but `compose.yaml` doesn't pass it to the container (a decision for the maintainer, Error Scenarios row 2); "avatar menu" (Accounts) and "account menu" (Card catalog) name one menu (Differing names); the Kamal section's claims about `.kamal/secrets` and `config/master.key` are off-limits; download sizes and durations are not checkable; the README has no "Using Collector" section (Gap).

---

## Phase 0: The suite checks no prose document

**Implements:** FR-5, decisions 3 and 7 | **Satisfies:** AC-4.1, AC-4.2, AC-4.3, AC-4.4, AC-4.5, AC-4.6, AC-4.7
**Files:** `spec/image_publishing_spec.rb`, `spec/readme_spec.rb` (deleted), `.rubocop.yml`, `spec/design_system_files_spec.rb`, `spec/export_format_document_spec.rb`, `.claude/rules/testing.md`
**Interfaces:** none. No code outside `spec/` is touched.

This phase comes first so that no later README correction is shaped by a pinned phrase. The two configuration expectations are moved before the file that holds them is deleted, so they are never unasserted.

- [ ] Add the two examples to `spec/image_publishing_spec.rb` (apply exactly):

```diff
@@ -50,6 +50,10 @@
         "SECRET_KEY_BASE", "SOLID_QUEUE_IN_PUMA", "HTTP_PORT", "COLLECTOR_MTG_LANGUAGES", "COLLECTOR_MTG_ART_MATCHING",
         "COLLECTOR_CURRENCY", "COLLECTOR_HTTPS", "COLLECTOR_TRUSTED_PROXIES")
     end
+
+    it "passes the art matching setting to the container, empty unless it is set (spec 011 AC-1.3)" do
+      expect(compose.read).to include('COLLECTOR_MTG_ART_MATCHING: "${COLLECTOR_MTG_ART_MATCHING:-}"')
+    end
   end
 
   describe "config/deploy.yml" do
@@ -62,6 +66,10 @@
       expect(deploy.dig("builder", "arch")).to eq("amd64")
       expect(deploy.dig("servers", "web")).to eq([ "192.168.0.1" ])
     end
+
+    it "offers art matching as a commented-out setting (spec 011 AC-1.3)" do
+      expect(Rails.root.join("config/deploy.yml").read).to include("# COLLECTOR_MTG_ART_MATCHING: true")
+    end
   end
 
   describe ".github/workflows/ci.yml" do
```

- [ ] Run: `bin/rspec spec/image_publishing_spec.rb` — expect: `25 examples, 0 failures` (the three `docs/releasing.md` examples are still there).
- [ ] Show each new example can fail (Testability). In `compose.yaml` line 22, change `"${COLLECTOR_MTG_ART_MATCHING:-}"` to `"true"`. Run: `bin/rspec spec/image_publishing_spec.rb -e "passes the art matching setting"` — expect: `1 example, 1 failure`. Keep the failure's first lines for `verification.md`. Run: `git checkout -- compose.yaml`.
- [ ] In `config/deploy.yml`, delete line 53 (`    # COLLECTOR_MTG_ART_MATCHING: true`). Run: `bin/rspec spec/image_publishing_spec.rb -e "offers art matching"` — expect: `1 example, 1 failure`. Keep the output. Run: `git checkout -- config/deploy.yml`, then `git status --short` — expect only `spec/image_publishing_spec.rb`.
- [ ] Commit: `test(image): keep the art matching configuration checks in the image publishing spec`.

- [ ] Delete `spec/readme_spec.rb` (`git rm spec/readme_spec.rb`) and remove this line from `.rubocop.yml`'s `RSpec/DescribeClass` exclusions:

```diff
-    - "spec/readme_spec.rb"
```

- [ ] Run: `git ls-files spec/readme_spec.rb; grep readme_spec .rubocop.yml` — expect: no output (AC-4.1). Run: `bin/rubocop` — expect: `no offenses detected`.
- [ ] Commit: `test: remove the README spec` with a body citing spec 020 decision 3.

- [ ] Remove the `docs/releasing.md` examples from `spec/image_publishing_spec.rb` (apply exactly; the line numbers are the file's after the first step; the file then ends with the `ghcr-cleanup.yml` describe's `end` and the outer `end`):

```diff
@@ -172,29 +180,4 @@
       expect(uses).to all(start_with("actions/").or(start_with("ruby/setup-ruby@")))
     end
   end
-
-  describe "docs/releasing.md" do
-    let(:doc) { Rails.root.join("docs/releasing.md").read }
-
-    it "records the release procedure and what each trigger publishes (AC-7.1)", :aggregate_failures do
-      expect(doc).to include("git tag -a v", "v0.1.0", "| Tag `vX.Y.Z` |", "| Push to `main` |", "| Pull request |")
-      expect(doc).to include("vX.Y.Z-<suffix>", "Only the newest release's workflow may be re-run")
-      expect(doc).to include("The workflow does not check that the tag is annotated or on `main`")
-    end
-
-    it "orders the go-public checklist and says it cannot be undone (AC-7.2)", :aggregate_failures do
-      positions = [ "Push the first image", "Verify an authenticated pull", "Confirm the package is linked",
-                    "Change the visibility to public", "Verify an anonymous pull" ].map { |step| doc.index(step) }
-      expect(positions).to all(be_a(Integer))
-      expect(positions).to eq(positions.sort)
-      expect(doc).to include("cannot be undone")
-    end
-
-    it "documents the cleanup: rule, grace period, schedule, manual and local runs, failures, token (AC-5.1)", :aggregate_failures do
-      expect(doc).to include("## Cleaning up untagged versions", "more than\n  7 days old", "**Never deleted:**")
-      expect(doc).to include("Sundays at 06:00 UTC", "The `dry_run` box is ticked by default")
-      expect(doc).to include('GH_TOKEN="$(gh auth token)" bin/ghcr-cleanup', "**A failed run failed closed:**")
-      expect(doc).to include("Investigate the cause before re-running", "personal access token (classic")
-    end
-  end
 end
```

- [ ] Run: `bin/rspec spec/image_publishing_spec.rb` — expect: `22 examples, 0 failures` (AC-4.2).
- [ ] Commit: `test(image): remove the examples that check docs/releasing.md`.

- [ ] Edit `spec/design_system_files_spec.rb` (apply exactly):

```diff
@@ -3,28 +3,10 @@
 RSpec.describe "Design system files" do
   let(:root) { Rails.root }
 
-  it "installs the export's stylesheets, fonts, logos, docs and skill", :aggregate_failures do
+  it "installs the export's stylesheets, fonts and logos", :aggregate_failures do
     %w[tokens components additions].each { |name| expect(root.join("app/assets/stylesheets/collector/#{name}.css")).to exist }
     expect(root.glob("app/assets/fonts/collector/*.woff2").size).to eq(4)
     expect(root.glob("app/assets/images/collector/*.svg").size).to eq(4)
-    %w[README.md tokens.json logos.md components/ItemPage.md previews/ItemPage.html].each do |path|
-      expect(root.join("docs/design-system", path)).to exist
-    end
-    expect(root.join(".claude/skills/collector-design-system/SKILL.md")).to exist
-    expect(root.join("CLAUDE.md").read).to include("## UI and design system", "collector-design-system")
-  end
-
-  it "documents every new pattern and lists it in the README", :aggregate_failures do
-    new_patterns = %w[StatusMessage Form AuthPage ConfirmPage SearchResults TileAdd FinishBadge FilterSelect Pager EmptyState
-      Details SingleStat MorePage AdminUsers TableActions SystemLogo
-      SortHeader StatusAction BulkConfirmPage ChoicePage BulkForm ViewSwitchForm TableItemLink Scanner
-      AdminJobs AdminCatalog StageList ProgressMeter
-      Footer]
-    readme = root.join("docs/design-system/README.md").read
-    new_patterns.each do |name|
-      expect(root.join("docs/design-system/components/#{name}.md")).to exist
-      expect(readme).to include("`#{name}`")
-    end
   end
 
   it "keeps colour literals and font families inside the design system directory" do
@@ -41,12 +23,6 @@
     let(:additions) { root.join("app/assets/stylesheets/collector/additions.css").read }
     let(:block) { additions[%r{/\* -+ Image fit \(spec 019\).*?(?=\n\n/\* -|\z)}m] }
 
-    it "documents the pattern, its three slots and that it overrides the export (AC-4.1, AC-4.2)", :aggregate_failures do
-      expect(root.join("docs/design-system/components/ImageFit.md").read).to include("`c-tile__media`", "`c-item__image`",
-        "`c-table__thumb`", "whole and in its own proportions", "`surface-sunken`", "overrides the export", "Upstream it")
-      expect(root.join("docs/design-system/README.md").read).to match(/^App additions \(spec 019, .*`ImageFit`.*Upstream it/)
-    end
-
     it "keeps the rules in one block of their own, with no colour literal or font (AC-4.3)", :aggregate_failures do
       expect(additions.scan("spec 019").size).to eq(1)
       expect(block).to include(".c-tile__media img, .c-item__image img { object-fit:contain; }",
```

- [ ] Run: `bin/rspec spec/design_system_files_spec.rb` — expect: `4 examples, 0 failures` (AC-4.3).
- [ ] Commit: `test(design-system): remove the examples that check documents`.

- [ ] Edit `spec/export_format_document_spec.rb` (apply exactly; the file then ends with the `coverage` describe's `end` and the outer `end`):

```diff
@@ -89,18 +89,4 @@
       ])
     end
   end
-
-  describe "the repository around it (AC-4.4)" do
-    it "is linked from the README" do
-      expect(Rails.root.join("README.md").read).to include("(docs/export-format/README.md)")
-    end
-
-    it "has its decision in the ADR index, no longer among the expected ones", :aggregate_failures do
-      adr_index = Rails.root.join("docs/adr/README.md").read
-
-      expect(adr_index).to include("[0020](0020-export-format.md)")
-      expect(adr_index[/^### Expected\n.*\z/m]).not_to include("export format")
-      expect(Rails.root.join("docs/adr/0020-export-format.md")).to exist
-    end
-  end
 end
```

- [ ] Run: `bin/rspec spec/export_format_document_spec.rb spec/export_format_examples_spec.rb` — expect: `25 examples, 0 failures` (AC-4.4).
- [ ] Commit: `test(export-format): remove the README link and ADR index examples`.

- [ ] Append to `.claude/rules/testing.md`, after its last line (`- ✗ Don't mock the object under test or stub ActiveRecord internals.`):

```markdown
- ✗ Don't check prose documents (`README.md`, `CLAUDE.md`, the files under `.claude/`, the Markdown and reference files under `docs/`) from RSpec; a document criterion is verified by reading and recorded in the spec's `verification.md`. The export format's document is the one exception (spec 020, decision 7).
```

- [ ] Commit: `docs(rules): don't check prose documents from RSpec`.
- [ ] Verify the phase:
  - `git diff --name-status origin/main...HEAD -- spec` — expect exactly: `D spec/readme_spec.rb`, `M spec/design_system_files_spec.rb`, `M spec/export_format_document_spec.rb`, `M spec/image_publishing_spec.rb` (AC-4.5).
  - `bin/rspec --dry-run | grep -E '^[0-9]+ examples'` — expect: `1206 examples, 0 failures` (AC-4.5).
  - `git diff --stat origin/main...HEAD -- .claude/rules/testing.md` — expect: one insertion, no deletions (AC-4.7).
  - `grep -rnE '\.md\b|docs/' spec --include='*.rb'` — expect only the lines AC-4.6 lists: the header comments of the image publishing and two export format specs, the `.dockerignore` rule list, `research.md §3` in `spec/models/mtg/collector_line_spec.rb`, and three lines of `spec/support/export_format_rules.rb`.
  - `bin/ci` — expect: every step passes.

---

## Phase 1: The introduction

**Implements:** FR-1 | **Satisfies:** AC-1.1 to AC-1.8, and AC-2.6 for the introduction's links
**Files:** `README.md` (lines 3 to 7)
**Interfaces:** none.

- [ ] Replace the README's first paragraph (from "Collector is a self-hostable" to "Accounts and collections are not built\nyet.") with exactly:

```markdown
Collector is a self-hostable, multi-tenant web app for tracking collectibles, starting with
Magic: The Gathering. Each person signs in to their own account and keeps their own collection.
Cards come from a catalog fed from Scryfall's bulk data (see [Card catalog](#card-catalog)): you
find a card by searching the catalog, or by reading it with the [card scanner](#card-scanner) on
a phone, and add it to your collection. An admin manages users and sign-up (see
[Accounts](#accounts)), starts and watches the catalog's refreshes, and sees, retries and
discards background jobs. Collector is pre-1.0; the [roadmap](docs/roadmap.md) says what is
built next.
```

- [ ] Check it, and keep each output for `verification.md`:
  - First sentence (AC-1.1): `ruby -e 'puts File.read("README.md").split(/\n\n/)[1].tr("\n", " ").start_with?("Collector is a self-hostable, multi-tenant web app for tracking collectibles, starting with Magic: The Gathering. ")'` — expect: `true`.
  - Read it against AC-1.2 to AC-1.4: "their own account and … their own collection"; "a catalog fed from Scryfall's bulk data", found "by searching" or "with the card scanner" and added; an admin "manages users and sign-up", "the catalog's refreshes" and "background jobs".
  - Word count (AC-1.7): `ruby -e 'p File.read("README.md").split(/\n\n/)[1].gsub(/\[([^\]]+)\]\([^)]+\)/, "\\1").split.size'` — expect: `97` (at most 130).
  - Banned words (AC-1.5): `ruby -e 'p File.read("README.md").split(/\n\n/)[1].scan(/not built|public/i)'` — expect: `[]`.
  - Links (AC-2.6): `grep -c -E '^## Card catalog$|^### Card scanner$|^### Accounts$' README.md` — expect: `3`; `test -f docs/roadmap.md && echo ok` — expect: `ok`.
  - Roadmap candidates (AC-1.6): read the paragraph against `docs/roadmap.md`'s open items; it names none (search, the scanner, accounts and the admin pages are built; exporting, importing, locations, typed entry, the open catalog and comics are not named).
  - What it says Collector does, and where (AC-1.8): accounts → `### Accounts`, `/session/new`, `/registration/new`; the collection → `/collection`; the catalog → `## Card catalog`; search → `/catalog/entries`; adding a card → `/catalog/entries/:entry_external_key/lots/new` and `POST /catalog/entries/:entry_external_key/quick_add`; the scanner → `### Card scanner`, `/scanner`; users and sign-up → `/admin/users`; refreshes → `/admin/catalog`; jobs → `/admin/jobs`. Confirm each route with `bin/rails routes -g 'session|registration|collection|catalog|scanner|lots|admin'`.
- [ ] Commit: `docs(readme): say what Collector does today in the introduction` with `Refs #63` in the body.

---

## Phase 2: The corrections known before the sweep

**Implements:** FR-2 (one correction), FR-4 | **Satisfies:** AC-2.5, AC-2.9, AC-2.10
**Files:** `README.md` (lines 114 and 115 today; 117 and 118 after Phase 1), `CLAUDE.md` (lines 7 and 20)
**Interfaces:** none.

- [ ] In `README.md`'s Testing and CI code block, replace the two command lines with exactly (the first line's padding grows by eight spaces to keep the comments aligned, the exception AC-2.7 allows):

```sh
bin/rspec                                       # full suite
bin/rspec spec/requests/health_check_spec.rb:5  # a single file or example
```

- [ ] In `CLAUDE.md`'s Commands list, replace `bin/rspec spec/requests/home_spec.rb:5` with `bin/rspec spec/requests/health_check_spec.rb:5` (decision 5, AC-2.10).
- [ ] Run: `bin/rspec spec/requests/health_check_spec.rb:5` — expect: `1 example, 0 failures`.
- [ ] Commit: `docs: name a spec file that exists in the single-spec example`.
- [ ] In `CLAUDE.md`'s Project Status, in the sentence beginning "Feature 002 added", replace `and a public card search proof-of-concept at \`/catalog/entries\`.` with exactly:

```markdown
and a card search at `/catalog/entries`, which has needed sign-in since accounts (spec 004).
```

- [ ] Commit: `docs(claude): say catalog search needs sign-in`.
- [ ] Run: `git diff --word-diff origin/main...HEAD -- CLAUDE.md` — expect changed words only in that sentence and in the Commands example (AC-2.9).

---

## Phase 3: The sweep

**Implements:** FR-2, FR-3, FR-4 (repeats of later corrections) | **Satisfies:** AC-2.1 to AC-2.4, AC-2.6 to AC-2.8, AC-3.1 to AC-3.5, AC-3.8
**Files:** `README.md` (corrections only), `CLAUDE.md` (repeats only), `docs/specs/020-readme-introduction/verification.md` (new; the record is filled in as the sweep goes)
**Interfaces:** none.

**Method, for every section.** Read the section. Split each sentence, list item, table row, command and code comment into its claims. Sort each claim by the glossary: checkable, not checkable, or off-limits. For a checkable claim, read the evidence and record the result as true, stale or not refuted. Count the claims. Then act:

| Result | Action in the README | Entry in the record |
|---|---|---|
| True | none | counted in its section's row |
| Not refuted (says something never happens or always holds; no counter-example found) | none | Not refuted list, with what it was checked against |
| Stale, and the smallest true wording is plain | change only that claim's words; don't re-flow | Corrections list: old text, new text, evidence |
| Stale, but a spec or ADR states the behaviour the README describes (the code is wrong) | none | Left stale list, with that spec or ADR |
| Stale or misleading, and the fix needs a choice | none yet; add it to the questions for the maintainer | Left stale list with the ruling, or Corrections list if a correction is ruled |
| Not checkable | none | Not checkable list, with the reason |
| Off-limits | none | Off-limits list |
| Something an operator or contributor would need is missing | none | Gaps list |
| Two true claims name one thing differently | none | Differing names list |
| A link whose target heading or file doesn't exist | correct the link to the heading or file it meant; rename no heading | Corrections list |
| A safety warning is itself stale | none; put it to the maintainer | Left stale list with the ruling, or Corrections list if a correction is ruled |
| A never-or-always claim, and a counter-example is found | treat it as stale (the three stale rows above) | as for stale |

In the record, for every section: Claims checked = True + Not refuted + Corrected + Left stale + Not checkable + Off-limits. Gaps and differing names are not claims.

After each correction, search `CLAUDE.md` for the corrected command, path, variable or phrase (`grep -n -F '<term>' CLAUDE.md`). Record the term and the result. Change `CLAUDE.md` only where it makes the same claim.

**Sections, and what each is checked against:**

| # | Section | Checked against |
|---|---|---|
| 1 | Text before the first `##` (the introduction is Phase 1; the "Built with" paragraph is swept here) | `Gemfile`, `Gemfile.lock`, `config/importmap.rb`, `config/database.yml`, `config/cable.yml`, `config/environments/production.rb` |
| 2 | Requirements | `.ruby-version`, `Gemfile`, `spec/support/` (the system specs' driver), `lib/collector/libvips_check.rb`, `bin/setup`, ADRs 0012 and 0013 for the two ADR numbers |
| 3 | Development | `bin/setup`, `bin/dev`, `config/database.yml`, `config/puma.rb`, `bin/jobs` |
| 4 | Worktrees | `bin/setup`, `lib/collector/worktree_setup.rb`, `lib/collector/dev_port.rb`, `.githooks/post-checkout`, `.worktreeinclude`, `orca.yaml` |
| 5 | Card scanner on a phone | `bin/fetch-ocr-engine`, `bin/dev-certificate`, `config/environments/development.rb`, `config/routes.rb`, `lib/collector/dev_certificate.rb`, `lib/tasks/scanner.rake`, `script/scanner/replay.rb`, `script/scanner/photo_run.rb`, `app/controllers/scanners_controller.rb`, `app/controllers/scanner/`; the iPhone steps and browser behaviour are not checkable |
| 6 | Testing and CI | `config/ci.rb`, `bin/ci`, `.github/workflows/ci.yml`, `.github/dependabot.yml`, `spec/rails_helper.rb`, `spec/support/`, `spec/cassettes/`, `docs/releasing.md` exists |
| 7 | Self-hosting (to the first `###`) | `Dockerfile`, `.github/workflows/ci.yml`, `docs/releasing.md`, `app/controllers/concerns/first_run.rb`; the registry's state is not checkable |
| 8 | Docker Compose | `compose.yaml` (each variable, default, port, volume, healthcheck), `Dockerfile` (uid), `config/database.yml`, `lib/collector/currency.rb`, `config/initializers/currency.rb`, `config/environments/production.rb` for `COLLECTOR_HTTPS`, `config/application.rb` and `lib/collector/trusted_proxies.rb` for `COLLECTOR_TRUSTED_PROXIES`, `lib/tasks/collector.rake` for `COLLECTOR_PASSWORD`, `bin/docker-entrypoint` |
| 9 | Kamal | `config/deploy.yml` (server, registry, aliases, volume, env), `bin/kamal`; `.kamal/secrets` and `config/master.key` are off-limits; Kamal's own behaviour is not checkable |
| 10 | Card scanner (under Self-hosting) | `config/routes.rb`, `app/controllers/ocr_assets_controller.rb`, `bin/fetch-ocr-engine`, `Dockerfile`, `app/javascript/scanner/`, `app/controllers/scanners_controller.rb`, `app/controllers/scanner/`, `config/deploy.yml`; "Photos never leave the phone" is a not-refuted check against the scanner's controllers and JavaScript |
| 11 | Accounts | `lib/tasks/collector.rake`, `app/models/user/command.rb`, `app/controllers/registrations_controller.rb`, `app/controllers/admin/` (with `sign_up_settings_controller.rb`), `app/views/layouts/_appbar.html.erb`, `app/views/mores/`, `compose.yaml` |
| 12 | Upgrading to accounts | `app/controllers/concerns/first_run.rb`, `bin/docker-entrypoint`, `config/deploy.yml` |
| 13 | Card catalog | `lib/tasks/catalog.rake`, `config/deploy.yml` aliases, `config/recurring.yml`, `app/models/catalog/refresh_run.rb`, `app/jobs/catalog/refresh_job.rb`, `app/models/mtg/scryfall/source.rb`, `app/models/mtg/art.rb`, `app/models/mtg/art/`, `app/controllers/admin/`, `app/views/admin/`, `app/views/layouts/_appbar.html.erb`, `app/views/mores/show.html.erb`; sizes and durations are not checkable |
| 14 | Your data | `docs/export-format/README.md`, `docs/export-format/v1.schema.json`, `docs/export-format/examples/`; no export or import route in `config/routes.rb` |
| 15 | License | `LICENSE` |

**Mechanical checks, run once over the whole file before reading section by section:**

- [ ] Scripts exist: `grep -oE '\bbin/[a-z-]+' README.md | sort -u | while read f; do test -e "$f" || echo "MISSING $f"; done` — expect: no output. This proves only that the `bin/` names exist; the two `script/scanner/` files and each command's arguments are checked by reading, in their sections (AC-2.2).
- [ ] Rake tasks exist: `bin/rails -AT | grep -E 'collector:user|catalog:refresh|catalog:status|scanner:findings|scanner:sitting_findings'` — expect: five lines.
- [ ] Kamal subcommands: `grep -oE 'bin/kamal [a-z-]+' README.md | sort -u` — for each that isn't `config`, `setup`, `deploy` or `app`, expect a key under `aliases:` in `config/deploy.yml`.
- [ ] Environment variables: `grep -oE '\b[A-Z][A-Z0-9]+(_[A-Z0-9]+)+\b' README.md | sort -u`, plus `PORT` and `HOME`, which the pattern misses (no underscore). For each: `git grep -l -w "<NAME>" -- ':!README.md' ':!CLAUDE.md' ':!docs' ':!spec' ':!spikes' ':!.claude' ':!.kamal/secrets'`. A name with no reader in the repository is checked against Rails, Puma, Kamal or the shell, and the record cites which (AC-2.4). Expected: every name has a tracked reader except `HOME` (the shell); `KAMAL_REGISTRY_PASSWORD` is only named in `config/deploy.yml`, and its reader is off-limits.
- [ ] Paths and routes: list the paths with ``grep -oE '`[^` ]*[/.][^` ]*`' README.md | sort -u``. Do not `test -e` `.kamal/secrets`, `config/master.key`, `.env` or anything under `storage/`: record the first three as off-limits, and check each `storage/…` path, and every other run-time path, against the code that writes it (AC-2.3). For the rest, `test -e`. For each URL path (`/scanner`, `/scanner/measurement`, `/admin/catalog`, `/admin/jobs`, `/catalog/entries`, `/up`, `/ocr/v7.0.0/`), `bin/rails routes -g '<path>'`.
- [ ] Links (AC-2.6): `ruby -e 'r = File.read("README.md"); heads = r.gsub(/^```.*?^```/m, "").scan(/^#+ (.+)$/).flatten.map { |h| h.downcase.gsub(/[^a-z0-9 -]/, "").tr(" ", "-") }; r.scan(/\]\(([^)]+)\)/).flatten.uniq.each { |l| ok = l.start_with?("http") || (l.start_with?("#") ? heads.include?(l[1..]) : File.exist?(l)); puts "#{ok ? "ok  " : "BAD "} #{l}" }'` — expect: every line `ok`.

**Then the sweep:**

- [ ] Create `verification.md` with the skeleton in Phase 4 and fill the section table and lists as each section is swept.
- [ ] Sweep sections 1 to 15 in order by the method above. Commit each README correction on its own (`docs(readme): <what was corrected>`), with its `CLAUDE.md` repeat in the same commit when there is one.
- [ ] Put the questions that need a ruling to the maintainer in one message, each with the claim, the evidence and a recommended correction. Known already: `COLLECTOR_PASSWORD` in the Compose variable table. Apply the rulings, one commit each.
- [ ] Record the safety warnings (AC-3.8): `diff <(git show origin/main:README.md | grep -E 'first person to reach|only acceptable on a trusted private network|Never run a plain') <(grep -E 'first person to reach|only acceptable on a trusted private network|Never run a plain' README.md)` — expect: no output (the four lines are whole and unchanged; the first-run warning appears twice). Record each line's number at the merge base and at `HEAD`, and its position: "Before you expose Collector" is before `### Docker Compose`; the **HTTPS** bullet is the last bullet before `### Kamal`; the "Never run a plain" paragraph is between Kamal's step 4 and "Data is stored in"; "Read this before you upgrade" is before "1. Pull the new image". A warning that is itself stale goes to the maintainer.
- [ ] Check the diff (AC-2.7): `git diff --word-diff origin/main...HEAD -- README.md` and `git diff origin/main...HEAD -- README.md` — every changed word and line outside the introduction belongs to a correction in the record.
- [ ] Check the headings (AC-2.8): `diff <(git show origin/main:README.md | ruby -e 'puts STDIN.read.gsub(/^```.*?^```/m, "").scan(/^#+ .+$/)') <(ruby -e 'puts File.read("README.md").gsub(/^```.*?^```/m, "").scan(/^#+ .+$/)')` — expect: no output.
- [ ] Check `CLAUDE.md` (AC-2.9): `git diff --word-diff origin/main...HEAD -- CLAUDE.md` — every changed word is in the Project Status sentence or a recorded repeat.
- [ ] Check the lists (AC-3.3): for each claim in the Not refuted, Not checkable and Off-limits lists, its line is not among the changed lines of `git diff origin/main...HEAD -- README.md`.

---

## Phase 4: The record

**Implements:** FR-3 | **Satisfies:** AC-3.1 to AC-3.8
**Files:** `docs/specs/020-readme-introduction/verification.md`
**Interfaces:** none.

- [ ] Complete `verification.md` with these sections, in this order:

```markdown
# Verification: An Accurate README (spec 020)

**Spec:** [spec.md](spec.md) v1.4.1 · **Plan:** [plan.md](plan.md) · **Recorded:** <date> ·
**Branch:** `020-readme-introduction` · **Issue:** [#63](https://github.com/plainprogrammer/Collector/issues/63)

## Commits
<`git log --oneline origin/main..HEAD`, up to the record's own commit>

## The suite (Story 4)
<per file: examples before and after; the two fail-first outputs; the three Phase 0 verification commands and their output>

## The introduction (Story 1)
<the paragraph; word count; banned-word search; each thing it says Collector does with its README section or route>

## The sweep, by section
| Section | Claims checked | Checked against | True | Not refuted | Corrected | Left stale | Not checkable | Off-limits |

## Corrections
| # | File and line | Old text | New text | Evidence | Searched in `CLAUDE.md` for | Result |

## Not refuted
| Claim | Checked against |

## Not checkable
| Claim | Reason |

## Off-limits
| Claim | File |

## Questions and rulings
| Claim | Evidence | Recommendation | Ruling |

## Left stale
| Claim | Evidence it is stale | Reason (spec or ADR, or the maintainer's ruling) |

## Gaps
<entries, or "none"; includes the missing "Using Collector" section>

## Differing names
<entries, or "none"; includes "avatar menu" and "account menu">

## Safety warnings
<four rows: the first-run warning twice, plain HTTP, plain `bin/kamal deploy`>
| Warning | Line at merge base | Line at HEAD | Text unchanged | Position unchanged |

## Diff checks
<the word diffs of README.md and CLAUDE.md, the heading comparison, the link check, and that no listed unchanged claim's line changed>

## `bin/ci`
<the final run's summary>

## Acceptance criteria
| AC | Evidence | Result |
```

- [ ] Fill the Acceptance criteria table with one row per AC of the spec (AC-1.1 to AC-4.7), each pointing at the section of the record or the command output that shows it.

---

## Integration Verification

- [ ] Run: `git fetch origin && bin/ci` — expect: every step passes (AC-3.6). Put the summary in the record.
- [ ] Run: `git diff --name-status origin/main...HEAD` — expect only: `README.md`, `CLAUDE.md`, `.rubocop.yml`, `.claude/rules/testing.md`, the four spec files, `.claude/memory/` entries, and `docs/specs/020-readme-introduction/`. `docs/roadmap.md` is not listed (AC-3.4).
- [ ] Commit: `docs(020): record the sweep and its evidence`.
- [ ] Run `sdd-superpowers:sdd-review` in implementation mode with a read-only Opus reviewer, then `sdd-superpowers:session-wrap`, before the PR is marked ready.
- [ ] Open the PR. Its description closes #63 (`Closes #63`), names the removal of the prose-document checks as a second outcome (decision 7), and lists the questions ruled on during the sweep (AC-3.7).

## Quickstart Validation

- [ ] Read the README's first screen on the branch's GitHub page: the introduction's three section links and the roadmap link resolve.
- [ ] Run the corrected single-spec command from the README as written: `bin/rspec spec/requests/health_check_spec.rb:5` — expect: `1 example, 0 failures`.
