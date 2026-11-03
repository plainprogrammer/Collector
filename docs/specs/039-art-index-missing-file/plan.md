# Implementation Plan: A Finished Art Build Whose Index File Is Missing Isn't "Ready"

**Spec:** [spec.md](spec.md) (v1.0.1; approved by the maintainer on 2026-11-03)
**Decisions:** no ADR. Decisions 1 and 3 and the settings-drift Non-Goal are the maintainer's rulings; the rest are the spec's.
**Created:** 2026-11-03
**Issue:** [#122](https://github.com/plainprogrammer/Collector/issues/122)

**How this plan was made.** Read-only: every code block below was traced by hand against the files it edits (`app/models/mtg/art.rb`, `app/models/mtg/art/operation.rb`, `app/models/mtg/art/index.rb`, `app/models/mtg/art_build.rb`, `app/models/catalog/operation.rb`, the specs named per phase). Nothing was run. Blocks are strong drafts, not pre-run: execution goes red first, then green, and records any deviation as a ruling in the commit body. What only a run can confirm is listed at the end.

## Global Constraints

- MTG code only: `Catalog::Operation`, the admin controllers and views, `AdminHelper` and the `poll` controller don't change (FR-4; `spec/admin_catalog_core_spec.rb`).
- No migration, gem, setting, view, job or controller change. `MTG::Art.page_config`, `MTG::Art::Build` and `MTG::Art::Index.write!` keep their behaviour.
- Examples that need a real index file write one through `MTG::Art::Index.write!` (never a hand-made file) and use the helper of Phase 1.
- Examples touching the art directory are tagged `:art_matching`, which empties `tmp/catalog/mtg/art` around each (`spec/support/art_helpers.rb`).
- UI copy (the summary and the fact labels) follows the `collector-design-system` skill's voice rules: read `docs/design-system/README.md` before wording it, as the spec's Interactions section says.
- One Conventional Commit per phase, `git add` and `git commit` as separate commands; each commit passes its files' specs. No text that holds "git" then "push" in a Bash command (the pre-push hook trigger): push from a plain command in the background (maintainer's notes: the hook runs the full `bin/ci`, about 20 minutes).
- Don't run RSpec in a subagent while `bin/ci` runs in the same worktree (one shared test database).

## Phase 1: The index says whether a file of a name is there (FR-1, decision 4)

**Red.**
- `spec/models/mtg/art/index_spec.rb`, `:art_matching`, one example, "knows whether a file of its name is there (spec 039 decision 4)", `:aggregate_failures`:
  - `path = described_class.write!("default-cards-1", [])`: `file?(path.basename.to_s)` is true;
  - false for `"art-index-default-cards-1-0123456789abcdef-3.bin.gz"` (right shape, no file), `nil`, `""`, `"art-index-upgrade.bin.gz"` (the upgrade seeds' name, not a `NAME`), and `"../../config/master.key"`;
  - false once the file is deleted (`path.delete`);
  - false for a directory that doesn't exist (`FileUtils.rm_rf(MTG::Art.root)` first).
- `spec/models/mtg/art_build_spec.rb`, one example under a new `describe "#index_file_present?"`: a finished build whose `index_file` names a written index is present; one naming nothing, with a nil `index_file`, or with `"../x"` is not.
- Helper `spec/support/art_helpers.rb`, added beside the existing `RSpec.configure` (no example of its own):

  ```ruby
  # A finished build's index file: writes an index for the version and returns its name, to set as the build's index_file
  # (spec 039). A bare finished build row has none, which now reads as "index file missing".
  module ArtIndexHelpers
    def art_index_name(version = "default-cards-1") = MTG::Art::Index.write!(version, []).basename.to_s
  end

  RSpec.configure { |config| config.include ArtIndexHelpers }
  ```

**Green.**
- `MTG::Art::Index`, after `built_for?`:

  ```ruby
  # True when a file of exactly this name is in the index directory (spec 039 decision 4). The name must be one this
  # class writes, so nothing outside the directory is looked at; the file isn't opened. A blank name, a name of another
  # shape and a directory that can't be examined are all "not there".
  def self.file?(name) = NAME.match?(name.to_s) && dir.join(name.to_s).file?
  ```

- `MTG::ArtBuild`, in the public methods before `counts`:

  ```ruby
  # Whether the index file this build wrote is still on the volume (spec 039). The row and the file can disagree after
  # a restore (a backup holds the database only) or when the directory was lost.
  def index_file_present? = MTG::Art::Index.file?(index_file)
  ```

**Commit:** `feat(art): ask whether a build's index file is still on disk`.

## Phase 2: The panel says the index file is missing (Story 1, FR-2)

**Red.**
- Existing examples that read a bare finished build as ready get a real file first (they pass before and after this phase; they would fail once it lands):
  - `spec/models/mtg/art/operation_spec.rb`: "shows the build as it ended when the job finished before the queue was read" (`quiet_build(job.active_job_id, index_file: art_index_name).finish!(:finished)`); "shows a finished build's counts and finish time (AC-4.7)" (`build(index_file: art_index_name, indexed_count: …)`); "ignores a build skipped because another was running…" (`build(index_file: art_index_name, indexed_count: 9, …)`). Its third fact check in the AC-4.7 example gains the "Index file" fact: `include("Index file" => art_index_name, …)`.
  - `spec/requests/admin/catalogs_spec.rb`, "shows a finished build's counts (AC-4.7) and a failed one's message and index (AC-4.8)": the build gets `index_file: art_index_name`; the first expected text becomes `"Art index Build art index Ready. Finished 9 Oct 2026 05:00 UTC Artworks indexed 31,904 Without an image 12 Failed images 3"` (unchanged: "Ready." keeps its facts).
- `spec/models/mtg/art/operation_spec.rb`, new context "with a finished build whose index file is gone (spec 039)", `loaded` first in each:
  1. AC-1.1, AC-1.2, AC-1.3 (`:aggregate_failures`): `build(index_file: "art-index-default-cards-1-0123456789abcdef-9.bin.gz", indexed_count: 9, without_image_count: 1, failed_count: 2)`: `state` is `:index_missing`, `summary` is "Index file missing. Build the art index again.", `startable?` true, `meter` nil, `failed_job?` false; facts by label are, in order, `["Finished", "Index file", "Artworks indexed", "Without an image", "Failed images"]` with "Index file" the name.
  2. AC-1.4 guard: the same with `index_file: art_index_name`: `:ready`, "Ready.".
  3. AC-1.5: a nil `index_file` → `:index_missing`, "Index file" fact `"none recorded"`; `"../../x"` → `:index_missing`, fact `"../../x"`.
  4. AC-1.6: a missing-file finished build and `queue_job(MTG::Art::BuildJob)` → `:queued`; a running (not left behind) build → `:building`; a failed build → `:failed` with "Failed. An unexpected error stopped it." (all three are guards of the state order and pass before the change).
  5. AC-1.7 guard: art matching off, build with no file → `:off` (in the existing "with art matching off" context, with `build(...)` and no file written; `MTG::Art::Index.file?` is expected not to be called: `expect(MTG::Art::Index).not_to receive(:file?)`).
- `spec/requests/admin/catalogs_spec.rb`, in the art section, `:art_matching`, `:aggregate_failures` (AC-1.8): refresh applied; `create(:mtg_art_build, index_file: "art-index-default-cards-1-0123456789abcdef-31904.bin.gz", indexed_count: 31_904, without_image_count: 12, failed_count: 3, finished_at: Time.utc(2026, 10, 9, 5, 0))`; `get admin_catalog_path`; the section's text equals `"Art index Build art index Index file missing. Build the art index again. Finished 9 Oct 2026 05:00 UTC Index file art-index-default-cards-1-0123456789abcdef-31904.bin.gz Artworks indexed 31,904 Without an image 12 Failed images 3"`; the button has no `disabled`; `page.at_css("[data-controller~='poll']")` is nil. (A member's 404 is the existing generic example.)

**Green.** `MTG::Art::Operation`:

```ruby
  INDEX_MISSING = "Index file missing. Build the art index again.".freeze
```

in `state`, replacing `else build.finished? ? :ready : :failed`:

```ruby
      elsif build.finished? then build.index_file_present? ? :ready : :index_missing
      else :failed
```

the header comment of `state` gains "A finished build whose index file isn't on the volume is :index_missing (spec 039); it is judged only once nothing is in flight or running, so the states above it win."; in `summary`, between `:ready` and `:failed`: `when :index_missing then INDEX_MISSING`; in `facts`, `when :ready` becomes `when :ready, :index_missing` calling a private method, and the private method is:

```ruby
    # What a finished build records, plus the file's name when that file is the point (spec 039 decision 2).
    def finished_facts
      [ fact("Finished", build.finished_at),
        (fact("Index file", build.index_file.presence || "none recorded") if state == :index_missing),
        fact("Artworks indexed", build.indexed_count), fact("Without an image", build.without_image_count),
        fact("Failed images", build.failed_count) ].compact
    end
```

with `facts`'s `when :ready, :index_missing then finished_facts`. The class header comment's last sentence gains "…, ready or index-missing (the file the build wrote is gone) or failed".

Check by reading before the green run: `Catalog::Operation#failed_job?` is overridden here to fire only for `:failed` and `:interrupted`, `record_running?` only for `:building`/`:stalled`, `meter` only for building, stalled and interrupted, so the new state needs no other change.

**Commit:** `fix(art): the art index panel says when a finished build's index file is missing`.

## Phase 3: `catalog:status` says so too (Story 2, FR-3)

**Red.** `spec/models/mtg/art_spec.rb`, under `.status_line`, `:art_matching`:
- the existing "reports a finished build's counts and index" gets `name = art_index_name` and `index_file: name` (the line still includes "ready" and the name).
- new "says the index file is missing, and what to press (spec 039 AC-2.1)", `:aggregate_failures`: `create(:mtg_art_build, indexed_count: 9, without_image_count: 1, failed_count: 2, index_file: "art-index-v1-0123456789abcdef-9.bin.gz")`; the line `start_with("Art matching: index file missing (art-index-v1-0123456789abcdef-9.bin.gz); press Build art index on the admin catalog page to write it again.")`, `include("9 artworks indexed", "1 without an image", "2 failed images")`, and `not_to match(/ready/i)`.
- new: a row with a nil `index_file` prints `(no file name recorded)`.
- guards (AC-2.3) already exist for running, stalled, interrupted, failed, off and no build; `bin/rspec spec/models/mtg/art_spec.rb` stays green in full. `spec/tasks/catalog_rake_spec.rb` and `spec/models/mtg/scryfall/source_spec.rb` read the line by prefix or by calling `status_line`, and are in the run.

**Green.** `MTG::Art.status_line`, between the `run.running?` branch and `elsif run.finished?`:

```ruby
    elsif run.finished? && !run.index_file_present?
      "Art matching: index file missing (#{run.index_file.presence || "no file name recorded"}); press Build art index on the " \
        "admin catalog page to write it again. #{run.indexed_count} artworks indexed, #{run.without_image_count} without an image, " \
        "#{run.failed_count} failed images"
```

and the comment above `status_line` gains "a finished build whose index file isn't on the volume reads as missing (spec 039)".

**Commit:** `fix(art): catalog:status says when a finished build's index file is missing`.

## Phase 4: Building again restores "Ready." (Story 3)

**Examples (guards: the build is unchanged, so they pass once phases 2 and 3 are in; their "missing" halves are red before them).**
- `spec/requests/admin/catalogs_spec.rb`, `:art_matching` (AC-3.1): refresh applied; a finished build with a missing named file; `get admin_catalog_path` shows an enabled button; `start("art_index")` sets `flash[:notice]` "Art index build queued." and `SolidQueue::Job.where(class_name: "MTG::Art::BuildJob").count` is 1.
- `spec/models/mtg/art/build_spec.rb`, `:art_matching` (AC-3.2), `:aggregate_failures`: one printing for `art_a`, `serve` its image, `run_build` (finishes, writes the file); `FileUtils.rm_rf(MTG::Art.root.join("index"))`; then `MTG::Art::Operation.new("mtg").state` is `:index_missing` and `MTG::Art.status_line` starts "Art matching: index file missing"; `WebMock.reset!` (no stub left: a request would raise); `run_build(job_id: "job-2")` has `status: "finished", fetched_count: 0`; `a_request(:any, /.*/)` has not been made; the named file now exists; a fresh `MTG::Art::Operation.new("mtg")` is `:ready` and the line starts "Art matching: ready". This needs ImageMagick (as the rest of the file does) and the `loaded` refresh run the file's `before` creates (an applied run for `mtg`, so the operation's catalog is loaded).

**Commit:** `test(art): building again after a missing index file restores ready`.

## Phase 5: The documents (Story 4)

Reading-verified (no RSpec on prose, `.claude/rules/testing.md`); record each in `verification.md`.

- `docs/architecture/catalog-operations.md` (AC-4.1): in "What the art index section shows", add the row after "Finished": `| Finished, its index file not on the volume | "Index file missing. Build the art index again.", finish time, the file's name ("none recorded" for a row without one), artworks indexed, without an image, failed images; button enabled unless a job is in flight; the page doesn't poll (spec 039 decision 2; #122) |`; the "Finished" row says "Ready." applies when the file is there; the status-line paragraph words the new line and says it always describes the latest build, so with a build queued it still says to press the button; the Glossary or Invariants say a finished build is judged ready by its own named file (one `stat`, never opened or cached, spec 039 decision 4); remove nothing from Accepted limits but add one: "A finished build is judged by the file's name only: a damaged file or one for older settings or an older catalog version still reads ready (spec 039 Non-Goals)"; Sources gets spec 039 and #122.
- `docs/architecture/release-and-deploy.md` (AC-4.1a): the Neighbours line at the top that points to #122 and the open-limit bullet that says the panel and `catalog:status` say "ready" although the file was left behind are brought up to date (the limit is fixed; say what they read after a restore), and spec 039 joins Sources.
- `README.md` (AC-4.3), the two places that tell the operator to press **Build art index** (the restore steps and the post-restore checklist; find them with `grep -n "Build art index" README.md`): add that until it is pressed the admin page and `catalog:status` read "Index file missing". `docs/backup-restore.md` and `lib/collector/backup/restore.rb` stay as they are.
- `docs/specs/README.md` (AC-4.2): the 039 row's status becomes Approved while the branch is open, its Plan cell "present"; the rows of 015, 011 and 030 gain, in their Superseded-by cell, "039 (spec 015 AC-4.1, the list of art index states; spec 011 AC-3.11, the art line's "ready"; spec 030 decision 12, "not fixed here")"; the 030 row's stray seventh cell is fixed in the same edit. Mind that the other parallel sessions edit rows of this file: keep edits to these rows.
- `docs/roadmap.md`: a Housekeeping-lane line for #122, "Done when its pull request merges: spec 039".
- `docs/specs/039-art-index-missing-file/spec.md`: status Approved (it is already approved); version stays 1.0.1.
- `docs/specs/039-art-index-missing-file/verification.md`: red evidence per phase, the green `bin/ci` result at the final commit, an AC table, and a `## Implementation review` heading with its verdict first (`sdd-review` Mode B, Opus, read-only).

**Commit:** `docs(art): record that a missing index file no longer reads as ready (#122)`; the verification file is its own commit.

## Finishing

At session end run `sdd-superpowers:session-wrap`, then `distill-feature` (area doc is already updated in Phase 5; it marks the index and, after the merge, retires this plan). Open the follow-up issue for settings drift (the maintainer decides who files it). This planning pull request says "Refs #122"; the implementation pull request, opened later, says "Closes #122".

## What only a run can confirm

- That `Pathname#file?` is false (no raise) for a missing or unreadable directory (assumed from Ruby's `File.file?`).
- That `MTG::Art::Operation.new("mtg")` works untagged in `build_spec.rb`'s example (the queue tables are in the test database); if not, tag it `:solid_queue`.
- The exact text of the request-spec expectations (the facts' rendering of a long name and of 31,904).
- That the example list of Phase 2's "existing examples" is complete: run `spec/models/mtg/art/operation_spec.rb`, `spec/models/mtg/art_spec.rb`, `spec/requests/admin/catalogs_spec.rb`, `spec/tasks/catalog_rake_spec.rb` and `spec/models/mtg/scryfall/source_spec.rb` before the green step; any that break are fixed by giving their build `index_file: art_index_name`.
- `bin/rubocop` on the new Ruby (line length, the `elsif` chain in `state`).
