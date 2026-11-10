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
