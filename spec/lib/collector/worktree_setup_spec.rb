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
end
