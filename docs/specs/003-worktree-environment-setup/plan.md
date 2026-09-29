# Implementation Plan: Worktree Environment Setup

**Spec:** docs/specs/003-worktree-environment-setup/spec.md (Approved), research in `research.md`
**Decisions:** none beyond the spec (no ADR)
**Created:** 2026-09-29

## Context

Spec 003 makes `bin/setup` the single setup command for fresh clones, the main checkout, and every kind of linked worktree: plain `git worktree add`, `claude --worktree`, and local and remote Orca. It fixes which ignored files are copied (`config/master.key`, `tmp/local_secret.txt`) and which are regenerated (all databases, caches). It adds a versioned `post-checkout` hook so new worktrees set themselves up, and gives each worktree a stable dev-server port.

On disk, this plan is saved as `docs/specs/003-worktree-environment-setup/plan.md` (number 003, since 002 is in flight elsewhere).

Environment facts (checked):
- git 2.55.
- `bin/rails server` passes `:Port` to Puma only when `-p` or `ENV["PORT"]` is given (`railties server_command.rb:207`). Otherwise `config/puma.rb`'s `port` wins, so deriving the port in `puma.rb` works.
- `config.autoload_lib(ignore: %w[assets tasks])`, so `lib/collector/*.rb` maps to `Collector::*`, and `Collector` is already the app module.
- `.dockerignore` excludes `/.git/`, so the image has no git metadata.
- `bin/setup` must run before gems are guaranteed, so the new lib code uses only the Ruby stdlib (`open3`, `fileutils`, `zlib`).

## Global Constraints

- `bin/setup` stays the single, universal setup command; flags `--skip-server` and `--reset` keep today's meaning.
- Copy list = repo-root `.worktreeinclude`, literal gitignored paths only; copy only when the destination is absent; copied files mode 0600; never overwrite.
- Never copy, symlink, or share database, log, or pid files between checkouts.
- Automatic setup runs `bin/setup --skip-server` only in a linked worktree on a new checkout (null previous commit, branch flag 1). It exits 0 even when setup fails.
- Never replace an existing different `core.hooksPath`. Never replace Claude Code's own worktree creation.
- Port: main checkout 3000; a linked worktree gets 3001–3999, derived from its realpath; `PORT` always wins; outside development, `PORT` or 3000 with no git calls.
- Setup is serialized per worktree (lock on `tmp/setup.lock`).
- Specs: RSpec; tag Rails spec types only where applicable; `:aggregate_failures` for multi-expectation examples; no real network. New string-described specs are added to `RSpec/DescribeClass` excludes with a comment.
- Commits: Conventional Commits with the types in `docs/git-convention.md`, one per step (small incremental commits). RSpec is green at every commit.
- Branch: the current branch `plainprogrammer/chore-003-worktree-environment-setup` (created by Orca) does not match `docs/git-convention.md`'s pattern. At the start of sdd-execute, offer a rename to `chore/003-worktree-environment-setup`.

## Goal

`bin/setup`, a versioned `post-checkout` hook, `orca.yaml`, and `.worktreeinclude` together make any new Collector worktree ready to develop and test with no manual step, and each worktree's dev server runs on its own stable port.

---

## Phase 0: Repository contracts (config files)

**Implements:** FR-2 (copy list), FR-3 (Orca declaration), Story 2 ignore/lint | **Satisfies:** AC-2.2, AC-3.1
**Files:** `spec/project_config_spec.rb`, `.worktreeinclude`, `orca.yaml`, `.gitignore`, `.rubocop.yml`
**Interfaces:** Consumes: nothing. Produces: `.worktreeinclude` (read by `Collector::WorktreeSetup#included_paths` in Phase 2), `orca.yaml` `scripts.setup`, and the RuboCop exclusion for `.claude/worktrees/`.

Lock down the checked-in files that the external tools (git, Claude Code, Orca, RuboCop) read before any Ruby exists.

- [ ] Write `spec/project_config_spec.rb`:
  ```ruby
  require "rails_helper"
  require "open3"
  require "yaml"

  RSpec.describe "Worktree project configuration" do
    def git_ignored?(path)
      _out, status = Open3.capture2e("git", "check-ignore", "-q", "--no-index", path, chdir: Rails.root.to_s)
      status.success?
    end

    describe ".worktreeinclude" do
      let(:entries) do
        Rails.root.join(".worktreeinclude").readlines(chomp: true).map(&:strip).reject { |l| l.empty? || l.start_with?("#") }
      end

      it "lists exactly the secrets copied into new worktrees" do
        expect(entries).to eq(%w[config/master.key tmp/local_secret.txt])
      end

      it "contains only literal, gitignored paths", :aggregate_failures do
        entries.each do |entry|
          expect(entry).not_to match(/[*?\[\]!]/), "#{entry} must be a literal path (Orca rejects globs)"
          expect(git_ignored?(entry)).to be(true), "#{entry} must be gitignored"
        end
      end
    end

    describe "orca.yaml" do
      let(:setup_script) { YAML.load_file(Rails.root.join("orca.yaml")).dig("scripts", "setup") }

      it "runs bin/setup without starting a server or resetting data", :aggregate_failures do
        expect(setup_script).to include("bin/setup --skip-server")
        expect(setup_script).not_to include("--reset")
      end
    end

    describe "Claude Code worktree directory" do
      it "is ignored by git" do
        expect(git_ignored?(".claude/worktrees/example/Gemfile")).to be(true)
      end

      it "is excluded from RuboCop" do
        require "rubocop"
        config = RuboCop::ConfigStore.new.for_dir(Rails.root.to_s)
        expect(config.file_to_exclude?(Rails.root.join(".claude/worktrees/example/app/models/thing.rb").to_s)).to be(true)
      end
    end
  end
  ```
- [ ] Add `spec/project_config_spec.rb` to `RSpec/DescribeClass: Exclude` in `.rubocop.yml`, extending the existing comment: "…and the project-config spec checks repository files, not a class".
- [ ] Run `bin/rspec spec/project_config_spec.rb`. Expect FAIL: missing `.worktreeinclude` and `orca.yaml`, `.claude/worktrees` not ignored or excluded.
- [ ] Create `.worktreeinclude`:
  ```
  # Gitignored files copied from the main checkout into new worktrees (spec 003, FR-2).
  # Read by Claude Code, Orca, and bin/setup. Literal paths only: no globs or negation.
  config/master.key
  tmp/local_secret.txt
  ```
- [ ] Create `orca.yaml`:
  ```yaml
  # Orca per-worktree hooks (spec 003). Orca runs this in each new worktree.
  # bin/setup is idempotent and serialized, so running after git's post-checkout hook is safe.
  scripts:
    setup: |
      bin/setup --skip-server
  ```
- [ ] Append to `.gitignore`:
  ```
  # Claude Code worktrees (claude --worktree) live inside the repo.
  /.claude/worktrees/
  ```
- [ ] Add to `.rubocop.yml` after `plugins:`:
  ```yaml
  # Claude Code worktrees are separate checkouts nested in this directory; lint them there, not here.
  inherit_mode:
    merge:
      - Exclude
  AllCops:
    Exclude:
      - ".claude/worktrees/**/*"
  ```
- [ ] Run `bin/rspec spec/project_config_spec.rb`. Expect PASS. Then `bin/rubocop`: expect `no offenses detected`.
- [ ] Commit: `chore(setup): declare worktree copy list, Orca setup script, and ignore Claude worktrees`

---

## Phase 1: Per-checkout dev server port

**Implements:** FR-5 | **Satisfies:** AC-6.1, AC-6.2, AC-6.3, AC-6.4, AC-6.6
**Files:** `lib/collector/dev_port.rb`, `spec/lib/collector/dev_port_spec.rb`, `config/puma.rb`
**Interfaces:** Consumes: nothing. Produces: `Collector::DevPort.resolve(root:, env: ENV) -> Integer` and `Collector::DevPort.for_worktree(path) -> Integer`, used by `config/puma.rb` and `bin/setup` (Phase 4).

`.git` is a file in a linked worktree and a directory in a main checkout. Checking which one it is avoids shelling out to git during server boot.

- [ ] Write `spec/lib/collector/dev_port_spec.rb`:
  ```ruby
  require "rails_helper"
  require "tmpdir"

  RSpec.describe Collector::DevPort do
    around { |ex| Dir.mktmpdir { |dir| @dir = dir; ex.run } }

    let(:main_checkout) { File.join(@dir, "main").tap { |p| FileUtils.mkdir_p(File.join(p, ".git")) } }
    let(:linked_worktree) do
      File.join(@dir, "wt").tap { |p| FileUtils.mkdir_p(p); File.write(File.join(p, ".git"), "gitdir: /x\n") }
    end
    let(:dev) { { "RAILS_ENV" => "development" } }

    describe ".resolve" do
      it "uses 3000 in the main checkout" do
        expect(described_class.resolve(root: main_checkout, env: dev)).to eq(3000)
      end

      it "derives a stable port in 3001..3999 in a linked worktree", :aggregate_failures do
        port = described_class.resolve(root: linked_worktree, env: dev)
        expect(port).to be_between(3001, 3999)
        expect(described_class.resolve(root: linked_worktree, env: dev)).to eq(port)
        expect(port).to eq(described_class.for_worktree(File.realpath(linked_worktree)))
      end

      it "defaults to development when RAILS_ENV is unset" do
        expect(described_class.resolve(root: linked_worktree, env: {})).not_to eq(3000)
      end

      it "honours PORT everywhere", :aggregate_failures do
        expect(described_class.resolve(root: linked_worktree, env: dev.merge("PORT" => "4567"))).to eq(4567)
        expect(described_class.resolve(root: main_checkout, env: { "RAILS_ENV" => "production", "PORT" => "8080" })).to eq(8080)
      end

      it "uses 3000 outside development or without git metadata", :aggregate_failures do
        expect(described_class.resolve(root: linked_worktree, env: { "RAILS_ENV" => "production" })).to eq(3000)
        expect(described_class.resolve(root: linked_worktree, env: { "RAILS_ENV" => "test" })).to eq(3000)
        expect(described_class.resolve(root: @dir, env: dev)).to eq(3000)
      end
    end

    describe ".for_worktree" do
      it "is a pure, in-range function of the path", :aggregate_failures do
        paths = %w[/home/a/Collector/wt-1 /home/a/Collector/wt-2 /srv/orca/Collector/feature /tmp/x]
        ports = paths.map { |p| described_class.for_worktree(p) }
        expect(ports).to all(be_between(3001, 3999))
        expect(paths.map { |p| described_class.for_worktree(p) }).to eq(ports)
        expect(ports.uniq.size).to eq(paths.size)
      end
    end
  end
  ```
- [ ] Run `bin/rspec spec/lib/collector/dev_port_spec.rb`. Expect FAIL: `uninitialized constant Collector::DevPort`.
- [ ] Implement `lib/collector/dev_port.rb`:
  ```ruby
  require "zlib"

  module Collector
    # Dev server port per checkout (spec 003, FR-5): 3000 in the main checkout, a
    # stable 3001–3999 port in a linked worktree, PORT always wins. Stdlib only:
    # loaded by config/puma.rb and bin/setup before the app boots.
    module DevPort
      DEFAULT = 3000
      WORKTREE_RANGE = (3001..3999)

      module_function

      def resolve(root:, env: ENV)
        return Integer(env["PORT"]) if env["PORT"] && !env["PORT"].empty?
        return DEFAULT unless env.fetch("RAILS_ENV", "development") == "development"
        # A linked worktree's .git is a file pointing at the shared git dir.
        return DEFAULT unless File.file?(File.join(root, ".git"))

        for_worktree(File.realpath(root))
      end

      def for_worktree(path)
        WORKTREE_RANGE.first + (Zlib.crc32(path) % WORKTREE_RANGE.size)
      end
    end
  end
  ```
- [ ] Run `bin/rspec spec/lib/collector/dev_port_spec.rb`. Expect PASS. (If the four sample paths collide, choose other sample paths; the spec does not guarantee distinctness.)
- [ ] Edit `config/puma.rb`: replace `port ENV.fetch("PORT", 3000)` and its comment with:
  ```ruby
  # Port: PORT if set; otherwise 3000 in the main checkout and a stable per-worktree
  # port in linked git worktrees during development (spec 003). See lib/collector/dev_port.rb.
  require_relative "../lib/collector/dev_port"
  port Collector::DevPort.resolve(root: File.expand_path("..", __dir__))
  ```
- [ ] Run `bin/rails zeitwerk:check`. Expect `All is good!`. Run `bin/rspec`. Expect all green.
- [ ] Commit: `feat(setup): give each linked worktree a stable dev server port`

---

## Phase 2: Checkout detection and secret copying

**Implements:** FR-1, FR-2 | **Satisfies:** AC-1.2, AC-4.1 (warning), AC-4.2, AC-5.2, AC-5.7 (copy part)
**Files:** `lib/collector/worktree_setup.rb`, `spec/lib/collector/worktree_setup_spec.rb`, `spec/support/git_sandbox.rb`
**Interfaces:** Consumes: `.worktreeinclude` (Phase 0). Produces:
- `Collector::WorktreeSetup.new(root:, env: ENV, git: "git")`
- `#checkout_kind -> :main | :linked | :none`
- `#main_checkout -> String | nil`
- `#included_paths -> Array<String>`
- `#copy_included_files -> Array<String>` (messages)
- `GitSandbox` spec helpers: `git!(dir, *args)`, `new_repo(dir)`

Git decides the checkout kind. The Orca path only produces a notice when it disagrees.

- [ ] Write `spec/support/git_sandbox.rb`:
  ```ruby
  require "open3"

  # Throwaway git repositories for worktree specs (spec 003). Isolated from the
  # developer's git config and from any GIT_* variables of an enclosing hook.
  module GitSandbox
    ENV_OVERRIDES = {
      "GIT_CONFIG_GLOBAL" => File::NULL, "GIT_CONFIG_NOSYSTEM" => "1",
      "GIT_DIR" => nil, "GIT_WORK_TREE" => nil, "GIT_INDEX_FILE" => nil, "GIT_COMMON_DIR" => nil,
      "GIT_AUTHOR_NAME" => "Spec", "GIT_AUTHOR_EMAIL" => "spec@example.test",
      "GIT_COMMITTER_NAME" => "Spec", "GIT_COMMITTER_EMAIL" => "spec@example.test"
    }.freeze

    def git(dir, *args, env: {})
      Open3.capture3(ENV_OVERRIDES.merge(env), "git", *args, chdir: dir)
    end

    def git!(dir, *args, env: {})
      out, err, status = git(dir, *args, env: env)
      raise "git #{args.join(' ')} failed: #{err}" unless status.success?
      out
    end

    # A main checkout with a .gitignore and .worktreeinclude for the two secrets.
    def new_repo(dir, extra_files: {})
      FileUtils.mkdir_p(File.join(dir, "tmp"))
      files = {
        ".gitignore" => "/config/*.key\n/tmp/*\n!/tmp/.keep\n",
        ".worktreeinclude" => "config/master.key\ntmp/local_secret.txt\n",
        "tmp/.keep" => ""
      }.merge(extra_files)
      files.each do |path, body|
        FileUtils.mkdir_p(File.dirname(File.join(dir, path)))
        File.write(File.join(dir, path), body)
      end
      git!(dir, "init", "-q", "-b", "main")
      git!(dir, "add", ".")
      git!(dir, "commit", "-q", "-m", "init")
      dir
    end
  end

  RSpec.configure { |config| config.include GitSandbox, :git_sandbox }
  ```
- [ ] Write `spec/lib/collector/worktree_setup_spec.rb` (the copy and detection part):
  ```ruby
  require "rails_helper"
  require "tmpdir"

  RSpec.describe Collector::WorktreeSetup, :git_sandbox do
    around { |ex| Dir.mktmpdir { |dir| @dir = File.realpath(dir); ex.run } }

    let(:main) { new_repo(File.join(@dir, "main")) }
    let(:worktree) do
      path = File.join(@dir, "wt")
      git!(main, "worktree", "add", "-q", path, "-b", "feature")
      path
    end
    let(:env) { GitSandbox::ENV_OVERRIDES.reject { |_k, v| v.nil? } }

    def setup_for(root, extra_env = {}) = described_class.new(root: root, env: env.merge(extra_env))

    def write_secret(root, path, body)
      FileUtils.mkdir_p(File.dirname(File.join(root, path)))
      File.write(File.join(root, path), body)
      File.chmod(0o644, File.join(root, path))
    end

    describe "#checkout_kind" do
      it "detects main checkouts, linked worktrees, and non-git directories", :aggregate_failures do
        expect(setup_for(main).checkout_kind).to eq(:main)
        expect(setup_for(worktree).checkout_kind).to eq(:linked)
        expect(setup_for(@dir).checkout_kind).to eq(:none)
      end

      it "reports :none when git is unavailable" do
        expect(described_class.new(root: main, git: "definitely-not-git").checkout_kind).to eq(:none)
      end
    end

    describe "#main_checkout" do
      it "resolves the main checkout from a linked worktree" do
        expect(setup_for(worktree).main_checkout).to eq(main)
      end

      it "returns nil when the only other entry is a bare repository" do
        bare = File.join(@dir, "bare.git")
        git!(@dir, "clone", "-q", "--bare", main, bare)
        wt = File.join(@dir, "from-bare")
        git!(bare, "worktree", "add", "-q", wt, "-b", "x")
        expect(setup_for(wt).main_checkout).to be_nil
      end
    end

    describe "#included_paths" do
      it "reads literal entries from .worktreeinclude, skipping comments and blanks" do
        File.write(File.join(main, ".worktreeinclude"), "# c\n\nconfig/master.key\n")
        expect(setup_for(main).included_paths).to eq(%w[config/master.key])
      end
    end

    describe "#copy_included_files" do
      it "copies missing secrets from the main checkout with mode 0600", :aggregate_failures do
        write_secret(main, "config/master.key", "k" * 32)
        write_secret(main, "tmp/local_secret.txt", "s" * 128)
        messages = setup_for(worktree).copy_included_files

        %w[config/master.key tmp/local_secret.txt].each do |path|
          copied = File.join(worktree, path)
          expect(File.read(copied)).to eq(File.read(File.join(main, path)))
          expect(File.stat(copied).mode & 0o777).to eq(0o600)
        end
        expect(messages).to include(a_string_including("Copied config/master.key"))
      end

      it "never overwrites a file the worktree already has" do
        write_secret(main, "config/master.key", "main-key")
        write_secret(worktree, "config/master.key", "own-key")
        setup_for(worktree).copy_included_files
        expect(File.read(File.join(worktree, "config/master.key"))).to eq("own-key")
      end

      it "warns about a missing master key but not a missing local secret", :aggregate_failures do
        messages = setup_for(worktree).copy_included_files
        expect(messages.join("\n")).to include("config/master.key", "RAILS_MASTER_KEY")
        expect(messages.join("\n")).not_to include("local_secret")
        expect(File).not_to exist(File.join(worktree, "tmp/local_secret.txt"))
      end

      it "copies nothing in a main checkout and still warns about a missing key", :aggregate_failures do
        messages = setup_for(main).copy_included_files
        expect(messages.join("\n")).to include("config/master.key")
        expect(messages.join("\n")).not_to include("Copied")
      end

      it "skips copying with a notice outside git" do
        expect(setup_for(@dir).copy_included_files).to eq(["Not a git checkout; skipping file copy and worktree hooks."])
      end

      it "prefers git's main checkout and notes a disagreeing ORCA_ROOT_PATH", :aggregate_failures do
        write_secret(main, "config/master.key", "main-key")
        messages = setup_for(worktree, "ORCA_ROOT_PATH" => "/elsewhere").copy_included_files
        expect(File.read(File.join(worktree, "config/master.key"))).to eq("main-key")
        expect(messages).to include(a_string_including("ORCA_ROOT_PATH"))
      end

      it "skips copying with a notice when no main checkout can be found" do
        bare = File.join(@dir, "bare.git")
        git!(@dir, "clone", "-q", "--bare", main, bare)
        wt = File.join(@dir, "from-bare")
        git!(bare, "worktree", "add", "-q", wt, "-b", "x")
        expect(setup_for(wt).copy_included_files).to include(a_string_including("main checkout not found"))
      end
    end
  end
  ```
- [ ] Run `bin/rspec spec/lib/collector/worktree_setup_spec.rb`. Expect FAIL: `uninitialized constant Collector::WorktreeSetup`.
- [ ] Implement `lib/collector/worktree_setup.rb` (copy and detection only; Phase 3 adds hooks and lock):
  ```ruby
  require "fileutils"
  require "open3"

  module Collector
    # Worktree-aware parts of bin/setup (spec 003): detect the checkout kind, copy
    # the gitignored files listed in .worktreeinclude from the main checkout, enable
    # the versioned git hooks, and serialize concurrent setups. Stdlib only.
    class WorktreeSetup
      INCLUDE_LIST = ".worktreeinclude"
      # Missing from the main checkout without a warning: Rails regenerates it.
      REGENERATED_IF_MISSING = %w[tmp/local_secret.txt].freeze
      NOT_GIT = "Not a git checkout; skipping file copy and worktree hooks.".freeze

      attr_reader :root

      def initialize(root:, env: ENV, git: "git")
        @root = root
        @env = env
        @git = git
      end

      def checkout_kind
        @checkout_kind ||= begin
          git_dir, common_dir = git_output("rev-parse", "--path-format=absolute", "--git-dir", "--git-common-dir")&.lines(chomp: true)
          if common_dir.nil? then :none
          elsif git_dir == common_dir then :main
          else :linked
          end
        end
      end

      def main_checkout
        return root if checkout_kind == :main
        return unless checkout_kind == :linked

        first = git_output("worktree", "list", "--porcelain").to_s.split("\n\n").first.to_s.lines(chomp: true)
        return if first.include?("bare")

        first.find { |line| line.start_with?("worktree ") }&.delete_prefix("worktree ")
      end

      def included_paths
        list = File.join(root, INCLUDE_LIST)
        return [] unless File.file?(list)

        File.readlines(list, chomp: true).map(&:strip).reject { |line| line.empty? || line.start_with?("#") }
      end

      def copy_included_files
        return [ NOT_GIT ] if checkout_kind == :none

        messages = []
        source = main_checkout
        if checkout_kind == :linked
          messages << orca_root_notice(source)
          messages << "!! main checkout not found (bare repository?); skipping file copy." if source.nil?
        end

        included_paths.each do |path|
          destination = File.join(root, path)
          next if File.exist?(destination)

          origin = source && File.join(source, path)
          if checkout_kind == :linked && origin && File.file?(origin)
            copy_secret(origin, destination)
            messages << "Copied #{path} from #{source}"
          elsif !REGENERATED_IF_MISSING.include?(path)
            messages << missing_warning(path)
          end
        end
        messages.compact
      end

      private

      def git_output(*args)
        out, status = Open3.capture2(@git, *args, chdir: root, err: File::NULL)
        out if status.success?
      rescue SystemCallError
        nil
      end

      def copy_secret(origin, destination)
        FileUtils.mkdir_p(File.dirname(destination))
        partial = "#{destination}.#{Process.pid}.partial"
        File.open(partial, File::WRONLY | File::CREAT | File::EXCL, 0o600) { |f| f.write(File.binread(origin)) }
        File.chmod(0o600, partial)
        File.rename(partial, destination)
      ensure
        FileUtils.rm_f(partial) if partial
      end

      def missing_warning(path)
        hint = path == "config/master.key" ? " or set RAILS_MASTER_KEY" : ""
        "!! #{path} is missing. Credentials are unavailable until you copy it into #{root}/#{path}#{hint}."
      end

      def orca_root_notice(source)
        orca_root = @env["ORCA_ROOT_PATH"]
        return if orca_root.nil? || orca_root.empty? || source.nil?
        return if File.expand_path(orca_root) == source

        "Note: ORCA_ROOT_PATH (#{orca_root}) differs from git's main checkout (#{source}); using git's."
      end
    end
  end
  ```
- [ ] Run `bin/rspec spec/lib/collector/worktree_setup_spec.rb`. Expect PASS. Run `bin/rails zeitwerk:check`. Expect `All is good!`.
- [ ] Commit: `feat(setup): copy worktree secrets from the main checkout`

---

## Phase 3: Enabling the hooks path and serializing setup

**Implements:** FR-3 (enabling, serialization) | **Satisfies:** AC-3.3, AC-5.5, AC-5.6, AC-5.7 (hooks part)
**Files:** `lib/collector/worktree_setup.rb`, `spec/lib/collector/worktree_setup_spec.rb`
**Interfaces:** Consumes: Phase 2's `WorktreeSetup`. Produces:
- `#enable_worktree_hooks -> Array<String>`
- `#with_lock { ... }` (exclusive `flock` on `<root>/tmp/setup.lock`)
- constants `HOOKS_PATH = ".githooks"`, `LOCK_FILE = "tmp/setup.lock"`

`core.hooksPath` is relative (`.githooks`), so each worktree runs the hook versioned with the code it checks out. It is written with plain `git config`, which lands in the shared repository config and therefore applies to every worktree.

- [ ] Add these examples to `spec/lib/collector/worktree_setup_spec.rb`:
  ```ruby
    describe "#enable_worktree_hooks" do
      it "points core.hooksPath at the versioned hooks directory", :aggregate_failures do
        messages = setup_for(main).enable_worktree_hooks
        expect(git!(main, "config", "--get", "core.hooksPath").strip).to eq(".githooks")
        expect(messages).to include(a_string_including("Enabled automatic setup"))
        expect(setup_for(main).enable_worktree_hooks).to eq([])
      end

      it "leaves a different custom hooks path alone", :aggregate_failures do
        git!(main, "config", "core.hooksPath", ".husky")
        messages = setup_for(main).enable_worktree_hooks
        expect(git!(main, "config", "--get", "core.hooksPath").strip).to eq(".husky")
        expect(messages).to include(a_string_including("not enabled"))
      end

      it "lists active hooks that stop running", :aggregate_failures do
        hook = File.join(main, ".git/hooks/pre-commit")
        File.write(hook, "#!/bin/sh\n")
        File.chmod(0o755, hook)
        messages = setup_for(main).enable_worktree_hooks
        expect(messages).to include(a_string_including("pre-commit"))
        expect(messages.join).not_to include(".sample")
      end

      it "does nothing outside git" do
        expect(setup_for(@dir).enable_worktree_hooks).to eq([])
      end
    end

    describe "#with_lock" do
      it "holds an exclusive lock that a second setup waits for", :aggregate_failures do
        FileUtils.mkdir_p(File.join(main, "tmp"))
        events = Queue.new
        release = Queue.new
        first = Thread.new { setup_for(main).with_lock { events << :first_locked; release.pop; events << :first_done } }
        expect(events.pop).to eq(:first_locked)

        File.open(File.join(main, described_class::LOCK_FILE)) do |f|
          expect(f.flock(File::LOCK_EX | File::LOCK_NB)).to be(false)
        end

        second = Thread.new { setup_for(main).with_lock { events << :second_ran } }
        release << true
        [ first, second ].each(&:join)
        expect([ events.pop, events.pop ]).to eq(%i[first_done second_ran])
      end
    end
  ```
- [ ] Run `bin/rspec spec/lib/collector/worktree_setup_spec.rb`. Expect FAIL: `undefined method 'enable_worktree_hooks'`.
- [ ] Implement: add to `WorktreeSetup` (constants at the top, public methods above `private`):
  ```ruby
      HOOKS_PATH = ".githooks"
      LOCK_FILE = "tmp/setup.lock"

      def enable_worktree_hooks
        return [] if checkout_kind == :none

        current = git_output("config", "--get", "core.hooksPath").to_s.strip
        return [] if current == HOOKS_PATH
        unless current.empty?
          return [ "Note: core.hooksPath is already #{current}; automatic worktree setup was not enabled." ]
        end

        messages = []
        active = active_default_hooks
        messages << "Note: these hooks in .git/hooks stop running now: #{active.join(', ')}" if active.any?
        git_output("config", "core.hooksPath", HOOKS_PATH)
        messages << "Enabled automatic setup for new worktrees (core.hooksPath=#{HOOKS_PATH})."
      end

      def with_lock
        path = File.join(root, LOCK_FILE)
        FileUtils.mkdir_p(File.dirname(path))
        File.open(path, File::RDWR | File::CREAT, 0o644) do |lock|
          lock.flock(File::LOCK_EX)
          yield
        end
      end
  ```
  and add this private helper:
  ```ruby
      def active_default_hooks
        common = git_output("rev-parse", "--path-format=absolute", "--git-common-dir").to_s.strip
        Dir.glob(File.join(common, "hooks", "*"))
          .select { |f| File.file?(f) && File.executable?(f) && !f.end_with?(".sample") }
          .map { |f| File.basename(f) }.sort
      end
  ```
- [ ] Run `bin/rspec spec/lib/collector/worktree_setup_spec.rb`. Expect PASS.
- [ ] Commit: `feat(setup): enable versioned git hooks and serialize setup runs`

---

## Phase 4: `post-checkout` hook and `bin/setup` wiring

**Implements:** FR-3 (trigger), FR-4 | **Satisfies:** AC-1.1, AC-1.3, AC-1.4, AC-1.5, AC-1.6, AC-5.1, AC-5.3, AC-5.4, AC-5.8, AC-6.5
**Files:** `.githooks/post-checkout`, `spec/githooks/post_checkout_spec.rb`, `bin/setup`, `.rubocop.yml`
**Interfaces:** Consumes:
- `Collector::WorktreeSetup#with_lock`, `#checkout_kind`, `#copy_included_files`, `#enable_worktree_hooks` (Phases 2–3)
- `Collector::DevPort.resolve(root:)` (Phase 1)

Produces: the automatic trigger, and the final `bin/setup`.

The hook specs use a sandbox repo whose committed `bin/setup` is a stub that records its arguments. The real setup never runs, so the specs stay fast.

- [ ] Write `spec/githooks/post_checkout_spec.rb`:
  ```ruby
  require "rails_helper"
  require "tmpdir"

  RSpec.describe "post-checkout hook", :git_sandbox do
    around { |ex| Dir.mktmpdir { |dir| @dir = File.realpath(dir); ex.run } }

    let(:stub_setup) { "#!/bin/sh\necho \"$@\" > setup-ran.txt\nexit ${STUB_SETUP_EXIT:-0}\n" }
    let(:main) do
      new_repo(File.join(@dir, "main"), extra_files: {
        ".githooks/post-checkout" => Rails.root.join(".githooks/post-checkout").read,
        "bin/setup" => stub_setup
      }).tap do |repo|
        File.chmod(0o755, File.join(repo, ".githooks/post-checkout"), File.join(repo, "bin/setup"))
        git!(repo, "add", ".")
        git!(repo, "commit", "-q", "-m", "exec bits")
        git!(repo, "config", "core.hooksPath", ".githooks")
      end
    end

    def ran_setup?(dir) = File.exist?(File.join(dir, "setup-ran.txt"))

    it "runs bin/setup --skip-server in a new linked worktree" do
      wt = File.join(@dir, "wt")
      git!(main, "worktree", "add", "-q", wt, "-b", "feature")
      expect(File.read(File.join(wt, "setup-ran.txt")).strip).to eq("--skip-server")
    end

    it "does not run without the hooks path (setup never run in this clone)" do
      git!(main, "config", "--unset", "core.hooksPath")
      wt = File.join(@dir, "wt")
      git!(main, "worktree", "add", "-q", wt, "-b", "feature")
      expect(ran_setup?(wt)).to be(false)
    end

    it "does not run on branch switches", :aggregate_failures do
      git!(main, "switch", "-q", "-c", "other")
      expect(ran_setup?(main)).to be(false)

      wt = File.join(@dir, "wt")
      git!(main, "worktree", "add", "-q", wt, "-b", "feature")
      File.delete(File.join(wt, "setup-ran.txt"))
      git!(wt, "switch", "-q", "-c", "feature-2")
      expect(ran_setup?(wt)).to be(false)
    end

    it "does not run in the main checkout even with a new-checkout signature" do
      _out, _err, status = Open3.capture3(GitSandbox::ENV_OVERRIDES, ".githooks/post-checkout", "0" * 40, "HEAD", "1", chdir: main)
      expect([ status.success?, ran_setup?(main) ]).to eq([ true, false ])
    end

    it "keeps the worktree and exits 0 when setup fails", :aggregate_failures do
      wt = File.join(@dir, "wt")
      _out, err, status = git(main, "worktree", "add", "-q", wt, "-b", "feature", env: { "STUB_SETUP_EXIT" => "1" })
      expect(status.success?).to be(true)
      expect(Dir).to exist(wt)
      expect(err).to include("bin/setup")
    end
  end
  ```
- [ ] Add `spec/githooks/post_checkout_spec.rb` to `RSpec/DescribeClass: Exclude` in `.rubocop.yml`, with a comment ("the hook spec exercises a git hook script, not a class").
- [ ] Run `bin/rspec spec/githooks/post_checkout_spec.rb`. Expect FAIL: `.githooks/post-checkout` does not exist (`Errno::ENOENT`).
- [ ] Create `.githooks/post-checkout` (mode 0755, committed with its executable bit):
  ```sh
  #!/bin/sh
  # Automatic worktree setup (spec 003, FR-3). Enabled by bin/setup via
  # core.hooksPath=.githooks. Runs only for a brand-new linked worktree:
  # null previous commit ($1), branch checkout ($3 = 1), and git dir != common dir.
  # Never fails the checkout: a setup failure is reported and the worktree kept.

  case "$1" in *[!0]*) exit 0 ;; esac
  [ "$3" = "1" ] || exit 0

  git_dir=$(git rev-parse --path-format=absolute --git-dir 2>/dev/null) || exit 0
  common_dir=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || exit 0
  [ "$git_dir" != "$common_dir" ] || exit 0
  [ -x bin/setup ] || exit 0

  echo "== New worktree: running bin/setup --skip-server =="
  if ! bin/setup --skip-server; then
    echo "!! Automatic setup failed. Run bin/setup in $(pwd) to finish setting up this worktree." >&2
  fi
  exit 0
  ```
- [ ] Run `git update-index --chmod=+x .githooks/post-checkout` after `git add` (so the executable bit is committed), then `bin/rspec spec/githooks/post_checkout_spec.rb`. Expect PASS.
- [ ] Rewrite `bin/setup`:
  ```ruby
  #!/usr/bin/env ruby
  require "fileutils"
  require_relative "../lib/collector/dev_port"
  require_relative "../lib/collector/worktree_setup"

  APP_ROOT = File.expand_path("..", __dir__)

  def system!(*args)
    system(*args, exception: true)
  end

  FileUtils.chdir APP_ROOT do
    # This script is a way to set up or update your development environment automatically.
    # It is idempotent and works in a fresh clone, the main checkout, or any linked git
    # worktree (spec 003). Git's post-checkout hook and Orca run it with --skip-server.
    checkout = Collector::WorktreeSetup.new(root: APP_ROOT)

    # Serialize concurrent runs in this checkout (e.g. git's hook, then Orca's script).
    checkout.with_lock do
      puts "== Installing dependencies =="
      system("bundle check") || system!("bundle install")

      puts "\n== Configuring #{checkout.checkout_kind} checkout =="
      (checkout.copy_included_files + checkout.enable_worktree_hooks).each { |line| puts line }

      puts "\n== Preparing database =="
      system! "bin/rails db:prepare"
      system! "bin/rails db:reset" if ARGV.include?("--reset")
      system! "bin/rails db:test:prepare"

      puts "\n== Removing old logs and tempfiles =="
      system! "bin/rails log:clear tmp:clear"
    end

    puts "\n== Dev server URL: http://localhost:#{Collector::DevPort.resolve(root: APP_ROOT)} =="

    unless ARGV.include?("--skip-server")
      puts "\n== Starting development server =="
      STDOUT.flush # flush the output before exec(2) so that it displays
      exec "bin/dev"
    end
  end
  ```
  The lock block closes before `exec`, so the server never holds the setup lock.
- [ ] Run `bin/setup --skip-server` in this worktree. Expect exit 0. Output shows `Configuring linked checkout`, then `Copied config/master.key …` and `Copied tmp/local_secret.txt …`, `Enabled automatic setup…`, and `Dev server URL: http://localhost:3xxx`. Then `ls -l config/master.key tmp/local_secret.txt` shows `-rw-------`. Run `bin/setup --skip-server` again. Expect exit 0 and no `Copied` lines (AC-5.3).
- [ ] Run `bin/rspec` and `bin/rubocop`. Expect both green.
- [ ] Commit: `feat(setup): run bin/setup automatically in new git worktrees`

---

## Phase 5: Documentation

**Implements:** FR-6 | **Satisfies:** — (documentation requirement)
**Files:** `README.md`, `CLAUDE.md`

- [ ] In `README.md`, under `## Development`, add `### Worktrees`:
  ```markdown
  ### Worktrees

  `bin/setup` also prepares git worktrees. Run it once in your clone: it points
  `core.hooksPath` at `.githooks/`, and from then on every `git worktree add`
  (including `claude --worktree` and Orca worktrees) runs `bin/setup --skip-server`
  in the new worktree automatically. Orca also runs it through `orca.yaml`.

  Enabling this replaces the clone's default `.git/hooks/` directory; setup lists
  any hooks there that stop running, and leaves an existing custom `core.hooksPath` alone.

  - **Copied from the main checkout** (only if missing, mode 0600): the files in
    `.worktreeinclude`, namely `config/master.key` and `tmp/local_secret.txt`.
  - **Regenerated per worktree:** all development databases (primary, queue,
    cache, cable), the test database, caches, logs, and pids. Nothing is shared.
  - **Ports:** the main checkout serves on 3000. Each worktree gets a stable port
    in 3001–3999, printed by `bin/setup`. Set `PORT` to override, e.g. if two
    worktrees collide.
  - **Remote Orca runtimes** have no copy of your `config/master.key`. Setup warns
    and continues; dev and tests work without it. Copy the key there, or set
    `RAILS_MASTER_KEY`, if you need credentials.
  - If automatic setup fails, the worktree is kept. Run `bin/setup` in it.
  ```
- [ ] In `CLAUDE.md`:
  - Update the `Setup:` command bullet to: "`bin/setup` (idempotent; works in clones and worktrees, copies `.worktreeinclude` files from the main checkout, enables `.githooks/` auto-setup; starts the server afterwards, `--skip-server` to not)".
  - Add a Non-obvious Facts bullet: "**Worktrees:** `bin/setup` sets `core.hooksPath=.githooks`, so `git worktree add`, `claude --worktree` and Orca (`orca.yaml`) worktrees set themselves up. Each worktree has its own DBs; dev port is 3000 in the main checkout, 3001–3999 per worktree (`lib/collector/dev_port.rb`), `PORT` overrides. Copy list = `.worktreeinclude`."
- [ ] Commit: `docs(setup): document the worktree setup workflow`

---

## Phase 6: Integration verification

**Implements:** All FRs | **Satisfies:** All ACs (manual items from the spec's Verification section)

- [ ] `bin/ci`: expect all steps green (setup, RuboCop, Brakeman, bundler-audit, importmap audit, RSpec).
- [ ] Plain git (AC-1.1, AC-1.2, AC-1.4). From this worktree:
  - `git worktree add ../collector-verify-git -b verify/git-worktree`
  - Expect setup output and prompt return with no server.
  - In the new worktree: `bin/rspec`, expect exit 0; `ls -l config/master.key tmp/local_secret.txt`, expect `-rw-------`.
- [ ] Claude Code (AC-2.1): `claude --worktree verify-claude -p "run bin/rspec and report the exit code"`. Expect exit 0, and `.claude/worktrees/verify-claude/config/master.key` present.
- [ ] Local Orca (AC-3.2): create a worktree via Orca (`orca worktree create …` or the UI) and approve the `orca.yaml` trust prompt. Expect the setup-runner terminal to finish with exit 0, then `bin/rspec` passes there.
- [ ] Missing key (AC-4.1). There is no remote runtime, so simulate one: temporarily rename the main checkout's `config/master.key` (the user runs this; the file is read-denied for agents), add a worktree, and confirm the warning, exit 0, and a passing `bin/rspec`. Then restore the key.
- [ ] Fresh clone (AC-5.1, AC-5.4): `git clone <main> /tmp/…/collector-clone && cd … && bin/setup --skip-server`. Expect no `Copied` lines, `Enabled automatic setup…`, and exit 0.
- [ ] Port (AC-6.5): in a verify worktree, `bin/dev`. Expect Puma's `Listening on http://…:<port printed by bin/setup>`, and `curl -s -o /dev/null -w '%{http_code}' localhost:<port>/up` returns `200`.
- [ ] Clean up the verification worktrees with `git worktree remove` and `git branch -D` of the verify branches, after user confirmation.
- [ ] Record the manual checklist results in the PR description.

---

## Quickstart Validation

```sh
bin/setup --skip-server                 # once per clone: enables .githooks
git worktree add ../collector-try -b try/worktree   # prints setup output, no server
cd ../collector-try && bin/rspec        # green, own databases
bin/dev                                 # listens on the port bin/setup printed (3001–3999)
```

## Spec coverage

| FR | Phase |
|---|---|
| FR-1 | 2 |
| FR-2 | 0, 2 |
| FR-3 | 0, 3, 4 |
| FR-4 | 4 |
| FR-5 | 1 |
| FR-6 | 5 |

Every AC maps to a phase header above. The manual ACs are confirmed in Phase 6.

Pre-implementation gates:
- **Simplicity:** 3 components (`DevPort`, `WorktreeSetup`, the hook script) plus config files. No new gems, stdlib only.
- **Anti-abstraction:** git, `flock`, and Puma's `port` are used directly.
- **Integration-first:** Phase 0 locks the files that external tools read, before any Ruby.
