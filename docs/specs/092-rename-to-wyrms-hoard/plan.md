# Implementation Plan: Rename the Application to Wyrm's Hoard (spec 092, issues #433 to #440, #445)

**Spec:** `docs/specs/092-rename-to-wyrms-hoard/spec.md` (Approved v0.6.0) · **ADRs:** [0032](../../adr/0032-the-rename-is-a-clean-break.md), [0033](../../adr/0033-the-image-moves-to-a-new-package.md) (Accepted) · **PRD:** [prd.md](prd.md) · **Created:** 2026-11-14
**Status:** Approved (2026-11-14, the maintainer, after two read-only reviews). Written in the main session (Opus). Plan review round 1 (Fable, read-only): REVISE (8 blocking, 5 major, 13 minor); round 2 (Fable, read-only): REVISE (2 blocking, 4 major, 7 minor). Both rounds' findings are fixed in this version.
**Branches:** the documents on `092-rename-to-wyrms-hoard` (pull request #446); then one branch per pull request of spec decision 1: `092-rename-comments` (A), `092-rename-internal-names` (B), `092-rename-operator-contract` (C), `092-rename-display-name` (D), each cut from `main` after the previous one merged.

## Context

The spec splits the rename into a repository rename, four pull requests and a release. Each pull request is a phase here. Each one leaves `main` green and is checked before the next starts (spec decision 1). The phases are sequential: B can't start before A has merged, because the comment ratchet compares B with the `main` that holds A's comments.

Facts the tasks rely on, read on `main` at `50435ba3` (and the branch at `13bc8faf`):

- **The ratchet** (`script/yard/comment_ratchet.rb`) parses the judged files (`app/models/`, `app/helpers/`, `app/*/concerns/`, `lib/`, `spec/support/`) at the head and at the merge base and compares each public object's text by qualified name. A renamed object counts as added and must have a summary. A changed object counts as changed and needs one too. Its internals `YardRatchet::Scope`, `Snapshot.build(root, files)` and each item's `file`, `line`, `name`, `exempt`, `commented` and `extents` are what the list script in T1.1 reads; the spec review ran that script.
- **`config/ci.rb`'s `bin/ci checks` steps**, in order: the upgrade guard, RuboCop, YARD, the ratchet, Brakeman, the bundler audit, the importmap audit, the licence check. `spec/config/ci_definition_spec.rb` places each step by line index.
- **Brakeman:** `config/brakeman.ignore` holds a `SendFile` warning for `app/controllers/ocr_assets_controller.rb`. Its fingerprint and `code` name `::Collector::OcrEngine`, so renaming the module changes the fingerprint.
- **Development prices database:** query log tags write `/*application='Collector'*/` into the five `CREATE` statements of `db/prices_structure.sql` (lines 4, 6, 13, 20, 25). `spec/prices_schema_spec.rb:85` reads one.
- **Backup names:**
  - `Create::PARTIAL` (`lib/collector/backup/create.rb:21`) is the sweep's one pattern.
  - The final name is built at `create.rb:45`.
  - `Restore::TEMPORARY` and `TEMPORARY_PRICES` are at `restore.rb:17-18`.
  - `restore.rb:83` removes a stopped run's temporaries with `Backup.remove(path, RESTORE_SUFFIXES)`.
  - The refusal hint is at `archive.rb:162`; the usage hint at `lib/tasks/backup.rake:18`.
  - `Databases#occupied` doesn't read temporary names.
- **The upgrade proof:** `Upgrade::Harness::REPOSITORY` is at `script/upgrade/harness.rb:26`, and `parse` defaults `repository:` to it at `:54`. The release image is composed at `:142` (`"#{@options.repository}:#{version.number}"`). The backup leg expects `Backup written: /backups/collector-backup-` at `:464`.
- **Setting readers:**
  - Settings that take an environment hash: `Catalog.public_in?(env)` (`PUBLIC_ENV`), `MTG::Art.enabled_in?(env)` (`ENV_NAME`), `MTG::Scryfall::Source.new(client:, env:)` (`LANGUAGES_ENV`, `#languages`), and `Collector::BuildFacts.read(env:, rails_env:)`.
  - Settings read straight from `ENV`: `config/initializers/currency.rb:5`, `config/application.rb:52` (trusted proxies), `config/environments/production.rb:28` and `development.rb:100` (HTTPS), `development.rb:87-95` (the scanner and request log settings), `lib/tasks/collector.rake:4` (password), `lib/collector/dev_certificate.rb:10`, `script/worktree/with_mise:30`, `spec/system/art_agreement_spec.rb:8`.
- **The app bar:**
  - The signed-in header has five links. The visitor's header has one link. The brand app bar (`_brand_appbar.html.erb`) has none.
  - `_appbar_logos.html.erb` draws the wordmark SVGs in `.c-appbar__wordmark` and the mark in `.c-appbar__mark`.
  - The phone rule hides the wordmark below 640px (`components.css:225-226`). The five-link swap runs from 640px to 719px (`additions.css:220-222`).
  - The guard is `spec/system/design_system_deck_rules_spec.rb:209-240`, with `open_in_narrow_frame`, `header_fit`, `header_fits?` and `logo`.

## Global Constraints

- **Repo rules:** `CLAUDE.md` and `.claude/rules/*.md`. Spec types are tagged; multi-expectation examples use `:aggregate_failures`; `RSpec/ExampleLength` max 15; specs under `lib/` and `script/` are `type: :model`, task specs `type: :task`.
- **Spellings (spec decision 2), and nothing else:** `Wyrm's Hoard` (straight apostrophe), `WyrmsHoard`, `wyrms_hoard`, `WYRMS_HOARD_`, `wyrms-hoard`; `wyrmshoard` only in `plainprogrammer/wyrmshoard` and `ghcr.io/plainprogrammer/wyrmshoard`. No inflection rule.
- **Stays (spec decision 10):** the collector line (`collector_number`, `collector_text`, `collector_line`, `CollectorLine`, the strip key `collector` and kin), the person ("a collector", `collector?`, `let(:collector)`), `MimeResponds::Collector`, the card set's name, `collector-export`, `urn:collector:` and `collector-export-<date>.json`. The `c-` CSS prefix stays.
- **Never edited (spec decision 15, Non-Goals):** `db/migrate/`, `spikes/`, `.kamal/`, shipped specs and their contracts (`docs/specs/0*/` except this spec's folder), accepted ADRs (`docs/adr/0*.md`), `docs/lessons/`, `docs/superpowers/`, `docs/screenshots/`, and the upgrade notes that were in release 0.3.0's `docs/releasing.md`. Every bulk text command below names its files with a pathspec that leaves these out.
- **One pull request per phase, in decision 1's order;** each pull request carries the documents of what it changes (decision 7).
- **One commit per task, test first:** red, implement, green, RuboCop. Conventional Commits naming the phase's issue, for example `refactor(rename): … (#436)`, with the attribution trailer in force at commit time.
- **Git:** one git operation per shell call, and `git add` in a call of its own, never chained with `git commit` (memory: pre-commit hook staging, worktree command guard). `git mv` is a git operation.
- **Line numbers** into `lib/collector/` are from `50435ba3`; after pull request A adds comments they shift, so a task finds its line by the quoted text.
- **Implementers** run on Opus. Each takes the 2 to 4 consecutive tasks its phase gives it and reads this plan by line range. The coordinator (the main session) checks each batch's diff, runs `bin/ci`, pushes, opens the pull request, and brings permission prompts to the maintainer.
- **Not run by an agent:** the `sqlite3` command, `bin/rails console`, `bundle add` or `update`, `bin/importmap pin`, a read of `.kamal/`, `config/master.key`, `.env*` or `storage/`. Where a task needs a Rails task that writes the development database (T2.5), the coordinator runs it.
- **Shared test database:** one test run at a time in a worktree. A targeted `bin/rspec <file>` needs no slot; a full `bin/ci` and a push are the coordinator's.
- **Comments:** every public class, module and method a phase adds or changes has a summary (the ratchet), with `@param`/`@return` on reusable code and `@see file:<area doc>.md`. No `{…}` outside YARD links. Core files name no collectible (`spec/*_core_spec.rb`).
- **UI:** the `wyrms-hoard-design-system` skill (named `collector-design-system` before B) and `docs/design-system/README.md` apply to T4.6. The new pattern goes in `additions.css` with a component doc. Pull request D carries screenshots at desktop and phone widths in both themes (memory: PR visual evidence).

## Goal

The application, its code, its operator's settings, command, volume, service and backups, its image and its living documents all use the new name, and nothing made before the rename stops being readable. The upgrade from 0.3.0 is proven in CI and written down. A `bin/ci checks` step keeps the old name out of the code and the agent's instructions. Release 0.4.0 is published at `ghcr.io/plainprogrammer/wyrmshoard`.

## Pre-implementation gates

- **Simplicity (≤3 components): pass.** The only new code is (1) the old-name check (`script/old_name/check.rb` with its spec and a `bin/ci checks` step) and (2) the text wordmark (a partial's markup and one CSS pattern). The rest renames what exists, plus two rules: the backup sweep's two prefixes, and the upgrade proof's repository by version.
- **Anti-abstraction: pass.** The check is one script with its forms and exclusions as frozen data, shaped like the comment ratchet. No wrapper is added around a setting's read; each reader keeps its injection point.
- **Integration-first: pass.** Each phase begins with the specs that fail on the old names (renamed constants, renamed settings, new backup names, the repository rule, display strings, the check's injected forms). The rename that makes them pass comes after.

## Files

| Phase | File | Change |
|---|---|---|
| 1 (A) | `lib/collector/**/*.rb`, `app/helpers/scanners_helper.rb`, `spec/support/backup_helpers.rb` | comments only |
| 2 (B) | `lib/collector/` → `lib/wyrms_hoard/`; `spec/lib/collector/` → `spec/lib/wyrms_hoard/`; `lib/tasks/collector.rake` → `lib/tasks/wyrms_hoard.rake`; `spec/tasks/collector_rake_spec.rb` → `spec/tasks/wyrms_hoard_rake_spec.rb`; `app/assets/{stylesheets,fonts,images}/collector/` → `…/wyrms_hoard/`; `.claude/skills/collector-design-system/` → `.claude/skills/wyrms-hoard-design-system/` | moved |
| 2 (B) | every file that names those paths or `Collector::` (code, config, `.dockerignore`, `.rubocop.yml`, `bin/image-smoke`, `.claude/hooks/pre_push_ci.rb`, `spec/support/runtime_log.txt`, `config/third_party_licences.yml`, tokens, living documents), `config/brakeman.ignore`, `db/prices_structure.sql`, `bin/backup-smoke` (cookie name), `spec/rename_internal_names_spec.rb` (new) | edited |
| 3 (C) | the setting readers and their specs; `lib/tasks/wyrms_hoard.rake` and its spec; `compose.yaml`, `config/deploy.yml`, `Dockerfile`, `.github/workflows/ci.yml`, `.github/workflows/ghcr-cleanup.yml`, `bin/image-smoke`, `bin/backup-smoke`, `bin/ghcr-cleanup`, `script/backup/measure.rb`; `lib/wyrms_hoard/backup/{create,restore,archive}.rb`, `lib/tasks/backup.rake`; `script/upgrade/harness.rb`; `lib/wyrms_hoard/ghcr_cleanup.rb`; `lib/wyrms_hoard/dev_certificate.rb`; `spec/old_settings_spec.rb` (new); `README.md`, `CLAUDE.md`, `docs/architecture/*.md`, `docs/backup-restore.md`, `docs/releasing.md`, `docs/north-star.md`, `.claude/memory/steering/tech-stack.md`; `docs/specs/README.md` (cells) | edited |
| 4 (D) | `script/old_name/check.rb` (new), `spec/script/old_name/check_spec.rb` (new), `config/ci.rb`, `spec/config/ci_definition_spec.rb`; views with titles and labels; `app/views/layouts/_appbar_logos.html.erb`, `_brand_appbar.html.erb`, `_appbar.html.erb`, `application.html.erb`; `app/views/pwa/manifest.json.erb`; `app/assets/stylesheets/wyrms_hoard/additions.css`; the mark SVGs (renamed) and the wordmark SVGs (deleted); `lib/wyrms_hoard/build_facts.rb`; message strings; User-Agents; `.yardopts`; the export schemas' titles; `script/yard/links.rb`; `docs/design-system/**`; the living documents; `.claude/rules/testing.md`; `docs/specs/README.md`; `docs/specs/092-rename-to-wyrms-hoard/verification.md` (new) | edited |

---

## Phase 0: The repository is renamed (#435)

**Implements:** decision 1 step 1 | **Satisfies:** AC-8.6
**Files:** none in the tree.
**Interfaces:** Consumes: pull request #446 merged (the spec and this plan on `main`). Produces: the repository `plainprogrammer/wyrmshoard`, which every later phase's URLs name.

The maintainer renames the repository, or tells the coordinator to. CI keeps publishing to the old package, because `ci.yml` still names it.

- [ ] T0.1 Merge #446 once the maintainer has approved this plan. CI must be green.
- [ ] T0.2 On the maintainer's go-ahead, run `gh repo rename wyrmshoard --yes`. Expect: `✓ Renamed repository plainprogrammer/wyrmshoard`.
- [ ] T0.3 Point the local remote at the new name: `git remote set-url origin git@github.com:plainprogrammer/wyrmshoard.git`. Then run `git remote -v`; expect both lines to name `plainprogrammer/wyrmshoard.git`.
- [ ] T0.4 Check the redirect: `curl -sI https://github.com/plainprogrammer/Collector | grep -i '^location'`. Expect: `location: https://github.com/plainprogrammer/wyrmshoard`. Record the output for `verification.md` (it is written in T4.9; keep the output in the coordinator's notes until then).
- [ ] T0.5 Comment on #435 with T0.2 to T0.4's output and close it. A push and a CI run on the renamed repository are proven by pull request A's first push and its merge (AC-8.6).

---

## Phase 1: Pull request A, the summary comments the rename needs (#445)

**Implements:** FR-1 | **Satisfies:** AC-1.1, AC-1.2, AC-1.3, and AC-1.4 (proved in Phase 2)
**Files:** `lib/collector/**/*.rb` (comments), `app/helpers/scanners_helper.rb`, `spec/support/backup_helpers.rb`
**Interfaces:** Consumes: nothing. Produces: a `main` on which every public object under `lib/collector/`, plus `ScannersHelper#ocr_engine_path` and `BackupHelpers#release_versions`, `#restore_backup` and `#scratch_root`, has a summary comment, so the ratchet passes phases 2 to 4 unchanged.

Branch `092-rename-comments` from `main`. Implementer 1 takes T1.1 and the first two commits of T1.2 (`lib/collector/backup/`); implementer 2 takes T1.2's other commits and T1.3. The coordinator splits T1.1's list between them at the directory boundary.

- [ ] **T1.1 List what the ratchet will judge.** Write `tmp/092_comment_list.rb`. It is not committed (`tmp/` is ignored).

  ```ruby
  # Lists the public objects the comment ratchet will judge in spec 092's rename and finds without a summary: every
  # object under lib/collector/ (renamed, so "added"), and any other judged object whose text names an old form
  # (changed). Run from the repository root: ruby tmp/092_comment_list.rb
  require "bundler/setup"
  load File.join(Dir.pwd, "script/yard/comment_ratchet.rb")

  OLD = %r{Collector::|module Collector|lib/collector|COLLECTOR_|collector[-:](?:backup|restore|user|smoke|local|dev|measure|ghcr|mark|wordmark)|plainprogrammer/collector|github\.com/plainprogrammer/Collector|\bCollector\b(?!\s+(?:numbers?|lines?|strip|Showcase))|"collector/|collector_storage|_collector_session}

  files = `git ls-files`.split("\n").select { YardRatchet::Scope.include?(it) }
  snapshot = YardRatchet::Snapshot.build(Dir.pwd, files)
  rows = snapshot.items.each_value.filter_map do |item|
    next if item.exempt || item.commented
    "#{item.file}:#{item.line} #{item.name}" if item.file.start_with?("lib/collector/") || item.extents.any? { OLD.match?(it) }
  end
  puts rows.sort
  puts "#{rows.size} objects"
  ```

  Run `ruby tmp/092_comment_list.rb > tmp/092_comment_list.txt; tail -1 tmp/092_comment_list.txt`. Expect `98 objects`: the 94 under `lib/collector/` and the 4 outside it of AC-1.2. A different count means the tree moved since `50435ba3`; the list is the truth, and the count goes into the pull request's description.
- [ ] **T1.2 Write the summaries,** in three commits: `lib/collector/backup/` and `lib/collector/backup.rb`; the rest of `lib/collector/`; and the four outside it.
  - **What to write:** follow `.claude/rules/code-documentation.md`. Say what the object gives its caller and why, not what the code does. Add `@param` and `@return` on reusable methods. Mark a helper with one caller `@api private`. Add `@see file:release-and-deploy.md` (backup, cleanup, CI) or `@see file:catalog-core.md` (build facts, licences) where an area doc holds the rule.
  - **No new name** (FR-1): a comment that has to name the module writes `Collector::…`, and pull request B renames it.
  - **Example,** for `lib/collector/trusted_proxies.rb:8`:

    ```ruby
    # The reverse proxies whose X-Forwarded-For Rails trusts, from the operator's comma-separated setting, added to Rails'
    # own private ranges (spec 004 AC-4.8). A malformed entry raises at boot, so a typo can't silently trust nothing.
    #
    # @param value [String, nil] the setting's value, as read from the environment
    # @return [Array<IPAddr>] Rails' defaults followed by the parsed addresses
    # @raise [IPAddr::InvalidAddressError] when an entry isn't an address or a CIDR range
    def self.parse(value)
    ```

    The implementer reads each method before writing its comment; the example shows the shape, not this method's facts.
  - **Commits:** `docs(rename): summaries on lib/collector/backup before the rename (#445)`, `docs(rename): summaries on the rest of lib/collector before the rename (#445)`, `docs(rename): summaries on the four objects outside lib/collector the rename changes (#445)`.
- [ ] **T1.3 Prove it.**
  1. Run `ruby tmp/092_comment_list.rb | tail -1`. Expect `0 objects`.
  2. `git diff --stat main` lists only the files of T1.2. Then run:

     ```
     git diff main -- lib app spec | grep '^[-+]' | grep -vE '^(\+\+\+|---)' | grep -vE '^[-+]\s*#' | grep -vE '^[-+]\s*$'
     ```

     Expect no output: only comment lines and blank lines changed (AC-1.3).
  3. The coordinator runs `bin/ci`. Expect `✅ Continuous Integration passed`.
  4. Open pull request A against `main`, assigned to the maintainer, with the count from T1.1. It is the first push to the renamed repository (AC-8.6).

---

## Phase 2: Pull request B, the internal names (#436)

**Implements:** FR-2 | **Satisfies:** AC-1.4, AC-2.1 to AC-2.13
**Files:** see the table's (B) rows.
**Interfaces:** Consumes: Phase 1 merged. Produces:
- the module `WyrmsHoard` (`Rails.application.class.module_parent_name == "WyrmsHoard"`);
- the paths `lib/wyrms_hoard/…`, `spec/lib/wyrms_hoard/…`, `lib/tasks/wyrms_hoard.rake`, `spec/tasks/wyrms_hoard_rake_spec.rb` and `app/assets/{stylesheets,fonts,images}/wyrms_hoard/`;
- the skill `.claude/skills/wyrms-hoard-design-system/`;
- unchanged: the four logo files' names `collector-mark.svg`, `collector-mark-reversed.svg`, `collector-wordmark.svg` and `collector-wordmark-reversed.svg` (inside the renamed directory), the rake namespace `collector`, and every `COLLECTOR_*` name, message and title.

Branch `092-rename-internal-names` from `main` after A merged. Implementer 1 takes T2.1 to T2.3; implementer 2 takes T2.4 to T2.6. T2.5's database task is the coordinator's.

- [ ] **T2.1 The failing spec.** Create `spec/rename_internal_names_spec.rb`:

  ```ruby
  require "rails_helper"
  require "rake"

  # Spec 092 FR-2: the application's own module and directories carry the new name, and what an operator meets doesn't
  # change in this step (AC-2.12). Pull request D's old-name check (script/old_name/check.rb) keeps the old forms out
  # afterwards; this spec pins pull request B's outcome until then.
  RSpec.describe "The internal names", type: :config do # rubocop:disable RSpec/DescribeClass -- a property of the tree
    it "is the WyrmsHoard module, from lib/wyrms_hoard (AC-2.1, AC-2.2)", :aggregate_failures do
      expect(Rails.application.class.module_parent_name).to eq("WyrmsHoard")
      expect(WyrmsHoard::BuildFacts::UPSTREAM_SOURCE).to start_with("https://github.com/plainprogrammer/")
      expect(Object.const_defined?(:Collector)).to be(false)
      expect(Rails.root.join("lib/wyrms_hoard")).to be_directory
      expect(Rails.root.join("lib/collector")).not_to exist
    end

    it "keeps the design system's files under wyrms_hoard/, with the logo files' names unchanged (AC-2.2, AC-2.3)", :aggregate_failures do
      %w[stylesheets fonts images].each do |kind|
        expect(Rails.root.join("app/assets/#{kind}/wyrms_hoard")).to be_directory
        expect(Rails.root.join("app/assets/#{kind}/collector")).not_to exist
      end
      expect(Rails.root.join("app/assets/images/wyrms_hoard/collector-mark.svg")).to exist
    end

    it "serves the fonts from the renamed directory, so no font URL 404s (AC-2.3)", :aggregate_failures do
      tokens = Rails.root.join("app/assets/stylesheets/wyrms_hoard/tokens.css").read
      expect(tokens).not_to include("/collector/")
      tokens.scan(%r{url\("/wyrms_hoard/([^"]+)"\)}).flatten.each do |font|
        expect(Rails.root.join("app/assets/fonts/wyrms_hoard", font)).to exist
      end
    end

    it "keeps the operator's command as it was until pull request C (AC-2.4)" do
      Rails.application.load_tasks unless Rake::Task.task_defined?("collector:user")
      expect(Rake::Task.task_defined?("collector:user")).to be(true)
    end
  end
  ```

  Run `bin/rspec spec/rename_internal_names_spec.rb`. Expect: 4 examples, 3 failures (`uninitialized constant WyrmsHoard`, the missing directories, the fonts' directory). The command's example passes already; it is a guard that holds until pull request C deletes it (T3.3), and pull request D deletes the file (T4.2).

  Commit: `test(rename): the internal names are WyrmsHoard and wyrms_hoard (#436)`.
- [ ] **T2.2 Move the files,** one `git mv` per call:

  ```
  git mv lib/collector lib/wyrms_hoard
  git mv spec/lib/collector spec/lib/wyrms_hoard
  git mv lib/tasks/collector.rake lib/tasks/wyrms_hoard.rake
  git mv spec/tasks/collector_rake_spec.rb spec/tasks/wyrms_hoard_rake_spec.rb
  git mv app/assets/stylesheets/collector app/assets/stylesheets/wyrms_hoard
  git mv app/assets/fonts/collector app/assets/fonts/wyrms_hoard
  git mv app/assets/images/collector app/assets/images/wyrms_hoard
  git mv .claude/skills/collector-design-system .claude/skills/wyrms-hoard-design-system
  ```

- [ ] **T2.3 Rewrite the references.** List the files once. The pathspec leaves out the records and the never-edited places of Global Constraints:

  ```
  git grep -lE 'Collector::|module Collector|lib/collector|spec/lib/collector|(stylesheets|fonts|images)/collector|"collector/|url\("/collector/|/collector/[a-z0-9-]+\.woff2|collector/(tokens|components|additions)|collector\.rake|collector_rake_spec|collector rake spec|_collector_session|collector-design-system|collector/(backup|ci_groups|ci_shard|push_scope|start_check)' -- . ':!db/migrate' ':!spikes' ':!.kamal' ':!docs/specs/0*' ':!docs/adr/0*' ':!docs/lessons' ':!docs/superpowers' ':!docs/screenshots' ':!.claude/memory' > tmp/092_b_files.txt
  git grep -lE 'Collector::|lib/collector|collector-design-system|stylesheets/collector' -- .claude/memory/steering .claude/memory/foundation.md >> tmp/092_b_files.txt
  ```

  Then rewrite them in place (Perl's `-i` works the same on macOS and Linux):

  ```
  xargs perl -pi -e '
    s{(?<![A-Za-z])Collector::}{WyrmsHoard::}g;
    s{module Collector\b}{module WyrmsHoard}g;
    s{lib/collector\b}{lib/wyrms_hoard}g;
    s{(stylesheets|fonts|images)/collector\b}{$1/wyrms_hoard}g;
    s{"collector/}{"wyrms_hoard/}g;
    s{url\("/collector/}{url("/wyrms_hoard/}g;
    s{(?<![A-Za-z0-9_./-])collector/(tokens|components|additions|backup|ci_groups|ci_shard|push_scope|start_check|[a-z0-9-]+\.woff2)}{wyrms_hoard/$1}g;
    s{collector\.rake}{wyrms_hoard.rake}g;
    s{collector_rake_spec}{wyrms_hoard_rake_spec}g;
    s{the collector rake spec}{the wyrms_hoard rake spec}g;
    s{_collector_session}{_wyrms_hoard_session}g;
    s{collector-design-system}{wyrms-hoard-design-system}g;
  ' < tmp/092_b_files.txt
  ```

  Then by hand:
  - **Leading `::`:** remove it from `::WyrmsHoard::` in `app/controllers/licences_controller.rb`, `app/controllers/ocr_assets_controller.rb` and `app/helpers/scanners_helper.rb`. Delete the comments at `licences_controller.rb:10` and `ocr_assets_controller.rb:12` that explain the `::`; `WyrmsHoard` collides with no Rails constant (FR-2).
  - **The ratchet's comment:** in `script/yard/comment_ratchet.rb` (line 48 at `50435ba3`), `Collector::PushScope` is now `WyrmsHoard::PushScope` via the list. Check it changed.
  - **Stale comment:** `config/application.rb:31-34` should say `wyrms_hoard/backup` and similar. Check that the substitution reads well.
  - **Not reached by the list:** `spec/design_system_files_spec.rb:13`'s `path.to_s.include?("/collector/")` becomes `"/wyrms_hoard/"`; `app/assets/stylesheets/application.css:2-3`'s comment names `wyrms_hoard/`; `docs/design-system/components/SystemLogo.md:9-10` names the new directory.

  Then run:
  - `bin/rails zeitwerk:check` — expect `All is good!`.
  - `bin/rspec spec/rename_internal_names_spec.rb spec/design_system_files_spec.rb spec/requests/design_system_spec.rb spec/script/yard/comment_ratchet_spec.rb` — expect 0 failures. The ratchet's spec has a fixture `"…\nmodule Collector\n…"`, which is why the substitution has no leading `\b`.
  - `bin/rubocop` — expect no offenses.

  Don't commit yet: the pre-commit hook runs Brakeman, which fails until T2.4 re-fingerprints the ignore file (the fingerprint includes the code). T2.3 and T2.4 are one commit.
- [ ] **T2.4 Regenerate Brakeman's ignore file** so it ignores the same warnings under the new fingerprints. Write `tmp/092_brakeman.rb`:

  ```ruby
  # Spec 092 FR-2: re-fingerprint config/brakeman.ignore after the module rename. Each ignored warning is matched to the
  # report's warning with the same check, file and line; its fingerprint and code are taken from the report and its note
  # renamed. It fails if any ignored warning has no match, so nothing new is silently ignored.
  require "json"
  report = JSON.parse(`bin/brakeman --quiet --no-pager --no-exit-on-warn --no-exit-on-error -f json`)
  ignore = JSON.parse(File.read("config/brakeman.ignore"))
  warnings = report.fetch("warnings") + report.fetch("ignored_warnings", [])
  ignore["ignored_warnings"].each do |entry|
    found = warnings.find { |w| w.values_at("check_name", "file", "line") == entry.values_at("check_name", "file", "line") }
    abort "no warning matches #{entry.values_at("check_name", "file", "line").inspect}" unless found
    entry["fingerprint"] = found.fetch("fingerprint")
    entry["code"] = found.fetch("code")
    entry["note"] = entry["note"].gsub("Collector::", "WyrmsHoard::")
  end
  File.write("config/brakeman.ignore", JSON.pretty_generate(ignore) + "\n")
  puts "#{ignore["ignored_warnings"].size} ignored warnings re-fingerprinted"
  ```

  1. Run `ruby tmp/092_brakeman.rb`. Expect the same count as `jq '.ignored_warnings | length'` on `git show main:config/brakeman.ignore`.
  2. Run `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`. Expect exit 0.
  3. `git diff config/brakeman.ignore` shows changes only to `fingerprint`, `code` and `note` (AC-2.5).

  Commit T2.3 and T2.4 together: `refactor(rename): the module is WyrmsHoard and its directories wyrms_hoard (#436)`, with a body line saying Brakeman's ignore file was re-fingerprinted.
- [ ] **T2.5 Regenerate the prices structure file** (FR-2, AC-2.10). The coordinator runs this, because it rewrites the development prices database:

  ```
  bin/rails db:drop:prices db:create:prices db:migrate:prices
  ```

  1. `git diff db/prices_structure.sql` must show only `/*application='Collector'*/` becoming `/*application='WyrmsHoard'*/` on the five `CREATE` lines.
  2. Update `spec/prices_schema_spec.rb:85`'s expectation to `WyrmsHoard` if it names the comment. Run `bin/rspec spec/prices_schema_spec.rb spec/config/prices_database_spec.rb`; expect 0 failures.
  3. In the pull request's description, tell developers to run the same command once: an old development prices database would dump the old name back.

  Commit: `chore(rename): the prices structure file carries the module's new name (#436)`.
- [ ] **T2.6 The run-time log, the skill, the hook, and the proof.**
  - **Run-time log:** `perl -pi -e 's{spec/lib/collector/}{spec/lib/wyrms_hoard/}g; s{spec/tasks/collector_rake_spec}{spec/tasks/wyrms_hoard_rake_spec}g' spec/support/runtime_log.txt`. Check every path in the log exists (AC-2.11):

    ```
    awk '{print $NF}' spec/support/runtime_log.txt | sed 's/:.*//' | sort -u | while read -r f; do [ -e "$f" ] || echo "missing $f"; done
    ```

    Expect no output. If the log's lines put the path in another column, adjust the `awk` field to the file's format; the check is the same.
  - **The skill:** in `.claude/skills/wyrms-hoard-design-system/SKILL.md`, the `name:` line reads `wyrms-hoard-design-system`. `CLAUDE.md`'s UI paragraph names the new path (from T2.3). Check with `git grep -n "design-system" CLAUDE.md` (AC-2.13).
  - **The hook:** confirm `.claude/hooks/pre_push_ci.rb` requires `lib/wyrms_hoard/push_scope` and names `WyrmsHoard::PushScope`. Then run `ruby -c .claude/hooks/pre_push_ci.rb`; expect `Syntax OK`. AC-2.9 is proven by the coordinator's push of this branch, which the hook runs on. Record its output.
  - **The image's guards:** `.dockerignore` and `bin/image-smoke:99` name `lib/wyrms_hoard/ghcr_cleanup.rb`, `lib/wyrms_hoard/ci_groups.rb`, `lib/wyrms_hoard/ci_shard.rb` and `lib/wyrms_hoard/push_scope.rb` (AC-2.6). Check with `grep -n wyrms_hoard .dockerignore bin/image-smoke`.
  - **Search:** run the following. Expect no output (AC-2.1, AC-2.12).

    ```
    git grep -nE 'Collector::|module Collector|lib/collector|(stylesheets|fonts|images)/collector' -- . ':!db/migrate' ':!spikes' ':!.kamal' ':!docs/specs/0*' ':!docs/adr/0*' ':!docs/lessons' ':!docs/superpowers' ':!docs/screenshots' ':!.claude/memory'
    ```

  - **The index** (FR-11, AC-8.4): in `docs/specs/README.md`, add to row 092's Supersedes cell "004 AC-1.1's FR text in part: the design system's skill is `wyrms-hoard-design-system` (B)", and to row 004's Superseded by cell "092 (the skill's name)".
  - **Commit:** `chore(rename): the run-time log, the skill, the hook and the index follow the new paths (#436)`.
  - **Coordinator:**
    1. Run `bin/ci`. Expect it to pass; it includes the ratchet with no change to its rules (AC-1.4) and Zeitwerk through the suite.
    2. Start the server (`bin/dev`, in the background, memory: background servers via task). Open a signed-in page and the licences page in headless Firefox. Check the network log shows no 404 for `/assets/wyrms_hoard/…` and the fonts (AC-2.3).
    3. Open `docs/design-system/previews/Button.html` from the checkout and check it styles (AC-2.8).
    4. Sign in, open a form, keep the tab, restart the server on this branch, submit: refused once as stale (CSRF), then works after a reload. Check the session survives (AC-2.7).
    5. Push and open pull request B; CI's image job must pass its smoke tests (AC-2.5).

---

## Phase 3: Pull request C, the operator contract, the image, old data and the upgrade proof (#437)

**Implements:** FR-3, FR-4, FR-5, FR-6, FR-10 (for what C renames), FR-11 (C's cells) | **Satisfies:** AC-3.1 to AC-3.10, AC-4.1 to AC-4.7, AC-5.1 to AC-5.5, AC-8.2, AC-8.3, AC-8.4 (in part)
**Files:** see the table's (C) rows.
**Interfaces:** Consumes: Phase 2 merged, so the module is `WyrmsHoard` and paths are `wyrms_hoard`. Produces:
- the settings `WYRMS_HOARD_*` (spec decision 8's table);
- the task `wyrms_hoard:user`;
- `WyrmsHoard::Backup::Create::PARTIAL` (both prefixes);
- `WyrmsHoard::Backup::Restore::TEMPORARY = "wyrms-hoard-restore.partial"`, `TEMPORARY_PRICES = "wyrms-hoard-restore-prices.partial"` and `OLD_TEMPORARIES`;
- `Upgrade::Harness.repository_for(version, override:)`, `Harness::OLD_REPOSITORY` and `Harness::REPOSITORY = "ghcr.io/plainprogrammer/wyrmshoard"`;
- the image `ghcr.io/plainprogrammer/wyrmshoard`, the local tags `wyrms-hoard:smoke` and `wyrms-hoard:local`, and the volume `wyrms_hoard_storage`.

Branch `092-rename-operator-contract` from `main` after B merged. Implementer 1 takes T3.1 to T3.3, implementer 2 takes T3.4 to T3.6, and implementer 3 takes T3.7 and T3.8. T3.9 is the coordinator's.

- [ ] **T3.1 The settings, failing first.**

  1. Create `spec/old_settings_spec.rb`:

     ```ruby
     require "rails_helper"

     # Spec 092 decisions 3 and 8 (ADR 0032 decision 1): every setting is read under WYRMS_HOARD_ and no old name has an
     # effect, with no fallback and no warning (AC-3.1 to AC-3.3). The readers that take an environment are asked with
     # each name; the rest are proved by the absence of an old read (AC-3.3). The old-name check excludes this file:
     # its examples must name the old settings (spec 092 decision 11).
     RSpec.describe "The old settings", type: :config do # rubocop:disable RSpec/DescribeClass -- a property of the readers
       it "opens the catalog under the new name only (AC-3.1, AC-3.2)", :aggregate_failures do
         expect(Catalog.public_in?("WYRMS_HOARD_PUBLIC_CATALOG" => "true")).to be(true)
         expect(Catalog.public_in?("COLLECTOR_PUBLIC_CATALOG" => "true")).to be(false)
       end

       it "turns on art matching under the new name only (AC-3.1, AC-3.2)", :aggregate_failures do
         expect(MTG::Art.enabled_in?("WYRMS_HOARD_MTG_ART_MATCHING" => "true")).to be(true)
         expect(MTG::Art.enabled_in?("COLLECTOR_MTG_ART_MATCHING" => "true")).to be(false)
       end

       it "reads the extra languages under the new name only (AC-3.1, AC-3.2)", :aggregate_failures do
         client = instance_double(MTG::Scryfall::Client)
         expect(MTG::Scryfall::Source.new(client:, env: { "WYRMS_HOARD_MTG_LANGUAGES" => "ja" }).languages).to include("ja")
         expect(MTG::Scryfall::Source.new(client:, env: { "COLLECTOR_MTG_LANGUAGES" => "ja" }).languages).not_to include("ja")
       end

       it "reads the build facts under the new names only (AC-3.7)", :aggregate_failures do
         new_facts = WyrmsHoard::BuildFacts.read(env: { "WYRMS_HOARD_VERSION" => "0.4.0" }, rails_env: "production")
         old_facts = WyrmsHoard::BuildFacts.read(env: { "COLLECTOR_VERSION" => "0.4.0" }, rails_env: "production")
         expect(new_facts.version).to eq("0.4.0")
         expect(old_facts.version).to be_nil
       end

       it "reads no COLLECTOR_ setting anywhere but the released currency migration (AC-3.3)" do
         reads = `git grep -n "COLLECTOR_" -- app config lib bin script .github Dockerfile compose.yaml ':!db/migrate'`.lines
         expect(reads).to be_empty
       end
     end
     ```

     Before writing the third example, the implementer checks the method that returns the parsed languages on `MTG::Scryfall::Source` (`#languages` at `source.rb:67`). If it is private, use `send(:languages)` and say why in a comment.
  2. Run `bin/rspec spec/old_settings_spec.rb`; expect 5 failures.
  3. Edit the existing specs that name a setting so they name the new one. These are the files `git grep -l "COLLECTOR_" -- spec ':!spec/migrations/set_account_currency_from_the_instance_spec.rb' ':!spec/old_settings_spec.rb'` lists: `spec/image_publishing_spec.rb`, `spec/lib/wyrms_hoard/currency_spec.rb`, `spec/models/catalog/refresh_scryfall_spec.rb`, `spec/models/mtg/art/operation_spec.rb`, `spec/models/mtg/scryfall/source_spec.rb`, `spec/requests/admin/catalogs_spec.rb`, `spec/support/backup_helpers.rb`, `spec/support/public_catalog.rb`, `spec/system/art_agreement_spec.rb`, `spec/tasks/wyrms_hoard_rake_spec.rb` and the build-facts specs. Use:

     ```
     git grep -l "COLLECTOR_" -- spec ':!spec/migrations/set_account_currency_from_the_instance_spec.rb' ':!spec/old_settings_spec.rb' | xargs perl -pi -e 's/COLLECTOR_/WYRMS_HOARD_/g'
     ```

  4. Run `bin/rspec $(git grep -l "WYRMS_HOARD_" -- spec)`. Expect failures in every example that sets a renamed setting.
  5. Commit: `test(rename): settings are read under WYRMS_HOARD_ and the old names have no effect (#437)`.
- [ ] **T3.2 Rename the settings** everywhere that reads, sets or passes them, except the released migration:

  ```
  git grep -l "COLLECTOR_" -- app config lib bin script Dockerfile compose.yaml .github ':!db/migrate' | xargs perl -pi -e 's/COLLECTOR_/WYRMS_HOARD_/g'
  ```

  This covers:
  - the readers' constants: `Catalog::PUBLIC_ENV`, `MTG::Art::ENV_NAME`, `MTG::Scryfall::Source::LANGUAGES_ENV`;
  - the initializers and the environments;
  - `lib/wyrms_hoard/build_facts.rb`'s three names and `dev_certificate.rb`'s `WYRMS_HOARD_DEV_CERT_DIR`;
  - `lib/tasks/wyrms_hoard.rake`'s password;
  - the `Dockerfile`'s `ARG` and `ENV`;
  - `compose.yaml`'s `WYRMS_HOARD_IMAGE`, `WYRMS_HOARD_PORT` and the six pass-throughs;
  - `config/deploy.yml`'s commented settings;
  - `ci.yml`'s build args;
  - `bin/image-smoke`'s `printenv` and `-e` lines;
  - `script/worktree/with_mise`'s `WYRMS_HOARD_MISE_SEARCH`.

  The comments that name a setting change with it.

  Then:
  1. Run `bin/rspec spec/old_settings_spec.rb $(git grep -l "WYRMS_HOARD_" -- spec)`. Expect 0 failures.
  2. Run `git grep -n "COLLECTOR_" -- . ':!db/migrate' ':!spec/migrations/set_account_currency_from_the_instance_spec.rb' ':!spec/old_settings_spec.rb' ':!docs' ':!.claude/memory' ':!spikes' ':!.kamal' ':!README.md' ':!CLAUDE.md'`. Expect no output; the documents follow in T3.8.
  3. Commit: `refactor(rename): the settings are WYRMS_HOARD_ (#437)`.
- [ ] **T3.3 The operator's command.**
  1. In `spec/tasks/wyrms_hoard_rake_spec.rb`, replace `"collector:user"` with `"wyrms_hoard:user"` (in the `describe`, `task_defined?`, `reenable` and `invoke` lines). Add:

     ```ruby
     it "has no collector:user task any more (spec 092 AC-3.4)" do
       expect(Rake::Task.task_defined?("collector:user")).to be(false)
     end
     ```

  2. In `spec/rename_internal_names_spec.rb`, delete the example "keeps the operator's command as it was until pull request C". It held only until this step.
  3. Run `bin/rspec spec/tasks/wyrms_hoard_rake_spec.rb`; expect failures.
  4. In `lib/tasks/wyrms_hoard.rake`, change `namespace :collector` to `namespace :wyrms_hoard`. Then:

     ```
     git grep -l "collector:user" -- app bin config lib script spec ':!spec/tasks/wyrms_hoard_rake_spec.rb' | xargs perl -pi -e 's/collector:user/wyrms_hoard:user/g'
     ```

     That covers `bin/image-smoke:50` and its messages, and `spec/support` if it names the task.
  5. Run `bin/rspec spec/tasks/wyrms_hoard_rake_spec.rb spec/rename_internal_names_spec.rb`; expect 0 failures.
  6. Commit: `refactor(rename): the user command is wyrms_hoard:user (#437)`.
- [ ] **T3.4 The backup's and the restore's names, failing first** (decision 12, AC-3.8, AC-4.1 to AC-4.4).

  1. In `spec/lib/wyrms_hoard/backup/create_spec.rb`, change the examples that read the written file's name to expect `wyrms-hoard-backup-`. Make the sweep's examples (around lines 156-159 at `50435ba3`) cover both prefixes:

     ```ruby
     it "sweeps stale partial files of both prefixes and leaves other files (spec 092 decision 12, AC-4.3)", :aggregate_failures do
       stale = %w[
         collector-backup-20260101T000000Z.tar.gz.0123456789abcdef.partial
         collector-backup-20260101T000000Z.sqlite3.0123456789abcdef.partial-wal
         wyrms-hoard-backup-20260102T000000Z.tar.gz.0123456789abcdef.partial
         wyrms-hoard-backup-20260102T000000Z.prices.sqlite3.0123456789abcdef.partial-journal
       ]
       kept = "wyrms-hoard-backup-20260102T000000Z.tar.gz"
       (stale + [ kept, "notes.txt" ]).each { directory.join(it).write("x") }
       stale.each { FileUtils.touch(directory.join(it), mtime: Time.now - 2 * 86_400) }

       run

       expect(stale.map { directory.join(it).exist? }).to all(be(false))
       expect([ directory.join(kept), directory.join("notes.txt") ]).to all(exist)
     end
     ```

     Take the age rule, `directory` and `run` from the existing sweep example beside it. If its stale age differs, use that example's way of aging a file in place of the `touch` above.
  2. In `spec/lib/wyrms_hoard/backup/restore_spec.rb`, add, with the helpers of `spec/support/backup_helpers.rb` (`create_backup`, `restore_backup(path, volume:)`, `scratch(name)`):

     ```ruby
     it "restores a backup whatever its file name's prefix (spec 092 AC-4.1, AC-4.2)", :aggregate_failures do
       made = create_backup
       %w[collector-backup-20251231T000000Z.tar.gz anything-at-all.tar.gz].each do |name| # not create_backup's own time, so the copy is a new file
         renamed = made.dirname.join(name)
         FileUtils.cp(made, renamed)
         expect { restore_backup(renamed, volume: scratch("volume-#{name}")) }.not_to raise_error
       end
     end

     it "removes a stopped restore's temporary files under both names (spec 092 decision 12, AC-4.4)", :aggregate_failures do
       volume = scratch("volume")
       leftovers = %w[collector-restore.partial collector-restore-prices.partial-journal wyrms-hoard-restore.partial-journal]
       leftovers.each { volume.join(it).write("x") }

       restore_backup(create_backup, volume:)

       expect(leftovers.map { volume.join(it).exist? }).to all(be(false))
     end
     ```

     `RESTORE_SUFFIXES` is `["", "-journal"]`, so the leftovers are the files and their journals, never `-wal`.
  3. Rename every other `collector-backup-…` file name in `spec/` to `wyrms-hoard-backup-…`, except the three examples above:

     ```
     git grep -lE "collector-(backup|restore)" -- spec ':!spec/support/upgrade_fakes.rb' ':!spec/script/upgrade/harness_spec.rb' | xargs perl -pi -e 's/collector-backup/wyrms-hoard-backup/g; s/collector-restore/wyrms-hoard-restore/g'
     ```

     Then restore the old names in the new examples above by hand (the sweep's two old files, the old-named backup, the two old temporaries). The renaming covers `restore_spec.rb:176-178` and `:188`'s temporaries. This covers `backup_helpers.rb`'s `scratch_root` (`wyrms-hoard-backup-spec`), `archive_spec.rb`, `spec/backup_boot_spec.rb`, `spec/tasks/backup_restore_rake_spec.rb` and `spec/script/upgrade/engine_spec.rb`.
  4. In `archive_spec.rb`, expect the refusal's hint to read `Give a wyrms-hoard-backup-….tar.gz file made by backup:create.`. In the two specs that assert the usage hint, expect `bin/rails "backup:restore[/path/to/wyrms-hoard-backup.tar.gz]"` (AC-3.8).
  5. Run `bin/rspec spec/lib/wyrms_hoard/backup spec/backup_boot_spec.rb spec/tasks/backup_restore_rake_spec.rb`. Expect failures on the names; the prefix-free restore already passes.
  6. Commit: `test(rename): new backups and restore temporaries take the new name; old leftovers are still swept (#437)`.
- [ ] **T3.5 Implement the names.**

  1. In `lib/wyrms_hoard/backup/create.rb`, set the final name to `wyrms-hoard-backup-#{…}.tar.gz` and replace `PARTIAL`:

     ```ruby
     # A stale partial file of an interrupted backup, under the backup's prefix since the rename or the one a release of
     # 0.3.0 or earlier wrote, so what an interrupted 0.3.0 left in the same directory is still swept (spec 092 decision 12):
     # <prefix>-backup-<time>.(tar.gz|sqlite3|prices.sqlite3).<16 hex>.partial[-journal|-wal|-shm] (contracts/archive.md).
     PARTIAL = /\A(?:wyrms-hoard|collector)-backup-\d{8}T\d{6}Z\.(?:tar\.gz|sqlite3|prices\.sqlite3)\.\h{16}\.partial(?:-journal|-wal|-shm)?\z/
     ```

  2. In `lib/wyrms_hoard/backup/restore.rb`, replace the two constants and the leftover line:

     ```ruby
     TEMPORARY = "wyrms-hoard-restore.partial".freeze
     TEMPORARY_PRICES = "wyrms-hoard-restore-prices.partial".freeze # the prices snapshot's temporary file, with the same suffixes
     # The temporary files a stopped restore of 0.3.0 or earlier left, removed with the new ones (spec 092 decision 12).
     OLD_TEMPORARIES = %w[collector-restore.partial collector-restore-prices.partial].freeze
     ```

     ```ruby
     ([ TEMPORARY, TEMPORARY_PRICES ] + OLD_TEMPORARIES).each { Backup.remove(volume.join(it), RESTORE_SUFFIXES) } # a stopped run's leftovers and their journals (FR-6; spec 092 decision 12)
     ```

  3. In `lib/wyrms_hoard/backup/archive.rb:162`, the hint becomes `"Give a wyrms-hoard-backup-….tar.gz file made by backup:create."`. In `lib/tasks/backup.rake`, the `desc` and the usage hint name `wyrms-hoard-backup-20261021T142100Z.tar.gz` and `/path/to/wyrms-hoard-backup.tar.gz`.
  4. In `bin/backup-smoke:177`, the expected line becomes `^Backup written: /backups/wyrms-hoard-backup-`.
  5. Run `bin/rspec spec/lib/wyrms_hoard/backup spec/backup_boot_spec.rb spec/tasks/backup_restore_rake_spec.rb`; expect 0 failures.
  6. Commit: `feat(rename): backups are wyrms-hoard-backup and the sweep keeps the old prefix (#437)`.
- [ ] **T3.6 The upgrade proof and the cleanup's package,** failing first (decision 13, AC-5.2 to AC-5.5).

  1. In `spec/script/upgrade/harness_spec.rb`, add:

     ```ruby
     describe ".repository_for" do
       it "names the old package for 0.3.0 and earlier and the new one after (spec 092 decision 13, ADR 0033 decision 4)", :aggregate_failures do
         expect(described_class.repository_for("0.3.0")).to eq("ghcr.io/plainprogrammer/collector")
         expect(described_class.repository_for("0.2.1")).to eq("ghcr.io/plainprogrammer/collector")
         expect(described_class.repository_for("0.4.0")).to eq("ghcr.io/plainprogrammer/wyrmshoard")
         expect(described_class.repository_for("1.0.0")).to eq("ghcr.io/plainprogrammer/wyrmshoard")
       end

       it "lets UPGRADE_IMAGE_REPOSITORY win for any version (AC-5.3)" do
         expect(described_class.repository_for("0.3.0", override: "registry.example/mine")).to eq("registry.example/mine")
       end
     end
     ```

     For AC-5.4, add beside the example that drives the backup leg (`git grep -n "Backup written" spec/script/upgrade`). `FakeEngine` takes the faked task's output as `task:` (`spec/support/upgrade_fakes.rb`):

     ```ruby
     %w[collector-backup wyrms-hoard-backup].each do |prefix|
       it "accepts the previous build's backup line with the #{prefix} prefix (spec 092 decision 13, AC-5.4)" do
         engine = FakeEngine.new(databases: leg_databases, tasks: listing, task: FakeEngine::Result.new("Backup written: /backups/#{prefix}-1.tar.gz\n", "", 0))
         expect(harness(engine:).call).to eq(0)
       end
     end
     ```

     `leg_databases` and `listing` are the names the existing backup-leg example's `let`s have; if they differ, use that example's own arrangement verbatim and vary only `task:`.
  2. In `spec/lib/wyrms_hoard/ghcr_cleanup_spec.rb` (or the client spec under it), expect `Client::API`, `REGISTRY` and `PULL_TOKEN` to name `wyrmshoard`:

     ```ruby
     it "works on the new package only (spec 092 FR-5, AC-5.5)", :aggregate_failures do
       expect(described_class::API).to eq("https://api.github.com/users/plainprogrammer/packages/container/wyrmshoard/versions")
       expect(described_class::REGISTRY).to eq("https://ghcr.io/v2/plainprogrammer/wyrmshoard/manifests/")
       expect(described_class::PULL_TOKEN).to eq("https://ghcr.io/token?scope=repository:plainprogrammer/wyrmshoard:pull")
     end
     ```

     Update the specs' stubbed URLs from `/collector/` to `/wyrmshoard/`.
  3. Run `bin/rspec spec/script/upgrade/harness_spec.rb spec/lib/wyrms_hoard/ghcr_cleanup`; expect failures.
  4. In `script/upgrade/harness.rb`, replace the constant:

     ```ruby
     # Releases up to 0.3.0 were published under the old name, at the old package; every later release is published at the new
     # one (spec 092 decision 13, ADR 0033 decision 4). This is the one place in the code that names the old image.
     OLD_REPOSITORY = "ghcr.io/plainprogrammer/collector".freeze
     REPOSITORY = "ghcr.io/plainprogrammer/wyrmshoard".freeze
     LAST_RELEASE_AT_OLD_REPOSITORY = Gem::Version.new("0.3.0")

     # The package that holds a release's image.
     #
     # @param version [String] the release's number, such as "0.3.0"
     # @param override [String, nil] UPGRADE_IMAGE_REPOSITORY, which wins for any version
     # @return [String] the image's repository, without a tag
     def self.repository_for(version, override: nil)
       return override if override

       Gem::Version.new(version) <= LAST_RELEASE_AT_OLD_REPOSITORY ? OLD_REPOSITORY : REPOSITORY
     end
     ```

  5. In `parse`, set `repository: env["UPGRADE_IMAGE_REPOSITORY"]` (nil when unset). At `:142`, the image becomes `"#{Harness.repository_for(version.number, override: @options.repository)}:#{version.number}"`. At `:464`, the check becomes `result.out.match?(%r{Backup written: /backups/(?:wyrms-hoard|collector)-backup-})`, with a comment: either prefix, because a previous build given by ref has no version (spec 092 decision 13).
  6. Fix `spec/script/upgrade/harness_spec.rb:11`'s `let(:options)`, which passes `repository:` explicitly: keep the old package there only where an example is about 0.3.0, and use `nil` otherwise.
  7. In `lib/wyrms_hoard/ghcr_cleanup.rb`, change `API`, `REGISTRY` and `PULL_TOKEN` to `wyrmshoard` and update the file's header comment. Leave `USER_AGENT` for D (decision 9). Change the comments in `bin/ghcr-cleanup:2` and `.github/workflows/ghcr-cleanup.yml:3` to name the new package.
  8. Run the same specs; expect 0 failures.
  9. Commit: `feat(rename): the upgrade proof finds a release's package by version, and the cleanup works on the new one (#437)`.
- [ ] **T3.7 The image, the volume, the service, the developer's names.** Test first:
  1. In `spec/image_publishing_spec.rb`, change the asserted values:
     - the image `ghcr.io/plainprogrammer/wyrmshoard`, the Compose default `${WYRMS_HOARD_IMAGE:-ghcr.io/plainprogrammer/wyrmshoard:latest}`, and `${WYRMS_HOARD_PORT:-3000}`;
     - the volume `wyrms_hoard_storage`, Kamal's `service: wyrms-hoard`, `image: plainprogrammer/wyrmshoard`, and the backup directory `/srv/wyrms-hoard-backups`;
     - the local tags `wyrms-hoard:smoke` and `wyrms-hoard:local`.

     Also change `spec/script/upgrade/files_spec.rb:46`'s expected `run:` line to `wyrms-hoard:smoke`, and `spec/script/upgrade/harness_spec.rb`'s `collector:smoke` (lines 89, 262, 305, 350 and 491 at `50435ba3`; `git grep -n collector:smoke spec/script/upgrade` lists them) to `wyrms-hoard:smoke`.

     Run `bin/rspec spec/image_publishing_spec.rb spec/script/upgrade/files_spec.rb spec/script/upgrade/harness_spec.rb`; expect failures.
  2. Then edit:
     - `.github/workflows/ci.yml`: `IMAGE: ghcr.io/plainprogrammer/wyrmshoard`; `tags: wyrms-hoard:smoke`; the three smoke steps' argument `wyrms-hoard:smoke`.
     - `compose.yaml`: the image default, the volume (`wyrms_hoard_storage` in the service and under `volumes:`), and the header comment's names; the first comment line stays "Collector" until D.
     - `config/deploy.yml`: `service: wyrms-hoard`, `image: plainprogrammer/wyrmshoard`, `wyrms_hoard_storage:/rails/storage`, `/srv/wyrms-hoard-backups` in both commented lines, and `wyrms-hoard-db` in the accessory comment.
     - `Dockerfile:6`'s comment: `--name wyrms-hoard wyrms-hoard:local`.
     - `bin/image-smoke:17`: `wyrms-hoard-smoke-$$`.
     - `bin/backup-smoke`: volume prefixes `wyrms-hoard-backup-smoke-`.
     - `script/backup/measure.rb:57`: `wyrms-hoard-measure`.
     - `lib/wyrms_hoard/dev_certificate.rb`: `~/.local/share/wyrms-hoard-dev-https`, `wyrms-hoard-dev.crt`, `/CN=wyrms-hoard dev …`, and its spec.
  3. Run `bin/rspec spec/image_publishing_spec.rb spec/script/upgrade/files_spec.rb spec/script/upgrade/harness_spec.rb spec/lib/wyrms_hoard/dev_certificate_spec.rb`; expect 0 failures.
  4. Run the following. Expect no output.

     ```
     git grep -nE 'collector_storage|service: collector|plainprogrammer/collector|collector:(smoke|local)|--name collector|collector-(smoke|measure|dev|db)|collector-backup-smoke' -- . ':!docs' ':!.claude/memory' ':!spikes' ':!.kamal' ':!README.md' ':!CLAUDE.md' | grep -vE '(script/upgrade/harness\.rb|spec/script/upgrade/harness_spec\.rb|spec/support/upgrade_fakes\.rb):.*ghcr\.io/plainprogrammer/collector'
     ```

  5. Commit: `refactor(rename): the image, the volume, the service and the developer's names (#437)`.
- [ ] **T3.8 The documents of what C renames, and the upgrade notes** (decision 7, FR-10, AC-3.10, AC-8.2, AC-8.3).

  1. **Rename in the living documents.** Apply the substitutions of T3.2, T3.3, T3.5 and T3.7 to the documents:

     ```
     git grep -lE 'COLLECTOR_|collector:user|collector_storage|service: collector|plainprogrammer/collector|collector:(smoke|local)|collector-backup|collector-restore|/srv/collector-backups|collector-dev' -- README.md CLAUDE.md docs/architecture docs/backup-restore.md docs/north-star.md docs/releasing.md .claude/memory/steering .claude/memory/foundation.md
     ```

     Edit each hit by hand, not by bulk substitution. Three kinds of place keep the old form:
     - the upgrade notes that were in 0.3.0's `docs/releasing.md` (`git show v0.3.0:docs/releasing.md`);
     - the released migration's mention in the area docs;
     - the statements that describe the old package or the old prefix (the two-package rule, the sweep).

     Examples name `ghcr.io/plainprogrammer/wyrmshoard:0.4.0`, not `:0.1.0` (decision 15). The README's restore procedures name `wyrms-hoard-backup-…`.
  2. **The release and deploy area doc** (AC-8.3). Add, each with its source:
     - the two-package rule (spec 092 decision 13, ADR 0033 decision 4);
     - the frozen old package (ADR 0033 decision 3);
     - the sweep's two prefixes and the restore's old temporaries (spec 092 decision 12).

     Update the Named constants table: the image name, the `WYRMS_HOARD_IMAGE` default, `PARTIAL`, `TEMPORARY`, `OLD_TEMPORARIES`, `REPOSITORY`, `OLD_REPOSITORY`. Add spec 092 and #437 to Sources.
  3. **`docs/releasing.md`.** Put the three notes added since 0.3.0 (specs 081, 086, 090) under a new heading `### 0.4.0` above the older notes, renamed, followed by the rename's notes. Under "Going public (one time)", add one sentence pointing to #439 for the new package. The rename's notes, in this order (AC-8.2):

     ````markdown
     #### Collector is now Wyrm's Hoard (spec 092)

     This release renames the application, its settings, its command, its volume, its Kamal service and its image. Nothing
     reads the old names, so an instance needs these steps once. Your data moves by a backup and a restore; the old volume is
     left as it is until you remove it.

     1. **Older than 0.3.0?** Upgrade to 0.3.0 first, following the notes below, and start it once.
     2. **Rename your settings.** Each keeps its suffix:

        | Before | After |
        |---|---|
        | `COLLECTOR_CURRENCY` | `WYRMS_HOARD_CURRENCY` |
        | `COLLECTOR_HTTPS` | `WYRMS_HOARD_HTTPS` |
        | `COLLECTOR_MTG_LANGUAGES` | `WYRMS_HOARD_MTG_LANGUAGES` |
        | `COLLECTOR_MTG_ART_MATCHING` | `WYRMS_HOARD_MTG_ART_MATCHING` |
        | `COLLECTOR_PUBLIC_CATALOG` | `WYRMS_HOARD_PUBLIC_CATALOG` |
        | `COLLECTOR_TRUSTED_PROXIES` | `WYRMS_HOARD_TRUSTED_PROXIES` |
        | `COLLECTOR_PASSWORD` | `WYRMS_HOARD_PASSWORD` |
        | `COLLECTOR_IMAGE` (Compose) | `WYRMS_HOARD_IMAGE` |
        | `COLLECTOR_PORT` (Compose) | `WYRMS_HOARD_PORT` |
     3. **The image** is `ghcr.io/plainprogrammer/wyrmshoard`. `ghcr.io/plainprogrammer/collector` keeps 0.3.0 and earlier
        and gets nothing new.
     4. **The user command** is `bin/rails "wyrms_hoard:user[EMAIL]"`.
     5. **Move the data, with Compose,** from the directory that holds your old `compose.yaml`:

        ```sh
        docker compose stop web
        mkdir -p backups && sudo chown 1000:1000 backups
        docker compose run --rm --no-deps -v "$PWD/backups:/backups" web bin/rails "backup:create[/backups]"
        ```

        The backup is written to `./backups/collector-backup-<time>.tar.gz`. Then take the new `compose.yaml`, set the
        renamed settings, and restore onto the new, empty volume before the first start:

        ```sh
        docker compose run --rm --no-deps -v "$PWD/backups:/backups" web bin/rails "backup:restore[/backups/collector-backup-<time>.tar.gz]"
        docker compose up -d
        ```

     6. **Move the data, with Kamal.** Stop the old service while `config/deploy.yml` still says `service: collector`,
        then back up the stopped instance from the host:

        ```sh
        bin/kamal app stop
        ssh <host> 'sudo install -d -o 1000 -g 1000 /srv/wyrms-hoard-backups && docker run --rm -v collector_storage:/rails/storage -v /srv/wyrms-hoard-backups:/backups -e SECRET_KEY_BASE_DUMMY=1 ghcr.io/plainprogrammer/collector:0.3.0 bin/rails "backup:create[/backups]"'
        ```

        Keep a copy of the old file (`cp config/deploy.yml config/deploy.collector.yml`), then change `config/deploy.yml` to the new service, image and volume, and restore before the first deploy:

        ```sh
        ssh <host> 'docker run --rm -u 1000 -v wyrms_hoard_storage:/rails/storage -v /srv/wyrms-hoard-backups:/backups -e SECRET_KEY_BASE_DUMMY=1 ghcr.io/plainprogrammer/wyrmshoard:0.4.0 bin/rails "backup:restore[/backups/collector-backup-<time>.tar.gz]"'
        bin/kamal deploy --skip-push --version 0.4.0
        bin/kamal app remove -c config/deploy.collector.yml   # removes the stopped collector containers
        ```

     7. **What the move doesn't carry** (a volume copy would have): everyone signs in again; pending Undos and bulk
        selections are gone; queued jobs and a previewed import are not carried; catalog downloads are fetched again at the
        next refresh; with art matching on, rebuild the art index from Admin, then Catalog.
     8. **Started 0.4.0 before moving the data?** It opened on an empty volume and shows first-run setup. Remove its
        containers and the new volume: with Compose, `docker compose down` then `docker volume rm <project>_wyrms_hoard_storage`;
        with Kamal, `bin/kamal app remove` then `ssh <host> docker volume rm wyrms_hoard_storage`. Start 0.3.0 again on the
        old volume with the old files, and follow steps 5 or 6. The old volume was never touched.
     9. **Building the image yourself?** Its build arguments are `WYRMS_HOARD_VERSION`, `WYRMS_HOARD_REVISION` and
        `WYRMS_HOARD_SOURCE_URL`.
     ````

     T3.9 runs every `docker` and `docker compose` command above, so those are tested; the three `bin/kamal` lines are first run by the maintainer's upgrade (AC-5.8). Where a run shows a command wrong (an argument, a mount, a user), T3.9 corrects the notes in the same task.
  4. **The index cells** (FR-11, AC-8.4). In `docs/specs/README.md`, add to row 092's Supersedes cell, and to each named row's Superseded by cell:
     - the settings: 005, 011, 020 AC-4.2, 023 decision 1, 038, 049, 084 decisions 3, 7 and 9, 089;
     - the command: 012 AC-6.3, 030 decision 3, 090 decision 8;
     - the image: 012, 013 (not 014, whose AC-1.4 names a 0.1.0 image that exists only in the old package);
     - the backup names: 030;
     - the upgrade proof: 031;
     - the CI image tag: 086 AC-4.3.

     Take the exact criteria from the spec's Supersedes table.
  5. Commit: `docs(rename): the operator's documents and the 0.4.0 upgrade notes (#437)`.
- [ ] **T3.9 The coordinator's checks.**
  1. **The suite.** Run `bin/ci`; expect it to pass.
  2. **The upgrade by the notes** (AC-3.1, AC-4.1, AC-4.5, AC-4.7, AC-5.2, AC-8.2), on the development machine. Memory applies: colima shares only `$HOME`; `TMPDIR` goes under the worktree; ghcr pulls are denied, so 0.3.0 is built from its tag; a local build needs `--previous-version`. Use scratch volume names (`092-old-storage`, `092-new-storage`), never `collector_storage`.
     1. Build both images: `mkdir -p tmp/092/v030`, `git archive v0.3.0 | tar -x -C tmp/092/v030`, `docker build -t collector:v030local tmp/092/v030`; and `docker build -t wyrms-hoard:local --build-arg WYRMS_HOARD_VERSION=pr-c --build-arg WYRMS_HOARD_REVISION=$(git rev-parse HEAD) --build-arg WYRMS_HOARD_SOURCE_URL=https://github.com/plainprogrammer/wyrmshoard .`.
     2. Run `TMPDIR="$PWD/tmp/092" bin/upgrade-smoke collector:v030local wyrms-hoard:local --previous-version 0.3.0`. Expect its success line, `OK: v0.3.0 (…) upgraded to …`.
     3. **Kamal's form** (plain `docker run`): start 0.3.0 on `092-old-storage` with `SECRET_KEY_BASE`; create an admin with `COLLECTOR_PASSWORD` and `collector:user`; download an export as that admin (keep the file); stop it; back it up with step 6's command (local image tag, scratch volume and a scratch host directory in place of the registry's, `collector_storage` and `/srv`); restore onto `092-new-storage` with the new image; start the new image with `WYRMS_HOARD_CURRENCY=EUR` and `WYRMS_HOARD_TRUSTED_PROXIES=10.0.0.5`. Check: sign-in works with the admin's password; `bin/rails runner 'puts User.count, Account.first.currency, Rails.configuration.x.default_currency, Rails.application.config.action_dispatch.trusted_proxies.map(&:to_s).include?("10.0.0.5")'` prints `1`, the account's currency from before (unchanged, AC-4.7), `EUR` and `true` (AC-3.1); `docker run --rm -e WYRMS_HOARD_HTTPS=true -e SECRET_KEY_BASE_DUMMY=1 wyrms-hoard:local bin/rails runner 'puts Rails.application.config.force_ssl'` prints `true`, and with `COLLECTOR_HTTPS=true` in its place prints `false` (AC-3.1, AC-3.2); the export downloaded from 0.3.0 previews and applies in the new instance's Import collection (AC-4.5).
     4. **Compose's form:** in a scratch directory under the worktree, with the old `compose.yaml` from `git show v0.3.0:compose.yaml` and `COLLECTOR_IMAGE=collector:v030local`, then the new one with `WYRMS_HOARD_IMAGE=wyrms-hoard:local`, run step 5's commands as written, with `-p 092compose` so the volumes are scratch. Check sign-in as in 3. Then run step 8's Compose recovery once (start the new file with no restore, `docker compose down`, `docker volume rm 092compose_wyrms_hoard_storage`) and check it succeeds.
     5. Record every command and its output in the coordinator's notes for `verification.md` (T4.9). Where a command in the notes proved wrong, correct the notes in this task and record the change.
  3. **The new package.** Push and open pull request C. When it merges, main's CI publishes `ghcr.io/plainprogrammer/wyrmshoard:edge` for both architectures (AC-5.1).
     1. Before the merge, list the old package's versions with their tags and keep the output: `gh api /users/plainprogrammer/packages/container/collector/versions --paginate --jq '.[] | "\(.id) \(.metadata.container.tags | join(","))"' | sort > tmp/092/old-package-before.txt`.
     2. After the merge, run `gh api /users/plainprogrammer/packages/container/wyrmshoard/versions --jq '.[0].metadata.container.tags'`; expect it to include `edge`.
  4. **The export is unchanged** (AC-4.6): `bin/rspec spec/models/collection_export_spec.rb spec/export_format_document_spec.rb` passes unchanged on this branch (they assert the file name, `format` and `format_version`; `git diff main -- app/models/export_format/*.json` shows no `$id` change). Record it.
  5. **The cleanup** (AC-5.5). Run `GH_TOKEN="$(gh auth token)" bin/ghcr-cleanup` (a dry run) after the merge. Expect it to list versions of `wyrmshoard` only.

---

## Phase 4: Pull request D, the display name, the links, the check and the supersessions (#438)

**Implements:** FR-7, FR-8, FR-9, FR-10, FR-11 | **Satisfies:** AC-6.1 to AC-6.12, AC-7.1 to AC-7.8, AC-8.1, AC-8.4, AC-8.5
**Files:** see the table's (D) rows.
**Interfaces:** Consumes: Phase 3 merged. Produces:
- `OldName::Check`, run as `ruby script/old_name/check.rb`, with `OldName::FORMS`, `OldName::EXCLUSIONS`, `OldName::Finding` and `OldName::Check.new(root).call` returning an array of findings;
- the `bin/ci checks` step `Names: the old name stays out`;
- the CSS class `.c-appbar__name`;
- the mark files `wyrms-hoard-mark.svg` and `wyrms-hoard-mark-reversed.svg`;
- `verification.md` with `## Implementation review`.

Branch `092-rename-display-name` from `main` after C merged. Implementer 1 takes T4.1 to T4.3 (the check); implementer 2 takes T4.4 to T4.6 (the display); implementer 3 takes T4.7 and T4.8 (the documents). T4.9 is the coordinator's.

- [ ] **T4.1 The check's spec,** failing first. Create `spec/script/old_name/check_spec.rb`:

  ```ruby
  require "rails_helper"
  require "tmpdir"
  require Rails.root.join("script/old_name/check").to_s

  # Spec 092 FR-9: the application's old name can't return to the code, the configuration or the agent's instructions.
  # Each form and each kind that stays is proved on injected text; the last examples judge the real tree.
  RSpec.describe OldName::Check, type: :model do # rubocop:disable RSpec/SpecFilePathFormat -- the file is script/old_name/check.rb
    let(:root) { Pathname(Dir.mktmpdir) }

    after { FileUtils.remove_entry(root) }

    def judge(path, text) = OldName.judge_text(path, text)

    {
      "the module" => "module Collector",
      "a constant" => "Collector::BuildFacts.read",
      "the name in a title" => 'content_for :title, "Search · Collector"',
      "a pattern's anchor" => '%r{\ACollector/}',
      "a setting" => 'ENV["COLLECTOR_HTTPS"]',
      "the command" => 'bin/rails "collector:user[EMAIL]"',
      "the rake namespace" => "namespace :collector do",
      "an image tag" => "docker build -t collector:smoke .",
      "the container" => "docker run --name collector collector:local",
      "the service" => "service: collector",
      "the volume" => "collector_storage:/rails/storage",
      "the session cookie" => "_collector_session",
      "the rake spec" => "spec/tasks/collector_rake_spec.rb",
      "the rake file" => "lib/tasks/collector.rake",
      "a backup" => "collector-backup-20261021T142100Z.tar.gz",
      "a restore temporary" => "collector-restore.partial",
      "a hyphenated developer name" => "~/.local/share/collector-dev-https",
      "the cleanup's agent" => "collector-ghcr-cleanup (+https://example.invalid)",
      "a logo" => "collector-mark.svg",
      "the skill" => ".claude/skills/collector-design-system/SKILL.md",
      "the image" => "ghcr.io/plainprogrammer/collector:0.3.0",
      "the repository" => "https://github.com/plainprogrammer/Collector",
      "the package" => "packages/container/collector/versions",
      "a checkout" => "https://example.invalid/collector.git",
      "a directory" => 'stylesheet_link_tag "collector/tokens"',
      "a trailing directory" => "PATTERNS = %w[app/assets/stylesheets/collector]",
      "a font's URL" => 'url("/collector/fraunces.woff2")',
      "the database comment" => "/*application='Collector'*/"
    }.each do |form, text|
      it "finds #{form} (AC-7.2)" do
        expect(judge("app/models/example.rb", "x = 1\n#{text}\n").map(&:line).uniq).to eq([ 2 ]) # a line may hold two forms
      end
    end

    {
      "the collector line" => "collector_number, collector_text, collector_line, MTG::CollectorLine, collectorText, collector-line",
      "the card's labels" => "Collector number, Collector numbers, Collector lines, Collector strip",
      "the strip's key" => 'STRIPS.collector, text.collector, "collector.png", %w[name collector], collector: { top: 1 }',
      "the person" => "a collector, the collector's lots, collector?, let(:collector), sign_in_as(collector)",
      "Rails' class" => "ActionController::MimeResponds::Collector",
      "the export identifier" => '"format": "collector-export", "$id": "urn:collector:export-format:v4", collector-export-2026-11-14.json'
    }.each do |kind, text|
      it "passes #{kind} (AC-7.3)" do
        expect(judge("app/models/example.rb", text)).to be_empty
      end
    end

    it "finds a person's name or the card set's name outside its excluded place (AC-7.3)", :aggregate_failures do
      expect(judge("spec/factories/other.rb", 'name { "Collector #{n}" }')).not_to be_empty
      expect(judge("spec/system/other_spec.rb", "Commander Collector Showcase Extras")).not_to be_empty
    end

    it "finds a path that is a form, and passes the collector line's files (AC-7.4)", :aggregate_failures do
      expect(OldName.judge_path("lib/collector/backup.rb")).not_to be_empty
      expect(OldName.judge_path("app/assets/images/wyrms_hoard/collector-mark.svg")).not_to be_empty
      expect(OldName.judge_path("app/models/mtg/collector_line.rb")).to be_empty
    end

    it "judges a binary file by its path only" do
      root.join("app").mkpath
      root.join("app/collector-mark.png").binwrite("\x89PNG\x00Collector".b)
      root.join("app/ok.png").binwrite("\x89PNG\x00Collector".b)
      found = described_class.new(root, files: %w[app/collector-mark.png app/ok.png], exclusions: []).call
      expect(found.map(&:path)).to eq(%w[app/collector-mark.png])
    end

    it "fails on an exclusion whose path or pattern no longer matches anything (AC-7.5)", :aggregate_failures do
      root.join("spec").mkpath
      root.join("spec/kept.rb").write("COLLECTOR_CURRENCY\n")
      exclusions = [
        OldName::Exclusion.new(path: "spec/gone.rb", pattern: nil, reason: "r"),
        OldName::Exclusion.new(path: "spec/kept.rb", pattern: /collector-backup/, reason: "r")
      ]
      found = described_class.new(root, files: %w[spec/kept.rb], exclusions:).call
      expect(found.map(&:form)).to include("a stale exclusion: spec/gone.rb", "a stale exclusion: spec/kept.rb")
    end

    it "reads the agent's instructions and no other document (AC-7.6)", :aggregate_failures do
      %w[CLAUDE.md .claude/CLAUDE.md .claude/rules/testing.md .claude/skills/wyrms-hoard-design-system/SKILL.md app/models/x.rb compose.yaml].each do |path|
        expect(OldName.read?(path)).to be(true), path
      end
      %w[README.md docs/architecture/catalog-core.md .claude/memory/foundation.md .claude/integrations.md spikes/x.rb .kamal/hooks/x].each do |path|
        expect(OldName.read?(path)).to be(false), path
      end
    end

    it "finds nothing in the real tree (AC-7.1)" do
      pending "until T4.7 renames the last documents the check reads" # T4.7 removes this line
      found = described_class.new(Rails.root).call
      expect(found.map(&:to_s)).to eq([])
    end

    it "finds a form added to CLAUDE.md (AC-7.7)" do
      text = Rails.root.join("CLAUDE.md").read + "\nSet COLLECTOR_HTTPS.\n"
      expect(judge("CLAUDE.md", text).map(&:form)).to include("an environment variable")
    end
  end
  ```

  Run `bin/rspec spec/script/old_name/check_spec.rb`. Expect `LoadError` (no `script/old_name/check.rb`).

  Commit: `test(rename): the old-name check's forms, kinds, exclusions and reach (#438)`.
- [ ] **T4.2 The check.** Create `script/old_name/check.rb`:

  ```ruby
  # Fails when the application's old name, Collector, appears in the code, the configuration or the agent's instructions
  # outside a written exclusion (spec 092 decisions 9 to 11, FR-9, issue #438). It matches the old name's forms, never the
  # word: "a collector" is the person, collector_number the card's collector line, collector-export the export's
  # identifier, and those stay (decision 10). Run as `ruby script/old_name/check.rb` from the repository root (the
  # bin/ci checks step, so a documentation-only push runs it too). Development tooling: under script/, outside the image.
  return if defined?(OldName)

  require "open3"
  require "pathname"

  module OldName
    # What the check reads (decision 11): code and configuration, and the documents an agent takes its instructions from.
    DIRECTORIES = %w[app/ bin/ config/ db/ lib/ public/ script/ spec/ .github/ .githooks/ .claude/hooks/ .claude/rules/ .claude/skills/].freeze
    FILES = %w[.dockerignore .rubocop.yml .yardopts .worktreeinclude Dockerfile compose.yaml orca.yaml Gemfile Gemfile.lock
      Rakefile config.ru CLAUDE.md .claude/CLAUDE.md].freeze

    # One form of the old name (decision 9), named in a failure.
    Form = Data.define(:name, :pattern)
    # A place the old name must stay, with why (decision 11). A nil pattern excludes the whole path.
    Exclusion = Data.define(:path, :pattern, :reason)
    # One hit: where, and which form.
    Finding = Data.define(:path, :line, :form) do
      # @return [String] "path:line: form", or "path: form" for a path or a stale exclusion
      def to_s = line ? "#{path}:#{line}: #{form}" : "#{path}: #{form}"
    end

    # The capitalised name, unless a card's label follows (decision 10) or it is Rails' MimeResponds::Collector. The first
    # alternative lets `\ACollector/` in a pattern count, since `A` is a word character.
    CAPITALISED = /(?:(?<=\\A)|(?<![A-Za-z0-9_]))(?<!MimeResponds::)Collector(?![A-Za-z0-9_])(?!\s+(?:numbers?|lines?|strip)\b)/

    FORMS = [
      Form.new("the capitalised name", CAPITALISED),
      Form.new("an environment variable", /COLLECTOR_/),
      Form.new("a rake task or an image tag", %r{(?<![A-Za-z0-9_./:-])collector:[a-z]}),
      Form.new("the rake namespace", /namespace :collector\b/),
      Form.new("a container or a service", /(?:--name|service:) collector\b/),
      Form.new("the volume", /collector_storage/),
      Form.new("the session cookie", /_collector_session/),
      Form.new("the rake file or its spec", /collector(?:\.rake|_rake)/),
      Form.new("a hyphenated name", /(?<![A-Za-z0-9_])collector-(?:backup|restore|ghcr-cleanup|dev|mark|wordmark|design-system|smoke|measure|db)/),
      Form.new("the image", %r{plainprogrammer/collector}),
      Form.new("the package", %r{packages/container/collector\b}),
      Form.new("a checkout", /collector\.git\b/),
      Form.new("a directory", %r{(?:/collector(?=/|["'\s)\]\}]|\z)|(?<![A-Za-z0-9_./-])collector/)})
    ].freeze

    EXCLUSIONS = [
      Exclusion.new(path: "db/migrate/", pattern: nil, reason: "released migrations are never edited (ADR 0032 decision 7)"),
      Exclusion.new(path: "spec/migrations/set_account_currency_from_the_instance_spec.rb", pattern: /COLLECTOR_CURRENCY/,
        reason: "the released currency migration's spec sets the setting that migration reads (ADR 0032 decision 7)"),
      Exclusion.new(path: "script/upgrade/harness.rb", pattern: %r{ghcr\.io/plainprogrammer/collector|collector-backup},
        reason: "the upgrade proof pulls 0.3.0 and earlier from the old package and reads the backup prefix they print (decision 13)"),
      Exclusion.new(path: "spec/script/upgrade/harness_spec.rb", pattern: %r{ghcr\.io/plainprogrammer/collector|collector-backup},
        reason: "the examples of that rule (decision 13)"),
      Exclusion.new(path: "spec/support/upgrade_fakes.rb", pattern: %r{ghcr\.io/plainprogrammer/collector|collector-backup},
        reason: "the fake of a release of 0.3.0 or earlier (decision 13)"),
      Exclusion.new(path: "lib/wyrms_hoard/backup/restore.rb", pattern: /collector-restore/,
        reason: "the restore removes what a stopped restore of 0.3.0 left (decision 12)"),
      Exclusion.new(path: "spec/lib/wyrms_hoard/backup/create_spec.rb", pattern: /collector-backup/,
        reason: "the sweep's examples of an old leftover (decision 12)"),
      Exclusion.new(path: "spec/lib/wyrms_hoard/backup/restore_spec.rb", pattern: /collector-(?:backup|restore)/,
        reason: "the examples that an old backup restores and an old temporary is removed (decision 12)"),
      Exclusion.new(path: "spec/factories/accounts.rb", pattern: /"Collector #\{n\}"/, reason: "a person's name (decision 10)"),
      Exclusion.new(path: "spec/migrations/backfill_households_spec.rb", pattern: /"Collector #\{i\}"/, reason: "a person's name (decision 10)"),
      Exclusion.new(path: "spec/system/card_page_spec.rb", pattern: /Collector Showcase/, reason: "a card set's name (decision 10)"),
      Exclusion.new(path: "spec/tasks/wyrms_hoard_rake_spec.rb", pattern: /collector:user/,
        reason: "the example that proves the old command is gone (AC-3.4)"),
      Exclusion.new(path: "spec/old_settings_spec.rb", pattern: /COLLECTOR_/, reason: "the examples that prove an old setting has no effect (AC-3.2)"),
      Exclusion.new(path: "script/old_name/check.rb", pattern: nil, reason: "the check names the forms it looks for"),
      Exclusion.new(path: "spec/script/old_name/check_spec.rb", pattern: nil, reason: "its examples inject the forms")
    ].freeze

    # Whether the check reads a path at all (decision 11).
    #
    # @param path [String] a path relative to the repository's root
    # @return [Boolean]
    def self.read?(path) = FILES.include?(path) || DIRECTORIES.any? { path.start_with?(it) }

    # The forms in one file's text, line by line.
    #
    # @param path [String] the file's path, for the findings
    # @param text [String] its contents
    # @return [Array<Finding>]
    def self.judge_text(path, text)
      text.each_line.with_index(1).flat_map do |line, number|
        FORMS.filter_map { |form| Finding.new(path:, line: number, form: form.name) if form.pattern.match?(line) }
      end
    end

    # The forms in a path itself (AC-7.4).
    #
    # @param path [String]
    # @return [Array<Finding>]
    def self.judge_path(path) = FORMS.filter_map { |form| Finding.new(path:, line: nil, form: "#{form.name} in the path") if form.pattern.match?(path) }

    # Judges the tracked files the check reads.
    class Check
      # @param root [Pathname, String] the repository's root
      # @param files [Array<String>, nil] the paths to judge; nil asks git for the tracked files the check reads
      # @param exclusions [Array<Exclusion>]
      def initialize(root, files: nil, exclusions: EXCLUSIONS)
        @root = Pathname(root)
        @files = files || tracked.select { OldName.read?(it) }
        @exclusions = exclusions
      end

      # Every finding outside the exclusions, and every stale exclusion (AC-7.5).
      #
      # @return [Array<Finding>]
      def call
        used = Hash.new(false)
        found = @files.flat_map do |path|
          whole = @exclusions.find { it.pattern.nil? && path.start_with?(it.path) }
          next (used[whole] = true) && [] if whole

          hits = OldName.judge_path(path) + text_findings(path)
          hits.reject do |hit|
            excused = @exclusions.find { it.pattern && it.path == path && hit.line && line_at(path, hit.line).match?(it.pattern) }
            used[excused] = true if excused
          end
        end
        found + @exclusions.reject { used[it] }.map { Finding.new(path: it.path, line: nil, form: "a stale exclusion: #{it.path}") }
      end

      private

      def tracked
        out, status = Open3.capture2("git", "ls-files", "-z", chdir: @root.to_s)
        raise "git ls-files failed" unless status.success?

        out.split("\0")
      end

      def text_findings(path)
        bytes = @root.join(path).binread
        return [] if bytes.byteslice(0, 8000).include?("\0") # a binary file is judged by its path only

        OldName.judge_text(path, bytes.force_encoding(Encoding::UTF_8).scrub)
      end

      def line_at(path, number) = @root.join(path).read.lines[number - 1].to_s
    end
  end

  if $PROGRAM_NAME == __FILE__
    found = OldName::Check.new(Dir.pwd).call
    if found.empty?
      puts "The old name appears nowhere outside its exclusions (spec 092)."
    else
      warn found.map(&:to_s)
      warn "\n#{found.size} found. Use the new name (spec 092 decision 2), or, where the old one must stay, add an exclusion with its reason in script/old_name/check.rb."
      exit 1
    end
  end
  ```

  Delete `spec/rename_internal_names_spec.rb` (pull request B's pin): the check replaces it, and its logo-path example would fail once T4.6 renames the mark (`git rm` in a call of its own). In `spec/old_settings_spec.rb`, delete the example "reads no COLLECTOR_ setting anywhere but the released currency migration": the check holds `COLLECTOR_` in its own forms and so would fail it, and the check now proves AC-3.3 (spec decision 18: "AC-3.3 until the check exists"). The file's exclusion stays live through its other examples.

  Notes for the implementer:
  - **Whole-path exclusions:** a directory exclusion (`db/migrate/`) is stale only when no tracked file is under it.
  - **The stale rule for a pattern:** an exclusion with a pattern is stale when no line of its file both holds a form and matches the pattern. A line that matches a pattern but holds no form is not a use.
  - **Encodings:** binary files are skipped by the NUL test. A text file that isn't UTF-8 is scrubbed.

  Then:
  1. Run `bin/rspec spec/script/old_name/check_spec.rb`. Expect every injected example to pass and the real-tree example to be pending, listing what pull request D still has to rename: that list is T4.4 to T4.7's worklist. Save it with `ruby script/old_name/check.rb > tmp/092_d_worklist.txt 2>&1`.
  2. **If a stays line is found:** if the list shows a line that is one of decision 10's kinds but is matched, stop and bring it to the coordinator. The fix is a spec change (a new kind), not a wider pattern.
  3. Commit: `feat(rename): the old-name check (#438)`.
- [ ] **T4.3 The `bin/ci checks` step** (AC-7.8).
  1. Add to `spec/config/ci_definition_spec.rb`:

     ```ruby
     it "runs the old-name check in bin/ci checks, directly after the licence check and not with the RSpec group (spec 092 AC-7.8)", :aggregate_failures do
       lines = Rails.root.join("config/ci.rb").readlines(chomp: true).map(&:strip)
       licences = lines.index('step "Licences: dependencies are under allowed licences", "bin/rails licences:check"')
       check = lines.index('step "Names: the old name stays out", "ruby script/old_name/check.rb"')
       guarded = lines.index("unless selection.group == :rspec")

       expect(check).to eq(licences + 1)
       expect(check).to be < lines.each_index.find { |i| i > guarded && lines[i] == "end" }
     end
     ```

  2. Run it; expect a failure.
  3. In `config/ci.rb`, after the licence step, add `step "Names: the old name stays out", "ruby script/old_name/check.rb"`.
  4. Run the spec again; expect a pass.
  5. Commit: `ci(rename): bin/ci checks runs the old-name check (#438)`.
  6. AC-7.8's first half is proven in T4.9: on a scratch branch, add `Set COLLECTOR_HTTPS.` to `CLAUDE.md`, run `bin/ci checks`, and record that the step "Names: the old name stays out" fails naming `CLAUDE.md`, the line and "an environment variable". Delete the scratch branch.
- [ ] **T4.4 The display name, failing first** (AC-6.1, AC-6.4, AC-6.6 to AC-6.12).
  1. Change the expected strings in these specs from the old name to `Wyrm's Hoard`, or `Wyrm&#39;s Hoard` where a spec reads raw HTML (FR-7):
     - the request specs that assert titles: `git grep -ln "· Collector" -- spec`;
     - `spec/requests/licence_line_spec.rb` and `footer_spec.rb`: `Wyrm's Hoard <version> (<sha>)`, and the notice `Wyrm's Hoard is unofficial Fan Content`;
     - `spec/requests/licences_spec.rb`;
     - the import's, the backup's, the restore's and the start check's message specs: `git grep -ln "Collector" -- spec/models/collection_import* spec/lib/wyrms_hoard/backup spec/lib/wyrms_hoard/start_check_spec.rb spec/models/user_spec.rb spec/requests/registrations*`;
     - `spec/models/mtg/scryfall/client_spec.rb`: the User-Agent, `%r{\Awyrms-hoard/}`;
     - `spec/lib/wyrms_hoard/ocr_engine_spec.rb` and `ghcr_cleanup` specs: their User-Agents;
     - `spec/lib/wyrms_hoard/build_facts_spec.rb`: `UPSTREAM_SOURCE`;
     - `spec/script/yard/links_spec.rb`: the base URL;
     - the specs that read the export schemas' `title`;
     - and every other spec the worklist names: `grep '^spec/' tmp/092_d_worklist.txt | cut -d: -f1 | sort -u`. At `50435ba3` that adds `spec/requests/admin/users_spec.rb`, `collection_import_previews_spec.rb`, `catalog/visitors_spec.rb`, `shell_spec.rb` (raw HTML, so `&#39;`), `spec/models/mtg/scryfall/source_spec.rb`, `spec/system/footer_spec.rb`, `spec/script/yard/site_spec.rb`, `spec/tasks/backup_restore_rake_spec.rb` and `spec/script/upgrade/harness_spec.rb:545,547`.
  2. Add to `spec/requests/shell_spec.rb`:

     ```ruby
     it "names the application in the head (spec 092 AC-6.1, AC-6.7)", :aggregate_failures do
       get collection_path # the file signs in before each example; the sign-in page would redirect
       expect(response.parsed_body.at("title").text).to end_with("Wyrm's Hoard")
       expect(response.parsed_body.at('meta[name="application-name"]')["content"]).to eq("Wyrm's Hoard")
     end
     ```

     The manifest isn't routed (`config/routes.rb:10` is commented), and routing it would change behaviour (Non-Goals). Add a `type: :config` example to `spec/design_system_files_spec.rb`:

     ```ruby
     it "names the application in the web app manifest (spec 092 AC-6.7)", :aggregate_failures do
       manifest = JSON.parse(ERB.new(Rails.root.join("app/views/pwa/manifest.json.erb").read).result)
       expect(manifest["name"]).to eq("Wyrm's Hoard")
       expect(manifest["description"]).to include("Wyrm's Hoard")
     end
     ```

     If the template calls helpers `ERB#result` can't reach, render it with `ApplicationController.render(template: "pwa/manifest", formats: :json)` instead.
  3. Also change `spec/image_publishing_spec.rb:102`'s expected `grep` line for the licence line to T4.5's `Wyrm&#39;s Hoard ${version} (${short}) is free software`.
  4. Run the changed specs; expect failures.
  5. Commit: `test(rename): the application calls itself Wyrm's Hoard (#438)`.
- [ ] **T4.5 Rename the display name** from the worklist (`tmp/092_d_worklist.txt`), file by file.
  1. **Titles:**

     ```
     git grep -l "· Collector" -- app | xargs perl -pi -e 's/ · Collector"/ · Wyrm\x27s Hoard"/g'
     ```

     The layout's default title, `application-name`, the manifest's `name` and `description` (the current `"Collector."` becomes `"Wyrm's Hoard."`: the name only, FR-7), the two `aria-label`s ("Wyrm's Hoard home", "Wyrm's Hoard search"), and `.yardopts`' `--title "Wyrm's Hoard"` are edited by hand.
  2. **Messages** (decision 9's last row): replace the name, keep every other word.
     - A string in single quotes that gains the apostrophe moves to double quotes. RuboCop's `Style/StringLiterals` and the parser catch a miss.
     - `WyrmsHoard::BuildFacts#name` returns `"Wyrm's Hoard #{version}…"` and `"Wyrm's Hoard (#{…})"`, and its comment's examples change with it.
     - `bin/image-smoke:77` greps `Wyrm&#39;s Hoard ${version} (${short}) is free software`, with a comment that the page escapes the apostrophe.
     - `bin/backup-smoke:238` greps `Wyrm's Hoard did not start`, the start check's log line, which isn't HTML.
  3. **The schemas:** each `vN.schema.json`'s `title` becomes `Wyrm's Hoard export, format version N`, and its `description` says `Wyrm's Hoard export`. `$id` and `format` stay (AC-6.9). The schemas exist twice and must stay byte-identical (`spec/models/export_format/rules_spec.rb`): edit `docs/export-format/vN.schema.json`, then `cp docs/export-format/v*.schema.json app/models/export_format/`. Run `bin/rspec spec/models/export_format/rules_spec.rb`; expect 0 failures.
  4. **Comments in code** that name the application ("Self-host Collector", "/* Collector … */") take the new name.
  5. Run T4.4's specs except the link and User-Agent ones, which stay red until T4.6 step 7. Expect 0 failures.
  6. **Commit:** `feat(rename): the application calls itself Wyrm's Hoard (#438)`.
- [ ] **T4.6 The text wordmark, the mark's files, the links and the User-Agents** (decisions 6, 9 and 14; AC-6.2 to AC-6.5, AC-6.10 to AC-6.12).
  1. **Move the mark's files, delete the wordmark's,** one git operation per call:

     ```
     git mv app/assets/images/wyrms_hoard/collector-mark.svg app/assets/images/wyrms_hoard/wyrms-hoard-mark.svg
     git mv app/assets/images/wyrms_hoard/collector-mark-reversed.svg app/assets/images/wyrms_hoard/wyrms-hoard-mark-reversed.svg
     git rm app/assets/images/wyrms_hoard/collector-wordmark.svg app/assets/images/wyrms_hoard/collector-wordmark-reversed.svg
     ```

     In both mark files, `aria-label="Collector"` becomes `aria-label="Wyrm's Hoard"`. `spec/design_system_files_spec.rb` expects the two mark files. The favicon's `asset_path` names `wyrms_hoard/wyrms-hoard-mark.svg`.
  2. **`app/views/layouts/_appbar_logos.html.erb`,** used inside a labelled link, so every `alt` is empty (AC-6.4):

     ```erb
     <%# Spec 092 decisions 6 and 14: the mark beside the name as live text (TextWordmark.md); below the swap points the mark stands alone. The link around it carries the accessible name. %>
     <span class="c-appbar__wordmark"><%= image_tag "wyrms_hoard/wyrms-hoard-mark.svg", alt: "", class: "c-logo--light" %><%= image_tag "wyrms_hoard/wyrms-hoard-mark-reversed.svg", alt: "", class: "c-logo--dark" %><span class="c-appbar__name">Wyrm's Hoard</span></span>
     <span class="c-appbar__mark"><%= image_tag "wyrms_hoard/wyrms-hoard-mark.svg", alt: "", class: "c-logo--light" %><%= image_tag "wyrms_hoard/wyrms-hoard-mark-reversed.svg", alt: "", class: "c-logo--dark" %></span>
     ```

  3. **`app/views/layouts/_brand_appbar.html.erb`,** an unlabelled span. The text names the brand in the wordmark; the mark alone carries the name in its `alt`:

     ```erb
     <header class="c-appbar" id="appbar">
       <span class="c-appbar__brand">
         <span class="c-appbar__wordmark"><%= image_tag "wyrms_hoard/wyrms-hoard-mark.svg", alt: "", class: "c-logo--light" %><%= image_tag "wyrms_hoard/wyrms-hoard-mark-reversed.svg", alt: "", class: "c-logo--dark" %><span class="c-appbar__name">Wyrm's Hoard</span></span>
         <span class="c-appbar__mark"><%= image_tag "wyrms_hoard/wyrms-hoard-mark.svg", alt: "Wyrm's Hoard", class: "c-logo--light" %><%= image_tag "wyrms_hoard/wyrms-hoard-mark-reversed.svg", alt: "Wyrm's Hoard", class: "c-logo--dark" %></span>
       </span>
     </header>
     ```

  4. **The pattern,** in `app/assets/stylesheets/wyrms_hoard/additions.css`, above the five-link rule:

     ```css
     /* ---------- Text wordmark (spec 092 decisions 6 and 14): the mark beside the application's name, set in the display face ---------- */
     .c-appbar__wordmark { display:inline-flex; align-items:center; gap:var(--space-2); }
     .c-appbar__name { font:600 20px/28px var(--font-display); color:var(--ink); white-space:nowrap; }
     ```

     Its size follows `.type-heading`'s 20px/28px, the closest step to the 32px mark, written in the `font:` shorthand as the app bar's other rules in `components.css` are; the design system has no size tokens, so this is the convention, not a hard-coded value outside it. The colour token switches with the theme, so no reversed variant is needed. Write `docs/design-system/components/TextWordmark.md` from `AppHeader.md`'s shape: what it is, its markup, its classes, the swap points, and accessibility (the link's name, the empty `alt`). Update `docs/design-system/logos.md`: the two mark files, and the wordmark as text. Update `AppHeader.md`, `VisitorHeader.md` and `SystemLogo.md`, the previews that loaded the wordmark SVGs (`git grep -l collector-wordmark -- docs/design-system`), and `tokens.json`'s `"name": "Wyrm's Hoard"`.
  5. **Measure, then set the swap point** (decision 14, AC-6.3). Add a temporary example to `spec/system/design_system_deck_rules_spec.rb`'s header group, and run it alone:

     ```ruby
     it "measures the header (spec 092 decision 14, temporary)" do
       fits = ->(width, links) do
         open_in_narrow_frame(collection_path, width:, ready: ".c-appbar__nav", height: 1200)
         within_narrow_frame do
           page.execute_script("document.querySelector('.c-appbar__nav a[href=\"#{locations_path}\"]').remove()") if links == 4
           page.execute_script("document.querySelectorAll('.c-appbar__wordmark').forEach(e => e.style.display = 'inline-flex'); document.querySelectorAll('.c-appbar__mark').forEach(e => e.style.display = 'none')")
           header_fits?(header_fit)
         end
       end
       first_five = (640..1000).find { fits.(it, 5) }
       puts "five links fit with the text from #{first_five}px; swap point #{first_five + 25}px; four links at 640px: #{fits.(640, 4)}"
       open_in_narrow_frame(collection_path, width: 1280, ready: ".c-appbar__nav", height: 900)
       width = within_narrow_frame { evaluate("return document.querySelector('.c-appbar__wordmark').getBoundingClientRect().width") }
       puts "the mark and the text are #{width}px wide"
     end
     ```

     Run `bin/rspec spec/system/design_system_deck_rules_spec.rb -e "measures the header"`. Record the three numbers for `verification.md`, then delete the example. Let S be the swap point:
     - **S = 720:** the CSS rule stays.
     - **Otherwise:** change `additions.css`'s rule to `@media (min-width: 640px) and (max-width: <S − 1>px)`. Update its comment with the measured numbers, and change the guard examples' widths from 719 and 720 to S − 1 and S.
     - **Four links at 640px don't fit:** drop `:has(.c-appbar__nav > :nth-child(5))` from both declarations, so the swap applies whatever the number of links. Change the four-link example to expect the mark alone, and note that spec 057 AC-1.6 is superseded in full (index cell in T4.8).
  6. **The guard and the other headers** (AC-6.2, AC-6.3).
     - Move `logo` from `spec/system/design_system_deck_rules_spec.rb` (the five-links group, `:202` at `50435ba3`) into `DesignSystemProbe` (`spec/support/design_system_probe.rb`), with its summary comment, and delete it from the spec file. That file's examples call it unchanged.
     - Create `spec/system/app_bar_headers_spec.rb`. It has no sign-in, and it opens a page before each example, so the narrow frame has a host:

       ```ruby
       require "rails_helper"

       # Spec 092 AC-6.3: the brand app bar (sign-in, first run, the licences page) and the visitor's header have no
       # five-link navigation, so only the phone rule applies: the text wordmark from 640px, the mark alone below it.
       RSpec.describe "The headers without a signed-in collector", type: :system do
         include DesignSystemProbe

         before { visit new_session_path }

         [ [ 640, true ], [ 639, false ] ].each do |width, text|
           it "shows #{text ? "the text wordmark" : "the mark alone"} in the brand app bar at #{width}px" do
             open_in_narrow_frame(new_session_path, width:, ready: ".c-appbar", height: 900)
             within_narrow_frame { expect(logo).to eq("wordmark" => text, "mark" => !text) }
           end

           it "shows #{text ? "the text wordmark" : "the mark alone"} in the visitor's header at #{width}px", :public_catalog do
             open_in_narrow_frame(catalog_entries_path, width:, ready: ".c-appbar", height: 900)
             within_narrow_frame { expect(logo).to eq("wordmark" => text, "mark" => !text) }
           end
         end

         [ 320, 360 ].each do |width|
           it "doesn't overflow the brand app bar or the visitor's header at #{width}px", :aggregate_failures, :public_catalog do
             [ new_session_path, catalog_entries_path ].each do |path|
               open_in_narrow_frame(path, width:, ready: ".c-appbar", height: 900)
               within_narrow_frame { expect(evaluate("const a = document.querySelector('.c-appbar'); return a.scrollWidth <= a.clientWidth")).to be(true), path }
             end
           end
         end
       end
       ```

     - In `spec/system/design_system_deck_rules_spec.rb`'s signed-in header group, add:

       ```ruby
       it "draws the name as text, never as an image of the old name (spec 092 AC-6.2)", :aggregate_failures do
         visit collection_path
         expect(page).to have_css(".c-appbar__name", text: "Wyrm's Hoard")
         expect(page).to have_no_css('img[src*="wordmark"]')
       end
       ```

     - Run `bin/rspec spec/system/app_bar_headers_spec.rb spec/system/design_system_deck_rules_spec.rb spec/design_system_files_spec.rb`; expect 0 failures.
     - Commit steps 1 to 6: `feat(rename): the text wordmark and the mark's files (#438)`.
  7. **The links and the User-Agents** (FR-8, decision 9):
     - `WyrmsHoard::BuildFacts::UPSTREAM_SOURCE = "https://github.com/plainprogrammer/wyrmshoard"`, and `script/yard/links.rb`'s `GITHUB` to the same.
     - `MTG::Scryfall::Client`'s agent: `"wyrms-hoard/1.0 (+https://github.com/plainprogrammer/wyrmshoard)"`.
     - `WyrmsHoard::OcrEngine`'s: `"wyrms-hoard OCR engine fetch"`.
     - `WyrmsHoard::GhcrCleanup::Client::USER_AGENT`: `"wyrms-hoard-ghcr-cleanup (+https://github.com/plainprogrammer/wyrmshoard)"`.
     - The fixtures' checkout paths and `collector.git` become `wyrmshoard`. Rename `spec/lib/wyrms_hoard/backup/free_space_spec.rb`'s `/no/such/place/for/collector` to `/no/such/place/for/wyrms_hoard`.
  8. **Run** the changed specs of T4.4, the link and User-Agent ones now included. Expect 0 failures. Then `ruby script/old_name/check.rb`: only documents are left on the list, the ones T4.7 renames.
  9. **Commit** step 7: `feat(rename): the repository's links and the User-Agents (#438)`.
- [ ] **T4.7 The agent's instructions and the rule** (decision 11, AC-7.6, AC-7.7).
  1. Rename what the check still finds in `CLAUDE.md`, `.claude/CLAUDE.md`, `.claude/rules/` and `.claude/skills/`. `CLAUDE.md`'s first paragraph calls the application Wyrm's Hoard.
  2. In `.claude/rules/testing.md`, the last line becomes:

     ```markdown
     - ✗ Don't check prose documents (`README.md`, `CLAUDE.md`, the files under `.claude/`, the Markdown and reference files under `docs/`) from RSpec; a document criterion is verified by reading and recorded in the spec's `verification.md`. Two exceptions: the export format's document (spec 020, decision 7), and the old-name check's reading of the agent's instructions, `CLAUDE.md`, `.claude/CLAUDE.md`, `.claude/rules/` and `.claude/skills/` (spec 092 decision 11), which finds only the old name's forms; the reading still covers the rest.
     ```

  3. Add the step to `CLAUDE.md`'s `bin/ci` list ("the old-name check (`ruby script/old_name/check.rb`: the old name's forms stay out of the code and the agent's instructions, spec 092)") and to `.claude/rules/testing.md`'s first bullet's list of what `bin/ci` runs.
  4. Run `ruby script/old_name/check.rb`. Expect `The old name appears nowhere outside its exclusions (spec 092).`
  5. Remove the `pending` line from the real-tree example. Run `bin/rspec spec/script/old_name/check_spec.rb`. Expect 0 failures and nothing pending.
  6. Commit: `docs(rename): the agent's instructions use the new name, and the testing rule names the check (#438)`.
- [ ] **T4.8 The rest of the living documents and the supersessions** (decision 15, FR-10, FR-11, AC-8.1, AC-8.4, AC-8.5).
  1. **Rename the application's name in the living documents of decision 15** that pull requests B and C didn't finish, by hand:
     - `README.md` (heading, first sentence, the procedures' prose);
     - `docs/architecture/*.md` and the area docs' README;
     - `docs/design-system/README.md` and the remaining component docs;
     - `docs/roadmap.md` (not its dated decision log rows), `docs/north-star.md`;
     - `docs/git-convention.md`, `docs/backup-restore.md`, `docs/releasing.md` (above 0.3.0's notes);
     - the prose of `docs/export-format/` (not the identifier);
     - `docs/adr/README.md`'s and `docs/specs/README.md`'s own prose (not quoted record titles);
     - `.claude/integrations.md`, `.claude/memory/foundation.md` and `.claude/memory/steering/*.md`.

     Issue, pull request and commit links stay (decision 15).
  2. **Memory files** that state a current name, path, command or image. From the brainstorm's search: `MEMORY.md`, `card-scanner-direction.md`, `claude-p-hook-proof.md`, `container-engine-colima-macos.md`, `ghcr-and-actions-facts.md`, `phone-lan-dev-access.md`, `pr-screenshots-workflow.md`, `pre-push-hook-trigger-text.md`, `rails-config-x-unset.md`, `shipped-percentile-upper-middle.md`, `spec-015-followups.md`, `brainstorm-mockups-with-collector-css.md`, `design-system-owned-in-code.md`. In each, update the statements of what is true now (a command to run, a path, an image to pull) and leave what it says happened. Re-run the search to catch any added since:

     ```
     git grep -lE 'COLLECTOR_|Collector::|lib/collector|plainprogrammer/collector|collector:user|collector_storage|collector-design-system|collector-backup|(stylesheets|fonts|images)/collector|collector-(mark|wordmark)|/collector/' -- .claude/memory
     ```

  3. **The index** (FR-11, AC-8.4). Complete row 092's Supersedes cell, and each named row's Superseded by cell, from the spec's Supersedes table:
     - the display rows: 001, 004, 018, 020 (AC-1.1 and the Glossary; decision 7 and AC-4.7 in part), 023 decision 3, 025, 032, 038 decision 7, 057 (and AC-1.6 in full if T4.6 dropped the five-link condition), 062, 064, 066, 068, 071, 081, 084 decision 2 and decision 5, 086's messages, 087;
     - (the skill's name was filled by B, T2.6).

     Set row 092's Status to Shipped when D merges (the distillation step's job). Its Areas cell is already filled.
  4. **The area docs** that cover a superseded criterion state the new value with its source (spec 092 and the criterion). Add #438 to each touched area doc's Sources.
  5. **Commit:** `docs(rename): the living documents and the index (#438)`.
- [ ] **T4.9 Verification and the implementation review** (decision 18).
  1. **Write `docs/specs/092-rename-to-wyrms-hoard/verification.md`.** One section per story, listing each AC with its evidence: the spec example, the command and its output, or what was read. It includes:
     - T0.4's redirect and T1.1's count;
     - T2.4's Brakeman count and T2.6's runs;
     - T3.9's upgrade proof and the notes' procedure, command by command;
     - T4.6's three measurements and the swap point;
     - the check step's time (`time ruby script/old_name/check.rb`, under 5 seconds: the NFR), and AC-7.8's scratch-branch run (T4.3 step 6);
     - the reading of each living document (AC-8.1), one line per document: read, which forms it still names and why;
     - AC-8.5's `git diff <commit before A>..HEAD -- docs/specs/0*/ docs/adr/0*.md docs/lessons docs/superpowers ':!docs/specs/092-rename-to-wyrms-hoard'`, expected empty but for lines `.claude/rules/documentation.md` allows.
  2. **Screenshots.** Take them on this branch: the signed-in app bar at 1280px, at S, at S − 1 and at 360px, and the sign-in page at 1280px and 360px, each in both themes. Embed them in the pull request by SHA-pinned links (memory: PR screenshots workflow, visual evidence).
  3. **The review.** Dispatch `sdd-superpowers:sdd-review` Mode B, read-only, on Opus (memory: review model), over pull requests A to D. Record it under `## Implementation review`. The first line gives the verdict and what is owed: `SPEC-ALIGNED, AC-5.6 to AC-5.8 owed to the release (#439, #440)`.
  4. **The distillation step.** Set the spec's `**Branch:**` line to `092-rename-display-name` alone, and run `distill-feature`, which writes the area docs' remaining rules and marks the index.
  5. **Push.** The coordinator runs `bin/ci`, pushes, and opens pull request D with the screenshots.

---

## Phase 5: The release (#439, #440)

**Implements:** decision 1 step 6 | **Satisfies:** AC-5.6, AC-5.7, AC-5.8
**Files:** `docs/specs/092-rename-to-wyrms-hoard/verification.md` (evidence added), `docs/releasing.md` only if a step proves a note wrong.
**Interfaces:** Consumes: Phases 3 and 4 merged. Produces: release 0.4.0 at `ghcr.io/plainprogrammer/wyrmshoard`, and the maintainer's instance upgraded.

- [ ] **T5.1 The package is public** (#439, AC-5.6). On a machine with no saved `ghcr.io` login (memory: the dev machine's saved login denies pulls), run:

  ```
  token=$(curl -s "https://ghcr.io/token?scope=repository:plainprogrammer/wyrmshoard:pull" | jq -r .token)
  curl -s -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $token" -H 'Accept: application/vnd.oci.image.index.v1+json' https://ghcr.io/v2/plainprogrammer/wyrmshoard/manifests/edge
  ```

  Expect `200`. If it isn't, the maintainer makes the package public in its settings and checks it is linked to the repository; then run it again. Record the output and close #439.
- [ ] **T5.2 Release 0.4.0** (AC-5.7), by `docs/releasing.md`'s procedure: the annotated tag `v0.4.0` on `main`, the upgrade proof in the image job, the publish.
  1. Run `gh api /users/plainprogrammer/packages/container/wyrmshoard/versions --jq '[.[].metadata.container.tags] | flatten'`. Expect it to include `0.4.0`, `0.4` and `latest`, and no `0`.
  2. Run T5.1's anonymous request for `0.4.0`. Expect `200`.
  3. Pull it and run `bin/image-smoke`. Its licence line reads `Wyrm's Hoard 0.4.0`.
  4. Run the same `gh api … container/collector/versions` listing as T3.9 step 3.1 and compare it with `tmp/092/old-package-before.txt`. Expect them identical (AC-5.1, ADR 0033 decision 3).
- [ ] **T5.3 The maintainer's instance** (#440, AC-5.8). The maintainer follows the 0.4.0 upgrade notes and nothing else. The coordinator records what they report: the collection, locations and decks are there, and any note that was wrong is corrected in a follow-up pull request. Add T5.1 to T5.3's evidence to `verification.md` and close #440 and #433.

---

## Integration Verification

**Implements:** all FRs | **Satisfies:** all ACs

- [ ] After each of A, B, C and D merges, `main`'s CI is green, the image job's three smoke tests pass, and an `edge` image is published: to the old package after A and B, to the new one from C.
- [ ] On D's branch, `bin/ci` passes with the old-name step, and `verification.md` lists every AC with its evidence, AC-5.6 to AC-5.8 marked owed.
- [ ] After the release, `verification.md` holds T5's evidence and every AC is checked.

## Quickstart Validation

On `main` after D:

```
ruby script/old_name/check.rb                      # The old name appears nowhere outside its exclusions (spec 092).
bin/rails runner 'puts Rails.application.class.module_parent_name'   # WyrmsHoard
bin/rails -T wyrms_hoard                            # bin/rails wyrms_hoard:user[email]
WYRMS_HOARD_PUBLIC_CATALOG=true bin/dev             # the catalog opens to visitors; COLLECTOR_PUBLIC_CATALOG=true does not
```

Then open `/session/new` at 1280px and 360px: the header shows the mark with "Wyrm's Hoard" beside it, then the mark alone. Each page's title ends `· Wyrm's Hoard`, and the footer's line begins `Wyrm's Hoard development`.

## Spec coverage

| Requirement | Phase and task |
|---|---|
| FR-1 | 1 (T1.1 to T1.3) |
| FR-2 | 2 (T2.1 to T2.6) |
| FR-3 | 3 (T3.1 to T3.3, T3.7) |
| FR-4 | 3 (T3.4, T3.5) |
| FR-5 | 3 (T3.6, T3.7), 5 |
| FR-6 | 3 (T3.6, T3.9) |
| FR-7 | 4 (T4.4 to T4.6) |
| FR-8 | 4 (T4.6) |
| FR-9 | 4 (T4.1 to T4.3, T4.7) |
| FR-10 | 2 (paths), 3 (T3.8), 4 (T4.7, T4.8) |
| FR-11 | 2 (T2.6), 3 (T3.8), 4 (T4.8) |
| AC-1.x | 1; AC-1.4 in 2 |
| AC-2.x | 2 |
| AC-3.x | 3 (AC-3.1's currency, HTTPS and proxies by T3.9 step 2.3) |
| AC-4.1 to AC-4.4 | 3 (T3.4, T3.5) |
| AC-4.5, AC-4.7 | 3 (T3.9 step 2) |
| AC-4.6 | 3 (T3.9 step 4) |
| AC-5.1 to AC-5.5 | 3 (T3.6, T3.9), 5 (T5.2) |
| AC-5.6 to AC-5.8 | 5 |
| AC-6.x | 4 (T4.4 to T4.6) |
| AC-7.x | 4 (T4.1 to T4.3, T4.7; AC-7.8's first half by T4.3 step 6 and T4.9) |
| AC-8.1 | 4 (T4.8, T4.9) |
| AC-8.2, AC-8.3 | 3 (T3.8, T3.9) |
| AC-8.4 | 2 (T2.6), 3 (T3.8), 4 (T4.8) |
| AC-8.5 | 4 (T4.9) |
| AC-8.6 | 0 (T0.4), 1 (T1.3) |
