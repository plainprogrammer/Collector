# Implementation Plan: A YARD Comment Ratchet in `bin/ci checks`

**Spec:** docs/specs/056-yard-comment-ratchet/spec.md (v1.2.2, approved; OD1–OD6 ruled as recommended)
**Decisions:** none new (OD6: no ADR); relies on [ADR 0027](../../adr/0027-yard-for-api-documentation.md)
**Created:** 2026-11-09
**Revised:** 2026-11-09 after the Opus plan review (APPROVE WITH CHANGES; its two blocking findings and the should-fix items are folded in)

## Global Constraints

Copied from the spec; every phase includes them.

- **Judged files (decision 1, OD1):** Ruby files under `app/models/` (concerns included), `app/helpers/`, `app/*/concerns/`, `lib/` and `spec/support/`. Nothing else.
- **Commented (decision 2, OD2):** the object has summary text (text before the first tag). Tags alone don't count; `@param`/`@return` aren't required. A `(see Other#method)` comment counts when YARD resolves it to a scoped method that has a summary.
- **Judged objects (decision 3, OD3):** public classes, modules and methods (instance and class, `class << self`). Not judged: private/protected methods, constants, attribute methods, `initialize`, and what YARD doesn't register (`scope`, `define_method`, `delegate`, methods in `RSpec.configure` and shared-context blocks). `@api private` counts as commented; `@private` and `@!visibility private` don't (the latter makes YARD call the method private, which must not exempt it). An override needs its own summary. A `Struct.new` or `Data.define` held in a constant is a class and is judged.
- **Changed (decision 4, OD4):** a method is changed when it is new or the text of its extent (its comment through its `end`) differs from the base's; a class or module is changed when new (judged once, at its first definition, passing if any definition has a summary) or when an existing one has a definition's comment-or-opening text edited (one removed and one added); its members' text is not part of it. Comparison is of text, by qualified name; the working tree is compared with the base; untracked, not-ignored files count as added; ignored files are not seen.
- **Base (decision 5, OD5):** `git merge-base HEAD origin/main` whatever `HEAD` is. The check **fails** (never passes, never skips) when `origin/main` or a merge base is missing or the repository is shallow, naming `fetch-depth: 0` and `git fetch --unshallow`. The `checks` job keeps `fetch-depth: 0`.
- **Output (decision 6):** one line per offender, sorted by path then line, saying whether it was added or changed; a count; the rule's path; a statement that comment quality and staleness aren't checked. It never calls a comment stale or poor.
- **No** allowlist, baseline file, inline skip marker, ADR, new gem, or change to `.yardopts`, `bin/yard doc` or the site. At most 30 s added to `bin/ci checks`. Writes nothing into the checkout.
- **Repository rules:** conventional commits, one per step, ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; `bin/ci` passes before pushing; the suite checks no prose document (docs criteria are verified by reading, in `verification.md`); the new file is development tooling under `script/yard/`, outside `app/` and `lib/` (never loaded by the app, already left out of the image by `/script` in `.dockerignore`); core files name no collectible (the fixtures use `Widget`, `Gadget`).

---

## Goal

`ruby script/yard/comment_ratchet.rb`, a step of `bin/ci checks`, fails a branch that adds or changes a judged object with no summary, and passes everything the branch doesn't touch.

## Pre-Implementation Gates

- **Simplicity:** one new file (`script/yard/comment_ratchet.rb`) with three parts (`Git`, `Snapshot`, `Check`) and one spec file; no new dependency (YARD is already a development gem; `Ripper` and `Open3` are standard library). Pass.
- **Anti-abstraction:** YARD's registry is used directly; the only structures are two `Data` types (`Snapshot::Item`, `Check::Offender`) and the `Result`. Pass.
- **Integration-first:** the first phase writes the behavioural examples against a throwaway Git repository before any implementation; the CLI contract (exit status, output) is tested in Phase 3. Pass.

**Known limits (to record in `verification.md`, not hidden):** YARD attaches a comment with one blank line before the `def`, which the extent doesn't include, so removing such a comment goes unjudged; a method made public without an edit to its text (moved above `private`) is judged because it is no longer exempt in the base, and one moved between files of the same class is not judged; a file YARD skips on `ArgumentError` or `NotImplementedError` isn't caught by the `Ripper` check; an alias's extent is one line.

**Design in one paragraph.** The check never reads a diff. It lists the scoped files at the head (`git ls-files --cached --others --exclude-standard`, which skips ignored files and includes untracked ones) and at the base (`git ls-tree` at `git merge-base HEAD origin/main`), writes the base's blobs into a temporary directory (`git cat-file --batch`), and parses each set in memory with YARD into a `Snapshot`: for every public class, module and method, its qualified name, its first location, whether it has summary text, whether it's exempt, and the **text of each definition's extent**. "Added" is "the name isn't in the base's snapshot"; "changed" is "the extent text differs from the base's" (decision 4). Because it compares text by name, renames, moves, deletions next to a method and where git places a hunk can't matter. A file YARD can't parse that the branch changed fails the check (`Ripper.sexp` is nil).

Research done while planning (YARD 0.9.45, nothing committed): a comment of tags alone and `# @private` give an empty `docstring.to_s`; `# @api private` gives `tag(:api).text == "private"`; `(see X)` gives an empty docstring while X is unresolved and X's text once X is in the registry (the head registry holds every scoped file, so a `(see Parent#to_param)` of a commented in-scope parent counts, spec 056 v1.2.2); attribute methods have `attr_info`; `private def` gives visibility `:private`; a `# @!visibility private` directive also sets `:private` (YARD `register_docstring`), so `exempt?` must look at the raw comment (`docstring.all`); methods in `RSpec.configure` blocks aren't registered; a `Struct.new` or `Data.define` in a constant is registered as a class with its block's methods; `object.source` for a method is `def` through `end` (heredocs included).

---

## Phase 1: The pipeline, for added code

**Implements:** FR-1 (objects from YARD, working tree, untracked files, all offenders in one run), FR-2 (output) | **Satisfies:** AC-1.1, AC-1.2, AC-1.3, AC-1.4, AC-1.5 (module), AC-1.9, AC-1.10, AC-1.11, AC-1.12, AC-1.15, AC-2.1, AC-3.1, AC-3.2, AC-3.6; decisions 1, 2, 3
**Files:** `script/yard/comment_ratchet.rb` (new), `spec/script/yard/comment_ratchet_spec.rb` (new)
**Interfaces:** Consumes: nothing. Produces: `YardRatchet::Scope.include?(path)`; `YardRatchet::Git.new(root)` with `#base`, `#head_files`, `#base_files(base)`, `#export(base, paths, into)`; `YardRatchet::Snapshot.build(root, files)` returning `{ name => Snapshot::Item }`; `YardRatchet::Check.new(root: Dir.pwd, git: Git.new(root)).call` returning `Check::Result` (`#ok?`, `#lines`). In this phase `Check#change` only knows "added" (a name absent from the base) and the base is `origin/main`'s tip; Phases 2 and 3 replace those.

Builds the whole path from a Git repository to a failing or passing result, for new code: the scope, YARD's view of the objects, the exemptions, and the report. "Changed" and the merge base come later, each with its own failing examples first.

- [ ] **Step 1: write the spec file** `spec/script/yard/comment_ratchet_spec.rb`:

```ruby
require "rails_helper"
require "open3"
require "tmpdir"
require Rails.root.join("script/yard/comment_ratchet").to_s

# The check that new and changed public code carries a comment (spec 056). Each example builds a throwaway Git
# repository whose origin/main is the base, changes the working tree and runs the check on it. The CLI and the CI
# step are in the last examples; the pieces that need no repository are exercised through the same runs.
RSpec.describe YardRatchet::Check, :git_sandbox, type: :model do # rubocop:disable RSpec/SpecFilePathFormat -- the file is script/yard/comment_ratchet.rb
  let(:root) { Pathname(Dir.mktmpdir) }

  after { FileUtils.remove_entry(root) }

  # GitSandbox#git! isolates git from the developer's config and from an enclosing hook's GIT_* variables.
  def run_git(*args, dir: root) = git!(dir.to_s, *args)

  def write(path, body, dir: root)
    dir.join(path).dirname.mkpath
    dir.join(path).write(body)
  end

  def commit_all(message)
    run_git("add", "-A")
    run_git("commit", "-q", "-m", message)
  end

  # origin/main is the commit of `files`; a topic branch is checked out on it.
  def base_with(files)
    run_git("init", "-q", "-b", "main")
    files.each { |path, body| write(path, body) }
    commit_all("base")
    run_git("update-ref", "refs/remotes/origin/main", "HEAD")
    run_git("checkout", "-q", "-b", "topic")
  end

  def check = described_class.new(root:).call

  def widget
    <<~RUBY
      # Spins things.
      class Widget
        # Turns once.
        def turn = 1
      end
    RUBY
  end

  # `widget` with `code` added before the class's closing `end` (the class opens on line 2; its `end` is line 5).
  def widget_plus(code) = widget.sub(/^end\n\z/, "#{code}end\n")

  it "fails for an added public method with no comment, naming its file, line and name (AC-1.1, AC-3.1)", :aggregate_failures do
    base_with("app/models/widget.rb" => widget)
    write("app/models/widget.rb", widget_plus("\n  def spin = 2\n"))

    result = check

    expect(result).not_to be_ok
    expect(result.lines).to include("app/models/widget.rb:6: Widget#spin has no comment (added)")
  end

  it "passes once the method has a one-line comment (AC-1.2)" do
    base_with("app/models/widget.rb" => widget)
    write("app/models/widget.rb", widget_plus("\n  # Spins once.\n  def spin = 2\n"))

    expect(check).to be_ok
  end

  it "judges added class methods, including those inside class << self (AC-1.3)", :aggregate_failures do
    base_with("app/models/widget.rb" => widget)
    write("app/models/widget.rb", widget_plus("\n  def self.build = new\n\n  class << self\n    def make = new\n  end\n"))

    lines = check.lines

    expect(lines).to include("app/models/widget.rb:6: Widget.build has no comment (added)",
                             "app/models/widget.rb:9: Widget.make has no comment (added)")
  end

  it "judges an added class and an added module, and accepts a comment above the line that opens them (AC-1.4, AC-1.5)", :aggregate_failures do
    base_with("README.md" => "base")
    write("app/models/gadget.rb", "class Gadget\n  # Runs.\n  def run = 1\nend\n")
    write("app/models/gizmo.rb", "module Gizmo\n  # Runs.\n  def self.run = 1\nend\n")

    lines = check.lines

    expect(lines).to include(a_string_starting_with("app/models/gadget.rb:1: Gadget has no comment (added)"),
                             a_string_starting_with("app/models/gizmo.rb:1: Gizmo has no comment (added)"))

    write("app/models/gadget.rb", "# A gadget.\nclass Gadget\n  # Runs.\n  def run = 1\nend\n")
    write("app/models/gizmo.rb", "# A gizmo.\nmodule Gizmo\n  # Runs.\n  def self.run = 1\nend\n")

    expect(check).to be_ok
  end

  it "says, for a class inside a namespace, that a comment above the namespace documents the namespace and not the class (AC-3.1)", :aggregate_failures do
    base_with("README.md" => "base")
    write("lib/gadget.rb", "# Outer.\nmodule Outer\n  class Gadget\n  end\nend\n")
    write("lib/loose.rb", "class Loose\nend\n")

    lines = check.lines

    expect(lines).to include("lib/gadget.rb:3: Outer::Gadget has no comment (added); a comment above an enclosing namespace documents the namespace, not this one",
                             "lib/loose.rb:1: Loose has no comment (added)")
  end

  it "counts a comment of tags alone, `@private` or `@!visibility private` as no comment (AC-1.9, AC-1.10)", :aggregate_failures do
    base_with("README.md" => "base")
    write("lib/tags.rb", "# Tags.\nclass Tags\n  # @return [Integer]\n  def a = 1\n\n  # @private\n  def b = 1\n\n  # @!visibility private\n  def c = 1\nend\n")

    expect(check.lines).to include("lib/tags.rb:4: Tags#a has no comment (added)", "lib/tags.rb:7: Tags#b has no comment (added)",
                                   "lib/tags.rb:10: Tags#c has no comment (added)")
  end

  def exempt_source
    <<~RUBY
      # Everything in here is exempt.
      class Exempt
        LIMIT = 3
        attr_reader :size

        def initialize; end

        define_method(:dynamic) { 1 }
        scope :recent, -> { 1 }
        delegate :a, to: :b

        # @api private
        def helper = 1

        protected

        def guarded = 1

        private

        def hidden = 1
      end
    RUBY
  end

  it "doesn't judge `@api private` objects, non-public methods, constants, attributes, initialize or what YARD doesn't register (AC-1.10)" do
    base_with("README.md" => "base")
    write("lib/exempt.rb", exempt_source)
    write("spec/support/exempt_config.rb", "RSpec.configure do |config|\n  def in_block = 1\nend\n")

    expect(check).to be_ok
  end

  it "judges a Struct.new or Data.define held in a constant as a class (decision 3)", :aggregate_failures do
    base_with("README.md" => "base")
    write("lib/pairs.rb", "# Pairs.\nmodule Pairs\n  Pair = Struct.new(:a) do\n    def twice = a * 2\n  end\nend\n")

    expect(check.lines).to include(a_string_starting_with("lib/pairs.rb:3: Pairs::Pair has no comment (added)"),
                                   "lib/pairs.rb:4: Pairs::Pair#twice has no comment (added)")
  end

  it "judges an override on its own; a summary, or a (see …) to a commented method, counts (AC-1.15)", :aggregate_failures do
    base_with("lib/parent.rb" => "# Parent.\nclass Parent\n  # The id.\n  def to_param = 1\nend\n")
    write("app/models/child.rb", "# Child.\nclass Child < Parent\n  def to_param = 1\nend\n")

    expect(check.lines).to include("app/models/child.rb:3: Child#to_param has no comment (added)")

    write("app/models/child.rb", "# Child.\nclass Child < Parent\n  # The id as a string.\n  def to_param = 1\nend\n")

    expect(check).to be_ok

    write("app/models/child.rb", "# Child.\nclass Child < Parent\n  # (see Parent#to_param)\n  def to_param = 1\nend\n")

    expect(check).to be_ok
  end

  {
    "app/controllers/things_controller.rb" => false, "app/jobs/thing_job.rb" => false, "db/seeds.rb" => false,
    "config/thing.rb" => false, "script/thing.rb" => false, "spec/models/thing_spec.rb" => false,
    "app/models/thing.rb" => true, "app/models/concerns/thing.rb" => true, "app/helpers/thing.rb" => true,
    "app/controllers/concerns/thing.rb" => true, "lib/thing.rb" => true, "spec/support/thing.rb" => true
  }.each do |path, judged|
    it "#{judged ? 'judges' : 'ignores'} an uncommented public method in #{path} (AC-1.11)" do
      base_with("README.md" => "base")
      write(path, "# Thing.\nclass Thing\n  def go = 1\nend\n")

      expect(check.ok?).to eq(!judged)
    end
  end

  it "sees a new file that isn't tracked yet and never one that Git ignores (AC-1.12)", :aggregate_failures do
    base_with(".gitignore" => "lib/ignored.rb\n", "README.md" => "base")
    write("lib/ignored.rb", "# Ignored.\nclass Ignored\n  def go = 1\nend\n")
    write("lib/fresh.rb", "# Fresh.\nclass Fresh\n  def go = 1\nend\n")

    lines = check.lines

    expect(lines).to include("lib/fresh.rb:3: Fresh#go has no comment (added)")
    expect(lines.join("\n")).not_to include("lib/ignored.rb")
  end

  it "passes, and says it found no changed code, when the branch changes nothing (AC-2.1)", :aggregate_failures do
    base_with("lib/old.rb" => "class Old\n  def go = 1\nend\n")

    result = check

    expect(result).to be_ok
    expect(result.lines.first).to include("Found no added or changed public code")
  end

  it "prints one line per object in path then line order, a count, the rule's path and what isn't checked (AC-3.1, AC-3.2, AC-3.6)", :aggregate_failures do
    base_with("README.md" => "base")
    write("lib/b.rb", "# B.\nclass B\n  def z = 1\n  def a = 1\nend\n")
    write("app/models/a.rb", "# A.\nclass A\n  def go = 1\nend\n")

    lines = check.lines

    expect(lines.first(3)).to eq([ "app/models/a.rb:3: A#go has no comment (added)",
                                   "lib/b.rb:3: B#z has no comment (added)",
                                   "lib/b.rb:4: B#a has no comment (added)" ])
    expect(lines.join("\n")).to include("3 added or changed public objects without a comment",
                                        ".claude/rules/code-documentation.md", "is not checked here")
    expect(lines.join("\n")).not_to match(/is (stale|poor|vague)/)
  end
end
```

- [ ] **Step 2: run it, expect FAIL** (the file to require doesn't exist): `bin/rspec spec/script/yard/comment_ratchet_spec.rb` — expect: `LoadError: cannot load such file -- …/script/yard/comment_ratchet`.

- [ ] **Step 3: commit the failing spec** (tests first): `git add spec/script/yard/comment_ratchet_spec.rb` then `git commit -m "test(yard): examples for the comment ratchet on added code (spec 056)"` with the attribution line.

- [ ] **Step 4: implement** `script/yard/comment_ratchet.rb`:

```ruby
# Fails when a branch adds or changes public code that has no comment (spec 056, issue #264). ADR 0027 kept a
# coverage gate out of bin/ci because a gate on the total would demand comments written for their own sake, and said
# a later spec may add one; this looks only at what the branch changed, so the code a branch doesn't touch is never
# judged and the documentation grows as code is touched. It enforces the easiest part of
# .claude/rules/code-documentation.md (a summary on public classes, modules and methods in the reusable code);
# whether a comment is current, or says why, stays with reviews.
#
# It doesn't read a diff. It parses the judged files at the head (the working tree) and at the base (the merge base
# with origin/main) with YARD and compares each object's text by name, so a rename, a move, a deletion next to a
# method or the place Git puts a hunk can't matter. Run as `ruby script/yard/comment_ratchet.rb` from the repository
# root (the bin/ci step). Development tooling: outside app/ and lib/ (the app never loads it) and, under script/,
# outside the image.
return if defined?(YardRatchet)

require "bundler/setup" if $PROGRAM_NAME == __FILE__
require "fileutils"
require "open3"
require "pathname"
require "tmpdir"
require "yard"

module YardRatchet
  RULE = ".claude/rules/code-documentation.md".freeze

  # The files judged (spec 056 decision 1): the reusable code the rule lists.
  module Scope
    PATTERNS = [ %r{\Aapp/models/}, %r{\Aapp/helpers/}, %r{\Aapp/[^/]+/concerns/}, %r{\Alib/}, %r{\Aspec/support/} ].freeze

    def self.include?(path) = path.end_with?(".rb") && PATTERNS.any? { it.match?(path) }
  end

  # The base can't be determined: the check fails instead of passing where it can't see (decision 5).
  class Unseen < StandardError; end

  # The repository's side of the check: which files, and the base's blobs.
  class Git
    CLEARED = { "GIT_DIR" => nil, "GIT_WORK_TREE" => nil, "GIT_INDEX_FILE" => nil, "GIT_COMMON_DIR" => nil }.freeze

    def initialize(root) = @root = root.to_s

    # The commit the branch is compared with. Phase 3 replaces this with the merge base and its guards.
    def base = run("rev-parse", "refs/remotes/origin/main").strip

    # Judged files at the head: tracked or untracked, never ignored, and present on disk.
    def head_files
      run("ls-files", "-z", "--cached", "--others", "--exclude-standard").split("\0").uniq.sort
        .select { Scope.include?(it) && File.file?(File.join(@root, it)) }
    end

    # Judged files at the base.
    def base_files(base) = run("ls-tree", "-r", "-z", "--name-only", base).split("\0").select { Scope.include?(it) }.sort

    # Writes the base's version of each path under `into`, through one `git cat-file --batch`.
    def export(base, paths, into)
      Open3.popen3(CLEARED, "git", "cat-file", "--batch", chdir: @root) do |stdin, stdout, stderr, _thread|
        stdout.binmode
        paths.each do |path|
          stdin.puts("#{base}:#{path}")
          stdin.flush
          header = stdout.gets or raise Unseen, "git cat-file stopped: #{stderr.read}"
          size = Integer(header.split.last, exception: false) or raise Unseen, "#{path} is not in #{base}"
          target = File.join(into, path)
          FileUtils.mkdir_p(File.dirname(target))
          File.binwrite(target, stdout.read(size))
          stdout.read(1)
        end
      end
    end

    private

    def run(*args)
      out, err, status = Open3.capture3(CLEARED, "git", *args, chdir: @root)
      return out if status.success?

      raise Unseen, "git #{args.join(' ')} failed: #{err.strip}"
    end
  end

  # What YARD sees in a set of files: one Item per class, module and method, by qualified name.
  module Snapshot
    Item = Data.define(:name, :namespace, :nested, :file, :line, :commented, :exempt)

    # root: the directory the files are in; files: paths relative to it. Parses in memory (writes nothing). YARD's
    # registry is cleared before and after, and its logger's level is put back.
    def self.build(root, files)
      return {} if files.empty?

      root = Pathname(root)
      level = YARD::Logger.instance.level
      YARD::Logger.instance.level = YARD::Logger::FATAL
      YARD::Registry.clear
      YARD.parse(files.map { root.join(it).to_s })
      YARD::Registry.all(:class, :module, :method).each_with_object({}) do |object, items|
        items[object.path] = item(object, root) unless object.files.empty?
      end
    ensure
      YARD::Registry.clear
      YARD::Logger.instance.level = level if level
    end

    def self.item(object, root)
      Item.new(name: object.path, namespace: object.type != :method, nested: !object.namespace.root?,
               file: Pathname(object.file).relative_path_from(root).to_s, line: object.line,
               commented: !object.docstring.to_s.strip.empty?, exempt: exempt?(object))
    end
    private_class_method :item

    # Not judged (decision 3): non-public objects, `@api private`, attribute methods and `initialize`. A
    # `@!visibility private` directive makes YARD call a method private, but it is not an exemption: only the
    # `private` keyword is, and `@api private` is the mark.
    def self.exempt?(object)
      return true if object.tag(:api)&.text == "private"
      return true if object.visibility != :public && !object.docstring.all.match?(/^\s*@!visibility\s+private\b/)

      object.type == :method && (!object.attr_info.nil? || object.name == :initialize)
    end
    private_class_method :exempt?
  end

  # Compares the head with the base and reports the added or changed public objects that have no summary.
  class Check
    Result = Data.define(:ok, :lines) do
      def ok? = ok
    end
    Offender = Data.define(:file, :line, :name, :kind, :hint)

    NAMESPACE_HINT = "; a comment above an enclosing namespace documents the namespace, not this one".freeze

    def initialize(root: Dir.pwd, git: Git.new(root))
      @root = root.to_s
      @git = git
    end

    # @return [Result] ok when every added or changed judged object has a summary; lines is what to print.
    def call
      base = @git.base
      Dir.mktmpdir("yard-ratchet") do |tmp|
        before_files = @git.base_files(base)
        @git.export(base, before_files, tmp)
        head = Snapshot.build(@root, @git.head_files)
        before = Snapshot.build(tmp, before_files)
        report(base, *judge(head, before))
      end
    rescue Unseen => error
      Result.new(ok: false, lines: [ error.message ])
    end

    private

    # Phase 2 replaces this with the comparison of text.
    def change(_item, old) = old.nil? ? :added : nil

    def judge(head, before)
      checked = 0
      offenders = head.each_value.filter_map do |item|
        next if item.exempt

        kind = change(item, before[item.name])
        next unless kind

        checked += 1
        next if item.commented

        Offender.new(file: item.file, line: item.line, name: item.name, kind:, hint: item.namespace && item.nested)
      end
      [ offenders, checked ]
    end

    def none(base) = "Found no added or changed public code in scope (compared with #{base[0, 8]})."

    def report(base, offenders, checked)
      return Result.new(ok: true, lines: [ none(base) ]) if checked.zero?

      if offenders.empty?
        return Result.new(ok: true, lines: [ "#{checked} added or changed public #{checked == 1 ? 'object' : 'objects'}, all with a comment (compared with #{base[0, 8]})." ])
      end

      lines = offenders.sort_by { [ it.file, it.line, it.name ] }.map { describe(it) }
      noun = offenders.size == 1 ? "object" : "objects"
      lines << "#{offenders.size} added or changed public #{noun} without a comment (compared with #{base[0, 8]}). Add a one-line summary above each (#{RULE}); mark a helper that exists for one caller `@api private`."
      lines << "Only a missing summary is checked: whether a comment is current, or says why, is not checked here and stays with reviews."
      Result.new(ok: false, lines:)
    end

    def describe(offender)
      "#{offender.file}:#{offender.line}: #{offender.name} has no comment (#{offender.kind})#{NAMESPACE_HINT if offender.hint}"
    end
  end
end
```

- [ ] **Step 5: run, expect PASS:** `bin/rspec spec/script/yard/comment_ratchet_spec.rb` — expect `0 failures`. If YARD registers something the examples assume it doesn't (the `RSpec.configure` and `scope` exemptions, the `Struct.new` class), the example says which; fix the example's expectation to what YARD does and correct spec 056's decision 3 the same way (`sdd-spec-update`), never loosen the check.
- [ ] **Step 6: lint:** `bin/rubocop script/yard/comment_ratchet.rb spec/script/yard/comment_ratchet_spec.rb` — expect no offenses (add a justified `rubocop:disable` only where the existing script specs do the same).
- [ ] **Step 7: commit:** `feat(yard): comment ratchet for public code a branch adds (spec 056)`.

---

## Phase 2: Changed code

**Implements:** FR-1 (what "changed" is), decision 4 | **Satisfies:** AC-1.4 (class opening), AC-1.5 (opening edit), AC-1.6, AC-1.7, AC-1.8, AC-1.13, AC-1.14, AC-2.2, AC-2.3, AC-2.4, AC-2.6, AC-2.7, AC-2.8, AC-2.9
**Files:** `script/yard/comment_ratchet.rb`, `spec/script/yard/comment_ratchet_spec.rb`
**Interfaces:** Consumes: Phase 1's `Snapshot.build`, `Check#judge`. Produces: `Snapshot::Item#extents` (an array of strings, one per definition: the unbroken run of comment lines directly above the object through its `end`, or for a class or module its comment and opening line), and the real `Check#change(item, old)` returning `:added`, `:changed` or `nil`.

Makes "changed" a comparison of text. The examples are written first and fail because Phase 1 only knows "added".

- [ ] **Step 1: add these examples** at the end of the `RSpec.describe` block in the spec file (before its final `end`), with the fixtures they use:

```ruby
  # Lines: 1 comment, 2 class, 3 def spin, 4-6 body, 7 end, 9 comment, 10 def turn, 11 body, 12 end, 14 def idle.
  def gadget
    <<~RUBY
      # A gadget.
      class Gadget
        def spin
          a = 1
          b = 2
          a + b
        end

        # Turns.
        def turn
          1
        end

        def idle = 0
      end
    RUBY
  end
  def bare = gadget.sub("# A gadget.\n", "")

  def trio
    <<~RUBY
      # Trio.
      class Trio
        def a
          1
        end

        def b
          1
        end

        def c
          1
        end
      end
    RUBY
  end

  def offences(result) = result.lines.grep(/ has no comment \(/)

  describe "what counts as changed" do
    it "judges an uncommented method whose body the branch edits, and not one whose comment stays (AC-1.6)", :aggregate_failures do
      base_with("app/models/gadget.rb" => gadget)
      write("app/models/gadget.rb", gadget.sub("a = 1", "a = 3"))

      expect(offences(check)).to eq([ "app/models/gadget.rb:3: Gadget#spin has no comment (changed)" ])

      write("app/models/gadget.rb", gadget.sub("def turn\n    1", "def turn\n    2"))

      expect(check).to be_ok
    end

    it "judges a method the branch only removes lines from (AC-1.7)" do
      base_with("app/models/gadget.rb" => gadget)
      write("app/models/gadget.rb", gadget.sub("    b = 2\n", ""))

      expect(offences(check)).to eq([ "app/models/gadget.rb:3: Gadget#spin has no comment (changed)" ])
    end

    it "judges a method the branch only reformats (AC-2.6)" do
      base_with("app/models/gadget.rb" => gadget)
      write("app/models/gadget.rb", gadget.sub("a = 1", "a=1"))

      expect(offences(check)).to eq([ "app/models/gadget.rb:3: Gadget#spin has no comment (changed)" ])
    end

    it "doesn't change an uncommented class when only one of its methods is edited (AC-1.8)" do
      base_with("app/models/gadget.rb" => bare)
      write("app/models/gadget.rb", bare.sub("def turn\n    1", "def turn\n    2"))

      expect(check).to be_ok
    end

    it "changes a class when its opening line is edited (AC-1.5)", :aggregate_failures do
      base_with("app/models/gadget.rb" => bare)
      write("app/models/gadget.rb", bare.sub("class Gadget", "class Gadget < Base"))

      expect(offences(check)).to contain_exactly(a_string_starting_with("app/models/gadget.rb:1: Gadget has no comment (changed)"))
    end

    it "judges only the inner class's method when a method of a nested class is edited (AC-1.14)" do
      base_with("lib/outer.rb" => "class Outer\n  class Inner\n    def run = 1\n  end\nend\n")
      write("lib/outer.rb", "class Outer\n  class Inner\n    def run = 2\n  end\nend\n")

      expect(offences(check)).to eq([ "lib/outer.rb:3: Outer::Inner#run has no comment (changed)" ])
    end

    it "ignores the uncommented methods of a file whose commented method is the only one edited (AC-2.2)" do
      base_with("app/models/gadget.rb" => gadget)
      write("app/models/gadget.rb", gadget.sub("def turn\n    1", "def turn\n    2"))

      expect(check.lines.join("\n")).not_to match(/spin|idle/)
    end

    it "passes a file renamed with no edit, and judges only the edited method of a renamed and edited one (AC-2.3)", :aggregate_failures do
      base_with("app/models/gadget.rb" => gadget)
      run_git("mv", "app/models/gadget.rb", "app/models/gizmo.rb")

      expect(check).to be_ok

      write("app/models/gizmo.rb", gadget.sub("def idle = 0", "def idle = 5"))

      expect(offences(check)).to eq([ "app/models/gizmo.rb:14: Gadget#idle has no comment (changed)" ])
    end

    it "never judges a deletion, of a method or of a file (AC-2.4)", :aggregate_failures do
      base_with("app/models/gadget.rb" => gadget, "lib/gone.rb" => "class Gone\n  def go = 1\nend\n")
      write("app/models/gadget.rb", gadget.sub("\n  def idle = 0\n", ""))
      FileUtils.rm(root.join("lib/gone.rb"))

      expect(check).to be_ok
    end

    it "judges neither neighbour of a deleted method, and not a method that only moved (AC-2.9)", :aggregate_failures do
      base_with("lib/trio.rb" => trio)
      write("lib/trio.rb", trio.sub("\n  def b\n    1\n  end\n", ""))

      expect(check).to be_ok

      moved = trio.sub("\n  def c\n    1\n  end\n", "").sub("class Trio\n", "class Trio\n  def c\n    1\n  end\n\n")
      write("lib/trio.rb", moved)

      expect(check).to be_ok
    end

    it "counts deleting a method's comment as changing it, and rewording a comment that keeps its summary as nothing (AC-2.7)", :aggregate_failures do
      base_with("app/models/gadget.rb" => gadget)
      write("app/models/gadget.rb", gadget.sub("  # Turns.\n", ""))

      expect(offences(check)).to eq([ "app/models/gadget.rb:9: Gadget#turn has no comment (changed)" ])

      write("app/models/gadget.rb", gadget.sub("# Turns.", "# Turns once."))

      expect(check).to be_ok
    end

    it "passes a comment added above an existing uncommented method (AC-2.8)" do
      base_with("app/models/gadget.rb" => gadget)
      write("app/models/gadget.rb", gadget.sub("  def spin", "  # Spins.\n  def spin"))

      expect(check).to be_ok
    end
  end

  describe "namespaces" do
    it "changes a class defined in two files when the only comment is deleted, though the other definition is unchanged (decision 4)" do
      base_with("lib/dup_a.rb" => "# Dup.\nclass Dup\nend\n", "lib/dup_b.rb" => "class Dup\n  # B.\n  def b = 1\nend\n")
      write("lib/dup_a.rb", "class Dup\nend\n")

      expect(offences(check)).to contain_exactly(a_string_starting_with("lib/dup_a.rb:1: Dup has no comment (changed)"))
    end


    def other = "# Collector's documentation.\nmodule Collector\n  # Other.\n  class Other\n  end\nend\n"

    it "doesn't judge a namespace a new file reopens (AC-1.13)", :aggregate_failures do
      base_with("lib/collector/other.rb" => other)
      write("lib/collector/thing.rb", "module Collector\n  # Does a thing.\n  class Thing\n  end\nend\n")

      expect(check).to be_ok
    end

    it "doesn't count a comment above the outer wrapper for the class the file defines (AC-1.13)", :aggregate_failures do
      base_with("lib/collector/other.rb" => other)
      write("lib/collector/thing.rb", "# Thing's header.\nmodule Collector\n  class Thing\n  end\nend\n")

      lines = offences(check)

      expect(lines).to contain_exactly(a_string_starting_with("lib/collector/thing.rb:3: Collector::Thing has no comment (added)"))
    end
  end
```

- [ ] **Step 2: run, expect FAIL:** `bin/rspec spec/script/yard/comment_ratchet_spec.rb` — expect the examples above to fail, those about edited bodies, reformatting, the opening edit, comment deletion and renames with an edit (Phase 1 returns `nil` for any name the base has); the ones that expect `be_ok` for an unchanged name and the namespace ones may already pass.
- [ ] **Step 3: commit the failing examples:** `test(yard): examples for what counts as changed (spec 056)`.
- [ ] **Step 4: implement.** In `script/yard/comment_ratchet.rb`, replace `Snapshot::Item`, `Snapshot.build`'s `item` call, add `extent`, and replace `Check#change`.

Replace the `Item` line with:

```ruby
    Item = Data.define(:name, :namespace, :nested, :file, :line, :commented, :exempt, :extents)
```

In `Snapshot.build`, replace the registry loop with one that reads each file's lines once:

```ruby
      sources = Hash.new { |hash, path| hash[path] = File.readlines(path, chomp: true) }
      YARD::Registry.all(:class, :module, :method).each_with_object({}) do |object, items|
        items[object.path] = item(object, root, sources) unless object.files.empty?
      end
```

Replace `Snapshot.item` with the version that takes `sources`, and add `extent`:

```ruby
    def self.item(object, root, sources)
      namespace = object.type != :method
      exempt = exempt?(object)
      extents = exempt ? [] : object.files.map { |file, line| extent(object, file, line, namespace, sources[file]) }
      Item.new(name: object.path, namespace:, nested: !object.namespace.root?,
               file: Pathname(object.file).relative_path_from(root).to_s, line: object.line,
               commented: !object.docstring.to_s.strip.empty?, exempt:, extents:)
    end
    private_class_method :item

    # The text of one definition (decision 4): its own comment (the unbroken run of comment lines directly above it)
    # through its `end`; for a class or module, its comment and its opening line only, so its members' text is not
    # part of it. An alias's `source` is the original method's, so an alias is one line.
    def self.extent(object, file, line, namespace, lines)
      first = line
      first -= 1 while first > 1 && lines[first - 2].lstrip.start_with?("#")
      span = namespace || object.source.nil? || object.is_alias? ? 1 : object.source.lines.size
      lines[(first - 1)..(line + span - 2)].join("\n")
    end
    private_class_method :extent
```

Replace `Check#change` (and its Phase 1 comment) with:

```ruby
    # :added, :changed or nil (decision 4). Text is compared by qualified name, so a rename, a move, a deletion
    # beside a method and the place Git puts a hunk can't matter. A method is changed when any of its extents is new;
    # a class or module the base has is changed only by an edit (a definition's text removed and another added),
    # never by a new file reopening it or a file that defined it going away. The comparison counts repeats (a class
    # defined in two files with the same opening line has that text twice), so it is a multiset difference.
    def change(item, old)
      return :added if old.nil?
      return nil if surplus(item.extents, old.extents).empty?
      return :changed unless item.namespace

      surplus(old.extents, item.extents).empty? ? nil : :changed
    end

    # The elements of `items` left over when each element of `others` cancels one equal element.
    def surplus(items, others)
      counts = others.tally
      items.reject { counts[it].to_i.positive? && (counts[it] -= 1) }
    end
```

- [ ] **Step 5: run, expect PASS:** `bin/rspec spec/script/yard/comment_ratchet_spec.rb` — expect `0 failures` (Phase 1's examples included).
- [ ] **Step 6: lint** `bin/rubocop script/yard/comment_ratchet.rb spec/script/yard/comment_ratchet_spec.rb`, then **commit:** `feat(yard): judge public code the branch changes, by comparing text with the base (spec 056)`.

---

## Phase 3: The base, the failures, and the command

**Implements:** FR-1 (the base; must not pass or skip silently), FR-2, decision 5 | **Satisfies:** AC-2.5, AC-3.3, AC-3.4, AC-3.5, AC-3.7, and the command's exit status (Story 3, FR-1)
**Files:** `script/yard/comment_ratchet.rb`, `spec/script/yard/comment_ratchet_spec.rb`
**Interfaces:** Consumes: `Git#base`, `Check#call`, `Check::Result`. Produces: `Git#base` returning the merge base of `HEAD` and `origin/main` and raising `YardRatchet::Unseen` (messages in the constants below) for a shallow repository, a missing `origin/main` or no merge base; `Check#call` failing for a changed file YARD can't parse; the file run as a script (`ruby script/yard/comment_ratchet.rb`) printing `Result#lines` and exiting 0 or 1.

Replaces Phase 1's "origin/main's tip" with the merge base (so the first example below fails: main's own changes must not be judged), then adds the refusals, the parse-error rule and the command.

- [ ] **Step 1: add these examples** to the spec file:

```ruby
  describe "the base" do
    def script = Rails.root.join("script/yard/comment_ratchet.rb").to_s

    it "doesn't judge what main changed while the branch didn't merge it (AC-2.5)" do
      base_with("lib/main_edit.rb" => "# Main's.\nclass MainEdit\n  def go = 1\nend\n")
      run_git("checkout", "-q", "main")
      write("lib/main_edit.rb", "# Main's.\nclass MainEdit\n  def go = 2\nend\n")
      commit_all("main moves on")
      run_git("update-ref", "refs/remotes/origin/main", "HEAD")
      run_git("checkout", "-q", "topic")

      expect(check).to be_ok
    end

    it "judges only the branch's own code after a merge of main that brought uncommented code (AC-2.5)", :aggregate_failures do
      base_with("README.md" => "base")
      run_git("checkout", "-q", "main")
      write("lib/old.rb", "class Old\n  def go = 1\nend\n")
      commit_all("main moves on")
      run_git("update-ref", "refs/remotes/origin/main", "HEAD")
      run_git("checkout", "-q", "topic")
      run_git("merge", "-q", "--no-ff", "-m", "merge main", "main")
      write("lib/new.rb", "class New\n  def go = 1\nend\n")

      lines = check.lines.join("\n")

      expect(lines).to include("lib/new.rb:1: New has no comment (added)")
      expect(lines).not_to include("lib/old.rb")
    end

    it "fails, saying to fetch origin/main, when there is none (AC-3.3)", :aggregate_failures do
      base_with("README.md" => "base")
      run_git("update-ref", "-d", "refs/remotes/origin/main")

      result = check

      expect(result).not_to be_ok
      expect(result.lines.join("\n")).to include("no origin/main", "git fetch origin main")
    end

    it "fails when the branch shares no history with origin/main (AC-3.3)", :aggregate_failures do
      base_with("README.md" => "base")
      run_git("checkout", "-q", "--orphan", "loner")
      commit_all("unrelated")

      result = check

      expect(result).not_to be_ok
      expect(result.lines.join("\n")).to include("shares no history")
    end

    it "fails on a shallow clone even when origin/main is there, naming fetch-depth 0 (AC-3.3)", :aggregate_failures do
      base_with("README.md" => "base")
      shallow = Pathname(Dir.mktmpdir)
      run_git("clone", "-q", "--depth", "1", "--branch", "main", "file://#{root}", shallow.to_s, dir: shallow.dirname)

      result = described_class.new(root: shallow).call

      expect(result).not_to be_ok
      expect(result.lines.join("\n")).to include("shallow", "fetch-depth: 0", "git fetch --unshallow")
    ensure
      FileUtils.remove_entry(shallow) if shallow
    end

    it "judges the branch's changes from a detached merge commit, as GitHub's pull request checkout is (AC-3.7)", :aggregate_failures do
      base_with("README.md" => "base")
      write("lib/new.rb", "class New\n  def go = 1\nend\n")
      commit_all("topic work")
      run_git("checkout", "-q", "--detach", "main")
      run_git("merge", "-q", "--no-ff", "-m", "pull request merge", "topic")

      result = check

      expect(result).not_to be_ok
      expect(result.lines).to include("lib/new.rb:1: New has no comment (added)")
    end

    it "finds nothing changed on a tag at the tip of origin/main (AC-3.7, a guard)" do
      base_with("README.md" => "base")
      run_git("checkout", "-q", "main")
      write("lib/new.rb", "class New\n  def go = 1\nend\n")
      commit_all("later")
      run_git("update-ref", "refs/remotes/origin/main", "HEAD")
      run_git("checkout", "-q", "--detach", "main")

      expect(check).to be_ok
    end

    it "finds nothing changed on a tag at an older commit of origin/main, whose later commits edited code (AC-3.7)" do
      base_with("lib/old.rb" => "class Old\n  def go = 1\nend\n")
      first = run_git("rev-parse", "HEAD").strip
      run_git("checkout", "-q", "main")
      write("lib/old.rb", "class Old\n  def go = 2\nend\n")
      commit_all("later")
      run_git("update-ref", "refs/remotes/origin/main", "HEAD")
      run_git("checkout", "-q", "--detach", first)

      expect(check).to be_ok
    end

    it "starts no parse when no judged file differs from the base (AC-4.3)", :aggregate_failures do
      base_with("lib/old.rb" => "class Old\n  def go = 1\nend\n")
      allow(YardRatchet::Snapshot).to receive(:build).and_call_original

      result = check

      expect(result).to be_ok
      expect(YardRatchet::Snapshot).not_to have_received(:build)
    end

    it "fails for a changed file YARD can't parse, and ignores an unchanged one (AC-3.4)", :aggregate_failures do
      base_with("lib/broken.rb" => "def broken(\n", "README.md" => "base")

      expect(check).to be_ok

      write("lib/broken.rb", "def broken(\nputs 1\n")
      result = check

      expect(result).not_to be_ok
      expect(result.lines.join("\n")).to include("lib/broken.rb", "can't parse")
    end

    it "writes nothing into the checkout (AC-3.5)", :aggregate_failures do
      base_with("README.md" => "base")
      write("lib/new.rb", "# New.\nclass New\n  def go = 1\nend\n")
      before = run_git("status", "--porcelain", "--ignored")

      check

      expect(run_git("status", "--porcelain", "--ignored")).to eq(before)
      expect(root.join(".yardoc")).not_to exist
    end

    it "exits 1 and prints each offender when run as a command, and 0 when nothing is missing (FR-1)", :aggregate_failures do
      base_with("README.md" => "base")
      write("lib/new.rb", "# New.\nclass New\n  def go = 1\nend\n")
      env = GitSandbox::ENV_OVERRIDES.merge("BUNDLE_GEMFILE" => Rails.root.join("Gemfile").to_s)

      out, _err, status = Bundler.with_unbundled_env { Open3.capture3(env, RbConfig.ruby, script, chdir: root.to_s) }

      expect(status.exitstatus).to eq(1)
      expect(out).to include("lib/new.rb:3: New#go has no comment (added)")

      write("lib/new.rb", "# New.\nclass New\n  # Goes.\n  def go = 1\nend\n")
      out, _err, status = Bundler.with_unbundled_env { Open3.capture3(env, RbConfig.ruby, script, chdir: root.to_s) }

      expect(status.exitstatus).to eq(0)
      expect(out).to include("all with a comment")
    end
  end
```

- [ ] **Step 2: run, expect FAIL:** `bin/rspec spec/script/yard/comment_ratchet_spec.rb -e "the base"` — expect failures from: "doesn't judge what main changed while the branch didn't merge it" and "a tag at an older commit" (both compare with main's tip in Phase 1, so main's later edit looks like the branch's change), the no-origin, no-history and shallow examples (no guards yet; the no-history one fails because `rev-parse` of the tip succeeds), the parse example, the "starts no parse" example and the command example. The merge-after-main example, the detached merge commit, the tag at the tip and the writes-nothing example are regression guards: they pass under Phase 1's rule too, and pin what Phase 3's merge base must keep.
- [ ] **Step 3: commit the failing examples:** `test(yard): examples for the base, the refusals and the command (spec 056)`.
- [ ] **Step 4: implement.** In `script/yard/comment_ratchet.rb`:

Add `require "ripper"` to the requires (after `require "pathname"`).

Add the messages to `YardRatchet` (after `RULE`):

```ruby
  SHALLOW = "The checkout is shallow, so the merge base with origin/main can't be trusted. Fetch the full history " \
            "(actions/checkout: `fetch-depth: 0`; locally `git fetch --unshallow`).".freeze
  NO_ORIGIN = "There is no origin/main to compare with. Fetch it (`git fetch origin main`).".freeze
  NO_MERGE_BASE = "HEAD shares no history with origin/main. Fetch origin/main again (`git fetch origin main`) or rebase the branch onto it.".freeze
```

Replace `Git#base` and `Git#run`:

```ruby
    # The merge base of HEAD and origin/main, whatever HEAD is: a branch, or the detached merge commit GitHub checks
    # out for a pull request or a tag (decision 5). Unlike Collector::PushScope, a detached HEAD isn't refused.
    def base
      raise Unseen, SHALLOW if run("rev-parse", "--is-shallow-repository").strip == "true"

      run("rev-parse", "--verify", "--quiet", "refs/remotes/origin/main^{commit}", fail_with: NO_ORIGIN)
      run("merge-base", "HEAD", "refs/remotes/origin/main", fail_with: NO_MERGE_BASE).strip
    end
```

```ruby
    def run(*args, fail_with: nil)
      out, err, status = Open3.capture3(CLEARED, "git", *args, chdir: @root)
      return out if status.success?

      raise Unseen, fail_with || "git #{args.join(' ')} failed: #{err.strip}"
    end
```

In `Check#call`, replace the body of the `Dir.mktmpdir` block so a changed file YARD can't parse fails before judging:

```ruby
      Dir.mktmpdir("yard-ratchet") do |tmp|
        before_files = @git.base_files(base)
        @git.export(base, before_files, tmp)
        head_files = @git.head_files
        differing = head_files.reject { identical?(it, tmp) }
        # Nothing added, edited or removed in the judged files: nothing can be changed, so YARD isn't started.
        next Result.new(ok: true, lines: [ none(base) ]) if differing.empty? && head_files == before_files

        broken = unparseable(differing)
        next Result.new(ok: false, lines: broken.map { "#{it}: YARD can't parse this file (a syntax error); fix it first." }) if broken.any?

        report(base, *judge(Snapshot.build(@root, head_files), Snapshot.build(tmp, before_files)))
      end
```

Add to `Check` (private):

```ruby
    # Whether the head's file is byte for byte the base's (exported under `base_dir`).
    def identical?(path, base_dir)
      base_path = File.join(base_dir, path)
      File.file?(base_path) && File.binread(base_path) == File.binread(File.join(@root, path))
    end

    # The changed judged files that Ripper, which YARD parses with, rejects. An unchanged file that doesn't parse is
    # the site's build to report (spec 054), not this check's.
    def unparseable(files)
      files.select { Ripper.sexp(File.binread(File.join(@root, it)).force_encoding(Encoding::UTF_8)).nil? }
    end
```

Append the command after the module's closing `end`:

```ruby
if $PROGRAM_NAME == __FILE__
  result = YardRatchet::Check.new.call
  puts result.lines
  exit(result.ok? ? 0 : 1)
end
```

- [ ] **Step 5: run, expect PASS:** `bin/rspec spec/script/yard/comment_ratchet_spec.rb` — expect `0 failures`.
- [ ] **Step 6: lint,** `bin/rubocop script/yard spec/script/yard`, **then run the command on this branch:** `ruby script/yard/comment_ratchet.rb; echo "exit=$?"` — expect `Found no added or changed public code in scope (compared with <sha>).` and `exit=0` (AC-4.4: this branch adds nothing in scope). Time it (`time …`) for AC-4.3. **Commit:** `feat(yard): compare with the merge base, refuse a shallow or history-less checkout, and run as a command (spec 056)`.

---

## Phase 4: The `bin/ci checks` step and the workflow's history

**Implements:** FR-1 (runs where `bin/ci checks` runs), decision 5 (the history) | **Satisfies:** AC-4.1, AC-4.3, AC-4.4, AC-4.5, AC-4.9 (and AC-4.2, see the note)
**Files:** `config/ci.rb`, `spec/config/ci_definition_spec.rb`, `spec/script/upgrade/files_spec.rb` (one description)
**Interfaces:** Consumes: the command of Phase 3. Produces: the step `"Docs: new and changed public code has a comment"` running `ruby script/yard/comment_ratchet.rb`, in the `checks` group directly after the YARD step.

- [ ] **Step 1: add the examples** to `spec/config/ci_definition_spec.rb`, after the existing YARD example, and (the file needs no new require):

```ruby
  it "runs the comment ratchet in bin/ci checks, directly after the YARD step and not with the RSpec group (spec 056 AC-4.1)", :aggregate_failures do
    lines = Rails.root.join("config/ci.rb").readlines(chomp: true).map(&:strip)
    yard = lines.index('step "Docs: YARD builds without warnings", "bin/yard doc --no-cache"')
    ratchet = lines.index('step "Docs: new and changed public code has a comment", "ruby script/yard/comment_ratchet.rb"')
    guarded = lines.index("unless selection.group == :rspec")

    expect(ratchet).not_to be_nil
    expect(ratchet).to eq(yard + 1)
    expect(ratchet).to be > guarded
    expect(ratchet).to be < lines.each_index.find { |i| i > guarded && lines[i] == "end" }
  end
```

In `spec/script/upgrade/files_spec.rb`, the example "fetches the full history and the tags in the checks job, which runs the guard" already asserts `fetch-depth: 0` for `checks`; add the ratchet to its description rather than a duplicate (AC-4.9): `it "fetches the full history and the tags in the checks job, which runs the guard and the comment ratchet's merge base (AC-8.5, AC-7.6 as superseded by spec 035; spec 056 AC-4.9)"`.

- [ ] **Step 2: run, expect FAIL:** `bin/rspec spec/config/ci_definition_spec.rb` — expect the new example to fail (no step yet; `ratchet` is nil). The `fetch-depth` example in `files_spec.rb` passes already; the description change only names this spec.
- [ ] **Step 3: commit the failing example:** `test(ci): the comment ratchet step belongs to bin/ci checks (spec 056)`.
- [ ] **Step 4: add the step** in `config/ci.rb`, directly after the YARD step:

```ruby
    step "Docs: YARD builds without warnings", "bin/yard doc --no-cache"
    step "Docs: new and changed public code has a comment", "ruby script/yard/comment_ratchet.rb"
```

- [ ] **Step 5: run, expect PASS:** `bin/rspec spec/config/ci_definition_spec.rb spec/script/upgrade/files_spec.rb`; then `bin/rubocop config/ci.rb spec/config/ci_definition_spec.rb spec/script/upgrade/files_spec.rb`.
- [ ] **Step 6: AC-4.5 by reading** (record in `verification.md`): `.dockerignore` has `/script` (the check lives under `script/yard/`, so it is outside the build context) and `bin/image-smoke` lists `script`; nothing new needs a path.
- [ ] **Step 7: commit:** `ci: run the comment ratchet in bin/ci checks after the YARD step (spec 056)`.
- [ ] **AC-4.2 (GitHub's `checks` job failing on a throwaway commit): a ruling is needed before this step.** The pre-push gate is a Claude Code hook (`.claude/settings.json`; `.githooks/` holds only `post-checkout`), so it blocks this session's `git push`, not the maintainer's. Recommended: the maintainer (or the coordinator on their word) pushes a throwaway commit by hand to a scratch branch off this one with a pull request, watches the `checks` job fail at "Docs: new and changed public code has a comment" naming the object, and closes the pull request; recorded in `verification.md`. Fallback if the maintainer declines, recorded as a ruling that changes how AC-4.2 is verified: the pull request's own `checks` run shows the step running on the pull request merge ref and passing, the failure on a detached merge commit is Phase 3's AC-3.7 example, and a local `bin/ci checks` run with an uncommented method added and reverted (Phase 6) is recorded.

---

## Phase 5: Documentation

**Implements:** FR-2, decision 6, Story 4 | **Satisfies:** AC-4.6, AC-4.7, AC-4.8 (verified by reading, recorded in `verification.md`; the suite checks no prose)
**Files:** `.claude/rules/code-documentation.md`, `CLAUDE.md`, `docs/architecture/release-and-deploy.md`, `docs/specs/056-yard-comment-ratchet/verification.md` (new); the 056 row and the 054 supersession of `docs/specs/README.md` already exist, and the status change belongs to `distill-feature`
**Interfaces:** Consumes: the step and its messages. Produces: nothing code depends on.

- [ ] **Step 1: the rule file.** In `.claude/rules/code-documentation.md`, under "Keeping comments true", add these bullets before the "Code reviews" bullet (the YARD-syntax rule about `{…}` is unaffected):

```markdown
- ✓ `bin/ci checks` fails a branch that adds or changes a public class, module or method with no comment (spec 056, the step "Docs: new and changed public code has a comment", `script/yard/comment_ratchet.rb`). It judges `app/models/` (concerns included), `app/helpers/`, `app/*/concerns/`, `lib/` and `spec/support/`, never total coverage and never code the branch didn't touch. A comment means summary text; tags alone and `@private` don't count, `@api private` does. Private and protected methods, constants, attribute methods and `initialize` aren't judged, and neither is what YARD doesn't register (`scope`, `define_method`, `delegate`, methods inside `RSpec.configure` blocks). It needs the full history (`fetch-depth: 0`) and fails, never passes, when it can't find the merge base with `origin/main`.
- ✓ Put a file's header comment above the class the file defines, not above its outer `module Collector` line: a comment above a namespace documents the namespace, and the check then names the class.
- ✗ Don't expect the check to find a stale or what-not-why comment; it reads only that a summary exists. That stays with reviews (the "Code reviews" bullet).
```

and amend the "Code reviews" bullet to read "Code reviews (`sdd-review` Mode B, code-review subagents) check new and changed public methods for a stale or what-not-why comment, and for `@param`/`@return` where the rule asks for them; a missing summary is `bin/ci checks`' to find."

- [ ] **Step 2: `CLAUDE.md`.** In the `bin/ci` Commands line, after "YARD," add "the comment ratchet (spec 056: public code the branch adds or changes needs a summary; `.claude/rules/code-documentation.md`),". Name the step and point to the rule only; don't restate its scope. Don't extend the Project Status paragraph, and record in `verification.md` that the Claude Code Hooks section was read and needs no change (the pre-push hook already runs `bin/ci checks` for a documentation-only branch).
- [ ] **Step 3: the area doc.** In `docs/architecture/release-and-deploy.md`: add "the comment ratchet" after "the YARD build" in the "`bin/ci` takes one optional group" bullet; add a bullet after the "One CI definition" bullet: "**The comment ratchet is a `bin/ci checks` step** (`ruby script/yard/comment_ratchet.rb`, after the YARD step): it fails a branch that adds or changes a judged public class, module or method with no summary, comparing each object's text with the merge base of `HEAD` and `origin/main` (never total coverage), and fails, not passes, when `origin/main`, the merge base or the history is missing; the `checks` job's `fetch-depth: 0` is what gives it the history (spec 056 decisions 1–6, AC-3.3, AC-3.7, AC-4.1, AC-4.9; ADR 0027's room for a later check; `script/yard/comment_ratchet.rb`, `config/ci.rb`, `.github/workflows/ci.yml:23-26`)."; extend the "configuration files … checked" bullet with "and the comment ratchet's step and the workflow's history in `spec/config/ci_definition_spec.rb` (spec 056 AC-4.1, AC-4.9)"; add `[Spec 056](../specs/056-yard-comment-ratchet/spec.md) (the comment ratchet step)` to Sources, naming issue #264. Leave the Distillation log to `distill-feature`.
- [ ] **Step 4: `verification.md`** at `docs/specs/056-yard-comment-ratchet/verification.md`: a table with one row per AC (1.1–1.15, 2.1–2.9, 3.1–3.7, 4.1–4.9) giving the spec example that proves it (by its description) or the command and its recorded output, and an `## Implementation review` heading left for Mode B. Fill AC-4.2/4.3 from the PR's run and the timing of Phase 3 Step 6; AC-4.5 from Phase 4 Step 6; AC-4.6–4.8 from reading the three documents.
- [ ] **Step 5: commit** `docs: record the comment ratchet in the rule, CLAUDE.md and the release-and-deploy area doc (spec 056)`, and `docs(specs): verification for spec 056`.

---

## Phase 6: Integration Verification

**Implements:** All FRs | **Satisfies:** All ACs

- [ ] Run the whole check on the branch: `ruby script/yard/comment_ratchet.rb; echo "exit=$?"` — expect `exit=0` and the "Found no added or changed public code" line.
- [ ] Add an uncommented public method to `lib/collector/dev_port.rb` in the working tree, run `bin/ci checks` — expect the step to fail naming `lib/collector/dev_port.rb:<line>: Collector::DevPort… has no comment (added|changed)` and `bin/ci checks` to exit non-zero; `git checkout -- lib/collector/dev_port.rb`; run again — expect the step to pass. Record both runs in `verification.md` (AC-4.2's local half).
- [ ] Run `bin/ci` (the pre-push gate runs it; one `bin/ci` at a time) — expect every step green, RSpec included; record the pushed SHA, the example count (`bin/rspec --dry-run`) and the step's run time (AC-4.3, at most 30 s).
- [ ] Because the spec file now `require`s `yard` into the RSpec process (it adds `Object#log`, `Object#P` and `Module#class_name`), run the whole suite twice more with other seeds (`bin/rspec --seed 1` and `bin/rspec --seed 42424`, one at a time, one `bin/ci` or suite at a time) and record that no example outside this feature changed its result.
- [ ] Run `bin/yard doc --no-cache` — expect no `[warn]` line (nothing under `app/` or `lib/` changed; the script's comments are outside YARD's files).
- [ ] After the push, read the pull request's `checks` job log for the step and its output (AC-4.2's CI half, AC-4.3's CI time); record both.
- [ ] Record the "Known limits" above in `verification.md`. Review: `sdd-review` Mode B on Opus; record its verdict under `## Implementation review` in `verification.md`.

---

## Quickstart Validation

```
ruby script/yard/comment_ratchet.rb          # on a branch: judges what it added or changed against origin/main
bin/ci checks                                # the step runs after "Docs: YARD builds without warnings"
bin/rspec spec/script/yard/comment_ratchet_spec.rb spec/config/ci_definition_spec.rb
```

On a branch that adds an uncommented public method under `app/models/`, the first command prints `app/models/<file>.rb:<line>: <Class>#<method> has no comment (added)`, a count, the rule's path and the line saying staleness isn't checked, and exits 1; with a one-line comment above the method it prints `<n> added or changed public objects, all with a comment (compared with <sha>).` and exits 0.
