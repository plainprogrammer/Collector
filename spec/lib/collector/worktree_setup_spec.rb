require "rails_helper"
require "tmpdir"

RSpec.describe Collector::WorktreeSetup, :git_sandbox do
  let(:dir) { File.realpath(Dir.mktmpdir) }
  let(:main) { new_repo(File.join(dir, "main")) }
  let(:worktree) do
    path = File.join(dir, "wt")
    git!(main, "worktree", "add", "-q", path, "-b", "feature")
    path
  end
  # A worktree whose only sibling entry is a bare repository (no main checkout).
  let(:bare_worktree) do
    bare = File.join(dir, "bare.git")
    git!(dir, "clone", "-q", "--bare", main, bare)
    path = File.join(dir, "from-bare")
    git!(bare, "worktree", "add", "-q", path, "-b", "x")
    path
  end

  after { FileUtils.remove_entry(dir) }

  def setup_for(root, extra_env = {})
    described_class.new(root: root, env: GitSandbox::ENV_OVERRIDES.compact.merge(extra_env))
  end

  def write_secret(root, path, body)
    FileUtils.mkdir_p(File.dirname(File.join(root, path)))
    File.write(File.join(root, path), body)
    File.chmod(0o644, File.join(root, path))
  end

  def mode_of(path) = File.stat(path).mode & 0o777

  describe "#checkout_kind" do
    it "detects main checkouts, linked worktrees, and non-git directories", :aggregate_failures do
      expect(setup_for(main).checkout_kind).to eq(:main)
      expect(setup_for(worktree).checkout_kind).to eq(:linked)
      expect(setup_for(dir).checkout_kind).to eq(:none)
    end

    it "ignores a GIT_DIR inherited from an enclosing git hook" do
      previous = ENV.fetch("GIT_DIR", nil)
      ENV["GIT_DIR"] = File.join(dir, "nowhere")
      expect(setup_for(main).checkout_kind).to eq(:main)
    ensure
      ENV["GIT_DIR"] = previous
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
      expect(setup_for(bare_worktree).main_checkout).to be_nil
    end
  end

  describe "#included_paths" do
    it "reads literal entries from .worktreeinclude, skipping comments and blanks" do
      File.write(File.join(main, ".worktreeinclude"), "# c\n\nconfig/master.key\n")
      expect(setup_for(main).included_paths).to eq(%w[config/master.key])
    end
  end

  describe "#copy_included_files" do
    context "when the main checkout has both secrets" do
      let(:messages) do
        write_secret(main, "config/master.key", "k" * 32)
        write_secret(main, "tmp/local_secret.txt", "s" * 128)
        setup_for(worktree).copy_included_files
      end

      before { messages }

      %w[config/master.key tmp/local_secret.txt].each do |path|
        it "copies #{path} with the same contents and mode 0600", :aggregate_failures do
          copied = File.join(worktree, path)
          expect(File.read(copied)).to eq(File.read(File.join(main, path)))
          expect(mode_of(copied)).to eq(0o600)
        end
      end

      it "reports the copy" do
        expect(messages).to include(a_string_including("Copied config/master.key"))
      end
    end

    it "never overwrites a file the worktree already has" do
      write_secret(main, "config/master.key", "main-key")
      write_secret(worktree, "config/master.key", "own-key")
      setup_for(worktree).copy_included_files
      expect(File.read(File.join(worktree, "config/master.key"))).to eq("own-key")
    end

    it "warns about a missing master key but not a missing local secret", :aggregate_failures do
      output = setup_for(worktree).copy_included_files.join("\n")
      expect(output).to include("config/master.key", "RAILS_MASTER_KEY")
      expect(output).not_to include("local_secret")
      expect(File).not_to exist(File.join(worktree, "tmp/local_secret.txt"))
    end

    it "copies nothing in a main checkout and still warns about a missing key", :aggregate_failures do
      output = setup_for(main).copy_included_files.join("\n")
      expect(output).to include("config/master.key")
      expect(output).not_to include("Copied")
    end

    it "skips copying with a notice outside git" do
      expect(setup_for(dir).copy_included_files).to eq([ "Not a git checkout; skipping file copy and worktree hooks." ])
    end

    it "prefers git's main checkout and notes a disagreeing ORCA_ROOT_PATH", :aggregate_failures do
      write_secret(main, "config/master.key", "main-key")
      messages = setup_for(worktree, "ORCA_ROOT_PATH" => "/elsewhere").copy_included_files
      expect(File.read(File.join(worktree, "config/master.key"))).to eq("main-key")
      expect(messages).to include(a_string_including("ORCA_ROOT_PATH"))
    end

    it "adds no notice when ORCA_ROOT_PATH matches git's main checkout" do
      messages = setup_for(worktree, "ORCA_ROOT_PATH" => main).copy_included_files
      expect(messages).not_to include(a_string_including("ORCA_ROOT_PATH"))
    end

    it "skips copying with a notice when no main checkout can be found" do
      expect(setup_for(bare_worktree).copy_included_files).to include(a_string_including("main checkout not found"))
    end
  end

  describe "#enable_worktree_hooks" do
    def add_executable(path)
      File.write(path, "#!/bin/sh\n")
      File.chmod(0o755, path)
    end

    # git cannot create config.lock in a read-only git dir, so writing config fails.
    def read_only(path)
      File.chmod(0o555, path)
      yield
    ensure
      File.chmod(0o755, path)
    end

    it "points core.hooksPath at the versioned hooks directory", :aggregate_failures do
      messages = setup_for(main).enable_worktree_hooks
      expect(git!(main, "config", "--get", "core.hooksPath").strip).to eq(".githooks")
      expect(messages).to include(a_string_including("Enabled automatic setup"))
      expect(setup_for(main).enable_worktree_hooks).to eq([])
    end

    it "writes the shared repository config when run from a linked worktree" do
      setup_for(worktree).enable_worktree_hooks
      expect(git!(main, "config", "--get", "core.hooksPath").strip).to eq(".githooks")
    end

    it "leaves a different custom hooks path alone", :aggregate_failures do
      git!(main, "config", "core.hooksPath", ".husky")
      messages = setup_for(main).enable_worktree_hooks
      expect(git!(main, "config", "--get", "core.hooksPath").strip).to eq(".husky")
      expect(messages).to include(a_string_including("not enabled"))
    end

    it "lists active hooks that stop running", :aggregate_failures do
      add_executable(File.join(main, ".git/hooks/pre-commit"))
      messages = setup_for(main).enable_worktree_hooks
      expect(messages).to include(a_string_including("pre-commit"))
      expect(messages.join).not_to include(".sample")
    end

    it "reports a failure instead of claiming success when git config cannot be written", :aggregate_failures do
      messages = read_only(File.join(main, ".git")) { setup_for(main).enable_worktree_hooks }
      expect(messages).to include(a_string_including("could not enable"))
      expect(messages).not_to include(a_string_including("Enabled"))
    end

    it "does nothing outside git or without git", :aggregate_failures do
      expect(setup_for(dir).enable_worktree_hooks).to eq([])
      expect(described_class.new(root: main, git: "definitely-not-git").enable_worktree_hooks).to eq([])
    end
  end

  describe "#with_lock" do
    # Starts a thread that holds the setup lock until `release` receives a value.
    def hold_lock(root, events, release)
      thread = Thread.new { setup_for(root).with_lock { events << :first_locked && release.pop && events << :first_done } }
      raise "first setup never acquired the lock" unless events.pop(timeout: 10) == :first_locked

      thread
    end

    # A separate open file description, so flock conflicts even within this process.
    def locked_elsewhere?(root)
      File.open(File.join(root, described_class::LOCK_FILE)) { |f| f.flock(File::LOCK_EX | File::LOCK_NB) == false }
    end

    def collect(events, count) = Array.new(count) { events.pop(timeout: 10) }

    it "holds an exclusive lock on tmp/setup.lock while the block runs", :aggregate_failures do
      events, release = Queue.new, Queue.new
      first = hold_lock(main, events, release)
      expect(locked_elsewhere?(main)).to be(true)
      release << true
      expect(first.join(10)).not_to be_nil
    end

    it "makes a second setup wait for the first to finish, then run" do
      events, release = Queue.new, Queue.new
      second = hold_lock(main, events, release) && Thread.new { setup_for(main).with_lock { events << :second_ran } }
      events << :second_waiting if second.join(0.2).nil?
      release << true
      expect(collect(events, 3)).to eq(%i[second_waiting first_done second_ran])
    end

    it "releases the lock afterwards so later setups run normally", :aggregate_failures do
      setup_for(main).with_lock { nil }
      expect(setup_for(main).with_lock { :again }).to eq(:again)
      expect(locked_elsewhere?(main)).to be(false)
    end
  end
end
