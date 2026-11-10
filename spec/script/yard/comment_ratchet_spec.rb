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
    dir.join(path).binwrite(body)
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
    def other = "# Collector's documentation.\nmodule Collector\n  # Other.\n  class Other\n  end\nend\n"

    it "changes a class defined in two files when the only comment is deleted, though the other definition is unchanged (decision 4)" do
      base_with("lib/dup_a.rb" => "# Dup.\nclass Dup\nend\n", "lib/dup_b.rb" => "class Dup\n  # B.\n  def b = 1\nend\n")
      write("lib/dup_a.rb", "class Dup\nend\n")

      expect(offences(check)).to contain_exactly(a_string_starting_with("lib/dup_a.rb:1: Dup has no comment (changed)"))
    end

    # A new class defined in two files is judged once and passes if any definition has a summary, whichever file YARD
    # reads last (decision 4): YARD's own docstring for it is the last definition's.
    {
      "the summary first" => [ "lib/a.rb", "lib/b.rb" ], "the summary last" => [ "lib/b.rb", "lib/a.rb" ]
    }.each do |order, (summary_file, tags_file)|
      it "passes a new class whose summary is in one of its two files, with #{order} (decision 4)" do
        base_with("README.md" => "base")
        write(summary_file, "# Foo summary.\nclass Foo\nend\n")
        write(tags_file, "# @see file:x.md\nclass Foo\nend\n")

        expect(check).to be_ok
      end
    end

    it "fails a new class defined in two files when neither definition has a summary, reporting it once (decision 4)" do
      base_with("README.md" => "base")
      write("lib/a.rb", "# @see file:x.md\nclass Foo\nend\n")
      write("lib/b.rb", "class Foo\nend\n")

      expect(offences(check)).to contain_exactly(a_string_matching(/\Alib\/[ab]\.rb:\d: Foo has no comment \(added\)/))
    end

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

    # One Latin-1 byte and no magic comment: Ruby's Ripper accepts the file, YARD drops it whole on an encoding error.
    def latin1(code = "def a = 1\n") = "# caf\xE9 note\nclass Cafe\n  #{code}end\n".b

    it "fails for a changed file that Ripper accepts and YARD drops (an encoding error), naming the file (AC-3.4)", :aggregate_failures do
      base_with("README.md" => "base")
      write("lib/c.rb", latin1)

      result = check

      expect(result).not_to be_ok
      expect(result.lines.join("\n")).to include("lib/c.rb", "can't parse")
      expect(result.lines.join("\n")).not_to include("Found no added or changed public code")
    end

    it "fails for an edited file YARD drops even when its base version was just as unreadable, though it adds a comment (AC-3.4)" do
      base_with("lib/c.rb" => latin1)
      write("lib/c.rb", latin1("# Spins.\n  def a = 2\n"))

      expect(check).not_to be_ok
    end

    it "doesn't fail a changed file that holds no class, module or method: an empty one, comments only, or constants only (AC-3.4)", :aggregate_failures do
      base_with("README.md" => "base")
      write("lib/empty.rb", "")
      write("lib/notes.rb", "# Only a comment.\n")
      write("spec/support/constants.rb", "require \"set\"\nLIMIT = 3\n")

      result = check

      expect(result).to be_ok
      expect(result.lines.first).to include("Found no added or changed public code")
    end

    it "ignores an unchanged file YARD drops, and judges the changed ones beside it (AC-3.4)", :aggregate_failures do
      base_with("lib/c.rb" => latin1, "README.md" => "base")
      write("lib/new.rb", "# New.\nclass New\n  # Goes.\n  def go = 1\nend\n")

      expect(check).to be_ok

      write("lib/new.rb", "class New\n  # Goes.\n  def go = 1\nend\n")

      expect(check.lines).to include("lib/new.rb:1: New has no comment (added)")
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
end
