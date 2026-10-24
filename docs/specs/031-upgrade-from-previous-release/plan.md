# Implementation Plan: Prove an Upgrade from the Previous Release in CI

**Spec:** docs/specs/031-upgrade-from-previous-release/spec.md (1.1.2: approved by the maintainer 2026-10-23, with the P4 PATCH ruled 2026-10-24)
**Decisions:** none new: no ADR is owed (research.md, P9). Spec decisions 1 to 10 stand; research.md section 5 lists the plan's rulings P1 to P10, of which P4 (the backup leg's restore allowance) was ruled by the maintainer on 2026-10-24 and is spec 031 1.1.2. `plan-review.md` maps the Opus review's findings to their fixes.
**Research:** [research.md](research.md). **Contracts:** [contracts/harness.md](contracts/harness.md), [contracts/yaml-files.md](contracts/yaml-files.md). No `data-model.md` (the spec adds no table, column or collector-owned data).
**Created:** 2026-10-23

## Global Constraints

Copied from the spec; every phase includes them.

- This spec adds no table, no column and no collector-owned data, so the export format is unchanged (Non-Goals).
- The previous release's image is pulled by its exact version tag, `ghcr.io/plainprogrammer/collector:X.Y.Z`; no registry listing, `latest`, `edge` or `sha-` tag decides it (FR-1, AC-1.3).
- The code under test is started on the same volume, with the same secret and settings; the only database command the proof causes is the entrypoint's `db:prepare`, and no command it runs is `db:schema:load`, `db:reset`, `db:drop` or `db:setup` (FR-3, AC-3.4).
- The comparison reads consolidated snapshots with SQLite directly, not through the application, on a host Ruby set up by the image job, and only listed expected changes pass a difference (FR-4, decision 5).
- Every failure names the step and the evidence; the only passes without a proof are "no previous release" and "no backup task" (FR-5).
- The check never writes outside its own containers, volumes and one temporary directory, removes them on every exit path, and adds no secret, login or permission of its own (FR-6).
- `bin/upgrade-smoke`, its helpers under `script/upgrade/` (not `lib/`), the seeds and the two yml files stay out of the published image (FR-8).
- Every criterion a suite can test without a container engine is tested in `bin/rspec`, which `bin/ci` runs (FR-7, AC-8.6).
- Time: under 5 minutes added to the `image` job per architecture, 10 minutes as the failure point of the upgrade step (decision 8, AC-7.4).
- Project rules: tests before code, RuboCop omakase (`bin/rubocop -a` after each Ruby edit), no new gem (`sqlite3` and `json_schemer` are already in the bundle), released migrations are never edited, plans are not run before approval.

---

## Goal

CI boots the previous release's published image, seeds it, starts the image built from the code under test on the same volume, and fails unless the database upgraded unattended, lost nothing and the app serves the collection as it was; `bin/ci` fails first when a released migration was edited or deleted; and a tag whose code cannot upgrade the last release publishes nothing.

| Phase | Delivers | Ends green with |
|---|---|---|
| 0 | Spec helpers (throwaway repositories and databases) | `bin/rspec spec/script/upgrade` |
| 1 | `Upgrade::Release`: tags, the tag being built, the previous release | its spec |
| 2 | `Upgrade::Guard`, the `bin/ci` step, tag-fetching checkout in the `ci` job | `bin/ci` |
| 3 | `Upgrade::Snapshot` and `Upgrade::Compare` | their specs |
| 4 | `rules.rb` (expected changes, seed exceptions, coverage, restore effects) and the two yml files | its spec |
| 5 | The seeds `0.2.1.rb` and `next.rb`, `next.rb` run in the suite | `bin/ci` |
| 6 | `Upgrade::Engine` (the allowlist) and `Upgrade::Web` | their specs |
| 7 | `Upgrade::Harness`, `bin/upgrade-smoke`, image hygiene, the first hand run and measurement | its specs, a hand run |
| 8 | The backup leg and `--previous-ref` | its specs, a hand run |
| 9 | The workflow: Ruby setup, full-history checkouts, the step before the push | workflow spec, `bin/ci` |
| 10 | Documents: `docs/releasing.md`, `CLAUDE.md`, rules pointer, roadmap | `bin/ci` |
| 11 | Integration verification, `verification.md`, the implementation review | `bin/ci`, the first CI run |

**Pre-implementation gates.**
- *Simplicity:* three components, not more: release resolution with the guard (`release.rb`, `guard.rb`), the comparison (`snapshot.rb`, `compare.rb`, `rules.rb`), and the runner (`engine.rb`, `web.rb`, `harness.rb`, `bin/upgrade-smoke`), plus data (seeds, two yml files). No new dependency. Nothing future-proofed: no multi-release chain (Non-Goals), no registry listing, no fixture database.
- *Anti-abstraction:* `Upgrade::Engine` wraps the container CLI because AC-8.3 needs one chokepoint for every command and because the runner must run against a fake in `bin/rspec`; it wraps nothing else (the sqlite3 gem, `Net::HTTP`, `Open3` and `git` are used directly). The harness reads the databases with `SQLite3::Database`, a single representation of a table.
- *Integration-first:* the contracts exist before code (`contracts/`), and every phase starts with the failing specs that state them.

> **Complexity note** (Simplicity, the runner is ~700 lines of Ruby where `bin/backup-smoke` is 177 of bash): the Ruby comparer is fixed by decision 5 (host Ruby); the orchestration in Ruby (P1) buys the engine-free specs of AC-1.2, AC-1.4, AC-1.5, AC-2.4, AC-2.7, AC-2.8, AC-3.3, AC-6.4, AC-7.3 and AC-7.5 that a bash script could not have.

**Conventions in this plan.** Specs live in `spec/script/upgrade/`; each requires its subject by path (`require Rails.root.join("script/upgrade/release").to_s`), because `script/` is not autoloaded. Groups are tagged `:upgrade` (and `:git_sandbox` where they need `git!`). Run one file with `bin/rspec spec/script/upgrade/<name>_spec.rb`. Every commit message ends with the `Co-Authored-By:` trailer that the executing session's attribution gives (this plan was written by Sonnet 5.5; implementation may run on another model); one conventional commit per step that says so. RuboCop is applied after each Ruby edit by the project hook; the code below is written in the project's style (spaces inside array brackets, methods after `private` indented).

---

## Phase 0: Spec helpers

**Implements:** FR-7 | **Satisfies:** (support for AC-1.x, AC-4.x, AC-8.x)
**Files:** `spec/support/upgrade_helpers.rb`, `.rubocop.yml`
**Interfaces:** Consumes: `GitSandbox` (`git!`, tag `:git_sandbox`). Produces: `UpgradeHelpers#upgrade_dir`, `#build_history(dir, steps)`, `#build_database(path) { |db| }`, `#open_database(path)`, included by the tag `:upgrade`, which also removes `upgrade_dir` after each example.

The helpers are test code, so Phase 1's first specs are the failing tests of them.

- [ ] Create `spec/support/upgrade_helpers.rb`:

```ruby
require "fileutils"
require "sqlite3"
require "tmpdir"

# Throwaway repositories and databases for spec 031's examples (tag a group :upgrade, and :git_sandbox when it needs git!).
module UpgradeHelpers
  def upgrade_dir = @upgrade_dir ||= File.realpath(Dir.mktmpdir("upgrade-spec"))

  # Commits each step in turn: { "message" => { "path" => "body" } }. A message that starts with "v" also tags the commit.
  def build_history(dir, steps)
    FileUtils.mkdir_p(dir)
    git!(dir, "init", "-q", "-b", "main")
    steps.each do |message, files|
      files.each do |path, body|
        FileUtils.mkdir_p(File.dirname(File.join(dir, path)))
        File.write(File.join(dir, path), body)
      end
      git!(dir, "add", "-A")
      git!(dir, "commit", "-q", "--allow-empty", "-m", message)
      git!(dir, "tag", message) if message.start_with?("v")
    end
    dir
  end

  # A SQLite database at `path`, built by the block (which gets the open connection) and closed.
  def build_database(path)
    database = SQLite3::Database.new(path)
    yield database
    database.close
    path
  end

  def open_database(path) = SQLite3::Database.new(path, readonly: true)
end

RSpec.configure do |config|
  config.include UpgradeHelpers, :upgrade
  config.after(:each, :upgrade) { FileUtils.remove_entry(@upgrade_dir) if @upgrade_dir && File.exist?(@upgrade_dir) }
end
```

- [ ] In `.rubocop.yml`, add the file that checks repository files rather than a class to `RSpec/DescribeClass`'s `Exclude` list (the line is added in Phase 2 with the file itself).
- [ ] Run: `bin/rspec spec/models/lot_spec.rb` — expect PASS (support loads without breaking the suite: `rails_helper` requires `spec/support/**/*.rb`).
- [ ] Commit: `test: add helpers for the upgrade proof specs (spec 031)`

---

## Phase 1: Release resolution

**Implements:** FR-1, decision 2 | **Satisfies:** AC-1.1, AC-1.2, AC-1.7, AC-8.5 (the fetch failure), the data AC-8.1 and AC-8.4 read
**Files:** `script/upgrade/release.rb`, `spec/script/upgrade/release_spec.rb`
**Interfaces:** Consumes: `git` on the PATH. Produces: `Upgrade::Release.new(dir = Dir.pwd, env: ENV)` with `#versions`, `#building` (a `Version` or nil), `#previous` (a `Version` or nil; raises `Upgrade::Release::TagsNotFetched`), `#migration_files(ref)`, `#migration_versions(ref)`, `#show(ref, path)`, `#ancestor?(ref)`, `#head`; `Upgrade::Release::Version` (`.parse(tag)`, `#tag`, `#number`, `#stable?`, `<=>`); `Upgrade::Release::Error`.

The one resolver (decision 2): `GITHUB_REF_TYPE=tag` → that tag; else in Actions (`GITHUB_ACTIONS` set) → none; else the highest tag pointing at `HEAD`. The previous release is the newest stable tag strictly below it; with none being built, the newest stable tag.

- [ ] Write `spec/script/upgrade/release_spec.rb`:

```ruby
require "rails_helper"
require Rails.root.join("script/upgrade/release").to_s

RSpec.describe Upgrade::Release, :git_sandbox, :upgrade do
  let(:dir) { upgrade_dir }
  let(:tags) { %w[v0.1.0 v0.2.0 v0.2.1 v0.10.0 v0.11.0-rc.1] }
  let(:branch) { { "GITHUB_ACTIONS" => "true", "GITHUB_REF_TYPE" => "branch", "GITHUB_REF_NAME" => "main" } }

  def release(env = {}) = described_class.new(dir, env:)
  def tag_push(name) = { "GITHUB_ACTIONS" => "true", "GITHUB_REF_TYPE" => "tag", "GITHUB_REF_NAME" => name }
  def commit_tags(*names) = build_history(dir, names.index_with { |name| { "f" => name } })

  describe "Version" do
    it "orders by number, not text, and puts a pre-release before its release (semver precedence)", :aggregate_failures do
      order = %w[v0.2.1 v0.9.0 v0.10.0 v1.0.0-alpha v1.0.0-alpha.1 v1.0.0-alpha.beta v1.0.0-beta v1.0.0-beta.2 v1.0.0-beta.11 v1.0.0-rc.1 v1.0.0]
      versions = order.map { described_class::Version.parse(it) }
      expect(versions.shuffle(random: Random.new(1)).sort.map(&:tag)).to eq(order)
      expect(described_class::Version.parse("v0.2.1").number).to eq("0.2.1")
      expect(described_class::Version.parse("v0.2.1-rc.1")).not_to be_stable
    end

    it "parses only release tags" do
      expect(%w[0.2.1 v1.2 release-1 v1.2.3-rc_1 v1.2.3-].map { described_class::Version.parse(it) }).to all(be_nil)
    end
  end

  describe "#previous" do
    before { commit_tags(*tags) }

    it "is the newest stable tag on a branch or pull request, in numeric order, skipping pre-releases (AC-1.1)" do
      expect(release(branch).previous.tag).to eq("v0.10.0")
    end

    it "is the newest stable tag strictly older than the tag being built on a tag push (AC-1.2)" do
      expect(release(tag_push("v0.10.0")).previous.tag).to eq("v0.2.1")
    end

    it "is the newest stable tag below a pre-release's version when a pre-release is built" do
      expect(release(tag_push("v0.3.0-rc.1")).previous.tag).to eq("v0.2.1")
    end

    it "compares a local checkout at an older tag against its own predecessor" do
      git!(dir, "checkout", "-q", "v0.2.1")
      expect(release.previous.tag).to eq("v0.2.0")
    end

    it "is the newest stable tag for a local checkout of an untagged commit" do
      File.write(File.join(dir, "f"), "work")
      git!(dir, "commit", "-q", "-am", "work")
      expect(release.previous.tag).to eq("v0.10.0")
    end
  end

  describe "#previous when there is none" do
    it "is nil for the first tag's run (AC-1.2)" do
      commit_tags("v0.1.0")
      expect(release(tag_push("v0.1.0")).previous).to be_nil
    end

    it "is nil when tags are present and none is stable" do
      commit_tags("v0.1.0-rc.1")
      expect(release(branch).previous).to be_nil
    end

    it "is nil when there are no tags and no remote" do
      commit_tags("work")
      expect(release(branch).previous).to be_nil
    end

    it "fails, saying to fetch tags, when there is a remote and no tags at all (AC-8.5)" do
      commit_tags("work")
      git!(dir, "remote", "add", "origin", "https://example.invalid/collector.git")
      expect { release(branch).previous }.to raise_error(described_class::TagsNotFetched, /fetch/i)
    end
  end

  describe "#building (AC-1.7)" do
    it "is no tag for a push to main whose commit is already tagged, and the previous release is the newest stable", :aggregate_failures do
      commit_tags("v0.2.1")
      expect(release(branch).building).to be_nil
      expect(release(branch).previous.tag).to eq("v0.2.1")
    end

    it "is the pushed tag" do
      commit_tags("v0.2.1")
      expect(release(tag_push("v0.2.1")).building.tag).to eq("v0.2.1")
    end

    it "is the tag at HEAD for a local checkout" do
      commit_tags("v0.2.1")
      expect(release.building.tag).to eq("v0.2.1")
    end

    it "is the tag of highest precedence when several point at HEAD" do
      commit_tags("v0.3.0-rc.1")
      git!(dir, "tag", "v0.3.0")
      expect(release.building.tag).to eq("v0.3.0")
    end

    it "refuses a pushed tag that is no release tag" do
      commit_tags("v0.2.1")
      expect { release(tag_push("nightly")).building }.to raise_error(described_class::Error, /not a release tag/)
    end
  end

  describe "the migration tree of a ref" do
    it "lists the files and versions of db/migrate at the ref, and shows a file as it was", :aggregate_failures do
      build_history(dir, "v0.1.0" => { "db/migrate/20261001000001_create_a.rb" => "a\n" },
        "v0.2.0" => { "db/migrate/20261002000001_create_b.rb" => "b\n", "db/migrate/20261001000001_create_a.rb" => "changed\n" })
      files = release.migration_files("v0.1.0")
      expect(files).to eq([ "db/migrate/20261001000001_create_a.rb" ])
      expect(release.migration_versions("v0.2.0")).to eq(%w[20261001000001 20261002000001])
      expect(release.show("v0.1.0", files.first)).to eq("a\n")
      expect(release.ancestor?("v0.1.0")).to be(true)
    end
  end
end
```

- [ ] Run: `bin/rspec spec/script/upgrade/release_spec.rb` — expect FAIL with `cannot load such file -- …/script/upgrade/release`.
- [ ] Create `script/upgrade/release.rb`:

```ruby
# Release resolution for the upgrade proof (spec 031 decision 2): the release tags of a checkout, the tag being built, and
# the previous release. Standard library only, so bin/ci's guard runs it before any gem is needed.
require "open3"

module Upgrade
  class Release
    Error = Class.new(StandardError)
    TagsNotFetched = Class.new(Error)

    TAG = /\Av(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?\z/

    # A release tag with semver precedence: by number, a pre-release before its release, pre-release identifiers
    # compared one by one (numbers before words, a shorter list before a longer one that starts with it).
    Version = Struct.new(:tag, :core, :pre) do
      include Comparable

      def self.parse(tag)
        match = TAG.match(tag.to_s)
        match && new(tag, match.captures.first(3).map(&:to_i), match[4]&.split("."))
      end

      def stable? = pre.nil?
      def number = tag.delete_prefix("v")
      def to_s = tag

      def <=>(other)
        return core <=> other.core unless core == other.core
        return 0 if pre.nil? && other.pre.nil?
        return 1 if pre.nil?
        return -1 if other.pre.nil?

        compare_identifiers(pre, other.pre)
      end

      private
        def compare_identifiers(left, right)
          left.zip(right).each do |one, other|
            return 1 if other.nil?

            order = identifier_order(one, other)
            return order unless order.zero?
          end
          left.size <=> right.size
        end

        def identifier_order(one, other)
          numeric = one.match?(/\A\d+\z/)
          other_numeric = other.match?(/\A\d+\z/)
          return one.to_i <=> other.to_i if numeric && other_numeric
          return -1 if numeric
          return 1 if other_numeric

          one <=> other
        end
    end

    def initialize(dir = Dir.pwd, env: ENV)
      @dir = dir
      @env = env
    end

    def versions = git("tag", "--list").lines(chomp: true).filter_map { Version.parse(it) }

    # The tag being built: the pushed tag; in GitHub Actions otherwise none (also when HEAD happens to be tagged, so the
    # ci and image jobs agree for one run); elsewhere the tag of highest precedence at HEAD, else none.
    def building
      if @env["GITHUB_REF_TYPE"] == "tag"
        name = @env["GITHUB_REF_NAME"].to_s
        Version.parse(name) || raise(Error, "#{name.inspect} is not a release tag (vX.Y.Z or vX.Y.Z-suffix)")
      elsif @env["GITHUB_ACTIONS"].to_s.empty?
        git("tag", "--points-at", "HEAD").lines(chomp: true).filter_map { Version.parse(it) }.max
      end
    end

    # The newest stable tag, strictly older than the tag being built when one is. Nil when there is none: tags present
    # and none stable, or no tags and no remote. A remote with no tags is a checkout that did not fetch them.
    def previous
      all = versions
      if all.empty? && remote?
        raise TagsNotFetched, "this checkout has a remote but no tags, so the previous release can't be found; " \
          "fetch them (git fetch --tags, or fetch-depth: 0 in actions/checkout)"
      end

      ceiling = building
      stable = all.select(&:stable?)
      stable = stable.select { it < ceiling } if ceiling
      stable.max
    end

    def migration_files(ref) = git("ls-tree", "-r", "--name-only", ref, "--", "db/migrate").lines(chomp: true).sort

    def migration_versions(ref) = migration_files(ref).filter_map { File.basename(it)[/\A\d+/] }

    def show(ref, path) = git("show", "#{ref}:#{path}", binmode: true)

    def ancestor?(ref) = Open3.capture3("git", "merge-base", "--is-ancestor", ref, "HEAD", chdir: @dir).last.success?

    def head = git("rev-parse", "HEAD").strip

    def remote? = !git("remote").strip.empty?

    private
      def git(*args, binmode: false)
        out, err, status = Open3.capture3("git", *args, chdir: @dir, binmode:)
        raise Error, "git #{args.join(" ")} failed: #{err.strip}" unless status.success?

        out
      end
  end
end
```

- [ ] Run: `bin/rspec spec/script/upgrade/release_spec.rb` — expect PASS.
- [ ] Run: `bin/rubocop script/upgrade spec/script/upgrade spec/support/upgrade_helpers.rb` — expect no offenses.
- [ ] Commit: `feat: resolve the previous release from a checkout's tags (spec 031 decision 2)`

---

## Phase 2: The engine-free guard in `bin/ci`

**Implements:** Story 8, FR-7, decision 1 (layer 2) | **Satisfies:** AC-8.1, AC-8.2, AC-8.4, AC-8.5, AC-7.6, AC-8.6
**Files:** `script/upgrade/guard.rb`, `spec/script/upgrade/guard_spec.rb`, `spec/script/upgrade/files_spec.rb`, `config/ci.rb`, `.github/workflows/ci.yml` (the `ci` job's checkout), `.rubocop.yml`
**Interfaces:** Consumes: `Upgrade::Release` (Phase 1). Produces: `Upgrade::Guard.new(release, root: Dir.pwd)#call` → `Upgrade::Guard::Result` (`ok?`, `lines`); `ruby script/upgrade/guard.rb` prints the lines and exits 0 or 1.

A released migration (a file in `db/migrate/` at the previous release's tag) must be present, byte for byte, in the working tree. A file that is missing is "deleted or renamed" when the tag is an ancestor of `HEAD`, and "behind" when it is not (a branch that lacks a migration the release has).

- [ ] Write `spec/script/upgrade/guard_spec.rb`:

```ruby
require "rails_helper"
require "open3"
require "rbconfig"
require Rails.root.join("script/upgrade/guard").to_s

RSpec.describe Upgrade::Guard, :git_sandbox, :upgrade do
  let(:dir) { upgrade_dir }
  let(:actions) { { "GITHUB_ACTIONS" => "true", "GITHUB_REF_TYPE" => "branch" } }
  let(:first) { "db/migrate/20261001000001_create_a.rb" }
  let(:second) { "db/migrate/20261001000002_create_b.rb" }

  def guard = described_class.new(Upgrade::Release.new(dir, env: actions), root: dir).call

  def release_with_two_migrations
    build_history(dir, "v0.2.0" => { first => "class CreateA; end\n", second => "class CreateB; end\n" })
  end

  it "passes when every released migration is unchanged and a new one was added (AC-8.1)" do
    release_with_two_migrations
    File.write(File.join(dir, "db/migrate/20261002000001_create_c.rb"), "class CreateC; end\n")
    expect(guard).to be_ok
  end

  it "fails naming an edited migration and saying a new migration is the fix (AC-8.2)", :aggregate_failures do
    release_with_two_migrations
    File.write(File.join(dir, first), "class CreateA; def change; end; end\n")
    result = guard
    expect(result).not_to be_ok
    expect(result.lines.join("\n")).to include(first, "v0.2.0", "never edited or deleted", "new migration")
  end

  it "fails naming a deleted migration (AC-8.2)" do
    release_with_two_migrations
    File.delete(File.join(dir, second))
    expect(guard.lines.join("\n")).to include("#{second} was deleted or renamed since v0.2.0")
  end

  it "fails naming a renamed migration (AC-8.2)" do
    release_with_two_migrations
    git!(dir, "mv", second, "db/migrate/20261001000003_create_b.rb")
    git!(dir, "commit", "-q", "-m", "rename")
    expect(guard.lines.join("\n")).to include("#{second} was deleted or renamed")
  end

  it "says the code under test is behind the release when a branch lacks a released migration (AC-8.4)", :aggregate_failures do
    build_history(dir, "v0.1.0" => { first => "a\n" }, "v0.2.0" => { second => "b\n" })
    git!(dir, "checkout", "-q", "v0.1.0")
    result = guard
    expect(result).not_to be_ok
    expect(result.lines.join("\n")).to include("the code under test is behind v0.2.0", second)
  end

  it "passes with a line saying there is no previous release when no tag is stable (AC-8.5)", :aggregate_failures do
    build_history(dir, "v0.1.0-rc.1" => { first => "a\n" })
    expect(guard).to be_ok
    expect(guard.lines.join).to include("no previous release")
  end

  it "fails saying to fetch tags when the checkout has a remote and no tags (AC-8.5)", :aggregate_failures do
    build_history(dir, "work" => { first => "a\n" })
    git!(dir, "remote", "add", "origin", "https://example.invalid/collector.git")
    expect(guard).not_to be_ok
    expect(guard.lines.join).to match(/fetch/i)
  end

  it "fails with a message, not a backtrace, when the ref names no release (AC-8.1, Error Scenarios)", :aggregate_failures do
    release_with_two_migrations
    guard = described_class.new(Upgrade::Release.new(dir, env: { "GITHUB_ACTIONS" => "true", "GITHUB_REF_TYPE" => "tag", "GITHUB_REF_NAME" => "nightly" }), root: dir)
    expect(guard.call).not_to be_ok
  end

  it "runs as a script: prints the lines and exits non-zero on a failure (AC-8.1)", :aggregate_failures do
    release_with_two_migrations
    File.write(File.join(dir, first), "edited\n")
    out, _err, status = Open3.capture3({ "GITHUB_ACTIONS" => "true", "GITHUB_REF_TYPE" => "branch", "GITHUB_REF_NAME" => "main" }, RbConfig.ruby, Rails.root.join("script/upgrade/guard.rb").to_s, chdir: dir)
    expect(status.exitstatus).to eq(1)
    expect(out).to include(first)
  end
end
```

- [ ] Write `spec/script/upgrade/files_spec.rb` (the files of the proof: `bin/ci`, the workflows; extended in Phases 7 and 9):

```ruby
require "rails_helper"
require "yaml"

# File-shape checks for the upgrade proof (spec 031). The behaviour is in the other specs of this directory.
RSpec.describe "Upgrade proof files" do
  let(:workflow) { YAML.load_file(Rails.root.join(".github/workflows/ci.yml")) }

  def checkout(job) = workflow.dig("jobs", job, "steps").find { it["uses"].to_s.start_with?("actions/checkout") }

  it "runs the migration guard in bin/ci (AC-8.1, AC-8.6)" do
    expect(Rails.root.join("config/ci.rb").read).to include('step "Upgrade: released migrations unchanged", "ruby script/upgrade/guard.rb"')
  end

  it "fetches the full history and the tags in the ci job, which runs the guard (AC-8.5, AC-7.6)", :aggregate_failures do
    expect(checkout("ci").dig("with", "fetch-depth")).to eq(0)
    run_lines = workflow.dig("jobs", "ci", "steps").filter_map { it["run"] }
    expect(run_lines).not_to include(a_string_matching(/upgrade-smoke|docker|podman/))
  end
end
```

- [ ] In `.rubocop.yml`, add `"spec/script/upgrade/files_spec.rb"` to `RSpec/DescribeClass`'s `Exclude` list, in order.
- [ ] Run: `bin/rspec spec/script/upgrade/guard_spec.rb spec/script/upgrade/files_spec.rb` — expect FAIL (`cannot load such file … script/upgrade/guard`; the files spec fails on the missing step and `fetch-depth`).
- [ ] Create `script/upgrade/guard.rb`:

```ruby
# The engine-free half of the upgrade proof (spec 031 decision 1, Story 8): a released migration is never edited,
# deleted or renamed. Compares every file in db/migrate/ at the previous release's tag with the working tree. Standard
# library only. Run as `ruby script/upgrade/guard.rb` from the repository root (the bin/ci step).
require_relative "release"

module Upgrade
  class Guard
    Result = Struct.new(:ok, :lines) do
      def ok? = ok
    end

    ADVICE = "A released migration is never edited or deleted; add a new migration instead (.claude/rules/sqlite-and-migrations.md)."

    def initialize(release, root: Dir.pwd)
      @release = release
      @root = root
    end

    def call
      previous = @release.previous
      return Result.new(true, [ "no previous release; the migration guard has nothing to compare" ]) if previous.nil?

      edited, missing = released_files(previous.tag).partition { File.file?(File.join(@root, it)) }
      edited = edited.reject { File.binread(File.join(@root, it)) == @release.show(previous.tag, it) }
      problems = describe_edited(edited, previous.tag) + describe_missing(missing, previous.tag)
      return Result.new(true, [ "#{previous.tag}: its #{released_files(previous.tag).size} migrations are unchanged" ]) if problems.empty?

      Result.new(false, problems + [ ADVICE ])
    rescue Release::Error => error # TagsNotFetched, a git failure, a GITHUB_REF_NAME that is no release tag
      Result.new(false, [ error.message ])
    end

    private
      def released_files(tag) = @release.migration_files(tag)

      def describe_edited(files, tag) = files.map { "#{it} was edited since #{tag}." }

      def describe_missing(files, tag)
        return [] if files.empty?
        return files.map { "#{it} was deleted or renamed since #{tag}." } if @release.ancestor?(tag)

        [ "the code under test is behind #{tag}: it lacks #{files.join(", ")}." ]
      end
  end
end

if $PROGRAM_NAME == __FILE__
  result = Upgrade::Guard.new(Upgrade::Release.new).call
  puts result.lines
  exit(result.ok? ? 0 : 1)
end
```

- [ ] Edit `config/ci.rb`: after the `Setup` step add `step "Upgrade: released migrations unchanged", "ruby script/upgrade/guard.rb"`.
- [ ] Edit `.github/workflows/ci.yml`: in the `ci` job, change `- name: Checkout code` / `uses: actions/checkout@v7` to add `with:` / `fetch-depth: 0` (full history and tags; decision 2):

```yaml
      - name: Checkout code
        uses: actions/checkout@v7
        with:
          fetch-depth: 0
```

- [ ] Run: `bin/rspec spec/script/upgrade spec/image_publishing_spec.rb` — expect PASS.
- [ ] Run: `ruby script/upgrade/guard.rb` — expect `v0.2.1: its 14 migrations are unchanged` and exit 0 (trace: `git diff v0.2.1 HEAD --stat -- db/migrate` shows six additions and no change to the fourteen; `git ls-tree` lists 14 files at the tag).
- [ ] Run: `bin/ci` — expect green (the new step runs second).
- [ ] Commit: `feat: fail bin/ci when a released migration was edited or deleted (spec 031 Story 8)`

---

## Phase 3: Snapshots and the comparison

**Implements:** FR-4, decision 5 | **Satisfies:** AC-2.4 (the snapshot half), AC-3.5, AC-4.1, AC-4.2, AC-4.3, AC-4.6 (the unlisted part), AC-4.7, AC-2.3 (the facts check)
**Files:** `script/upgrade/snapshot.rb`, `script/upgrade/compare.rb`, `spec/script/upgrade/snapshot_spec.rb`, `spec/script/upgrade/compare_spec.rb`
**Interfaces:** Consumes: the `sqlite3` gem, `UpgradeHelpers` of Phase 0. Produces: `Upgrade::Snapshot.consolidate(source_dir, basename, target)` and `.open(path)`; `Upgrade::Snapshot::Missing`; `Upgrade::Compare.new(old_db, new_db, expected: [], optional: [], emptied: []).call` → `Report(lines, failures, expected, unmatched, ok?, to_lines)`; class methods `.tables(db)`, `.count(db, table)`, `.columns(db, table)`, `.integrity(db)`, `.seed_problems(db)`, `.digest(rows)`; entries passed as `expected:` respond to `table`, `column`, `kind` (`"dropped"`, `"rewritten"`, `"rows_removed"`, `"rows_added"`), `migration`, `reason`, `matched`.

- [ ] Write `spec/script/upgrade/snapshot_spec.rb`:

```ruby
require "rails_helper"
require Rails.root.join("script/upgrade/snapshot").to_s

RSpec.describe Upgrade::Snapshot, :upgrade do
  let(:dir) { upgrade_dir }

  # A volume whose last writes are still in the -wal file, copied while the writer is open, as a stopped container's can be.
  def volume_with_log
    source = File.join(dir, "volume")
    FileUtils.mkdir_p(source)
    writer = SQLite3::Database.new(File.join(source, "production.sqlite3"))
    writer.execute_batch("PRAGMA journal_mode = WAL; PRAGMA wal_autocheckpoint = 0; CREATE TABLE things (id INTEGER PRIMARY KEY, name); INSERT INTO things (name) VALUES ('kept')")
    copies = File.join(dir, "copies")
    FileUtils.mkdir_p(copies)
    Dir[File.join(source, "production.sqlite3*")].each { FileUtils.cp(it, copies) }
    writer.close
    copies
  end

  it "folds in a write-ahead log that the copied files came with (AC-2.4)", :aggregate_failures do
    copies = volume_with_log
    main_only = File.join(dir, "main-only")
    FileUtils.mkdir_p(main_only)
    FileUtils.cp(File.join(copies, "production.sqlite3"), main_only)
    expect(SQLite3::Database.new(File.join(main_only, "production.sqlite3")).execute("SELECT name FROM sqlite_master WHERE name = 'things'")).to be_empty
    target = described_class.consolidate(copies, "production.sqlite3", File.join(dir, "snapshot.sqlite3"))
    expect(open_database(target).execute("SELECT name FROM things")).to eq([ [ "kept" ] ])
  end

  it "fails naming the file when the main database file is missing" do
    expect { described_class.consolidate(dir, "production.sqlite3", File.join(dir, "x.sqlite3")) }
      .to raise_error(described_class::Missing, /production\.sqlite3/)
  end
end
```

- [ ] Write `spec/script/upgrade/compare_spec.rb` (every Story 4 criterion with synthetic databases):

```ruby
require "rails_helper"
require Rails.root.join("script/upgrade/compare").to_s

RSpec.describe Upgrade::Compare, :upgrade do
  let(:dir) { upgrade_dir }
  let(:base) { [ "CREATE TABLE widgets (id INTEGER PRIMARY KEY, name TEXT, size INTEGER)",
    "INSERT INTO widgets VALUES (1, 'a', 10), (2, 'b', 20), (3, 'c', 30)" ] }
  let(:entry) { Struct.new(:table, :column, :kind, :migration, :reason, :matched, keyword_init: true) }

  def databases(old_sql, new_sql)
    [ old_sql, new_sql ].each_with_index.map do |statements, index|
      path = build_database(File.join(dir, "db#{index}.sqlite3")) { |db| db.execute_batch(statements.join(";\n")) }
      open_database(path)
    end
  end

  def compare(old_sql, new_sql, **) = described_class.new(*databases(old_sql, new_sql), **).call

  it "passes identical databases and prints a line per table with its counts (AC-4.1)", :aggregate_failures do
    report = compare(base, base)
    expect(report).to be_ok
    expect(report.lines.first).to match(/widgets\s+old\s+3\s+new\s+3\s+same/)
  end

  it "reports a missing row with the table and the first key (AC-4.2)", :aggregate_failures do
    report = compare(base, base.take(1) + [ "INSERT INTO widgets VALUES (1, 'a', 10), (3, 'c', 30)" ])
    expect(report.failures.map(&:kind)).to eq([ :rows_removed ])
    expect(report.to_lines.join("\n")).to include("widgets", "id = 2")
  end

  it "reports an extra row, a changed value (with its column), a dropped column and a dropped table (AC-4.2)", :aggregate_failures do
    extra = compare(base, base + [ "INSERT INTO widgets VALUES (4, 'd', 40)" ])
    changed = compare(base, base + [ "UPDATE widgets SET name = 'z' WHERE id = 3" ])
    dropped_column = compare(base, [ "CREATE TABLE widgets (id INTEGER PRIMARY KEY, name TEXT)", "INSERT INTO widgets VALUES (1, 'a'), (2, 'b'), (3, 'c')" ])
    dropped_table = compare(base, [ "CREATE TABLE other (id INTEGER PRIMARY KEY)" ])
    expect(extra.failures.map(&:kind)).to eq([ :rows_added ])
    expect(changed.failures.map { [ it.kind, it.column, it.key ] }).to eq([ [ :value_changed, "name", "id = 3" ] ])
    expect(dropped_column.failures.map { [ it.kind, it.column ] }).to eq([ [ :column_dropped, "size" ] ])
    expect(dropped_table.failures.map { [ it.kind, it.table ] }).to eq([ [ :table_dropped, "widgets" ] ])
  end

  it "ignores a column only the new table has, and a new table (AC-4.3)" do
    report = compare(base, base + [ "ALTER TABLE widgets ADD COLUMN note TEXT", "CREATE TABLE extras (id INTEGER PRIMARY KEY)" ])
    expect(report).to be_ok
  end

  it "says to fix the migration or list an expected change when a migration empties a column (AC-4.6)", :aggregate_failures do
    report = compare(base, base + [ "UPDATE widgets SET size = NULL" ])
    expect(report.failures.map { [ it.kind, it.column ] }).to eq([ [ :value_changed, "size" ] ])
    expect(report.to_lines.join("\n")).to include("fix it, or list the change in script/upgrade/expected_changes.yml")
  end

  it "passes a difference an expected change lists and prints it with its reason (AC-4.4)", :aggregate_failures do
    listed = entry.new(table: "widgets", column: "size", kind: "rewritten", migration: "1", reason: "Spec 99 rescales sizes")
    report = compare(base, base + [ "UPDATE widgets SET size = size * 2" ], expected: [ listed ])
    expect(report).to be_ok
    expect(report.to_lines.join("\n")).to include("expected: widgets.size rewritten (Spec 99 rescales sizes)")
    unlisted = compare(base, base + [ "UPDATE widgets SET name = 'q'" ], expected: [ listed ])
    expect(unlisted.failures.map(&:column)).to eq([ "name" ])
  end

  it "fails a live expected change that matches nothing and names it (AC-4.5)", :aggregate_failures do
    stale = entry.new(table: "widgets", column: "size", kind: "dropped", migration: "1", reason: "Spec 99 drops size")
    report = compare(base, base, expected: [ stale ])
    expect(report).not_to be_ok
    expect(report.to_lines.join("\n")).to include("widgets.size dropped (migration 1) matched no difference")
  end

  it "orders a table without an integer primary key by all its columns, so rowid order doesn't matter (AC-4.7)", :aggregate_failures do
    old = [ "CREATE TABLE pairs (a TEXT, b TEXT, PRIMARY KEY (a, b))", "INSERT INTO pairs VALUES ('x', '1'), ('y', '2')" ]
    reordered = [ "CREATE TABLE pairs (a TEXT, b TEXT, PRIMARY KEY (a, b))", "INSERT INTO pairs VALUES ('y', '2'), ('x', '1')" ]
    changed = [ "CREATE TABLE pairs (a TEXT, b TEXT, PRIMARY KEY (a, b))", "INSERT INTO pairs VALUES ('x', '1'), ('y', '3')" ]
    expect(compare(old, reordered)).to be_ok
    failure = compare(old, changed).failures.first
    expect(failure.kind).to eq(:value_changed)
    expect(failure.key).to include("row 2 of the ordering by a, b", "'y', '2'")
  end

  it "tells 1 from '1' and NULL from '' (decision 5's encoding; AC-4.7)", :aggregate_failures do
    old = [ "CREATE TABLE loose (id INTEGER PRIMARY KEY, v)", "INSERT INTO loose VALUES (1, 1), (2, NULL)" ]
    swapped = [ "CREATE TABLE loose (id INTEGER PRIMARY KEY, v)", "INSERT INTO loose VALUES (1, '1'), (2, '')" ]
    expect(compare(old, swapped).failures.map(&:key)).to eq([ "id = 1" ])
    expect(described_class.digest([ [ "1" ] ])).not_to eq(described_class.digest([ [ "'1'" ] ]))
  end

  it "skips schema_migrations, SQLite's own tables and a full-text table with its shadow tables (P5)", :aggregate_failures do
    sql = [ "CREATE TABLE names (id INTEGER PRIMARY KEY, name TEXT)", "CREATE TABLE schema_migrations (version TEXT)",
      "CREATE VIRTUAL TABLE names_fts USING fts5(name, content='names', content_rowid='id')", "INSERT INTO names VALUES (1, 'a')" ]
    rebuilt = sql + [ "INSERT INTO names_fts (names_fts) VALUES ('rebuild')" ]
    old_db, new_db = databases(sql, rebuilt)
    expect(described_class.tables(old_db)).to eq([ "names" ])
    expect(described_class.new(old_db, new_db).call).to be_ok
  end

  it "reads the facts of AC-2.3 back from a seeded database", :aggregate_failures do
    seeded = [ "CREATE TABLE accounts (id INTEGER PRIMARY KEY)", "CREATE TABLE users (id INTEGER PRIMARY KEY, password_digest TEXT)",
      "CREATE TABLE lots (id INTEGER PRIMARY KEY, account_id INTEGER)", "CREATE TABLE instance_settings (id INTEGER PRIMARY KEY, sign_up_open BOOLEAN)",
      "INSERT INTO accounts VALUES (1), (2)", "INSERT INTO users VALUES (1, 'x'), (2, 'y')", "INSERT INTO instance_settings VALUES (1, 1)",
      *Array.new(2000) { |i| "INSERT INTO lots VALUES (#{i + 1}, 1)" } ]
    full, thin = databases(seeded, seeded.reject { it.include?("(1, 1)") || it.start_with?("INSERT INTO lots") })
    expect(described_class.seed_problems(full)).to be_empty
    expect(described_class.seed_problems(thin).join("\n")).to include("fewer than 2,000 lots", "sign-up is not open")
  end

  it "reports a foreign key violation and a clean database (AC-3.5)", :aggregate_failures do
    clean, broken = databases(base, [ "PRAGMA foreign_keys = OFF", "CREATE TABLE parents (id INTEGER PRIMARY KEY)", "CREATE TABLE kids (id INTEGER PRIMARY KEY, parent_id INTEGER REFERENCES parents(id))",
      "INSERT INTO kids VALUES (1, 99)" ])
    expect(described_class.integrity(clean)).to be_empty
    expect(described_class.integrity(broken).join).to include("foreign_key_check: kids row 1")
  end

  it "requires the tables of a restore to be emptied and passes their removal (P4)", :aggregate_failures do
    old = [ "CREATE TABLE sessions (id INTEGER PRIMARY KEY)", "INSERT INTO sessions VALUES (1), (2)" ]
    optional = entry.new(table: "sessions", kind: "rows_removed", reason: "backup:restore ends every session")
    ended = compare(old, [ "CREATE TABLE sessions (id INTEGER PRIMARY KEY)" ], optional: [ optional ], emptied: %w[sessions])
    kept = compare(old, [ "CREATE TABLE sessions (id INTEGER PRIMARY KEY)", "INSERT INTO sessions VALUES (2)" ], optional: [ optional ], emptied: %w[sessions])
    expect(ended).to be_ok
    expect(kept.failures.map(&:kind)).to include(:not_emptied)
  end
end
```

- [ ] Run: `bin/rspec spec/script/upgrade/snapshot_spec.rb spec/script/upgrade/compare_spec.rb` — expect FAIL (`cannot load such file`).
- [ ] Create `script/upgrade/snapshot.rb`:

```ruby
# A consolidated, read-only copy of a container's primary database (spec 031 decision 5, AC-2.4). A stopped container can
# leave a write-ahead log beside the main file, so the main file is never read alone: it is copied with any -wal and -shm
# into a scratch directory, opened there (SQLite replays the log) and written out whole with VACUUM INTO.
require "fileutils"
require "sqlite3"
require "tmpdir"

module Upgrade
  module Snapshot
    Missing = Class.new(StandardError)

    SUFFIXES = [ "", "-wal", "-shm" ].freeze

    def self.consolidate(source_dir, basename, target)
      main = File.join(source_dir, basename)
      raise Missing, "#{main} is missing: the volume holds no #{basename}" unless File.file?(main)

      Dir.mktmpdir("upgrade-copy") do |scratch|
        SUFFIXES.each do |suffix|
          source = File.join(source_dir, "#{basename}#{suffix}")
          FileUtils.cp(source, File.join(scratch, "#{basename}#{suffix}")) if File.file?(source)
        end
        database = SQLite3::Database.new(File.join(scratch, basename))
        begin
          database.execute("VACUUM INTO ?", [ target ])
        ensure
          database.close
        end
      end
      rollback_journal(target)
      target
    end

    def self.open(path) = SQLite3::Database.new(path, readonly: true)

    # The snapshot is a plain file: no -wal or -shm will appear beside it when it is opened (spec 030 research, section 3).
    def self.rollback_journal(path)
      database = SQLite3::Database.new(path)
      database.execute("PRAGMA journal_mode = DELETE")
    ensure
      database&.close
    end
    private_class_method :rollback_journal
  end
end
```

- [ ] Create `script/upgrade/compare.rb`:

```ruby
# Compares two consolidated snapshots of a primary database, the old one a release made and the new one the code under
# test upgraded (spec 031 decision 5, Story 4). It reads them with SQLite directly, never through the application: for
# every table of the old database the table must exist and hold the same rows over the columns both have. A difference is
# a failure unless an expected change (decision 6) lists it.
require "digest"
require "sqlite3"

module Upgrade
  class Compare
    SEPARATOR = "\x1f".freeze # quote() never produces it at a value boundary: text is wrapped in quotes, numbers are digits
    SKIPPED = %w[schema_migrations ar_internal_metadata].freeze
    HINT = "A migration must not lose data: fix it, or list the change in script/upgrade/expected_changes.yml with the " \
      "migration's version and a reason that names the spec."

    Difference = Struct.new(:table, :column, :kind, :key, :detail, keyword_init: true) do
      def label = [ table, column ].compact.join(".")
      def to_s = "#{label}: #{detail}#{" (first key #{key})" if key}"
    end

    Report = Struct.new(:lines, :failures, :expected, :unmatched, keyword_init: true) do
      def ok? = failures.empty? && unmatched.empty?

      def to_lines
        lines + failures.map { "FAIL #{it}" } +
          expected.map { |entry, difference| "expected: #{difference.label} #{entry.kind} (#{entry.reason})" } +
          unmatched.map { "FAIL expected_changes.yml: #{[ it.table, it.column ].compact.join(".")} #{it.kind} (migration #{it.migration}) matched no difference; remove it or fix it" } +
          (failures.empty? ? [] : [ HINT ])
      end
    end

    class << self
      def quote_id(name) = %("#{name.gsub('"', '""')}")

      # The tables a comparison and the coverage rule look at: not SQLite's own, not schema_migrations or
      # ar_internal_metadata, and not a virtual (full-text) table or the shadow tables SQLite keeps for it.
      def tables(db)
        rows = db.execute("SELECT name, sql FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite\\_%' ESCAPE '\\' ORDER BY name")
        virtual = rows.select { |_name, sql| sql.to_s.start_with?("CREATE VIRTUAL TABLE") }.map(&:first)
        rows.map(&:first).reject { |name| SKIPPED.include?(name) || virtual.any? { |each| name == each || name.start_with?("#{each}_") } }
      end

      def count(db, table) = db.get_first_value("SELECT count(*) FROM #{quote_id(table)}")

      def columns(db, table) = db.execute("PRAGMA table_info(#{quote_id(table)})").map { it[1] }

      def primary_key(db, table)
        db.execute("PRAGMA table_info(#{quote_id(table)})").select { it[5].positive? }.sort_by { it[5] }.map { it[1] }
      end

      def integrity(db)
        db.execute("PRAGMA integrity_check").flatten.reject { it == "ok" }.map { "integrity_check: #{it}" } +
          db.execute("PRAGMA foreign_key_check").map { |table, rowid, parent, *| "foreign_key_check: #{table} row #{rowid} has no row in #{parent}" }
      end

      # The count and digest of decision 5: SHA-256 of the SHA-256 of each row, a row being its quote()d values joined.
      def digest(rows)
        rows.each_with_object(Digest::SHA256.new) { |row, total| total << Digest::SHA256.hexdigest(row.join(SEPARATOR)) << "\n" }.hexdigest
      end

      # What AC-2.3 says the seed left, read back from the old snapshot.
      def seed_problems(db)
        found = []
        found << "fewer than two accounts" if count(db, "accounts") < 2
        found << "a user without a password" if db.get_first_value("SELECT count(*) FROM users WHERE coalesce(password_digest, '') = ''").positive?
        found << "fewer than 2,000 lots" if count(db, "lots") < 2000
        found << "no account without lots" if db.get_first_value("SELECT count(*) FROM accounts WHERE id NOT IN (SELECT account_id FROM lots)").zero?
        found << "sign-up is not open" if db.get_first_value("SELECT count(*) FROM instance_settings WHERE sign_up_open = 1").zero?
        found << "fewer than two locations" if tables(db).include?("locations") && count(db, "locations") < 2
        found.map { "AC-2.3: the seed left #{it}" }
      end
    end

    def initialize(old_db, new_db, expected: [], optional: [], emptied: [])
      @old = old_db
      @new = new_db
      @expected = expected
      @optional = optional
      @emptied = emptied
    end

    def call
      (@expected + @optional).each { it.matched = false }
      new_tables = self.class.tables(@new)
      lines = []
      differences = []
      self.class.tables(@old).each do |table|
        found, line = compare_table(table, new_tables)
        lines << line
        differences.concat(found)
      end
      @emptied.each { |table| differences << not_emptied(table) if new_tables.include?(table) && self.class.count(@new, table).positive? }
      report(lines, differences)
    end

    private
      def compare_table(table, new_tables)
        old_count = self.class.count(@old, table)
        unless new_tables.include?(table)
          return [ [ difference(table, nil, :table_dropped, nil, "table dropped (it held #{old_count} rows)") ], line(table, old_count, "-", "dropped") ]
        end

        old_columns = self.class.columns(@old, table)
        new_columns = self.class.columns(@new, table)
        found = (old_columns - new_columns).map { difference(table, it, :column_dropped, nil, "column dropped") }
        common = (old_columns & new_columns).sort
        key = self.class.primary_key(@old, table)
        keyed = key.size == 1 && common.include?(key.first)
        order = keyed ? key : common
        old_rows = rows(@old, table, common, order)
        new_rows = rows(@new, table, common, order)
        same = old_rows.size == new_rows.size && self.class.digest(old_rows) == self.class.digest(new_rows)
        unless same
          found.concat(keyed ? keyed_differences(table, common, key.first, old_rows, new_rows) : positional_differences(table, common, old_rows, new_rows))
        end
        [ found, line(table, old_count, new_rows.size, same && found.empty? ? "same #{self.class.digest(old_rows)[0, 8]}" : "differs") ]
      end

      def rows(db, table, columns, order)
        return [] if columns.empty?

        select = columns.map { "quote(#{self.class.quote_id(it)})" }.join(", ")
        by = order.map { self.class.quote_id(it) }.join(", ")
        db.execute("SELECT #{select} FROM #{self.class.quote_id(table)} ORDER BY #{by}")
      end

      def keyed_differences(table, common, key, old_rows, new_rows)
        at = common.index(key)
        old_by = old_rows.to_h { [ it[at], it ] }
        new_by = new_rows.to_h { [ it[at], it ] }
        removed = old_by.keys - new_by.keys
        added = new_by.keys - old_by.keys
        shared = old_by.keys & new_by.keys
        found = []
        found << difference(table, nil, :rows_removed, "#{key} = #{removed.first}", "#{removed.size} rows removed") if removed.any?
        found << difference(table, nil, :rows_added, "#{key} = #{added.first}", "#{added.size} rows added") if added.any?
        common.each_with_index do |column, position|
          changed = shared.find { old_by[it][position] != new_by[it][position] }
          found << difference(table, column, :value_changed, "#{key} = #{changed}", "values rewritten") if changed
        end
        found
      end

      def positional_differences(table, common, old_rows, new_rows)
        position = (0...[ old_rows.size, new_rows.size ].max).find { old_rows[it] != new_rows[it] }
        return [] unless position

        old_row = old_rows[position]
        new_row = new_rows[position]
        where = "row #{position + 1} of the ordering by #{common.join(", ")}"
        return [ difference(table, nil, :rows_added, "#{where}: #{new_row.join(", ")}", "rows added") ] if old_row.nil?
        return [ difference(table, nil, :rows_removed, "#{where}: #{old_row.join(", ")}", "rows removed") ] if new_row.nil?

        common.each_index.select { old_row[it] != new_row[it] }
          .map { difference(table, common[it], :value_changed, "#{where}: #{old_row.join(", ")}", "values rewritten") }
      end

      def not_emptied(table)
        difference(table, nil, :not_emptied, nil, "#{self.class.count(@new, table)} rows after the restore, which ends every session and so empties this table (spec 031 decision 7)")
      end

      def difference(table, column, kind, key, detail) = Difference.new(table:, column:, kind:, key:, detail:)

      def line(table, old_count, new_count, state) = format("%-32s old %6s  new %6s  %s", table, old_count, new_count, state)

      def report(lines, differences)
        expected = []
        failures = []
        differences.each do |difference|
          entry = (@expected + @optional).find { matches?(it, difference) }
          if entry
            entry.matched = true
            expected << [ entry, difference ]
          else
            failures << difference
          end
        end
        Report.new(lines:, failures:, expected:, unmatched: @expected.reject(&:matched))
      end

      def matches?(entry, difference)
        return false unless entry.table == difference.table

        case entry.kind
        when "dropped" then entry.column ? (difference.kind == :column_dropped && difference.column == entry.column) : difference.kind == :table_dropped
        when "rewritten" then difference.kind == :value_changed && difference.column == entry.column
        when "rows_removed" then difference.kind == :rows_removed
        when "rows_added" then difference.kind == :rows_added
        else false
        end
      end
  end
end
```

- [ ] Run: `bin/rspec spec/script/upgrade/snapshot_spec.rb spec/script/upgrade/compare_spec.rb` — expect PASS. Trace of the two examples that depend on SQLite behaviour: (a) positional ordering `ORDER BY "a", "b"` sorts `('x','1')` before `('y','2')` whatever the insertion order, so the digests agree; (b) the changed pair's first differing position is 1 (`'y','2'` against `'y','3'`), and `where` reads `row 2 of the ordering by a, b`.
- [ ] Run: `bin/rubocop script/upgrade spec/script/upgrade` — expect no offenses.
- [ ] Commit: `feat: snapshot and compare an old and an upgraded primary database (spec 031 decision 5)`

---

## Phase 4: Expected changes, seed exceptions and the coverage rule

**Implements:** decisions 5 and 6, FR-4 | **Satisfies:** AC-4.4, AC-4.5, AC-2.5, AC-2.6 (the rule), AC-6.2 (the restore allowance, P4)
**Files:** `script/upgrade/rules.rb`, `script/upgrade/expected_changes.yml`, `script/upgrade/seed_exceptions.yml`, `spec/script/upgrade/expected_changes_spec.rb`, `spec/script/upgrade/seed_exceptions_spec.rb`
**Interfaces:** Consumes: `Upgrade::Compare.tables`, `.count`. Produces: `Upgrade::ExpectedChanges.load(path, previous_versions:, current_versions:)` → `Loaded(live, retired, errors)` with `Entry(table, column, kind, migration, reason, matched)`; `Upgrade::SeedExceptions.load(path, key)` → `Result(entries, errors)` with `Entry(table, reason)`; `Upgrade::SeedExceptions.coverage(db, entries, label:, seed:, only: nil)` → `[ problems, notes ]`; `Upgrade::ExpectedChanges.restore_effects` → `Entry` list (the `optional:` expected changes of the backup leg) and `Upgrade::ExpectedChanges::RESTORE_ENDS_SESSIONS` (the tables to pass as `emptied:`).

The formats are in [contracts/yaml-files.md](contracts/yaml-files.md).

- [ ] Write `spec/script/upgrade/expected_changes_spec.rb` (the first `RSpec.describe` below) and `spec/script/upgrade/seed_exceptions_spec.rb` (the second; one top-level group per file, as the project's RuboCop expects):

```ruby
require "rails_helper"
require Rails.root.join("script/upgrade/rules").to_s

RSpec.describe Upgrade::ExpectedChanges, :upgrade do
  let(:dir) { upgrade_dir }
  let(:current) { %w[20261001000001 20261101100001] }

  def load_yaml(body, previous: [])
    path = File.join(dir, "expected_changes.yml")
    File.write(path, body)
    described_class.load(path, previous_versions: previous, current_versions: current)
  end

  let(:entry) do
    <<~YAML
      changes:
        - table: lots
          column: lot_key
          kind: rewritten
          migration: "20261101100001"
          reason: "Spec 033 decision 2"
    YAML
  end

  it "keeps an entry whose migration the previous release lacks as live (AC-4.4)", :aggregate_failures do
    loaded = load_yaml(entry)
    expect(loaded.errors).to be_empty
    expect(loaded.live.map { [ it.table, it.column, it.kind, it.migration ] }).to eq([ [ "lots", "lot_key", "rewritten", "20261101100001" ] ])
  end

  it "retires an entry whose migration the previous release already has, without failing (AC-4.5)", :aggregate_failures do
    loaded = load_yaml(entry, previous: %w[20261001000001 20261101100001])
    expect(loaded.live).to be_empty
    expect(loaded.retired.size).to eq(1)
    expect(loaded.errors).to be_empty
  end

  it "reads an unquoted migration number as the version it is" do
    expect(load_yaml(entry.sub('"20261101100001"', "20261101100001")).live.first.migration).to eq("20261101100001")
  end

  it "names the entry that is incomplete, has an unknown kind, or rewrites without a column (AC-4.5)", :aggregate_failures do
    expect(load_yaml("changes:\n  - table: lots\n    kind: dropped\n    migration: '20261101100001'\n").errors)
      .to eq([ "expected_changes.yml entry 1 has no reason" ])
    expect(load_yaml(entry.sub("rewritten", "mangled")).errors.first).to include("entry 1", "mangled")
    expect(load_yaml(entry.sub("          column: lot_key\n", "")).errors.first).to include("names its column")
  end

  it "names an entry whose migration is no file of the code under test (AC-4.5)" do
    expect(load_yaml(entry.sub("20261101100001", "20269999999999")).errors.first).to include("20269999999999", "not a file in db/migrate/")
  end

  it "refuses an unknown top-level key and a file that is not a mapping", :aggregate_failures do
    expect(load_yaml("changes: []\nextra: 1\n").errors.first).to include("extra")
    expect(load_yaml("- 1\n").errors.first).to include("mapping")
  end

  it "lists the tables a restore empties as rows_removed entries (P4)", :aggregate_failures do
    expect(described_class::RESTORE_ENDS_SESSIONS).to eq(%w[sessions bulk_removals bulk_selections bulk_selection_marks])
    expect(described_class.restore_effects.map(&:table)).to eq(described_class::RESTORE_ENDS_SESSIONS)
    expect(described_class.restore_effects.map(&:kind).uniq).to eq([ "rows_removed" ])
  end

  it "names every table the schema cascades from sessions, so the allowance can't go stale (P4, review m8)" do
    connection = ActiveRecord::Base.connection
    cascading = ->(parents) { connection.tables.select { |table| connection.foreign_keys(table).any? { it.on_delete == :cascade && parents.include?(it.to_table) } } }
    closure = [ "sessions" ]
    closure |= cascading.call(closure) until cascading.call(closure).all? { closure.include?(it) }
    expect(closure).to match_array(described_class::RESTORE_ENDS_SESSIONS),
      "a table now cascades from sessions: update RESTORE_ENDS_SESSIONS and spec 031's decision 7, FR-4 and AC-6.2 (a PATCH)"
  end

  it "ships empty and valid" do
    real = described_class.load(Rails.root.join("script/upgrade/expected_changes.yml"), previous_versions: [], current_versions: [])
    expect([ real.live, real.retired, real.errors ]).to all(be_empty)
  end
end

RSpec.describe Upgrade::SeedExceptions, :upgrade do
  let(:dir) { upgrade_dir }

  def exceptions(body, key)
    path = File.join(dir, "seed_exceptions.yml")
    File.write(path, body)
    described_class.load(path, key)
  end

  def database_with(rows)
    open_database(build_database(File.join(dir, "seeded.sqlite3")) do |db|
      rows.each { |table, count| db.execute("CREATE TABLE #{table} (id INTEGER PRIMARY KEY)"); count.times { db.execute("INSERT INTO #{table} DEFAULT VALUES") } }
    end)
  end

  it "reads only the key asked for, a release's or next", :aggregate_failures do
    body = "\"0.2.1\":\n  - { table: mtg_artworks, reason: needs the art build }\nnext: []\n"
    expect(exceptions(body, "0.2.1").entries.map(&:table)).to eq([ "mtg_artworks" ])
    expect(exceptions(body, "next").entries).to be_empty
    expect(exceptions(body, "0.9.9").entries).to be_empty
  end

  it "names an entry without a reason" do
    expect(exceptions("next:\n  - { table: x }\n", "next").errors).to eq([ "seed_exceptions.yml next: entry 1 needs a table and a reason" ])
  end

  describe ".coverage" do
    it "fails a table without a row, naming the table and the seed file (AC-2.5, AC-2.6)", :aggregate_failures do
      problems, = described_class.coverage(database_with("lots" => 3, "locations" => 0), [], label: "next", seed: "script/upgrade/seeds/next.rb")
      expect(problems.size).to eq(1)
      expect(problems.first).to include("locations", "script/upgrade/seeds/next.rb", "seed_exceptions.yml")
    end

    it "passes a listed exception and prints it (AC-2.5)", :aggregate_failures do
      entries = [ described_class::Entry.new(table: "locations", reason: "no feature yet") ]
      problems, notes = described_class.coverage(database_with("lots" => 3, "locations" => 0), entries, label: "0.2.1", seed: "0.2.1.rb")
      expect(problems).to be_empty
      expect(notes).to eq([ "seed exception: locations (no feature yet)" ])
    end

    it "fails an exception for a table the database does not have (AC-2.5)" do
      entries = [ described_class::Entry.new(table: "ghosts", reason: "gone") ]
      problems, = described_class.coverage(database_with("lots" => 3), entries, label: "0.2.1", seed: "0.2.1.rb")
      expect(problems).to eq([ "script/upgrade/seed_exceptions.yml lists ghosts for 0.2.1, which has no such table" ])
    end

    it "looks only at the tables asked for when restricted" do
      problems, = described_class.coverage(database_with("lots" => 3, "solid_queue_jobs" => 0), [], label: "next", seed: "next.rb", only: %w[lots])
      expect(problems).to be_empty
    end
  end

  it "ships with no exception for the previous release or for next" do
    path = Rails.root.join("script/upgrade/seed_exceptions.yml")
    expect([ exceptions(path.read, "0.2.1"), exceptions(path.read, "next") ].flat_map { [ it.entries, it.errors ] }).to all(be_empty)
  end
end

```

- [ ] Run: `bin/rspec spec/script/upgrade/expected_changes_spec.rb spec/script/upgrade/seed_exceptions_spec.rb` — expect FAIL (`cannot load such file … rules`).
- [ ] Create `script/upgrade/rules.rb`:

```ruby
# The two yml files of the upgrade proof and the rules that read them (spec 031 decisions 5 and 6; formats in
# docs/specs/031-upgrade-from-previous-release/contracts/yaml-files.md).
require "yaml"
require_relative "compare"

module Upgrade
  class ExpectedChanges
    KINDS = %w[dropped rewritten rows_removed rows_added].freeze
    Entry = Struct.new(:table, :column, :kind, :migration, :reason, :matched, keyword_init: true)
    Loaded = Struct.new(:live, :retired, :errors, keyword_init: true)

    # The tables spec 030 requires `backup:restore` to empty: it ends every session, and the foreign keys cascade. Spec 031
    # 1.1.2 (decision 7, FR-4, AC-6.2) names them; rules_spec checks the list against the schema's `on_delete: :cascade` keys.
    RESTORE_ENDS_SESSIONS = %w[sessions bulk_removals bulk_selections bulk_selection_marks].freeze

    # Not a migration's change, so not in expected_changes.yml: the allowance of the backup leg only (plan P4).
    def self.restore_effects
      RESTORE_ENDS_SESSIONS.map do |table|
        Entry.new(table:, kind: "rows_removed",
          reason: "backup:restore ends every session, which cascades to the bulk removals and selections (spec 030, docs/backup-restore.md)")
      end
    end

    # An entry whose migration the previous release has is retired (ignored, never a failure); one whose migration is
    # not a file of the code under test is an error, so a typo can't excuse another migration's difference.
    def self.load(path, previous_versions:, current_versions:)
      data = YAML.safe_load_file(path, permitted_classes: [], aliases: false)
      data = {} if data.nil?
      return Loaded.new(live: [], retired: [], errors: [ "expected_changes.yml is not a mapping with a `changes` list" ]) unless data.is_a?(Hash)

      extra = data.keys - [ "changes" ]
      errors = extra.any? ? [ "expected_changes.yml has an unknown key: #{extra.join(", ")}" ] : []
      live = []
      retired = []
      Array(data["changes"]).each_with_index do |raw, index|
        entry, problems = build(raw, index + 1, current_versions)
        errors.concat(problems)
        (previous_versions.include?(entry.migration) ? retired : live) << entry if entry
      end
      Loaded.new(live:, retired:, errors:)
    end

    def self.build(raw, position, current_versions)
      where = "expected_changes.yml entry #{position}"
      return [ nil, [ "#{where} is not a mapping" ] ] unless raw.is_a?(Hash)

      problems = %w[table kind migration reason].select { raw[it].to_s.strip.empty? }.map { "#{where} has no #{it}" }
      problems << "#{where}: kind #{raw["kind"].inspect} is none of #{KINDS.join(", ")}" if raw["kind"] && !KINDS.include?(raw["kind"])
      problems << "#{where}: a rewritten change names its column" if raw["kind"] == "rewritten" && raw["column"].to_s.empty?
      migration = raw["migration"].to_s
      problems << "#{where} names migration #{migration}, which is not a file in db/migrate/" unless migration.empty? || current_versions.include?(migration)
      return [ nil, problems ] if problems.any?

      [ Entry.new(table: raw["table"], column: raw["column"]&.to_s, kind: raw["kind"], migration:, reason: raw["reason"]), [] ]
    end
    private_class_method :build
  end

  class SeedExceptions
    Entry = Struct.new(:table, :reason, keyword_init: true)
    Result = Struct.new(:entries, :errors)

    def self.load(path, key)
      data = YAML.safe_load_file(path, permitted_classes: [], aliases: false) || {}
      errors = []
      entries = Array(data[key.to_s]).each_with_index.filter_map do |item, index|
        if item.is_a?(Hash) && !item["table"].to_s.empty? && !item["reason"].to_s.empty?
          Entry.new(table: item["table"], reason: item["reason"])
        else
          errors << "seed_exceptions.yml #{key}: entry #{index + 1} needs a table and a reason"
          nil
        end
      end
      Result.new(entries, errors)
    end

    # The coverage rule: every table holds a row after a seed ran, except the listed ones. Returns the problems (each a
    # failure of the run) and the notes to print (every used exception). `only` limits the tables looked at (the suite's
    # test database also holds Solid Queue's).
    def self.coverage(db, entries, label:, seed:, only: nil)
      tables = Compare.tables(db)
      tables &= only if only
      excepted = entries.map(&:table)
      empty = tables.select { Compare.count(db, it).zero? }
      problems = (empty - excepted).map do
        "table #{it} has no row after #{seed}; the seed must fill it (script/upgrade/seed_exceptions.yml lists the tables that can't be filled, with a reason)"
      end
      problems += (excepted - tables).map { "script/upgrade/seed_exceptions.yml lists #{it} for #{label}, which has no such table" }
      notes = (empty & excepted).map { |table| "seed exception: #{table} (#{entries.find { it.table == table }.reason})" }
      [ problems, notes ]
    end
  end
end
```

- [ ] Create `script/upgrade/expected_changes.yml`:

```yaml
# Changes a migration is meant to make to data a release already holds (spec 031 decision 6). Format and rules:
# docs/specs/031-upgrade-from-previous-release/contracts/yaml-files.md. A difference between the old and the upgraded
# database that is not listed here fails the upgrade proof. After tagging a release, delete the entries whose migration
# it contains (docs/releasing.md).
changes: []
```

- [ ] Create `script/upgrade/seed_exceptions.yml`:

```yaml
# Tables a seed can't fill (spec 031 decision 5), by the release whose seed they excuse, or `next` for seeds/next.rb.
# Each entry is { table: <name>, reason: <why it can't be filled> }. Cutting a release renames next.rb and the `next` key to
# the version (docs/releasing.md).
"0.2.1": []
next: []
```

- [ ] Run: `bin/rspec spec/script/upgrade/expected_changes_spec.rb spec/script/upgrade/seed_exceptions_spec.rb` — expect PASS. (Trace: in the first retired example `previous` holds the entry's migration, so it lands in `retired`; in "ships empty" `current_versions: []` is fine because there are no entries.)
- [ ] Run: `bin/rubocop script/upgrade spec/script/upgrade` — expect no offenses.
- [ ] Commit: `feat: expected changes, seed exceptions and the coverage rule for the upgrade proof (spec 031)`

---

## Phase 5: The seeds

**Implements:** decision 4, FR-2 | **Satisfies:** AC-2.2, AC-2.3, AC-2.5, AC-2.6 (the suite half), AC-5.4's and AC-5.7's data
**Files:** `script/upgrade/seeds/0.2.1.rb`, `script/upgrade/seeds/next.rb`, `spec/script/upgrade/seeds_spec.rb`, `.rubocop.yml`
**Interfaces:** Consumes: `Upgrade::SeedExceptions`, `Upgrade::Compare.seed_problems`. Produces: two scripts for `bin/rails runner -` that print `UPGRADE-SEED-COMPLETE <json>` (contracts/harness.md, "The seed's output"): `{"release", "password", "marker", "locations", "users": [{"email", "lots", "names"}]}`.

`0.2.1.rb` is traced against `git show v0.2.1:app/models/…` (research.md section 3): every call below exists there with these arguments. It is the seed for the previous release and never changes after `v0.2.1`. `next.rb` is the same script plus what `main` added, run on the code under test; it is also what a release step renames to the next tag's version. Both are plain top-level code with no constant, because they are evaluated, not required.

- [ ] Write `spec/script/upgrade/seeds_spec.rb`:

```ruby
require "rails_helper"
require Rails.root.join("script/upgrade/rules").to_s

RSpec.describe "Upgrade seeds", :upgrade do
  let(:seeds) { Rails.root.join("script/upgrade/seeds") }
  let(:database) { ActiveRecord::Base.lease_connection.raw_connection }

  def run_seed(name)
    original = $stdout
    $stdout = StringIO.new
    load seeds.join(name).to_s
    $stdout.string
  ensure
    $stdout = original
  end

  def summary(output) = JSON.parse(output.lines.grep(/\AUPGRADE-SEED-COMPLETE /).last.delete_prefix("UPGRADE-SEED-COMPLETE "))

  describe "next.rb, run on the code under test" do
    it "prints the completion line with what the harness reads (AC-2.2)", :aggregate_failures do
      facts = summary(run_seed("next.rb"))
      expect(facts.keys).to contain_exactly("release", "password", "marker", "locations", "users")
      expect(facts["users"].map { it["email"] }).to eq(%w[ada@upgrade.example grace@upgrade.example])
      expect(facts["users"].first["lots"]).to be >= 2000
      expect(facts["users"].first["names"].size).to eq(50)
      expect(facts["users"].last).to include("lots" => 0, "names" => [])
      expect(facts["locations"]).to eq([ "Binder A", "Shelf B" ])
    end

    it "fills every table db/schema.rb creates, except those listed under next (AC-2.6, FR-7)" do
      run_seed("next.rb")
      schema_tables = Rails.root.join("db/schema.rb").read.scan(/^  create_table "([^"]+)"/).flatten
      listed = Upgrade::SeedExceptions.load(seeds.join("../seed_exceptions.yml"), "next").entries
      problems, = Upgrade::SeedExceptions.coverage(database, listed, label: "next", seed: "script/upgrade/seeds/next.rb", only: schema_tables)
      expect(problems).to be_empty
    end

    it "leaves what AC-2.3 asks for" do
      run_seed("next.rb")
      expect(Upgrade::Compare.seed_problems(database)).to be_empty
    end

    it "schedules a job with the marker argument a year ahead" do
      expect { run_seed("next.rb") }.to have_enqueued_job(Catalog::RefreshJob).with("mtg", "upgrade-marker")
    end
  end

  describe "both seeds' source" do
    it "parses, names no constant and prints one completion line", :aggregate_failures do
      %w[0.2.1.rb next.rb].each do |name|
        source = seeds.join(name).read
        expect { RubyVM::InstructionSequence.compile(source) }.not_to raise_error
        expect(source).not_to match(/^\s*[A-Z][A-Za-z_]*\s*=[^=]/)
        expect(source.scan("UPGRADE-SEED-COMPLETE").size).to eq(1)
      end
    end
  end

  describe "0.2.1.rb" do
    it "uses nothing that arrived after v0.2.1" do
      expect(seeds.join("0.2.1.rb").read).not_to match(/\b(Location|NumberEntry|ImportUpload|ActiveStorage|Catalog::Operation)\b/)
    end
  end
end
```

(`0.2.1.rb` cannot run in the suite: it needs v0.2.1's code. It is first run against the real image in Phase 7's hand run; its coverage is checked by AC-2.5 on every run of the proof.)

- [ ] Run: `bin/rspec spec/script/upgrade/seeds_spec.rb` — expect FAIL (`No such file or directory @ rb_sysopen - …/seeds/next.rb`).
- [ ] Add `"spec/script/upgrade/seeds_spec.rb"` to `RSpec/DescribeClass`'s `Exclude` in `.rubocop.yml`.
- [ ] Create `script/upgrade/seeds/0.2.1.rb`:

```ruby
# Seed for the upgrade proof when v0.2.1 is the previous release (spec 031 decision 4). Run by `bin/rails runner -` in a
# container of v0.2.1's published image, so it can use only what that release has, through that release's own models.
# It fills every table of v0.2.1 (seed_exceptions.yml lists none) and never changes after v0.2.1 is tagged. The last line it
# prints is what the harness reads.
password = "upgrade-password-1234"
marker = "upgrade-marker"
now = Time.current

sets = %w[ups upt].each_with_index.map do |code, index|
  Catalog::Set.create!(collectible_type: "mtg", code:, name: "Upgrade Set #{code.upcase}", released_on: Date.new(2020 + index, 1, 1),
    content_digest: "upgrade-seed")
end

names = Array.new(50) { |index| format("Upgrade Dragon %02d", index + 1) }
entries = names.each_with_index.map do |name, index|
  set = sets[index % 2]
  identity = Catalog::Identity.create!(collectible_type: "mtg", external_key: "upgrade-identity-#{index}", name:, content_digest: "upgrade-seed")
  entry = Catalog::Entry.create!(collectible_type: "mtg", external_key: "upgrade-entry-#{index}", set:, identity:, number: (index + 1).to_s,
    language: "en", name:, kind: "card", released_on: set.released_on, content_digest: "upgrade-seed")
  MTG::Card.create!(identity:, mana_cost: "{R}", type_line: "Creature", oracle_text: "Seed text.")
  MTG::Printing.create!(entry:, rarity: "common", finishes: %w[nonfoil foil], layout: "normal", illustration_id: "upgrade-illustration-#{index}",
    scryfall_uri: "https://scryfall.com/card/#{set.code}/#{index + 1}",
    faces: [ { "name" => name, "mana_cost" => "{R}", "type_line" => "Creature", "oracle_text" => "Seed text.", "artist" => "Nobody", "image_uris" => {} } ])
  entry
end
Catalog::NameIndex.new("mtg").rebuild

ada, = User::Command.call(email: "ada@upgrade.example", password:)
grace = User.create!(name: "Grace", email_address: "grace@upgrade.example", password:)
InstanceSetting.current.update!(sign_up_open: true)
[ ada, grace ].each { |user| user.sessions.create!(ip_address: "127.0.0.1", user_agent: "upgrade-seed") }

# 50 printings x 2 finishes x 5 conditions x 4 prices = 2,000 lots for Ada; Grace's collection stays empty.
variants = %w[nonfoil foil].product(%w[near_mint lightly_played moderately_played heavily_played damaged], [ nil, 100, 250, 1999 ])
Lot.insert_all(entries.each_with_index.flat_map do |entry, index|
  variants.each_with_index.map do |(finish, condition, price), position|
    { account_id: ada.account_id, catalog_entry_id: entry.id, quantity: 1 + (index + position) % 7, finish:, condition:, price_paid_cents: price,
      lot_key: Lot.key_for(finish, condition, price), created_at: now, updated_at: now }
  end
end)
Scanner::Sitting.add!(account: ada.account, printing: entries.first, finish: "nonfoil", reading_key: SecureRandom.hex(16))

session = ada.sessions.first
selection = BulkSelection.for(session)
ada.account.lots.limit(3).pluck(:id).each { |lot_id| selection.marks.create!(lot_id:, account: ada.account) }
BulkRemoval.create!(session:, account: ada.account, copies: 2,
  lots_data: [ { "catalog_entry_id" => entries.first.id, "finish" => "foil", "condition" => "damaged", "price_paid_cents" => nil, "quantity" => 2 } ])

Catalog::RefreshRun.create!(collectible_type: "mtg", trigger: "manual", status: "applied", source_version: "upgrade-seed", languages: "en",
  started_at: now - 60, finished_at: now, seen_count: 50, inserted_count: 50)
MTG::ArtBuild.create!(status: "finished", job_id: "upgrade-seed", catalog_version: "upgrade-seed", settings_digest: "upgrade-seed",
  index_file: "art-index-upgrade.bin.gz", started_at: now - 60, heartbeat_at: now, finished_at: now, total_count: 50, indexed_count: 50)
MTG::Artwork.create!(entry: entries.first, illustration_id: "upgrade-illustration-0", fingerprint: "\x00".b * 128, settings_digest: "upgrade-seed")
Catalog::RefreshJob.set(wait: 1.year).perform_later("mtg", marker)

facts = { release: "0.2.1", password:, marker:, locations: [],
  users: [ { email: ada.email_address, lots: ada.account.lots.count, names: }, { email: grace.email_address, lots: 0, names: [] } ] }
puts "UPGRADE-SEED-COMPLETE #{facts.to_json}"
```

- [ ] Create `script/upgrade/seeds/next.rb`. It is `0.2.1.rb` plus what `main` added (traced against `app/models/location.rb`, `number_entry.rb` and `import_upload.rb`: `Location.create!(account:, name:)` normalises the name; `NumberEntry.add!(account:, entry:, quantity:, finish:, line_key:)` requires a 32-hex key and adds the lot through `Lot.add!`; `ImportUpload.store!(account:, bytes:, plan:)` needs only `plan.fingerprint(checksum)` and creates the blob and the attachment; `ActiveStorage::VariantRecord` has `blob` and `variation_digest`):

```ruby
# Seed for the release not yet cut (spec 031 decision 4). Run by `bin/rails runner -` on a fresh instance of the image built
# from the code under test (AC-2.6) and, once a release step has renamed this file to a version, in that release's image.
# It fills every table of main (seed_exceptions.yml lists none under `next`). The last line it prints is what the harness reads.
password = "upgrade-password-1234"
marker = "upgrade-marker"
now = Time.current

sets = %w[ups upt].each_with_index.map do |code, index|
  Catalog::Set.create!(collectible_type: "mtg", code:, name: "Upgrade Set #{code.upcase}", released_on: Date.new(2020 + index, 1, 1),
    content_digest: "upgrade-seed")
end

names = Array.new(50) { |index| format("Upgrade Dragon %02d", index + 1) }
entries = names.each_with_index.map do |name, index|
  set = sets[index % 2]
  identity = Catalog::Identity.create!(collectible_type: "mtg", external_key: "upgrade-identity-#{index}", name:, content_digest: "upgrade-seed")
  entry = Catalog::Entry.create!(collectible_type: "mtg", external_key: "upgrade-entry-#{index}", set:, identity:, number: (index + 1).to_s,
    language: "en", name:, kind: "card", released_on: set.released_on, content_digest: "upgrade-seed")
  MTG::Card.create!(identity:, mana_cost: "{R}", type_line: "Creature", oracle_text: "Seed text.")
  MTG::Printing.create!(entry:, rarity: "common", finishes: %w[nonfoil foil], layout: "normal", illustration_id: "upgrade-illustration-#{index}",
    scryfall_uri: "https://scryfall.com/card/#{set.code}/#{index + 1}",
    faces: [ { "name" => name, "mana_cost" => "{R}", "type_line" => "Creature", "oracle_text" => "Seed text.", "artist" => "Nobody", "image_uris" => {} } ])
  entry
end
Catalog::NameIndex.new("mtg").rebuild

ada, = User::Command.call(email: "ada@upgrade.example", password:)
grace = User.create!(name: "Grace", email_address: "grace@upgrade.example", password:)
InstanceSetting.current.update!(sign_up_open: true)
[ ada, grace ].each { |user| user.sessions.create!(ip_address: "127.0.0.1", user_agent: "upgrade-seed") }

# 50 printings x 2 finishes x 5 conditions x 4 prices = 2,000 lots for Ada; Grace's collection stays empty.
variants = %w[nonfoil foil].product(%w[near_mint lightly_played moderately_played heavily_played damaged], [ nil, 100, 250, 1999 ])
Lot.insert_all(entries.each_with_index.flat_map do |entry, index|
  variants.each_with_index.map do |(finish, condition, price), position|
    { account_id: ada.account_id, catalog_entry_id: entry.id, quantity: 1 + (index + position) % 7, finish:, condition:, price_paid_cents: price,
      lot_key: Lot.key_for(finish, condition, price), created_at: now, updated_at: now }
  end
end)
Scanner::Sitting.add!(account: ada.account, printing: entries.first, finish: "nonfoil", reading_key: SecureRandom.hex(16))

session = ada.sessions.first
selection = BulkSelection.for(session)
ada.account.lots.limit(3).pluck(:id).each { |lot_id| selection.marks.create!(lot_id:, account: ada.account) }
BulkRemoval.create!(session:, account: ada.account, copies: 2,
  lots_data: [ { "catalog_entry_id" => entries.first.id, "finish" => "foil", "condition" => "damaged", "price_paid_cents" => nil, "quantity" => 2 } ])

Catalog::RefreshRun.create!(collectible_type: "mtg", trigger: "manual", status: "applied", source_version: "upgrade-seed", languages: "en",
  started_at: now - 60, finished_at: now, seen_count: 50, inserted_count: 50)
MTG::ArtBuild.create!(status: "finished", job_id: "upgrade-seed", catalog_version: "upgrade-seed", settings_digest: "upgrade-seed",
  index_file: "art-index-upgrade.bin.gz", started_at: now - 60, heartbeat_at: now, finished_at: now, total_count: 50, indexed_count: 50)
MTG::Artwork.create!(entry: entries.first, illustration_id: "upgrade-illustration-0", fingerprint: "\x00".b * 128, settings_digest: "upgrade-seed")
locations = [ "Binder A", "Shelf B" ].map { |location| Location.create!(account: ada.account, name: location) }
NumberEntry.add!(account: ada.account, entry: entries.first, quantity: 2, finish: "foil", line_key: SecureRandom.hex(16))
plan = Object.new
def plan.fingerprint(checksum) = "upgrade-seed-#{checksum}"
upload = ImportUpload.store!(account: grace.account, bytes: "{}", plan:)
ActiveStorage::VariantRecord.create!(blob: upload.file.blob, variation_digest: "upgrade-seed")
Catalog::RefreshJob.set(wait: 1.year).perform_later("mtg", marker)

facts = { release: "next", password:, marker:, locations: locations.map(&:name),
  users: [ { email: ada.email_address, lots: ada.account.lots.count, names: }, { email: grace.email_address, lots: 0, names: [] } ] }
puts "UPGRADE-SEED-COMPLETE #{facts.to_json}"
```

- [ ] Run: `bin/rspec spec/script/upgrade/seeds_spec.rb` — expect PASS. If an Active Storage example leaves a file in `tmp/storage`, `spec/support/active_storage.rb` empties it after the suite.
- [ ] Run: `bin/rubocop script/upgrade spec/script/upgrade` — the seeds are plain scripts: RuboCop must pass without disables.
- [ ] Run: `bin/ci` — expect green (the suite now runs the guard, the comparer and `next.rb`).
- [ ] Commit: `feat: seeds for the previous release and the next one (spec 031 decision 4)`

---

## Phase 6: The command chokepoint and the web checks

**Implements:** FR-3, FR-6, FR-8 (the engine half), decision 5 (behaviour) | **Satisfies:** AC-3.4, AC-8.3, AC-5.1 (the client), AC-5.3 (the form check), AC-1.3's digest read
**Files:** `script/upgrade/engine.rb`, `script/upgrade/web.rb`, `spec/script/upgrade/engine_spec.rb`, `spec/script/upgrade/web_spec.rb`, `spec/support/upgrade_fakes.rb` (`FakeEngine`, `FakeWeb`, used from Phase 7)
**Interfaces:** Consumes: the container CLI (`docker`, else `podman`, or `CONTAINER_CLI`). Produces: `Upgrade::Engine.new(cli: Engine.detect, run_flags: [], executor: nil)` with `Result(out, err, status)` (`ok?`), `Engine::Failure`, `Engine::FORBIDDEN`, `Engine::ALLOWED` and the builders `pull(image, platform: nil)`, `image_info(image)` (a Hash or nil), `create_volume(name)`, `remove_volume(name)`, `start(name:, volume:, secret:, image:, mounts: [])`, `port(name)`, `state(name)` (`{ running:, exit_code: }`), `stop(name)`, `logs(name)`, `remove(name)`, `runner(name, code)` (`Result`), `tasks(name)` (`Result` of `bin/rails -T backup`), `task(name, task)` (`Result`), `restore(image:, volume:, directory:, file:)` (`Result`), `copy_database(volume:, image:, into:)`, `list_directory(image, directory)` (names), `own(image, directory)`, `remove_directory(image, directory)`; `Upgrade::Web.new(port)` with `#get(path)` → `Response(status, body)`, `#status(path)` (0 when nothing answers), `#sign_in(email, password)` → boolean, `Web.signup_form?(body)`.

`run` and `run!` are private: nothing outside `Engine` can make a command line (AC-8.3). `run(category, args, check: args, stdin: nil)` refuses an argument that names a forbidden task, then a list the category's lambda does not accept (`check` is the in-container command for the `files` category).

- [ ] Write `spec/support/upgrade_fakes.rb` (the doubles that Phases 7 and 8 use; it is test code; `rails_helper` loads every file of `spec/support`, so from this step the suite needs `engine.rb` and `web.rb` to load, which is why Phase 6 writes them in the same phase and a red run here may fail with `cannot load such file`):

```ruby
require Rails.root.join("script/upgrade/engine").to_s
require Rails.root.join("script/upgrade/web").to_s

# An Upgrade::Engine that runs nothing: it records each call and answers from DEFAULTS, overridden per example by
# keyword (a value, or a callable that gets the call's arguments). Spec 031 AC-8.6.
class FakeEngine
  Result = Upgrade::Engine::Result
  SEED_LINE = "UPGRADE-SEED-COMPLETE ".freeze
  FACTS = { "release" => "0.2.1", "password" => "pw-1234-pw-1234", "marker" => "upgrade-marker", "locations" => [],
    "users" => [ { "email" => "ada@x.test", "lots" => 2001, "names" => [ "Dragon One", "Dragon Two" ] }, { "email" => "grace@x.test", "lots" => 0, "names" => [] } ] }.freeze
  DEFAULTS = {
    pull: Result.new("", "", 0),
    image_info: { "RepoDigests" => [ "ghcr.io/plainprogrammer/collector@sha256:abc123" ],
      "Config" => { "Labels" => { "org.opencontainers.image.version" => "0.2.1", "org.opencontainers.image.revision" => "deadbeef" } } },
    create_volume: nil, remove_volume: nil, start: nil, port: 4000, state: { running: true, exit_code: 0 }, stop: nil, logs: "", remove: nil,
    tasks: Result.new("", "", 0), task: Result.new("Backup written: /backups/collector-backup-1.tar.gz\n", "", 0),
    restore: Result.new("Restored collector-backup-1.tar.gz into /rails/storage.\n", "", 0), list_directory: [ "collector-backup-1.tar.gz" ],
    own: nil, remove_directory: nil
  }.freeze

  attr_reader :calls

  # `databases`: the files that copy_database hands out, in order (old, upgraded, ...); `log` receives each call's name;
  # `facts`: what the seed reports; `runner_answers`: { /code pattern/ => Result } consulted before the defaults.
  def initialize(databases: [], log: [], facts: FACTS, runner_answers: {}, **scripted)
    @databases = databases.dup
    @log = log
    @facts = facts
    @runner_answers = runner_answers
    @scripted = scripted
    @calls = []
  end

  def names = @calls.map(&:first)

  def runner(name, code)
    record(:runner, [ name, code ], {}) { default_runner(code) }
  end

  def copy_database(volume:, image:, into:)
    record(:copy_database, [], { volume:, image:, into: }) do
      FileUtils.cp(@databases.shift || raise("no database left for copy_database"), File.join(into, "production.sqlite3"))
      [ "production.sqlite3" ]
    end
  end

  (Upgrade::Engine.public_instance_methods(false) - %i[runner copy_database]).each do |method|
    define_method(method) do |*args, **kwargs|
      record(method, args, kwargs) { DEFAULTS.fetch(method) }
    end
  end

  private
    def record(method, args, kwargs)
      @calls << [ method, args, kwargs ]
      @log << method
      answer = @scripted.key?(method) ? @scripted[method] : yield
      answer.respond_to?(:call) ? answer.call(*args, **kwargs) : answer
    end

    # The seed, the marker count, the recurring check and the enqueue check, told apart by their code.
    def default_runner(code)
      answer = @runner_answers.find { |pattern, _| code.match?(pattern) }&.last
      return(answer.respond_to?(:call) ? answer.call : answer) if answer

      case code
      when /fake seed/ then Result.new("#{SEED_LINE}#{JSON.generate(@facts)}\n", "", 0)
      when /RecurringTask|perform_later/ then Result.new("true\n", "", 0)
      else Result.new("1\n", "", 0)
      end
    end
end

# Upgrade::Web with pages scripted per path (a Response, or a callable that gets the signed-in user's email or nil). Each
# client the harness makes remembers who signed in. Fetching a page is logged as :get, a sign-in as :sign_in; the /up poll
# and the status reads are not logged.
class FakeWeb
  Response = Upgrade::Web::Response

  class Client
    def initialize(web)
      @web = web
      @user = nil
    end

    def get(path) = @web.fetch(path, @user, logged: true)

    def status(path) = @web.fetch(path, @user, logged: false).status

    def sign_in(email, _password)
      @web.log << :sign_in
      @user = email if @web.sign_in_ok
      @web.sign_in_ok
    end
  end

  attr_accessor :sign_in_ok
  attr_reader :log

  def initialize(pages: {}, log: [])
    @pages = pages
    @log = log
    @sign_in_ok = true
  end

  def new_client(_port) = Client.new(self)

  def fetch(path, user, logged:)
    @log << :get if logged
    answer = @pages.fetch(path) { Response.new(200, "") }
    answer.respond_to?(:call) ? answer.call(user) : answer
  end
end
```

- [ ] Write `spec/script/upgrade/web_spec.rb` (a loopback server on a free port speaks real HTTP, so the cookie jar, the CSRF token and the redirects are the real ones):

```ruby
require "rails_helper"
require "socket"
require Rails.root.join("script/upgrade/web").to_s

RSpec.describe Upgrade::Web do
  # routes: a callable (method, path, head, body) -> [status, headers, body]
  def serve(routes)
    server = TCPServer.new("127.0.0.1", 0)
    thread = Thread.new do
      loop do
        client = server.accept
        head = +""
        while (line = client.gets) && line != "\r\n"
          head << line
        end
        method, path = head.lines.first.to_s.split
        length = head[/content-length: (\d+)/i, 1].to_i
        body = length.positive? ? client.read(length) : ""
        status, headers, payload = routes.call(method, path, head, body)
        client.write("HTTP/1.1 #{status} X\r\n#{headers.map { |key, value| "#{key}: #{value}\r\n" }.join}Content-Length: #{payload.bytesize}\r\nConnection: close\r\n\r\n#{payload}")
        client.close
      end
    rescue IOError, Errno::EBADF
      nil
    end
    [ server, thread ]
  end

  let(:routes) do
    lambda do |method, path, head, body|
      case [ method, path ]
      when [ "GET", "/session/new" ] then [ 200, {}, '<meta name="csrf-token" content="tok123" />' ]
      when [ "POST", "/session" ]
        good = body.include?("authenticity_token=tok123") && body.include?("password=right")
        good ? [ 303, { "Set-Cookie" => "sid=abc; path=/; HttpOnly" }, "" ] : [ 422, {}, "no" ]
      when [ "GET", "/collection" ] then head.include?("Cookie: sid=abc") ? [ 200, {}, "Dragon" ] : [ 302, {}, "" ]
      else [ 404, {}, "" ]
      end
    end
  end

  let!(:listener) { serve(routes) }
  let(:port) { listener.first.addr[1] }
  let(:web) { described_class.new(port) }

  after do
    listener.first.close
    listener.last.kill
  end

  it "signs in with the form's CSRF token and keeps the session cookie (AC-5.1)", :aggregate_failures do
    expect(web.get("/collection").status).to eq(302)
    expect(web.sign_in("ada@x.test", "right")).to be(true)
    expect(web.get("/collection").body).to eq("Dragon")
  end

  it "reports a refused sign-in" do
    expect(web.sign_in("ada@x.test", "wrong")).to be(false)
  end

  it "answers status 0 when nothing listens" do
    closed_port = port
    listener.first.close
    expect(described_class.new(closed_port).status("/up")).to eq(0)
  end

  it "tells the sign-up form from the closed notice by its email field (AC-5.3)", :aggregate_failures do
    expect(described_class.signup_form?('<input name="user[email_address]" type="email">')).to be(true)
    expect(described_class.signup_form?("<p>Sign-up is closed.</p>")).to be(false)
  end
end
```

- [ ] Write `spec/script/upgrade/engine_spec.rb`:

```ruby
require "rails_helper"
require Rails.root.join("script/upgrade/engine").to_s

RSpec.describe Upgrade::Engine do
  let(:calls) { [] }
  let(:listing) { "production.sqlite3\nproduction.sqlite3-wal\nproduction_cache.sqlite3\n" }
  let(:executor) do
    lambda do |argv, _stdin|
      calls << argv
      out = if argv.include?("inspect") && argv.include?("image") then "[{}]"
      elsif argv.include?("ls") then listing
      else ""
      end
      Upgrade::Engine::Result.new(out, "", 0)
    end
  end
  let(:engine) { described_class.new(cli: "docker", run_flags: [ "--platform", "linux/arm64" ], executor:) }

  def refused(category, args, **) = engine.send(:run, category, args, **)

  it "builds only commands that a category accepts, for the container's life (AC-8.3)", :aggregate_failures do
    expect do
      engine.pull("img:1", platform: "linux/arm64")
      engine.image_info("img:1")
      engine.create_volume("v")
      engine.start(name: "c", volume: "v", secret: "s", image: "img:1", mounts: [ "/tmp/b:/backups" ])
      engine.port("c")
      engine.state("c")
      engine.logs("c")
      engine.stop("c")
      engine.remove("c")
      engine.remove_volume("v")
    end.not_to raise_error
    expect(calls).to all(start_with("docker"))
  end

  it "builds only commands that a category accepts, for the tasks and the files (AC-8.3)", :aggregate_failures do
    expect do
      engine.runner("c", "puts 1")
      engine.tasks("c")
      engine.task("c", "backup:create[/backups]")
      engine.restore(image: "img:1", volume: "v", directory: "/tmp/b", file: "collector-backup-1.tar.gz")
      engine.copy_database(volume: "v", image: "img:1", into: "/tmp/out")
      engine.list_directory("img:1", "/tmp/b")
      engine.own("img:1", "/tmp/b")
      engine.remove_directory("img:1", "/tmp/s")
    end.not_to raise_error
    expect(calls).to all(start_with("docker"))
  end

  it "refuses a database task in any category (AC-3.4)", :aggregate_failures do
    %w[db:schema:load db:reset db:drop db:setup].each do |task|
      expect { refused(:runner, [ "exec", "-i", "c", "bin/rails", task ]) }.to raise_error(described_class::Failure, /database task/)
    end
  end

  it "refuses a task, a file command and a category that are not on the list", :aggregate_failures do
    expect { refused(:tasks, [ "exec", "c", "bin/rails", "db:migrate" ]) }.to raise_error(described_class::Failure, /not on the proof's list/)
    expect { refused(:files, [ "run", "--rm", "img", "rm", "-rf", "/etc" ], check: %w[rm -rf /etc]) }.to raise_error(described_class::Failure, /not on the proof's list/)
    expect { refused(:shell, [ "run", "sh" ]) }.to raise_error(described_class::Failure, /unknown command category/)
  end

  it "starts a container the way an operator does: the volume, the secret, the port, the flags and the entrypoint's boot", :aggregate_failures do
    engine.start(name: "c", volume: "v", secret: "s3", image: "img:1")
    expect(calls.last).to eq(%w[docker run -d --name c --platform linux/arm64 -p 127.0.0.1::8080 -v v:/rails/storage
      -e SECRET_KEY_BASE=s3 -e HTTP_PORT=8080 -e SOLID_QUEUE_IN_PUMA=true img:1])
  end

  it "restores with the dummy secret from a read-only directory, as the README documents (AC-6.1)" do
    engine.restore(image: "img:1", volume: "v", directory: "/tmp/b", file: "collector-backup-1.tar.gz")
    expect(calls.last).to eq(%w[docker run --rm -u 1000 --platform linux/arm64 -v v:/rails/storage -v /tmp/b:/backups:ro
      -e SECRET_KEY_BASE_DUMMY=1 img:1 bin/rails backup:restore[/backups/collector-backup-1.tar.gz]])
  end

  it "copies out the main database file and any -wal and -shm, not the other databases (AC-2.4)", :aggregate_failures do
    engine.copy_database(volume: "v", image: "img:1", into: "/tmp/out")
    copy = calls.find { it.include?("cp") }
    expect(copy.last(3)).to eq(%w[/rails/storage/production.sqlite3 /rails/storage/production.sqlite3-wal /out/])
    expect(copy).not_to include("/rails/storage/production_cache.sqlite3")
  end

  it "has a fake that answers every builder, so the harness specs cover what the harness calls" do
    fake = FakeEngine.new
    expect(described_class.public_instance_methods(false)).to all(satisfy { |name| fake.respond_to?(name) })
  end

  it "keeps every forbidden task name in one constant and out of every other line of the harness (AC-3.4, AC-8.3)", :aggregate_failures do
    files = Dir[Rails.root.join("script/upgrade/**/*.rb").to_s] + [ Rails.root.join("bin/upgrade-smoke").to_s ]
    pattern = /db:(schema:load|reset|drop|setup)/
    hits = files.flat_map { |file| File.readlines(file).grep(pattern).map { |line| [ File.basename(file), line.strip ] } }
    expect(hits.map(&:first).uniq).to eq([ "engine.rb" ])
    expect(hits.map(&:last)).to all(start_with("FORBIDDEN ="))
  end

  it "starts a process only in engine.rb (the container CLI) and release.rb (read-only git) (AC-8.3)" do
    spawning = /Open3|\bsystem\(|\bspawn\(|%x[\[{(]|IO\.popen|Kernel\.exec|Process\.(spawn|exec)/
    files = Dir[Rails.root.join("script/upgrade/**/*.rb").to_s] + [ Rails.root.join("bin/upgrade-smoke").to_s ]
    offenders = files.reject { File.basename(it).then { |name| %w[engine.rb release.rb].include?(name) } }.select { File.read(it).match?(spawning) }
    expect(offenders).to be_empty
  end
end
```

- [ ] Run: `bin/rspec spec/script/upgrade/engine_spec.rb spec/script/upgrade/web_spec.rb` — expect FAIL (`cannot load such file`).
- [ ] Create `script/upgrade/engine.rb`:

```ruby
# Every container command of the upgrade proof goes through this class (spec 031 AC-3.4, AC-8.3): a builder per command,
# one `run` that refuses anything a category does not accept and any database task, and an executor that a spec replaces.
require "fileutils"
require "json"
require "open3"

module Upgrade
  class Engine
    Failure = Class.new(StandardError)
    Result = Struct.new(:out, :err, :status) do
      def ok? = status.zero?
    end

    FORBIDDEN = %w[db:schema:load db:reset db:drop db:setup].freeze
    FILE_COMMANDS = %w[ls cp chown chmod rm].freeze
    ALLOWED = {
      pull: ->(args) { args.first == "pull" },
      inspect: ->(args) { args.first(2) == %w[image inspect] || (args.first == "inspect" && args[1] == "--format") },
      start: ->(args) { args.first(2) == %w[run -d] && args.include?("SOLID_QUEUE_IN_PUMA=true") && args.include?("127.0.0.1::8080") },
      observe: ->(args) { %w[port logs].include?(args.first) },
      stop: ->(args) { (args.first == "stop" && args[1] == "-t") || args.first(2) == %w[rm -f] },
      runner: ->(args) { args.first(2) == %w[exec -i] && args.last(3) == %w[bin/rails runner -] },
      tasks: ->(args) { args.first == "exec" && (args[3..] == %w[-T backup] || args[3].to_s.match?(%r{\Abackup:create\[/backups\]\z})) },
      restore: ->(args) { args.first(3) == %w[run --rm -u] && args.last.to_s.match?(%r{\Abackup:restore\[/backups/[\w.-]+\]\z}) },
      files: ->(command) { FILE_COMMANDS.include?(command.first) && (command.first != "rm" || command.drop(2).all? { it.start_with?("/work/") }) },
      volume: ->(args) { args.first == "volume" && %w[create rm].include?(args[1]) }
    }.freeze

    def self.detect = ENV["CONTAINER_CLI"] || (system("docker", "--version", out: File::NULL, err: File::NULL) ? "docker" : "podman")

    def initialize(cli: self.class.detect, run_flags: [], executor: nil)
      @cli = cli
      @run_flags = run_flags
      @executor = executor || method(:execute)
    end

    def pull(image, platform: nil) = run(:pull, [ "pull", *(platform ? [ "--platform", platform ] : []), image ])

    def image_info(image)
      result = run(:inspect, [ "image", "inspect", image ])
      JSON.parse(result.out).first if result.ok?
    end

    def create_volume(name) = run!(:volume, [ "volume", "create", name ])

    def remove_volume(name) = run(:volume, [ "volume", "rm", "-f", name ])

    def start(name:, volume:, secret:, image:, mounts: [])
      run!(:start, [ "run", "-d", "--name", name, *@run_flags, "-p", "127.0.0.1::8080", "-v", "#{volume}:/rails/storage",
        *mounts.flat_map { [ "-v", it ] }, "-e", "SECRET_KEY_BASE=#{secret}", "-e", "HTTP_PORT=8080", "-e", "SOLID_QUEUE_IN_PUMA=true", image ])
    end

    def port(name) = run!(:observe, [ "port", name, "8080" ]).out.lines.first.to_s[/:(\d+)\s*\z/, 1].to_i

    def state(name)
      running, code = run!(:inspect, [ "inspect", "--format", "{{.State.Running}} {{.State.ExitCode}}", name ]).out.split
      { running: running == "true", exit_code: code.to_i }
    end

    def logs(name) = run(:observe, [ "logs", name ]).then { it.out + it.err }

    def stop(name) = run!(:stop, [ "stop", "-t", "30", name ])

    def remove(name) = run(:stop, [ "rm", "-f", name ])

    # The seed, or a check, on standard input: `bin/rails runner -` evaluates it (railties-8.1.4 runner_command.rb).
    def runner(name, code) = run(:runner, [ "exec", "-i", name, "bin/rails", "runner", "-" ], stdin: code)

    def tasks(name) = run!(:tasks, [ "exec", name, "bin/rails", "-T", "backup" ])

    def task(name, task) = run(:tasks, [ "exec", name, "bin/rails", task ])

    def restore(image:, volume:, directory:, file:)
      run(:restore, [ "run", "--rm", "-u", "1000", *@run_flags, "-v", "#{volume}:/rails/storage", "-v", "#{directory}:/backups:ro",
        "-e", "SECRET_KEY_BASE_DUMMY=1", image, "bin/rails", "backup:restore[/backups/#{file}]" ])
    end

    # The primary database file and any -wal and -shm out of a stopped volume into a host directory (AC-2.4).
    def copy_database(volume:, image:, into:)
      listing = oneoff!(image, [ "#{volume}:/rails/storage:ro" ], %w[ls /rails/storage]).out.split
      files = listing.grep(/\Aproduction\.sqlite3(-wal|-shm)?\z/)
      raise Failure, "the volume #{volume} holds no production.sqlite3 (it holds: #{listing.join(" ")})" unless files.include?("production.sqlite3")

      oneoff!(image, [ "#{volume}:/rails/storage:ro", "#{into}:/out" ], [ "cp", "-p", *files.map { "/rails/storage/#{it}" }, "/out/" ])
      oneoff!(image, [ "#{into}:/out" ], %w[chmod -R a+rwX /out])
      files
    end

    def list_directory(image, directory) = oneoff!(image, [ "#{directory}:/backups:ro" ], %w[ls /backups]).out.split

    # What the container's user (uid 1000) writes can't be removed by the invoking user, nor can what a root one-off wrote.
    def own(image, directory)
      FileUtils.chmod(0o777, directory) unless oneoff(image, [ "#{directory}:/dir" ], %w[chown 1000:1000 /dir]).ok?
    end

    def remove_directory(image, directory) = oneoff(image, [ "#{directory}:/work" ], %w[rm -rf /work/copies /work/backups])

    private
      def oneoff(image, mounts, command)
        run(:files, [ "run", "--rm", "-u", "0", *@run_flags, *mounts.flat_map { [ "-v", it ] }, image, *command ], check: command)
      end

      def oneoff!(image, mounts, command)
        oneoff(image, mounts, command).tap { |result| raise Failure, "#{command.join(" ")} failed (status #{result.status}): #{result.err.strip}" unless result.ok? }
      end

      def run(category, args, check: args, stdin: nil)
        validator = ALLOWED.fetch(category) { raise Failure, "unknown command category #{category.inspect}" }
        if (args + Array(check)).any? { |argument| FORBIDDEN.any? { argument.include?(it) } }
          raise Failure, "refused: #{args.join(" ")} names a database task, which the proof never runs"
        end
        raise Failure, "refused: #{category} #{args.join(" ")} is not on the proof's list of commands" unless validator.call(check)

        @executor.call([ @cli, *args ], stdin)
      end

      def run!(category, args, **)
        run(category, args, **).tap do |result|
          raise Failure, "#{@cli} #{args.first(3).join(" ")} failed (status #{result.status}): #{result.err.strip}" unless result.ok?
        end
      end

      def execute(argv, stdin)
        out, err, status = Open3.capture3(*argv, stdin_data: stdin.to_s)
        Result.new(out, err, status.exitstatus || 128 + status.termsig.to_i)
      end
  end
end
```

- [ ] Create `script/upgrade/web.rb`:

```ruby
# The HTTP side of the behaviour checks (spec 031 Story 5): a client that keeps cookies, signs in at the form with its CSRF
# token as a browser does, and never follows a redirect.
require "net/http"

module Upgrade
  class Web
    Response = Struct.new(:status, :body)

    CSRF = /<meta name="csrf-token" content="([^"]*)"/
    UNREACHABLE = [ Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EPIPE, EOFError, SocketError, Net::OpenTimeout, Net::ReadTimeout ].freeze

    # The sign-up page answers 200 whether sign-up is open or closed; only the open one has this field (AC-5.3).
    def self.signup_form?(body) = body.include?('name="user[email_address]"')

    def initialize(port, host: "127.0.0.1")
      @host = host
      @port = port
      @cookies = {}
    end

    def get(path) = send_request(Net::HTTP::Get.new(path))

    def status(path) = get(path).status

    def sign_in(email, password)
      token = CSRF.match(get("/session/new").body)&.captures&.first
      return false unless token

      request = Net::HTTP::Post.new("/session")
      request.set_form_data("authenticity_token" => token, "email_address" => email, "password" => password)
      [ 302, 303 ].include?(send_request(request).status)
    end

    private
      def send_request(request)
        request["Cookie"] = @cookies.map { |name, value| "#{name}=#{value}" }.join("; ") unless @cookies.empty?
        Net::HTTP.start(@host, @port, open_timeout: 5, read_timeout: 30) do |http|
          response = http.request(request)
          response.get_fields("set-cookie")&.each do |cookie|
            name, value = cookie.split(";", 2).first.split("=", 2)
            @cookies[name] = value
          end
          Response.new(response.code.to_i, response.body.to_s)
        end
      rescue *UNREACHABLE
        Response.new(0, "")
      end
  end
end
```

- [ ] Run: `bin/rspec spec/script/upgrade/engine_spec.rb spec/script/upgrade/web_spec.rb` — expect PASS.
- [ ] Run: `bin/rubocop script/upgrade spec/script/upgrade spec/support/upgrade_fakes.rb` — expect no offenses.
- [ ] Commit: `feat: the upgrade proof's command allowlist and web client (spec 031 AC-3.4, AC-8.3)`

---

## Phase 7: The harness, `bin/upgrade-smoke` and the first hand run

**Implements:** decisions 1, 2, 3, 4, 5, 8; FR-1 to FR-8 | **Satisfies:** AC-1.2 to AC-1.6, AC-2.1 to AC-2.9, AC-3.1 to AC-3.5, AC-4.1, AC-5.1 to AC-5.7, AC-7.3 to AC-7.5, AC-8.6, FR-8
**Files:** `script/upgrade/harness.rb`, `bin/upgrade-smoke`, `spec/script/upgrade/harness_spec.rb`, `spec/script/upgrade/files_spec.rb` (extended), `.dockerignore`, `bin/image-smoke`, `.rubocop.yml`
**Interfaces:** Consumes: Phases 1 to 6. Produces: `Upgrade::Harness.parse(argv, env: ENV)` → `[previous, current, options]`; `Upgrade::Harness.new(previous:, current:, release:, engine:, options:, web: Web.method(:new), out: $stdout, root: Dir.pwd, sleeper: Kernel.method(:sleep)).call` → exit status 0 or 1; `bin/upgrade-smoke <previous|auto> <current> [options]`.

The sequence is contracts/harness.md's. In words, with the spec's order of AC-2.9: resolve → seed and rules (AC-2.7, before any container) → pull → boot the previous release on volume A, seed it, take the pre-stop pages and the backup → clean stop, copy, snapshot, coverage and facts (AC-2.1, 2.4, 2.5, 2.3) → boot the code under test on volume A → clean stop, snapshot, compare, integrity, versions (AC-3.1 to AC-3.5, 4.1) → restart, the behaviour checks (Story 5) → the backup leg (Phase 8) → `next.rb` on a fresh instance (AC-2.6) → `OK`. Nothing signs in, enqueues or downloads before the upgraded snapshot (AC-2.9).

- [ ] Write `spec/script/upgrade/harness_spec.rb`:

```ruby
require "rails_helper"
require Rails.root.join("script/upgrade/harness").to_s

RSpec.describe Upgrade::Harness, :git_sandbox, :upgrade do
  let(:dir) { upgrade_dir }
  let(:root) { File.join(dir, "checkout") }
  let(:out) { StringIO.new }
  let(:log) { [] }
  let(:old_migrations) { %w[20261001000001] }
  let(:all_migrations) { %w[20261001000001 20261002000001] }
  let(:options) { described_class::Options.new(timeout: 60, boot_attempts: 2, repository: "ghcr.io/plainprogrammer/collector") }

  before do
    build_history(root, "v0.2.1" => { "db/migrate/20261001000001_create_a.rb" => "a\n", "script/upgrade/seeds/0.2.1.rb" => "# fake seed\n",
      "script/upgrade/seeds/next.rb" => "# fake seed\n", "script/upgrade/seed_exceptions.yml" => "\"0.2.1\": []\nnext: []\n",
      "script/upgrade/expected_changes.yml" => "changes: []\n", "app/models/export_format/v2.schema.json" => "{}\n" },
      "work" => { "db/migrate/20261002000001_create_b.rb" => "b\n" })
  end

  # A seeded database as a release makes it (accounts, users, 2,000 lots, sign-up open), with the given migrations recorded.
  def seeded(name, versions, lots: 2000)
    build_database(File.join(dir, "#{name}.sqlite3")) do |db|
      db.execute_batch(<<~SQL)
        CREATE TABLE accounts (id INTEGER PRIMARY KEY); CREATE TABLE users (id INTEGER PRIMARY KEY, password_digest TEXT);
        CREATE TABLE lots (id INTEGER PRIMARY KEY, account_id INTEGER); CREATE TABLE instance_settings (id INTEGER PRIMARY KEY, sign_up_open BOOLEAN);
        CREATE TABLE schema_migrations (version TEXT PRIMARY KEY);
        INSERT INTO accounts VALUES (1), (2); INSERT INTO users VALUES (1, 'x'), (2, 'y'); INSERT INTO instance_settings VALUES (1, 1);
        WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < #{lots}) INSERT INTO lots SELECT i, 1 FROM n;
        #{versions.map { "INSERT INTO schema_migrations VALUES ('#{it}');" }.join}
      SQL
    end
  end

  let(:pages) do
    { "/registration/new" => FakeWeb::Response.new(200, '<input name="user[email_address]">'),
      "/collection" => ->(user) { FakeWeb::Response.new(200, user == "ada@x.test" ? "Dragon One Dragon Two" : "") },
      "/collection/export" => FakeWeb::Response.new(200, JSON.generate("format_version" => 2, "lots" => Array.new(2001) { {} })) }
  end
  let(:web) { FakeWeb.new(pages:, log:) }
  let(:databases) { [ seeded("old", old_migrations), seeded("upgraded", all_migrations), seeded("next", all_migrations) ] }
  let(:engine) { FakeEngine.new(databases:, log:) }

  def harness(previous: "auto", engine: self.engine, env: { "GITHUB_ACTIONS" => "true" }, options: self.options, release: Upgrade::Release.new(root, env:))
    described_class.new(previous:, current: "collector:smoke", release:, engine:, options:, web: web.method(:new_client), out:, root:, sleeper: ->(_) {})
  end

  it "proves a clean upgrade, in AC-2.9's order, and prints the comparison (AC-4.1, AC-7.3)", :aggregate_failures do
    expect(harness.call).to eq(0)
    starts = log.each_index.select { log[it] == :start }
    upgrade_start = starts.fetch(1)
    snapshot = log.each_index.find { it > upgrade_start && log[it] == :copy_database }
    expect(log[upgrade_start..snapshot]).not_to include(:runner, :sign_in, :get)
    expect(out.string).to match(/lots\s+old\s+2000\s+new\s+2000\s+same/)
    expect(out.string).to include("== upgrade", "== snapshot and compare", "== behaviour", "skipped").and match(/^OK: v0\.2\.1/)
  end

  it "prints 'no previous release' and touches no container when there is none (AC-1.2)", :aggregate_failures do
    empty = File.join(dir, "empty")
    build_history(empty, "work" => { "f" => "x" })
    expect(harness(release: Upgrade::Release.new(empty, env: { "GITHUB_ACTIONS" => "true" })).call).to eq(0)
    expect(engine.calls).to be_empty
    expect(out.string).to include("no previous release")
  end

  it "pulls the exact version tag for the platform and prints the digest and revision (AC-1.3)", :aggregate_failures do
    options.platform = "linux/arm64"
    harness.call
    expect(engine.calls.first).to eq([ :pull, [ "ghcr.io/plainprogrammer/collector:0.2.1" ], { platform: "linux/arm64" } ])
    expect(out.string).to include("v0.2.1", "sha256:abc123", "deadbeef")
  end

  it "fails naming the tag and the platform, without a retry or a fallback, when the image has no manifest (AC-1.4)", :aggregate_failures do
    engine = FakeEngine.new(pull: FakeEngine::Result.new("", "Error: manifest unknown\n", 1))
    options.platform = "linux/arm64"
    expect(harness(engine:).call).to eq(1)
    expect(engine.names.count(:pull)).to eq(1)
    expect(out.string).to include("FAIL: pull", "v0.2.1", "linux/arm64", "manifest unknown")
  end

  it "tries a transient pull failure three times, waiting between, then fails naming the registry's last answer (AC-1.5)", :aggregate_failures do
    waits = []
    engine = FakeEngine.new(pull: FakeEngine::Result.new("", "dial tcp: i/o timeout\n", 1))
    harness = described_class.new(previous: "auto", current: "collector:smoke", release: Upgrade::Release.new(root, env: { "GITHUB_ACTIONS" => "true" }),
      engine:, options:, web: web.method(:new_client), out:, root:, sleeper: ->(seconds) { waits << seconds })
    expect(harness.call).to eq(1)
    expect([ engine.names.count(:pull), waits.size ]).to eq([ 3, 2 ])
    expect(out.string).to include("ghcr.io", "i/o timeout")
  end

  it "fails before booting anything when the previous release has no seed, naming the file and the release step (AC-2.7)", :aggregate_failures do
    File.delete(File.join(root, "script/upgrade/seeds/0.2.1.rb"))
    expect(harness.call).to eq(1)
    expect(engine.names).not_to include(:start)
    expect(out.string).to include("script/upgrade/seeds/0.2.1.rb", "docs/releasing.md")
  end

  it "fails with the seed's error rather than comparing a half-filled database (AC-2.8)", :aggregate_failures do
    engine = FakeEngine.new(databases:, runner: FakeEngine::Result.new("", "NoMethodError: undefined method 'x'\n", 1))
    expect(harness(engine:).call).to eq(1)
    expect(out.string).to include("FAIL: seed", "v0.2.1", "NoMethodError")
    expect(engine.names).not_to include(:copy_database)
  end

  it "fails naming the container when it was killed at the end of the grace period (AC-2.4)", :aggregate_failures do
    engine = FakeEngine.new(databases:, state: { running: false, exit_code: 137 })
    expect(harness(engine:).call).to eq(1)
    expect(out.string).to match(/upgrade-smoke-\d+-previous stopped with status 137/)
  end

  it "fails when the old database was not made by the previous release (AC-2.1)", :aggregate_failures do
    engine = FakeEngine.new(databases: [ seeded("wrong", %w[20261001000001 20269999999999]) ])
    expect(harness(engine:).call).to eq(1)
    expect(out.string).to include("AC-2.1", "20269999999999")
  end

  it "fails when a table of the previous release got no rows from the seed (AC-2.5)" do
    bare = build_database(File.join(dir, "bare.sqlite3")) { |db| db.execute_batch("CREATE TABLE schema_migrations (version TEXT); INSERT INTO schema_migrations VALUES ('20261001000001'); CREATE TABLE things (id INTEGER PRIMARY KEY)") }
    harness(engine: FakeEngine.new(databases: [ bare ])).call
    expect(out.string).to include("table things has no row after script/upgrade/seeds/0.2.1.rb")
  end

  it "names the migration and the release when the upgraded container exits before /up (AC-3.3)", :aggregate_failures do
    up = [ 200, 200, 0 ] # the previous boot, the pre-stop pages, then the upgraded container never answers
    pages["/up"] = ->(_user) { FakeWeb::Response.new(up.length > 1 ? up.shift : up.first, "") }
    states = [ { running: true, exit_code: 0 }, { running: false, exit_code: 1 } ]
    migrating = "== 20261002000001 CreateB: migrating =====\nSQLite3::ConstraintException: boom\n"
    engine = FakeEngine.new(databases:, state: ->(*) { states.shift }, logs: migrating)
    options.boot_attempts = 1
    expect(harness(engine:).call).to eq(1)
    expect(out.string).to include("v0.2.1", "20261002000001 CreateB", "boom")
  end

  it "fails naming the table and the first key when the upgrade loses a row (AC-4.2, AC-7.5)", :aggregate_failures do
    thin = seeded("thin", all_migrations, lots: 1999)
    expect(harness(engine: FakeEngine.new(databases: [ databases[0], thin, databases[2] ])).call).to eq(1)
    expect(out.string).to include("FAIL lots", "id = 2000", "fix it, or list the change")
    expect(out.string).to match(/previous: v0\.2\.1 .*sha256:abc123/)
    expect(out.string).to include("commit: #{Upgrade::Release.new(root).head}", "reproduce: bin/upgrade-smoke ghcr.io/plainprogrammer/collector:0.2.1 collector:smoke")
  end

  it "fails when a collector can't sign in with their old password (AC-5.1)", :aggregate_failures do
    web.sign_in_ok = false
    expect(harness.call).to eq(1)
    expect(out.string).to include("AC-5.1", "collector 1 of 2")
    expect(out.string).not_to include("ada@x.test")
  end

  it "fails when the upgraded database lacks a migration of the code under test (AC-3.2)", :aggregate_failures do
    unmigrated = seeded("unmigrated", old_migrations)
    expect(harness(engine: FakeEngine.new(databases: [ databases[0], unmigrated ])).call).to eq(1)
    expect(out.string).to include("AC-3.2", "20261002000001")
  end

  it "fails when the collector's own page lacks a card name, or shows it to another collector (AC-5.2)", :aggregate_failures do
    pages["/collection"] = ->(_user) { FakeWeb::Response.new(200, "Dragon One") }
    expect(harness.call).to eq(1)
    expect(out.string).to include("AC-5.2", "1 of the 2 seeded names")
    expect(out.string).not_to include("Dragon Two")
  end

  it "fails when a seeded location is not listed, and passes when it is (AC-5.4)", :aggregate_failures do
    facts = FakeEngine::FACTS.merge("locations" => [ "Binder A" ])
    pages["/locations"] = FakeWeb::Response.new(200, "Shelf B")
    expect(harness(engine: FakeEngine.new(databases:, facts:)).call).to eq(1)
    expect(out.string).to include("AC-5.4", "1 of the 1 seeded locations")
    expect(out.string).not_to include("Binder A")
  end

  it "fails when the export holds fewer lots than were seeded, or names a version it has no schema for (AC-5.5)", :aggregate_failures do
    pages["/collection/export"] = FakeWeb::Response.new(200, JSON.generate("format_version" => 2, "lots" => [ {} ]))
    expect(harness.call).to eq(1)
    expect(out.string).to include("AC-5.5", "holds 1 lots, the seed made 2001")
  end

  it "fails when the recurring tasks are not all registered, after waiting for them (AC-5.6)", :aggregate_failures do
    engine = FakeEngine.new(databases:, runner_answers: { /RecurringTask/ => FakeEngine::Result.new("false\n", "", 0) })
    expect(harness(engine:).call).to eq(1)
    expect(out.string).to include("AC-5.6")
    expect(engine.names.count(:runner)).to be > 30
  end

  it "fails when the seeded scheduled job isn't in the queue before the stop (AC-2.3)", :aggregate_failures do
    missing = FakeEngine.new(databases:, runner_answers: { /arguments LIKE/ => FakeEngine::Result.new("0\n", "", 0) })
    expect(harness(engine: missing).call).to eq(1)
    expect(out.string).to include("the seed's scheduled job")
  end

  it "fails when the scheduled job is gone from the queue after the upgrade (AC-5.7)", :aggregate_failures do
    counts = [ "1\n", "0\n" ] # before the stop, then after the upgrade
    gone = FakeEngine.new(databases:, runner_answers: { /arguments LIKE/ => -> { FakeEngine::Result.new(counts.shift || "0\n", "", 0) } })
    expect(harness(engine: gone).call).to eq(1)
    expect(out.string).to include("AC-5.7: the scheduled job upgrade-marker is no longer in the queue (found 0)")
  end

  it "fails when a job enqueued on the upgraded instance has no row in the queue database (AC-5.7)", :aggregate_failures do
    unrowed = FakeEngine.new(databases:, runner_answers: { /perform_later/ => FakeEngine::Result.new("false\n", "", 0) })
    expect(harness(engine: unrowed).call).to eq(1)
    expect(out.string).to include("has no row in solid_queue_jobs")
  end

  it "fails when the sign-up page differs after the upgrade (AC-5.3)", :aggregate_failures do
    shown = [ FakeWeb::Response.new(200, '<input name="user[email_address]">'), FakeWeb::Response.new(200, "closed") ]
    pages["/registration/new"] = ->(_user) { shown.length > 1 ? shown.shift : shown.first }
    expect(harness.call).to eq(1)
    expect(out.string).to include("AC-5.3")
  end

  it "fails the run when the check exceeds its time limit, printing the time (AC-7.4)", :aggregate_failures do
    options.timeout = 1
    engine = FakeEngine.new(databases:, start: ->(*, **) { sleep 3 })
    expect(harness(engine:).call).to eq(1)
    expect(out.string).to match(/exceeded 1 s \(elapsed \d+ s\)/)
  end

  it "reports an error of no expected kind with the same evidence lines (AC-7.5, Error Scenarios)", :aggregate_failures do
    broken = FakeEngine.new(databases:, runner: FakeEngine::Result.new("UPGRADE-SEED-COMPLETE {not json", "", 0))
    expect(harness(engine: broken).call).to eq(1)
    expect(out.string).to match(/^FAIL: .*JSON::ParserError/).and include("reproduce:")
  end

  it "removes every container, volume and the scratch directory on success and on failure (AC-7.3, FR-6)", :aggregate_failures do
    harness.call
    started = engine.calls.select { it.first == :start }.map { it[2][:name] }
    expect(engine.calls.select { it.first == :remove }.map { it[1].first }.uniq).to match_array(started)
    expect(engine.names).to include(:remove_volume, :remove_directory)
    failing = FakeEngine.new(databases: [ databases[0] ], runner: FakeEngine::Result.new("", "boom", 1))
    harness(engine: failing).call
    expect(failing.names).to include(:remove, :remove_volume, :remove_directory)
  end

  it "removes its temporary directory" do
    before = Dir.glob(File.join(Dir.tmpdir, "upgrade-smoke*"))
    harness.call
    expect(Dir.glob(File.join(Dir.tmpdir, "upgrade-smoke*"))).to eq(before)
  end

  describe ".parse" do
    it "reads the images and options (decision 2)", :aggregate_failures do
      previous, current, parsed = described_class.parse(%w[img:old img:new --previous-version 0.2.1 --timeout 90 --platform linux/arm64], env: { "SMOKE_BOOT_ATTEMPTS" => "7" })
      expect([ previous, current ]).to eq(%w[img:old img:new])
      expect(parsed.to_h).to include(previous_version: "0.2.1", timeout: 90, platform: "linux/arm64", boot_attempts: 7)
    end

    it "refuses a missing image" do
      expect { described_class.parse(%w[auto]) }.to raise_error(ArgumentError, /usage/)
    end
  end

  describe ".failed_migration" do
    it "names the last migration a log began" do
      log = "== 20261001000001 A: migrating ==\n== 20261002000001 CreateB: migrating ==\nboom\n"
      expect(described_class.failed_migration(log)).to eq("20261002000001 CreateB")
    end
  end
end
```

The happy-path example reads the call log that `FakeEngine` (each builder's name) and `FakeWeb` (`:get` for a page, `:sign_in`) share; the `/up` poll is not logged. The timeout example's `start` answer sleeps past the `Timeout.timeout` that the harness wraps its whole run in.

- [ ] Add `"spec/script/upgrade/harness_spec.rb"` and `"spec/script/upgrade/files_spec.rb"` (its "the image job" group memoizes six helpers) to the `Exclude` list of `RSpec/MultipleMemoizedHelpers` in `.rubocop.yml` (the scenario specs of spec 028 are there for the same reason: a checkout, databases, a fake engine and a fake web are the scenario).
- [ ] Run: `bin/rspec spec/script/upgrade/harness_spec.rb` — expect FAIL (`cannot load such file … harness`).
- [ ] Create `script/upgrade/harness.rb`:

```ruby
# The upgrade proof (spec 031): boots the previous release's image, seeds it through its own code, starts the image built
# from the code under test on the same volume, and fails unless the database upgraded unattended, lost nothing and the app
# serves the collection as it was. Orchestration only: the commands are Upgrade::Engine's, the reading of the databases is
# Upgrade::Snapshot and Upgrade::Compare, the rules Upgrade::ExpectedChanges and Upgrade::SeedExceptions.
require "fileutils"
require "json"
require "json_schemer"
require "optparse"
require "timeout"
require "tmpdir"
require_relative "release"
require_relative "snapshot"
require_relative "compare"
require_relative "rules"
require_relative "engine"
require_relative "web"

module Upgrade
  class Harness
    Failure = Class.new(StandardError)
    Options = Struct.new(:previous_version, :previous_ref, :timeout, :boot_attempts, :platform, :repository, keyword_init: true)
    Instance = Struct.new(:name, :port, :volume)

    REPOSITORY = "ghcr.io/plainprogrammer/collector".freeze
    PULL_ATTEMPTS = 3
    PERMANENT_PULL_FAILURE = /manifest unknown|not found|no matching manifest|unauthorized|denied|requested access|invalid reference/i
    SEED_LINE = "UPGRADE-SEED-COMPLETE ".freeze
    SECRET = "secret-of-the-previous-release-instance-0001".freeze
    RESTORE_SECRET = "a-different-secret-of-the-restored-instance-0002".freeze
    RECURRING = <<~'RUBY'.freeze
      require "yaml"
      expected = YAML.load_file(Rails.root.join("config/recurring.yml"), aliases: true).fetch("production").keys.sort
      puts SolidQueue::RecurringTask.pluck(:key).sort == expected
    RUBY
    ENQUEUE = <<~'RUBY'.freeze
      job = Catalog::RefreshJob.set(wait: 1.year).perform_later("mtg", "upgrade-enqueued")
      puts SolidQueue::Job.where(active_job_id: job.job_id).exists?
    RUBY

    def self.parse(argv, env: ENV)
      options = Options.new(timeout: 600, boot_attempts: Integer(env.fetch("SMOKE_BOOT_ATTEMPTS", 60)),
        repository: env.fetch("UPGRADE_IMAGE_REPOSITORY", REPOSITORY))
      rest = OptionParser.new do |parser|
        parser.on("--previous-version VERSION") { options.previous_version = it }
        parser.on("--previous-ref REF") { options.previous_ref = it }
        parser.on("--timeout SECONDS", Integer) { options.timeout = it }
        parser.on("--platform PLATFORM") { options.platform = it }
      end.parse(argv)
      raise ArgumentError, "usage: bin/upgrade-smoke <previous|auto> <current> [--previous-version X.Y.Z | --previous-ref REF] [--timeout SECONDS] [--platform P]" unless rest.size == 2

      [ rest.first, rest.last, options ]
    end

    # Rails prints "== 20261021100001 CreateLocations: migrating" before it runs a migration (AC-3.3).
    def self.failed_migration(log) = log.scan(/^==\s+(\d{14})\s+(\w+):\s+migrating/).last&.join(" ")

    def initialize(previous:, current:, release:, engine:, options:, web: Web.method(:new), out: $stdout, root: Dir.pwd, sleeper: Kernel.method(:sleep))
      @previous_arg = previous
      @current = current
      @release = release
      @engine = engine
      @options = options
      @web = web
      @out = out
      @root = root
      @sleeper = sleeper
      @tag = Process.pid
      @containers = []
      @volumes = []
      @step = "start"
    end

    def call
      @started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      Timeout.timeout(@options.timeout) { prove }
      0
    rescue Failure, Engine::Failure, Snapshot::Missing, Release::Error => error
      report_failure(error.message)
    rescue Timeout::Error
      report_failure("exceeded #{@options.timeout} s (elapsed #{elapsed} s)")
    rescue StandardError => error # an export or seed line that isn't JSON, a copy SQLite can't read: still AC-7.5's report, never a bare backtrace
      report_failure("#{error.class}: #{error.message}")
    ensure
      clean_up
    end

    private
      def prove
        return unless resolve

        find_seed_and_rules if @plan[:version] || !@plan[:release]
        fetch_previous
        find_seed_and_rules unless @seed
        @scratch = Dir.mktmpdir("upgrade-smoke")
        old = previous_database
        tables = upgrade(old)
        behaviour_after_upgrade
        backup_leg(old)
        next_release
        @out.puts "OK: #{@plan[:tag]} (#{@digest}) upgraded to #{@release.head[0, 12]}; #{tables} tables compared, behaviour verified, #{elapsed} s"
      end

      # -- steps ---------------------------------------------------------------------------------------------------

      def step(name)
        @step = name
        @out.puts "== #{name}"
      end

      def resolve
        step("resolve")
        @plan =
          if @previous_arg == "auto" then auto_plan
          elsif @options.previous_ref then ref_plan
          else { release: true, tag: nil, version: nil, ref: nil, image: @previous_arg, pull: false }
          end
        @plan&.tap { @out.puts "previous release: #{it[:tag] || "to be read from #{it[:image]}"}" }
      end

      def auto_plan
        version = @release.previous
        if version.nil?
          @out.puts "no previous release; nothing to upgrade from"
          return
        end
        { release: true, tag: version.tag, version: version.number, ref: version.tag, image: "#{@options.repository}:#{version.number}", pull: true }
      end

      def ref_plan
        ref = @options.previous_ref
        @out.puts "this run is not a release proof: #{@previous_arg} is the build of #{ref}; the seed is next.rb and its exceptions are the `next` ones"
        { release: false, tag: ref, version: nil, ref:, image: @previous_arg, pull: false }
      end

      def find_seed_and_rules
        step("seed and rules")
        name = @plan[:release] ? "#{@plan[:version]}.rb" : "next.rb"
        @seed = File.join(@root, "script/upgrade/seeds", name)
        unless File.file?(@seed)
          raise Failure, "no seed for #{@plan[:tag]}: expected script/upgrade/seeds/#{name}. Cutting a release creates it by renaming seeds/next.rb (docs/releasing.md, \"Cutting a release\")"
        end

        exceptions = SeedExceptions.load(File.join(@root, "script/upgrade/seed_exceptions.yml"), @plan[:release] ? @plan[:version] : "next")
        changes = ExpectedChanges.load(File.join(@root, "script/upgrade/expected_changes.yml"),
          previous_versions: @release.migration_versions(@plan[:ref]), current_versions: working_versions)
        problems = exceptions.errors + changes.errors
        raise Failure, "script/upgrade yml files: #{problems.join("; ")}" if problems.any?

        @exceptions = exceptions.entries
        @changes = changes
        changes.retired.each { @out.puts "retired: #{[ it.table, it.column ].compact.join(".")} #{it.kind} (migration #{it.migration} is in #{@plan[:tag]})" }
      end

      def fetch_previous
        step("pull")
        image = @plan[:image]
        pull(image) if @plan[:pull] || @engine.image_info(image).nil?
        info = @engine.image_info(image) || raise(Failure, "#{image} is not in the engine after pulling")
        labels = info.dig("Config", "Labels") || {}
        @digest = Array(info["RepoDigests"]).first || info["Id"]
        settle_version(labels) if @plan[:release] && @plan[:version].nil?
        @out.puts "previous: #{@plan[:tag]}  image #{image}  digest #{@digest}  version #{labels["org.opencontainers.image.version"] || "unknown"}  revision #{labels["org.opencontainers.image.revision"] || "unknown"}"
      end

      def pull(image)
        last = nil
        PULL_ATTEMPTS.times do |attempt|
          last = @engine.pull(image, platform: @options.platform)
          return if last.ok?
          break if last.err.match?(PERMANENT_PULL_FAILURE)

          @sleeper.call(5 * (attempt + 1)) if attempt < PULL_ATTEMPTS - 1
        end
        raise Failure, "can't pull #{image} (#{@plan[:tag] || "release unknown"}, #{@options.platform || "this platform"}) from #{image.split("/").first}: #{last.err.strip.lines.last.to_s.strip}"
      end

      def settle_version(labels)
        label = labels["org.opencontainers.image.version"].to_s
        flag = @options.previous_version
        version = flag || (label if label.match?(/\A\d+\.\d+\.\d+\z/))
        raise Failure, "the image's version label is #{label.inspect}, not a stable X.Y.Z; name the release with --previous-version X.Y.Z" unless version

        @out.puts "the image's label says #{label.inspect} and --previous-version says #{flag}; using #{flag}" if flag && label != flag
        @plan.merge!(version:, tag: "v#{version}", ref: "v#{version}")
      end

      def previous_database
        step("boot the previous release")
        @backups = File.join(@scratch, "backups")
        FileUtils.mkdir_p(@backups)
        @engine.own(@current, @backups)
        @volume = new_volume("a")
        instance = boot("previous", @plan[:image], @volume, SECRET, mounts: [ "#{@backups}:/backups" ])
        step("seed")
        @facts = run_seed(instance, @seed, where: @plan[:tag])
        step("before the stop")
        before_stop(instance)
        @backup_expected = backup_task?(instance)
        step("stop and snapshot the old database")
        stop_and_snapshot(instance, "old").tap { verify_old(it) }
      end

      def run_seed(instance, path, where:)
        result = @engine.runner(instance.name, File.read(path))
        line = result.out.lines.reverse.find { it.start_with?(SEED_LINE) }
        unless result.ok? && line
          raise Failure, "#{File.basename(path)} failed on #{where} (status #{result.status}):\n#{(result.out + result.err).lines.last(40).join}"
        end

        JSON.parse(line.delete_prefix(SEED_LINE))
      end

      def before_stop(instance)
        @before = pages(@web.call(instance.port))
        raise Failure, "the previous instance shows no sign-up form, so the seed's open sign-up isn't visible: #{@before.inspect}" unless @before[:sign_up].last

        queued = marker_count(instance)
        raise Failure, "the seed's scheduled job (#{@facts["marker"]}) isn't in the queue: found #{queued}" unless queued == 1
      end

      def pages(web)
        signup = web.get("/registration/new")
        { up: web.status("/up"), sign_in: web.status("/session/new"), sign_up: [ signup.status, Web.signup_form?(signup.body) ] }
      end

      def stop_and_snapshot(instance, label)
        @engine.stop(instance.name)
        code = @engine.state(instance.name)[:exit_code]
        unless [ 0, 143 ].include?(code)
          raise Failure, "#{instance.name} stopped with status #{code}, not 0 or 143 (#{code == 137 ? "it was killed at the end of the grace period" : "it did not stop cleanly"}); no database was compared"
        end

        copies = File.join(@scratch, "copies", label)
        FileUtils.mkdir_p(copies)
        @engine.copy_database(volume: instance.volume, image: @current, into: copies)
        Snapshot.open(Snapshot.consolidate(copies, "production.sqlite3", File.join(@scratch, "#{label}.sqlite3")))
      end

      def verify_old(db)
        expected = @release.migration_versions(@plan[:ref]).sort
        actual = db.execute("SELECT version FROM schema_migrations").flatten.sort
        unless expected == actual
          raise Failure, "AC-2.1: schema_migrations of the old database isn't the versions of db/migrate at #{@plan[:tag]} (missing #{expected - actual}, extra #{actual - expected}); #{@plan[:image]} didn't make it"
        end

        problems, notes = SeedExceptions.coverage(db, @exceptions, label: @plan[:version] || "next", seed: relative(@seed))
        notes.each { @out.puts it }
        raise Failure, problems.join("\n") if problems.any?

        problems = Compare.seed_problems(db)
        raise Failure, problems.join("\n") if problems.any?
      end

      def upgrade(old)
        step("upgrade")
        instance = boot("upgrade", @current, @volume, SECRET)
        step("snapshot and compare")
        upgraded = stop_and_snapshot(instance, "upgraded")
        @engine.remove(instance.name)
        compare(old, upgraded)
      end

      # Prints the comparison; returns how many tables it covered.
      def compare(old, upgraded, optional: [], emptied: [])
        report = Compare.new(old, upgraded, expected: @changes.live, optional:, emptied:).call
        report.to_lines.each { @out.puts it }
        raise Failure, "the upgraded database differs from the old one (see above)" unless report.ok?

        problems = Compare.integrity(upgraded)
        raise Failure, "AC-3.5: #{problems.first(3).join("; ")}" if problems.any?

        missing = (working_versions + @release.migration_versions(@plan[:ref])) - upgraded.execute("SELECT version FROM schema_migrations").flatten
        raise Failure, "AC-3.2: schema_migrations of the upgraded database lacks #{missing}" if missing.any?

        report.lines.size
      end

      def behaviour_after_upgrade
        step("behaviour")
        check_behaviour(boot("behaviour", @current, @volume, SECRET), queue: true)
      end

      def check_behaviour(instance, queue:)
        webs = @facts["users"].to_h do |user|
          web = @web.call(instance.port)
          raise Failure, "AC-5.1: #{who(user)} couldn't sign in with their old password" unless web.sign_in(user["email"], @facts["password"])

          [ user["email"], web ]
        end
        owner = @facts["users"].find { it["lots"].positive? }
        empty = @facts["users"].find { it["lots"].zero? }
        check_collections(webs, owner, empty)
        after = pages(@web.call(instance.port))
        raise Failure, "AC-5.3: #{@before.inspect} before the stop, #{after.inspect} after" unless after == @before

        check_locations(webs.fetch(owner["email"]))
        check_export(webs.fetch(owner["email"]), owner)
        check_recurring(instance)
        check_queue(instance) if queue
      end

      def check_collections(webs, owner, empty)
        listed = webs.fetch(owner["email"]).get("/collection").body
        missing = owner["names"].reject { listed.include?(it) }
        raise Failure, "AC-5.2: #{who(owner)}'s collection page doesn't list #{missing.size} of the #{owner["names"].size} seeded names (first: position #{owner["names"].index(missing.first) + 1})" if missing.any?

        other = webs.fetch(empty["email"]).get("/collection")
        leaked = owner["names"].select { other.body.include?(it) }
        raise Failure, "AC-5.2: #{who(empty)}'s collection page answered #{other.status} and shows #{leaked.size} of another collector's seeded names" if other.status != 200 || leaked.any?
      end

      def check_locations(web)
        return if @facts["locations"].empty?

        body = web.get("/locations").body
        missing = @facts["locations"].reject { body.include?(it) }
        raise Failure, "AC-5.4: the locations page doesn't list #{missing.size} of the #{@facts["locations"].size} seeded locations" if missing.any?
      end

      # Failures name a collector by position and give counts, never an email, card or location name (spec 031 NFR Security).
      def who(user) = "collector #{@facts["users"].index(user) + 1} of #{@facts["users"].size}"

      def check_export(web, owner)
        response = web.get("/collection/export")
        raise Failure, "AC-5.5: /collection/export answered #{response.status}" unless response.status == 200

        document = JSON.parse(response.body)
        schema = File.join(@root, "app/models/export_format/v#{document["format_version"]}.schema.json")
        raise Failure, "AC-5.5: the export names format_version #{document["format_version"].inspect}, which this checkout has no schema for" unless File.file?(schema)

        errors = JSONSchemer.schema(JSON.parse(File.read(schema))).validate(document).first(3).map { it["error"] }
        raise Failure, "AC-5.5: the export doesn't validate against #{File.basename(schema)}: #{errors.join("; ")}" if errors.any?
        raise Failure, "AC-5.5: the export holds #{document["lots"].size} lots, the seed made #{owner["lots"]}" unless document["lots"].size == owner["lots"]
      end

      def check_recurring(instance)
        state = nil
        30.times do
          state = @engine.runner(instance.name, RECURRING).out.lines.last.to_s.strip
          break if state == "true"

          @sleeper.call(2)
        end
        raise Failure, "AC-5.6: the production recurring tasks of config/recurring.yml aren't all registered (got #{state.inspect})" unless state == "true"
      end

      def check_queue(instance)
        count = marker_count(instance)
        raise Failure, "AC-5.7: the scheduled job #{@facts["marker"]} is no longer in the queue (found #{count})" unless count == 1

        queued = @engine.runner(instance.name, ENQUEUE).out.lines.last.to_s.strip
        raise Failure, "AC-5.7: a job enqueued on the upgraded instance has no row in solid_queue_jobs (got #{queued.inspect})" unless queued == "true"
      end

      def marker_count(instance)
        @engine.runner(instance.name, %(puts SolidQueue::Job.where("arguments LIKE ?", "%#{@facts["marker"]}%").count)).out.lines.last.to_s.strip.to_i
      end

      def backup_task?(instance) = @engine.tasks(instance.name).out.include?("backup:create")

      # Skipped only when the previous release lists no backup task; a release that has one and a leg that does not run
      # fails the run (AC-6.4). Phase 8 replaces the failing branch with the leg.
      def backup_leg(_old)
        step("backup leg")
        return @out.puts("previous release #{@plan[:tag]} has no backup task; backup leg skipped") unless @backup_expected

        raise Failure, "AC-6.4: #{@plan[:tag]} has a backup task and the backup leg did not run"
      end

      def next_release
        step("seed of the next release")
        seed = File.join(@root, "script/upgrade/seeds/next.rb")
        raise Failure, "script/upgrade/seeds/next.rb is missing; releasing renames it, so a new one must be added (docs/releasing.md)" unless File.file?(seed)

        instance = boot("next", @current, new_volume("next"), SECRET)
        run_seed(instance, seed, where: "the code under test")
        database = stop_and_snapshot(instance, "next")
        exceptions = SeedExceptions.load(File.join(@root, "script/upgrade/seed_exceptions.yml"), "next")
        raise Failure, exceptions.errors.join("; ") if exceptions.errors.any?

        problems, notes = SeedExceptions.coverage(database, exceptions.entries, label: "next", seed: "script/upgrade/seeds/next.rb")
        notes.each { @out.puts it }
        raise Failure, problems.join("\n") if problems.any?

        problems = Compare.seed_problems(database)
        raise Failure, problems.join("\n") if problems.any?
      end

      # -- containers ----------------------------------------------------------------------------------------------

      def new_volume(label)
        name = "upgrade-smoke-#{@tag}-#{label}"
        @volumes << name
        @engine.create_volume(name)
        name
      end

      def boot(label, image, volume, secret, mounts: [])
        name = "upgrade-smoke-#{@tag}-#{label}"
        @containers << name
        @engine.start(name:, volume:, secret:, image:, mounts:)
        Instance.new(name, @engine.port(name), volume).tap { wait_for_up(it, label) }
      end

      def wait_for_up(instance, label)
        web = @web.call(instance.port)
        @options.boot_attempts.times do
          return if web.status("/up") == 200
          raise Failure, boot_failure(instance, label) unless @engine.state(instance.name)[:running]

          @sleeper.call(2)
        end
        raise Failure, "#{label}: /up did not answer 200 within #{@options.boot_attempts * 2} s\n#{@engine.logs(instance.name).lines.last(60).join}"
      end

      def boot_failure(instance, label)
        logs = @engine.logs(instance.name)
        migration = self.class.failed_migration(logs)
        about = migration ? " The last migration it began was #{migration}, upgrading the database of #{@plan[:tag]}." : ""
        "#{label}: the container exited before /up answered.#{about}\n#{logs.lines.last(60).join}"
      end

      def clean_up
        @containers.each { quietly { @engine.remove(it) } }
        @volumes.each { quietly { @engine.remove_volume(it) } }
        return unless @scratch

        quietly { @engine.remove_directory(@current, @scratch) }
        FileUtils.rm_rf(@scratch)
      end

      def quietly
        yield
      rescue StandardError
        nil
      end

      # -- reporting -----------------------------------------------------------------------------------------------

      def report_failure(message)
        @out.puts "FAIL: #{@step}: #{message}"
        @out.puts "  previous: #{@plan&.dig(:tag) || "not resolved"} #{@digest}"
        @out.puts "  commit: #{@release.head}"
        @out.puts "  read: the lines above; the container's log is printed where a boot failed"
        @out.puts "  reproduce: #{reproduce}"
        1
      end

      def reproduce
        flags = []
        flags += [ "--previous-ref", @plan[:ref] ] if @plan && !@plan[:release]
        flags += [ "--platform", @options.platform ] if @options.platform
        "bin/upgrade-smoke #{[ @plan&.dig(:image) || @previous_arg, @current, *flags ].join(" ")}"
      end

      def elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - @started).round

      def working_versions = Dir[File.join(@root, "db/migrate/*.rb")].filter_map { File.basename(it)[/\A\d+/] }

      def relative(path) = path.delete_prefix("#{@root}/")
  end
end
```

(`backup_task?` reads the previous container's `bin/rails -T backup`; `backup_leg` is final for a release without the task, and for one with it fails until Phase 8 writes the leg, test first. `check_behaviour(…, queue:)` has its final signature now.)

- [ ] Create `bin/upgrade-smoke` (and `chmod +x bin/upgrade-smoke`):

```ruby
#!/usr/bin/env ruby
# Proves an upgrade from the previous release (spec 031): boots the previous release's published image, seeds it through its
# own code, starts the image built from this checkout on the same volume, and compares the two databases and what the app
# serves. Needs a container engine (docker, else podman; CONTAINER_CLI overrides), git, and Ruby with this bundle's gems.
#
#   bin/upgrade-smoke <previous|auto> <current> [--previous-version X.Y.Z | --previous-ref REF] [--timeout SECONDS]
#                     [--platform linux/arm64]
#
# `auto` finds the previous release from this checkout's tags and pulls its image (what the image job runs); an image
# reference is used as it is (a hand run). Exit status 0 means every check passed or there is no previous release.
require "bundler/setup"
require_relative "../script/upgrade/harness"

begin
  previous, current, options = Upgrade::Harness.parse(ARGV)
rescue ArgumentError, OptionParser::ParseError => error
  warn error.message
  exit 2
end

run_flags = options.platform ? [ "--platform", options.platform ] : []
release = Upgrade::Release.new(File.expand_path("..", __dir__))
engine = Upgrade::Engine.new(run_flags:)
exit Upgrade::Harness.new(previous:, current:, release:, engine:, options:, root: File.expand_path("..", __dir__)).call
```

- [ ] Extend `spec/script/upgrade/files_spec.rb` with the image hygiene examples:

```ruby
  it "keeps bin/upgrade-smoke out of the image, and the image smoke test checks it (FR-8)", :aggregate_failures do
    rules = Rails.root.join(".dockerignore").readlines(chomp: true).map(&:strip)
    expect(rules).to include("/bin/upgrade-smoke", "/script")
    expect(Rails.root.join("bin/image-smoke").read).to include("bin/upgrade-smoke")
  end

  it "is executable and starts with a Ruby shebang", :aggregate_failures do
    path = Rails.root.join("bin/upgrade-smoke")
    expect(path.executable?).to be(true)
    expect(path.readlines.first).to eq("#!/usr/bin/env ruby\n")
  end
```

- [ ] Edit `.dockerignore`: after `/bin/backup-smoke` add `/bin/upgrade-smoke`. Edit `bin/image-smoke`'s absent-path list: after `bin/backup-smoke` add `bin/upgrade-smoke` (the line reads `… lib/collector/ghcr_cleanup.rb bin/backup-smoke bin/upgrade-smoke; do`).
- [ ] Run: `bin/rspec spec/script/upgrade spec/image_publishing_spec.rb` — expect PASS. Trace of the three examples that depend on ordering: (1) the happy path's `databases` are handed out in call order: `copy_database` runs for the old snapshot, the upgraded snapshot and the `next` snapshot, which is the order of the fixtures; (2) the skip line is printed by the stub `backup_leg`, so `"skipped"` is in the output; (3) in the lost-row example the upgraded fixture has 1,999 lots, so the comparer reports `rows_removed` with the first key `id = 2000` (the last id, absent from the new table) and the run exits 1 before any behaviour check.
- [ ] Run: `bin/rubocop` — expect no offenses (the project's `RSpec/ExampleLength` is 15; the harness examples above are written to fit, and `RSpec/MultipleMemoizedHelpers` is excluded for `spec/script/upgrade/harness_spec.rb` in `.rubocop.yml`, with the other apply specs' reason: scenario specs).
- [ ] Commit: `feat: bin/upgrade-smoke proves an upgrade from the previous release (spec 031)`
- [ ] **First hand run (not part of `bin/ci`; needs the maintainer's machine with podman and network).** Build the image of this branch and run the proof against the real `v0.2.1`:

```sh
podman build -t collector:upgrade-dev .
time bin/upgrade-smoke auto collector:upgrade-dev
```

  Expect `OK: v0.2.1 (ghcr.io/plainprogrammer/collector@sha256:…) upgraded to <sha>; 19 tables compared, behaviour verified`. Confirm here, in this order, the assumptions of research.md section 6 that only a real engine settles (the pull's failure wording, the clean stop's exit status, `inspect --format`, rootless id mapping for the copy-out, the recurring-task wait), and fix `Engine` or the harness test-first for any that differs (a failing example that states the real behaviour, then the change). Record the command, the output, the per-step times (`== …` lines carry no times; use `time` and the printed total) and the result in `verification.md`. Run it a second time with `SMOKE_BOOT_ATTEMPTS=1` against a deliberately stopped registry (or with `UPGRADE_IMAGE_REPOSITORY=ghcr.io/plainprogrammer/does-not-exist`) to see AC-1.4's failure message in the engine's own words, and record it.

---

## Phase 8: The backup leg and the hand modes

**Implements:** decision 7, decision 2 (the hand run) | **Satisfies:** AC-6.1, AC-6.2, AC-6.3, AC-6.4, AC-6.5, AC-2.1's ref mode
**Files:** `script/upgrade/harness.rb`, `spec/script/upgrade/harness_spec.rb`
**Interfaces:** Consumes: Phases 6 and 7 (`Engine#task`, `#restore`, `#list_directory`; `ExpectedChanges.restore_effects`, `RESTORE_ENDS_SESSIONS`; `Harness#compare(..., optional:, emptied:)`, `#check_behaviour(..., queue: false)`). Produces: the leg in `Harness#backup_leg`, `#take_backup`, the `--previous-ref` and explicit-image plans' behaviour proved.

When the previous release lists `backup:create`, the previous instance takes a backup (while it runs, into the mounted `/backups`), and after the upgrade comparison the leg restores it with the code under test's image onto a fresh volume under another `SECRET_KEY_BASE` (as the README documents: a read-only host directory owned by uid 1000, `SECRET_KEY_BASE_DUMMY=1`), starts it, snapshots its database after a clean stop, compares it to the **old** snapshot with the restore's allowance (P4), and runs Story 5's checks except AC-5.7.

- [ ] Add to `spec/script/upgrade/harness_spec.rb` (inside the top-level group; the `seeded` helper gains an `extra:` SQL argument, `def seeded(name, versions, lots: 2000, extra: "")`, whose text is added to the batch after the `schema_migrations` inserts):

```ruby
  describe "the backup leg" do
    let(:listing) { FakeEngine::Result.new("rails backup:create[DIRECTORY]  # Back up\nrails backup:restore[FILE]  # Restore\n", "", 0) }
    let(:sessions) { "CREATE TABLE sessions (id INTEGER PRIMARY KEY); INSERT INTO sessions VALUES (1), (2);" }
    let(:ended) { "CREATE TABLE sessions (id INTEGER PRIMARY KEY);" }
    let(:leg_databases) { [ seeded("old2", old_migrations, extra: sessions), seeded("upgraded2", all_migrations, extra: sessions), seeded("restored", all_migrations, extra: ended), databases[2] ] }

    it "backs up with the previous release, restores with the code under test under another secret, and compares (AC-6.1, AC-6.2)", :aggregate_failures do
      engine = FakeEngine.new(databases: leg_databases, tasks: listing)
      expect(harness(engine:).call).to eq(0)
      expect(engine.calls.find { it.first == :task }[1]).to eq([ "upgrade-smoke-#{Process.pid}-previous", "backup:create[/backups]" ])
      restore = engine.calls.find { it.first == :restore }[2]
      expect(restore).to include(image: "collector:smoke", file: "collector-backup-1.tar.gz")
      secrets = engine.calls.select { it.first == :start }.map { it[2][:secret] }
      expect(secrets[1]).to eq(secrets[0])
      expect(secrets[3]).not_to eq(secrets[0])
      expect(out.string).to include("== backup leg").and match(/^sessions\s+old\s+2\s+new\s+0/)
    end

    it "runs Story 5's checks on the restored instance but not AC-5.7, which a primary-only backup can't satisfy (AC-6.2)" do
      engine = FakeEngine.new(databases: leg_databases, tasks: listing)
      harness(engine:).call
      expect(engine.calls.count { it.first == :runner && it[1].last.include?("perform_later") }).to eq(1)
    end

    it "fails when the sessions a restore ends are still there (P4)", :aggregate_failures do
      kept = seeded("kept", all_migrations, extra: sessions)
      expect(harness(engine: FakeEngine.new(databases: leg_databases.take(2) + [ kept ], tasks: listing)).call).to eq(1)
      expect(out.string).to include("sessions", "after the restore")
    end

    it "fails when the restore loses a row (AC-6.2)", :aggregate_failures do
      thin = seeded("thin", all_migrations, lots: 1999, extra: ended)
      expect(harness(engine: FakeEngine.new(databases: leg_databases.take(2) + [ thin ], tasks: listing)).call).to eq(1)
      expect(out.string).to include("FAIL lots", "id = 2000")
    end

    it "fails naming the refusal when the code under test refuses a backup the previous release took (AC-6.3)", :aggregate_failures do
      refusal = FakeEngine::Result.new("", "This backup was made by a newer Collector.\n", 1)
      expect(harness(engine: FakeEngine.new(databases: leg_databases, tasks: listing, restore: refusal)).call).to eq(1)
      expect(out.string).to include("AC-6.3", "newer Collector")
    end

    it "fails when the backup directory doesn't hold exactly one file (AC-6.1)", :aggregate_failures do
      expect(harness(engine: FakeEngine.new(databases: leg_databases, tasks: listing, list_directory: [])).call).to eq(1)
      expect(out.string).to include("exactly one file")
    end

    it "skips the leg with a printed line, and the exit status doesn't change, when the previous release has no backup task (AC-6.4)", :aggregate_failures do
      expect(harness.call).to eq(0)
      expect(out.string).to include("previous release v0.2.1 has no backup task; backup leg skipped")
      expect(engine.names).not_to include(:restore, :task)
    end
  end

  describe "the hand modes (decision 2, AC-6.5)" do
    it "treats an image of a commit as no release: reads the tree from the ref, runs next.rb, retires listed changes, says so", :aggregate_failures do
      options.previous_ref = "v0.2.1"
      File.write(File.join(root, "script/upgrade/expected_changes.yml"),
        "changes:\n  - table: lots\n    kind: rows_removed\n    migration: \"20261001000001\"\n    reason: \"Spec 99\"\n")
      expect(harness(previous: "ghcr.io/plainprogrammer/collector:edge").call).to eq(0)
      expect(out.string).to include("this run is not a release proof", "retired: lots rows_removed (migration 20261001000001 is in v0.2.1)")
      expect(engine.names).not_to include(:pull)
    end

    it "reads the release from the image's version label (decision 2)", :aggregate_failures do
      expect(harness(previous: "ghcr.io/plainprogrammer/collector:0.2.1").call).to eq(0)
      expect(out.string).to include("previous: v0.2.1")
    end

    it "asks for --previous-version when the label is not a stable version, and lets the flag win and say so", :aggregate_failures do
      info = { "RepoDigests" => [ "x@sha256:1" ], "Config" => { "Labels" => { "org.opencontainers.image.version" => "edge" } } }
      expect(harness(previous: "x:edge", engine: FakeEngine.new(image_info: info)).call).to eq(1)
      expect(out.string).to include("--previous-version X.Y.Z")
      out.truncate(0)
      out.rewind
      options.previous_version = "0.2.1"
      expect(harness(previous: "x:edge", engine: FakeEngine.new(databases:, image_info: info)).call).to eq(0)
      expect(out.string).to include("the image's label says \"edge\" and --previous-version says 0.2.1; using 0.2.1")
    end
  end
```

- [ ] Run: `bin/rspec spec/script/upgrade/harness_spec.rb` — expect FAIL (the leg raises `AC-6.4 … did not run`; `take_backup` and the restore are not there).
- [ ] In `script/upgrade/harness.rb`, in `previous_database`, after `@backup_expected = backup_task?(instance)` add `@backup_file = take_backup(instance) if @backup_expected`. Replace the Phase 7 `backup_leg` with the leg and add `take_backup`:

```ruby
      # Takes the backup while the previous instance runs, into the directory mounted at /backups (decision 7).
      def take_backup(instance)
        result = @engine.task(instance.name, "backup:create[/backups]")
        unless result.ok? && result.out.include?("Backup written: /backups/collector-backup-")
          raise Failure, "backup:create failed on #{@plan[:tag]}:\n#{(result.out + result.err).strip}"
        end

        files = @engine.list_directory(@current, @backups)
        raise Failure, "the backup directory should hold exactly one file; it holds: #{files.inspect}" unless files.size == 1

        files.first
      end

      # Skipped only when the previous release lists no backup task (AC-6.4). Otherwise the backup it took is restored by the
      # code under test onto a fresh volume under another secret, and the database is judged as the upgrade's is, except that
      # the sessions the restore ends are expected gone (P4) and AC-5.7 doesn't apply (the backup holds the primary only).
      def backup_leg(old)
        step("backup leg")
        return @out.puts("previous release #{@plan[:tag]} has no backup task; backup leg skipped") unless @backup_expected

        volume = new_volume("restored")
        result = @engine.restore(image: @current, volume:, directory: @backups, file: @backup_file)
        raise Failure, "AC-6.3: backup:restore refused the backup #{@plan[:tag]} took: #{(result.out + result.err).strip.lines.last}" unless result.ok?

        instance = boot("restored", @current, volume, RESTORE_SECRET)
        restored = stop_and_snapshot(instance, "restored")
        @engine.remove(instance.name)
        compare(old, restored, optional: ExpectedChanges.restore_effects, emptied: ExpectedChanges::RESTORE_ENDS_SESSIONS)
        check_behaviour(boot("restored-behaviour", @current, volume, RESTORE_SECRET), queue: false)
      end
```

  (`compare` reads `@changes.live` for the migrations' expected changes as the upgrade does, so a restored database is judged by the same listed changes.)
- [ ] Run: `bin/rspec spec/script/upgrade` — expect PASS. Trace of the examples that depend on order: (1) the containers start in the order previous, upgrade, behaviour, restored, restored-behaviour, next, so `secrets[1]` (the upgrade) equals the previous release's secret and `secrets[3]` (the restored one) is `RESTORE_SECRET`; `leg_databases` hands out old, upgraded, restored, next in the order `copy_database` is called. (2) The line `sessions old 2 new 0` comes from the leg's comparison, where the table's removal is expected and its emptiness required. (3) The explicit-image examples return 0 only if the seed `0.2.1.rb` exists in the fixture root, which `before` writes.
- [ ] Run: `bin/rubocop script/upgrade spec/script/upgrade` — expect no offenses.
- [ ] Commit: `feat: restore a backup the previous release took and judge it as the upgrade is (spec 031 decision 7)`
- [ ] **First backup-leg run, by hand (AC-6.5; the maintainer's machine, podman, network).** No release has `backup:create` yet, so use the build of the commit that merged spec 030 as the "previous" image and the build of this branch as the current one:

```sh
podman pull ghcr.io/plainprogrammer/collector:sha-4cd1ef5   # main's image after spec 030 (AC-6.5): has the backup tasks
podman build -t collector:upgrade-dev .
time bin/upgrade-smoke ghcr.io/plainprogrammer/collector:sha-4cd1ef5 collector:upgrade-dev --previous-ref 4cd1ef5
```

  If that tag is not in the registry (the run of `4cd1ef5` pushed nothing, or cleanup removed it), pull `edge` instead if its revision label is at or after `4cd1ef5`, and only then build it locally (`git worktree add ../collector-030 4cd1ef5`, `podman build -t collector:030 .` there, pass `collector:030`); AC-6.5 says an `edge` or `sha-` image of `main`, so record the deviation and why in `verification.md`.

  Expect: `this run is not a release proof`, `== backup leg` with its comparison (the four session tables `old n new 0`, every other table `same`), the behaviour checks on the restored instance, and `OK`. Record the commands, the full output and the timings in `verification.md`, and remove any worktree. From the first release that has the task the image job runs the leg itself.

---

## Phase 9: The workflow

**Implements:** decision 8, FR-6, FR-8 | **Satisfies:** AC-7.1, AC-7.2 (the job graph), AC-7.4 (the limits), AC-1.6, AC-8.5 (the image job's checkout)
**Files:** `.github/workflows/ci.yml`, `spec/script/upgrade/files_spec.rb`
**Interfaces:** Consumes: `bin/upgrade-smoke auto collector:smoke --platform <matrix.platform>`. Produces: the `image` job's two steps and its tag-fetching checkout.

- [ ] Extend `spec/script/upgrade/files_spec.rb`:

```ruby
  describe "the image job" do
    let(:image_job) { workflow.dig("jobs", "image") }
    let(:steps) { image_job["steps"] }
    let(:names) { steps.map { it["id"] || it["name"] } }
    let(:proof) { steps.find { it["run"].to_s.start_with?("bin/upgrade-smoke") } }
    let(:ruby) { steps.find { it["uses"].to_s.start_with?("ruby/setup-ruby") } }

    it "runs bin/upgrade-smoke for each architecture after the backup smoke test and before the push, on every event (AC-7.1)", :aggregate_failures do
      expect(proof["run"]).to eq("bin/upgrade-smoke auto collector:smoke --platform ${{ matrix.platform }}")
      expect(names.index(proof["name"])).to be_between(names.index("Backup smoke test"), names.index("push")).exclusive
      expect(proof).not_to have_key("if")
      expect(image_job.dig("strategy", "matrix", "include").size).to eq(2)
    end

    it "sets up the host Ruby for the comparer before it, outside the proof's own limit (decision 5, AC-7.4)", :aggregate_failures do
      expect(names.index(ruby["name"])).to be < names.index(proof["name"])
      expect(ruby["with"]).to include("bundler-cache" => true)
      expect(image_job.dig("env", "BUNDLE_WITHOUT")).to eq("development:test")
      expect(proof["timeout-minutes"]).to eq(12)
    end

    it "fetches the full history and the tags, because the proof resolves the previous release from them (AC-8.5)" do
      expect(checkout("image").dig("with", "fetch-depth")).to eq(0)
    end

    it "adds no secret, login or permission of its own, and can't be skipped past (AC-1.6, AC-7.2, FR-6)", :aggregate_failures do
      expect(proof.to_s).not_to include("secrets.")
      expect(proof).not_to have_key("continue-on-error")
      expect(image_job).not_to have_key("continue-on-error")
      expect(image_job["permissions"]).to eq("contents" => "read", "packages" => "write")
      expect(workflow.dig("jobs", "publish", "needs")).to eq("image")
    end
  end
```

- [ ] Run: `bin/rspec spec/script/upgrade/files_spec.rb` — expect FAIL (no proof step, no `fetch-depth` in the image job).
- [ ] Edit `.github/workflows/ci.yml`, `image` job: give it `BUNDLE_WITHOUT` at **job** level (a variable on the setup-ruby step alone is not persisted by `bundle install`, so the later `bin/upgrade-smoke` step's `bundler/setup` would resolve the development and test groups that were never installed and raise `Bundler::GemNotFound`; review plan-review.md M2), next to `strategy:`:

```yaml
    env:
      BUNDLE_WITHOUT: development:test
```

  and give its checkout the full history:

```yaml
      - name: Checkout code
        uses: actions/checkout@v7
        with:
          fetch-depth: 0
```

  and after the `Backup smoke test` step (before the comment on "Push by digest") add:

```yaml
      # Boots the previous release's published image, seeds it, starts this build on the same volume and compares the two
      # databases and what the app serves (spec 031). It runs before the image is pushed, so a release tag that can't upgrade
      # the last release publishes nothing. The comparer is Ruby on the runner, neither release's code (decision 5).
      - name: Set up Ruby for the upgrade proof
        uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true

      - name: Upgrade smoke test
        timeout-minutes: 12
        run: bin/upgrade-smoke auto collector:smoke --platform ${{ matrix.platform }}
```

- [ ] Run: `bin/rspec spec/script/upgrade/files_spec.rb spec/image_publishing_spec.rb` — expect PASS (the existing examples find steps by `id`/`name`/`run` and are unaffected by the new ones: `Smoke test` still lies between `build` and `push`).
- [ ] Run: `bin/ci` — expect green.
- [ ] Commit: `ci: prove an upgrade from the previous release before an image is pushed (spec 031 decision 8)`

> **Verification owed to the first CI run, not to a spec:** the arm64 bundle install and its cache (P10), the step's duration on each architecture, an anonymous pull on a pull request from the repository's own branch (a fork's is the same step with the same token-less pull). Phase 11 records them.

---

## Phase 10: The documents

**Implements:** decision 9 | **Satisfies:** AC-9.1, AC-9.2, AC-9.3; the roadmap line and the rule pointer of "Documents that change"
**Files:** `docs/architecture/release-and-deploy.md`, `docs/releasing.md`, `CLAUDE.md`, `.claude/rules/sqlite-and-migrations.md`, `docs/roadmap.md`, `bin/backup-smoke` (its header comment), `docs/specs/README.md`
**Interfaces:** Consumes: the names and commands of Phases 1 to 9. `origin/main` is merged into the branch (`71e3424`, with `docs/architecture/release-and-deploy.md` and `docs/architecture/data-portability.md`; merge it again first if `main` has moved). Produces: prose only, verified by reading (`.claude/rules/testing.md`: no RSpec on prose documents).

- [ ] `docs/releasing.md`, "Cutting a release". The existing step numbers stay (AC-9.1 and the upgrade notes cite them); the edits are:
  1. After step 1 ("Make sure `main` is green and contains everything the release needs.") add, indented under it:

```markdown
   **Prepare the upgrade proof for the release after this one (spec 031).** The proof compares each build with the previous release using that release's seed, `script/upgrade/seeds/<version>.rb`, so the seed for the release you are about to cut must exist under its version before you tag it. On `main`: `git mv script/upgrade/seeds/next.rb script/upgrade/seeds/0.3.0.rb` (the version you are cutting); rename the `next` key of `script/upgrade/seed_exceptions.yml` to `"0.3.0"`; add a new `script/upgrade/seeds/next.rb` (start from the file you renamed, and add what the following release will add) and a `next` key where it needs exceptions. The tagged commit's own run still uses the previous release's seed (it upgrades from the release before), and every later run applies the coverage rule to the new `next.rb`. Commit and push these before tagging.
```

  2. In step 3, after "Both `amd64` and `arm64` appear, with `linux`." add:

```markdown
   Also read the `Upgrade smoke test` step of both `Image` jobs in the same run: it booted the previous release's image, upgraded its seeded database with this build and compared the two, before anything was pushed. If it failed, nothing was published; fix the cause and cut the next patch (or pre-release) version, and never move, reuse or delete the failed tag by hand to get past it (a tag is published history; `docs/architecture/release-and-deploy.md`, Re-runs).
```

  3. Step 4 (the export restore) is unchanged. Replace step 5 with:

```markdown
5. Before announcing a release that changes the schema, the backup or the restore, restore the maintainer's own real backup onto the new image (spec 030 AC-5.7). CI already proves that a seeded database of the previous release upgrades on the new image and, once a release has the backup commands, that a backup it took restores on the next (spec 031); this step is only what no seed imitates, the shape and size of real data. Take a backup of the NAS instance on the previous release, restore it onto a fresh Compose project of the new image (`docs/backup-restore.md` and the README's "Backup and restore"), start it, sign in, and compare the printed counts and an export of each with the source's. Record the steps, counts and timings in the feature's `verification.md`.
```

  4. After step 6 add:

```markdown
7. After the tag, delete the entries of `script/upgrade/expected_changes.yml` whose migration the tag contains (the proof ignores them from now on and prints them as retired).
```

  5. In the sentence "that is procedure (step 2 below)" nothing changes: the tag is still step 2.
  6. Add to "Upgrade notes", first in the list:

```markdown
- **Upgrade proof (spec 031).** No migration, nothing required of the operator. CI now boots the previous release's published image, fills it through its own code, starts each build on that volume and fails unless the database upgraded unattended, lost nothing and the app served the collection as it was; a release tag whose build fails it publishes no image. `bin/ci` also fails when a released migration is edited, deleted or renamed. The proof's seeds, its list of expected changes and the release steps that keep them current are in "Cutting a release".
```

- [ ] `docs/architecture/release-and-deploy.md` (the area doc, on `main` since #130; `documentation.md`: a change to an area's behaviour updates its doc in the same pull request, each new statement with its source inline). Edit, in the doc's own sections and style:
  1. *Scope*, "Covers": add a line for the upgrade proof: `bin/upgrade-smoke`, `script/upgrade/` (the release resolution, the migration guard, the comparison, the seeds, the two yml files), and the workflow's Ruby setup and `Upgrade smoke test` steps (spec 031; #42). Backup and restore's line (spec 030) stays.
  2. *Invariants*, "The pipeline and the tags": (a) the guard is a `bin/ci` step (`ruby script/upgrade/guard.rb`, `config/ci.rb`) that fails when a released migration (one in the newest stable tag below the tag being built) is edited, deleted or renamed, and uses no engine (spec 031 FR-8, AC-8.1, AC-8.2, AC-8.4); (b) the `image` job proves an upgrade from the previous release's published image after `bin/backup-smoke` and before the push, on both architectures, on every event, so a tag whose build can't upgrade publishes nothing (spec 031 decision 8, AC-7.1); (c) the `image` job checks out the full history and the tags, and sets `BUNDLE_WITHOUT` at job level (spec 031 AC-8.5, decision 5; plan P10); the `ci` job's checkout is unchanged (the guard fetches its own tags).
  3. *Invariants*, "The image": `bin/upgrade-smoke` joins `bin/backup-smoke` in the paths the build context leaves out, and `bin/image-smoke`'s absent-path list gains it (spec 031 FR-7; the edits of Phase 7).
  4. *States and transitions*, the workflow-run table: the `image` column's "build, `bin/image-smoke`, `bin/backup-smoke`" gains `, `bin/upgrade-smoke`` in the pull-request row, and "same" in the others already carries it. "An upgrade": add that CI proves the one-release step (the previous release's published image, seeded through its own code, upgraded unattended by the build, nothing lost, the app serving the collection as it was; once a release has `backup:create`, the leg that restores its backup too) and where its limits are (spec 031 decisions 1, 4, 7; Non-Goals).
  5. *Named constants*: the proof's limits (the `Upgrade smoke test` step's `timeout-minutes: 12`, the harness's 600 s, the 5-minute addition target, the 30 s stop grace, 3 pull attempts, `SMOKE_BOOT_ATTEMPTS`), each with its definition (`ci.yml`, `script/upgrade/*.rb`) and spec source (decision 8, AC-7.4, AC-1.5, AC-2.4). Re-read every `ci.yml:NN` citation in the doc after Phases 2 and 9 and correct the shifted ones (`ci.yml:49`, `:75-76`, `:125`, `:156-157`, `:159-161`, `:58-61`, `:96-98`, `:109-110`, `:3-10`, `:9-10`, `:17`, `:151`, `:51-53`).
  6. *Decisions not in an ADR*: reword the `bin/backup-smoke` line (it no longer serves #42: the backup leg is in `bin/upgrade-smoke`, which restores the backup of its own seed; the option for a second image stays; plan P3); add the release procedure around the proof (the seed renamed to the release's version and `seed_exceptions.yml`'s `next` key renamed before the tag, the retired expected changes deleted after it, `docs/releasing.md` steps 1, 3, 5 and 7; spec 031 decision 9), the previous release as the newest stable tag below the tag being built (`auto`, P2), and that the proof's allowance in the backup leg is the four tables the restore empties (spec 031 1.1.2, decision 7).
  7. *Accepted limits and open issues*: one release step only (no chain from older releases); the old release's database is its own schema loaded by its own code, not a real instance's data; the hand restore of the maintainer's real backup (spec 030 AC-5.6, decision 9) stays manual; the proof's seed fills the catalog directly and so never exercises a refresh (the Monday 03:15 window is outside the proof); the deliberately failing tag (AC-7.2) is the maintainer's check, recorded in `verification.md`.
  8. *Sources*: add [Spec 031](../specs/031-upgrade-from-previous-release/spec.md): all, and issue [#42](https://github.com/plainprogrammer/Collector/issues/42); spec 030's *Sources* line says "all but decision 11": add "(its decision 14 and AC-5.7 are superseded in part by spec 031 decision 7)". *Distillation log*: add a row for this change (date of the merge, "Spec 031 (the upgrade proof, the migration guard, the release steps around them)", the pull request). *Neighbours*: no change (data portability has none of it: the seed holds no collector-owned data, spec 031 index row).
  9. Verify by reading that no statement of the doc is false after the change (the doc's own *Sources* rule), and that each added statement has its source inline.
- [ ] `CLAUDE.md` (on `main` it points to the area doc for release and deploy and does not restate it): (1) in "Project Status" add one sentence after the backup sentence: `CI proves an upgrade from the previous release's published image (\`bin/upgrade-smoke\`, \`script/upgrade/\`, spec 031, #42; [release and deploy](docs/architecture/release-and-deploy.md)).` (2) in "Commands", after "Backup smoke":

```markdown
- Upgrade smoke: `bin/upgrade-smoke <previous|auto> <current>` (spec 031): boots the previous release's published image, seeds it, starts a build on the same volume and compares the databases and what the app serves; CI runs it in the image job, before the push, on both architectures; it needs a container engine and a Ruby with the bundle, so it is not a `bin/ci` step. `ruby script/upgrade/guard.rb` is a `bin/ci` step.
```

  (3) in "Non-obvious Facts" do **not** add a rules bullet; extend the existing "Release and deploy" bullet's list by `, 031` in its spec list and ` the upgrade proof and its release steps` in what it lists, so the facts stay in the area doc (`documentation.md`: don't restate an area's rules in CLAUDE.md). The one thing an agent needs before opening the doc, a table or migration added to `main` can need `script/upgrade/seeds/next.rb` or an expected-changes entry to follow it, is in the doc's *Invariants*; add it there (item 2 above) with that sentence.
- [ ] `.claude/rules/sqlite-and-migrations.md`: on the line `- ✗ Never edit or delete a released migration — self-hosters may be on any prior version; add a new one.` append ` \`ruby script/upgrade/guard.rb\` (a \`bin/ci\` step) fails on it, and the upgrade proof (\`bin/upgrade-smoke\`, spec 031) fails on a migration that loses data.`
- [ ] `docs/roadmap.md`: item 7 becomes `7. [#42](https://github.com/plainprogrammer/Collector/issues/42) Prove an upgrade from the previous release in CI (supports the 1.0 test's third check). **Built <date>, done when its pull request merges:** [spec 031](specs/031-upgrade-from-previous-release/spec.md); this completes theme A.` (the form of item 9; `<date>` is the day the verification is written). Theme A's heading needs no change.
- [ ] `bin/backup-smoke`: in the header comment, replace `(issue #42 reuses this with the previous release as <image>)` with `(spec 031's backup leg does not use this: bin/upgrade-smoke restores the backup of its own seed)`. The option keeps working.
- [ ] `docs/specs/README.md`: spec 031's row has *Supersedes* and spec 030's row has *Superseded by* (AC-9.3). They were made with the draft and survived the merge of `main` (`71e3424`), which froze 030 (the *Superseded by* cell was put back on its Frozen row). Re-read both after any later merge. Point the 031 row's *Areas* cell at [release and deploy](../architecture/release-and-deploy.md) (it already names the area; add the link), and leave its status for the distillation step (`distill-feature`) to set, which also marks the row once the area doc above is written. The area doc is now written here, in this pull request, not by the distillation step alone.
- [ ] Verify by reading, against the criteria: AC-9.1 (the two renames before tagging, the proof's result read in the tag's run, the real-data restores kept for the releases that touch import, export, the schema, the backup or the restore, a line in the upgrade notes, and step 4's old upgrade wording gone while the export restore is unchanged), AC-9.2 (`bin/upgrade-smoke`, the seeds, the expected-changes file and the never-edited rule in the area doc and `CLAUDE.md`, each pointing to the spec), AC-9.3. Record in `verification.md`.
- [ ] Run: `bin/ci` — expect green.
- [ ] Commit: `docs: release steps and notes for the upgrade proof (spec 031 decision 9)`

---

## Phase 11: Integration verification

**Implements:** All FRs | **Satisfies:** All ACs (the evidence), AC-7.2, AC-7.4

- [ ] Run: `bin/ci` — expect green (RuboCop, Brakeman, bundler-audit, importmap audit, the migration guard, RSpec).
- [ ] Run the hand runs of Phases 7 and 8 again on the final code and keep their output.
- [ ] Open a draft pull request from the branch (CI runs only on pull requests and `main`). Read the first run: `ci` green; both `Image` jobs: `Set up Ruby for the upgrade proof` (time, cache hit or not) and `Upgrade smoke test` (time, printed table of 19 tables, `OK: v0.2.1`). Record in `verification.md` the two durations per architecture, their sum as "added to the job", and the 5-minute target met or missed (the maintainer rules if missed, decision 8). If the bar is missed, the first levers are `docker stop -t` (the stop grace), the Ruby setup's cache and the three seed boots; nothing else changes the proof.
- [ ] **The deliberately failing tag (AC-7.2) is the maintainer's.** A tag on the public repository is outward-facing and a wrongly passing run would publish an image, so the plan does not push it. The recipe: on a throwaway branch from this one add `db/migrate/20261201000001_delete_a_seeded_lot.rb` (`def up = execute("DELETE FROM lots WHERE id = (SELECT min(id) FROM lots)")` with an empty `down`), push the branch and open a **draft pull request** from it (a pushed branch alone runs nothing: `ci.yml` triggers on pull requests, pushes to `main` and release tags), check that the pull request's `ci` job passes and its `image` jobs fail only at `Upgrade smoke test`, then tag that commit (the tag's own run repeats both, and is the run to read) **`v0.2.2-throwaway.1`** (a pre-release of the version after `v0.2.1`, so that its previous release is `v0.2.1`; a tag below `0.2.1` would find none and pass). Confirm: the `Publish manifest list` job did not run and `ghcr.io/plainprogrammer/collector:0.2.2-throwaway.1` does not exist; then delete the tag locally and on the remote, and the branch. Spec 013's cleanup removes the orphaned untagged digest. Record the run URL and the outcome in `verification.md`.
- [ ] Write `verification.md` (a row per AC with its evidence: spec example or document location or run; a Measurements table with the hand-run and CI timings; the Owed list: AC-7.2's tag, the NAS restore of decision 9 (not owed by this spec), anything a first CI run showed).
- [ ] Run `sdd-superpowers:sdd-review` Mode B (implementation review); record it in `verification.md` under `## Implementation review` with the verdict on its first line, and fix its findings.
- [ ] At session end run `sdd-superpowers:session-wrap`, then `distill-feature` (the area doc, the index row, the plan's retirement after the merge).
- [ ] Commit: `docs(specs): verification of the upgrade proof (spec 031)`

---

## Quickstart Validation

On a machine with Ruby (the project's), git with the tags fetched, podman or docker, and network:

```sh
git fetch --tags
ruby script/upgrade/guard.rb                              # v0.2.1: its 14 migrations are unchanged
bin/rspec spec/script/upgrade                             # the comparer, the rules, the seed, the harness against its fakes
podman build -t collector:upgrade-dev .
bin/upgrade-smoke auto collector:upgrade-dev              # pulls ghcr.io/plainprogrammer/collector:0.2.1 and proves the upgrade
```

The last command prints `== resolve` through `== seed of the next release` and ends `OK: v0.2.1 (…@sha256:…) upgraded to <sha>; 19 tables compared, behaviour verified, <n> s`. To see a failure, edit a released migration (for example add a comment to `db/migrate/20261007100001_*.rb`) and run the guard: it names the file and says a new migration is the fix. To see the data check fail, add a migration that deletes a lot, build, and run the proof: it names `lots`, the first key, and says to fix the migration or list an expected change.

---

## Traceability

Every criterion, decision and requirement of spec 031 1.1.2, with the phase that delivers it and the test or document that proves it. *Spec* = an example in `spec/script/upgrade/`; *CI run* = the first run of the image job; *hand* = a hand run recorded in `verification.md`; *read* = verified by reading.

| Item | Phase | Proof |
|---|---|---|
| AC-1.1 stable tags in numeric order, pre-releases skipped | 1 | release_spec "#previous … newest stable tag", "Version orders by number" |
| AC-1.2 strictly older than the tag being built; none → "no previous release", no container, exit 0 | 1, 7 | release_spec "tag push", "nil for the first tag"; harness_spec "prints 'no previous release' and touches no container" |
| AC-1.3 exact tag, platform, digest and revision printed | 6, 7 | harness_spec "pulls the exact version tag for the platform and prints the digest"; engine_spec argv |
| AC-1.4 missing manifest or platform fails naming tag, platform, answer; no fallback | 7 | harness_spec "fails naming the tag and the platform, without a retry" |
| AC-1.5 three attempts with a wait; auth/404 not retried | 7 | harness_spec "tries a transient pull failure three times" and the AC-1.4 example |
| AC-1.6 fork PR: anonymous pull, no secret, no new permission | 9 | files_spec "adds no secret, login or permission of its own"; read of the workflow |
| AC-1.7 the one resolver, four cases | 1 | release_spec "#building (AC-1.7)" |
| AC-2.1 the old database holds exactly the previous release's migration versions | 7 | harness_spec "fails when the old database was not made by the previous release"; CI run |
| AC-2.2 seed run in the container prints a completion line | 5, 7 | seeds_spec "prints the completion line"; harness `run_seed`; hand |
| AC-2.3 accounts, lots, setting, catalog, one scheduled job, locations | 3, 5, 7 | compare_spec "reads the facts of AC-2.3"; seeds_spec "leaves what AC-2.3 asks for"; harness "scheduled job isn't in the queue before the stop" |
| AC-2.4 clean stop (0 or 143), copy with -wal/-shm, VACUUM INTO | 3, 6, 7 | snapshot_spec "folds in a write-ahead log"; engine_spec "copies out the main database file"; harness "killed at the end of the grace period" |
| AC-2.5 every table has a row except listed exceptions | 4, 7 | seed_exceptions_spec ".coverage"; harness "no rows from the seed" |
| AC-2.6 next.rb runs on the code under test and covers its tables | 4, 5, 7 | seeds_spec "fills every table db/schema.rb creates" (in `bin/ci`); harness `next_release`; CI run |
| AC-2.7 no seed → fails before booting, naming file and release step | 7 | harness_spec "fails before booting anything when the previous release has no seed" |
| AC-2.8 failing seed → fails with its error, no comparison | 7 | harness_spec "fails with the seed's error" |
| AC-2.9 order: upgrade boot, /up, stop, snapshot, compare, restart, behaviour | 7 | harness_spec "proves a clean upgrade, in AC-2.9's order" |
| AC-3.1 same volume, secret, settings; db:prepare unattended; /up | 6, 7 | engine_spec "starts a container the way an operator does"; hand; CI run |
| AC-3.2 schema_migrations holds every version | 7 | harness_spec "fails when the upgraded database lacks a migration" |
| AC-3.3 migration failure → container log, release and migration named | 7 | harness_spec "names the migration and the release when the upgraded container exits before /up" |
| AC-3.4 only db:prepare, no schema:load/reset/drop/setup | 6 | engine_spec "refuses a database task", "keeps every forbidden task name in one constant" |
| AC-3.5 integrity_check and foreign_key_check | 3, 7 | compare_spec "reports a foreign key violation"; harness `compare` |
| AC-4.1 table by table: same count and digest; one line per table | 3, 7 | compare_spec "passes identical databases and prints a line per table"; harness happy path |
| AC-4.2 missing/extra row, changed value, dropped column, dropped table | 3 | compare_spec the two AC-4.2 examples |
| AC-4.3 new column or table is no failure | 3 | compare_spec "ignores a column only the new table has" |
| AC-4.4 listed expected change passes, printed with its reason | 3, 4 | compare_spec "passes a difference an expected change lists"; expected_changes_spec "keeps an entry … as live" |
| AC-4.5 stale/incomplete/typo entries fail; retired entries ignored | 3, 4, 8 | compare_spec "fails a live expected change that matches nothing"; expected_changes_spec; harness "treats an image of a commit as no release" |
| AC-4.6 silent loss named, with the fix | 3 | compare_spec "says to fix the migration or list an expected change" |
| AC-4.7 ordering without an integer key; encoding tells 1 from '1', NULL from '' | 3 | compare_spec "orders a table without an integer primary key", "tells 1 from '1'" |
| AC-5.1 each seeded user signs in | 6, 7 | web_spec "signs in with the form's CSRF token"; harness "can't sign in" |
| AC-5.2 collection lists names; accounts isolated | 7 | harness "collector's own page lacks a card name" |
| AC-5.3 sign-up form before and after; /up and /session/new statuses | 6, 7 | web_spec "tells the sign-up form from the closed notice"; harness "sign-up page differs after the upgrade" |
| AC-5.4 locations listed | 7 | harness "seeded location is not listed" |
| AC-5.5 export valid against its version's schema, lot count | 7 | harness "export holds fewer lots" |
| AC-5.6 recurring tasks registered | 7 | harness "recurring tasks are not all registered" |
| AC-5.7 scheduled job still queued; new job gets a row | 7 | harness the two AC-5.7 examples |
| AC-6.1 backup with the previous release, restore with the code under test under another secret | 8 | harness "backs up with the previous release, restores with the code under test" |
| AC-6.2 compared and behaviour-checked, AC-5.7 not applied | 8 | harness "runs Story 5's checks on the restored instance but not AC-5.7", the P4 examples |
| AC-6.3 a refused backup fails naming the refusal | 8 | harness "fails naming the refusal" |
| AC-6.4 skipped with a line only when no backup task; task present and no leg fails | 7, 8 | harness "skips the leg with a printed line"; the Phase 7 guard branch |
| AC-6.5 first run by hand with a commit's image and `--previous-ref` | 8 | hand (Phase 8); harness "treats an image of a commit as no release" |
| AC-7.1 step between backup smoke and push, each architecture, every event | 9 | files_spec "runs bin/upgrade-smoke for each architecture" |
| AC-7.2 failing tag publishes nothing | 9, 11 | files_spec "can't be skipped past" (job graph); the maintainer's throwaway tag |
| AC-7.3 exits 0/non-zero, prints the steps, cleans up on every path | 7 | harness "removes every container, volume and the scratch directory"; "proves a clean upgrade" output |
| AC-7.4 10-minute failure point; first times recorded | 7, 9, 11 | harness "fails the run when the check exceeds its time limit"; files_spec `timeout-minutes`; hand and CI run in `verification.md` |
| AC-7.5 failure names tag, digest, commit, step, evidence, reproduction | 7 | harness "fails naming the table and the first key" |
| AC-7.6 the ci job pulls no image and needs no engine; runs the guard | 2 | files_spec "fetches the full history … in the ci job" |
| AC-8.1 guard compares db/migrate at the tag with the working tree | 2 | guard_spec "passes when every released migration is unchanged"; `bin/ci` |
| AC-8.2 edited/deleted/renamed named, with the fix | 2 | guard_spec the edit, delete and rename examples |
| AC-8.3 every command on the allowlist | 6 | engine_spec "builds only commands that a category accepts" (two examples), "starts a process only in engine.rb and release.rb" |
| AC-8.4 behind the release | 2 | guard_spec "behind the release" |
| AC-8.5 no stable tag or no remote → none; remote without tags → fetch; checkouts fetch tags | 1, 2, 9 | release_spec, guard_spec, files_spec (both checkouts) |
| AC-8.6 these specs need no engine, network or registry, and run in bin/ci | all | `spec/script/upgrade` uses fakes and loopback only; config/ci.rb runs bin/rspec |
| AC-9.1 releasing.md steps | 10 | read |
| AC-9.2 CLAUDE.md and the release-and-deploy area doc (on `main`, so written in this pull request) | 10 | read |
| AC-9.3 index rows both ways | 10 | read (made with the draft; kept through the merge of `main`, `71e3424`) |
| Decision 1 two layers | 2, 7, 9 | the guard in `bin/ci`; the proof in the image job |
| Decision 2 previous release | 1, 7 | Phase 1 and the hand modes |
| Decision 3 fail closed | 7 | the pull and none examples |
| Decision 4 real image, own seeds | 5, 7 | seeds; hand run |
| Decision 5 what "can upgrade" means | 3, 4, 7 | compare, snapshot, rules |
| Decision 6 expected changes and retirement | 4 | expected_changes_spec |
| Decision 7 the backup leg | 8 | harness "the backup leg" |
| Decision 8 before the push; time bars | 9, 11 | files_spec; times in `verification.md` |
| Decision 9 manual checks shrink | 10 | read |
| Decision 10 one spec, one pull request | all | this plan's single branch |
| FR-1 to FR-8 | 1, 6, 7, 9 | as the rows above; FR-6 cleanup in harness "removes every container"; FR-8 files_spec "keeps bin/upgrade-smoke out of the image" |
| NFR time | 7, 11 | measurements |
| NFR security | 6, 7, 9 | engine allowlist; no secret in the step; harness "fails when a collector can't sign in" (position, no email) |
| Error Scenarios: a log or database the snapshot cannot read; the harness cannot run; an unforeseen error | 7 | harness "reports an error of no expected kind with the same evidence lines"; guard_spec "fails with a message, not a backtrace, when the ref names no release" |
| 1.1.2 (the backup leg's four tables, FR-4, decisions 6 and 7, AC-6.2) | 3, 4, 8 | compare_spec "requires the tables of a restore to be emptied"; rules_spec "names every table the schema cascades from sessions"; harness "fails when the sessions a restore ends are still there" |
| NFR self-hosting: no migration, no setting | all | `git diff --stat db/ config/` empty except `config/ci.rb` |

**Gaps:** none. **Not provable by a suite, and owed:** AC-7.2's real tag (maintainer), the first CI run's times (Phase 11), the NAS restores (decision 9, not this spec's).
