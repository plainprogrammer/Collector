require "rails_helper"
require "tmpdir"

# The sandbox repository commits the real hook with a stub bin/setup that records
# its arguments, so the real setup never runs here.
RSpec.describe "post-checkout hook", :git_sandbox do
  let(:dir) { File.realpath(Dir.mktmpdir) }
  let(:stub_setup) { "#!/bin/sh\necho \"$@\" > setup-ran.txt\nexit ${STUB_SETUP_EXIT:-0}\n" }
  let(:main) do
    new_repo(File.join(dir, "main"), extra_files: {
      ".githooks/post-checkout" => Rails.root.join(".githooks/post-checkout").read,
      "bin/setup" => stub_setup
    }).tap do |repo|
      File.chmod(0o755, File.join(repo, ".githooks/post-checkout"), File.join(repo, "bin/setup"))
      git!(repo, "add", ".")
      git!(repo, "commit", "-q", "-m", "exec bits")
      git!(repo, "config", "core.hooksPath", ".githooks")
    end
  end
  let(:worktree) { File.join(dir, "wt") }

  after { FileUtils.remove_entry(dir) }

  def ran_setup?(checkout) = File.exist?(File.join(checkout, "setup-ran.txt"))

  def add_worktree(env: {}) = git(main, "worktree", "add", "-q", worktree, "-b", "feature", env: env)

  # A linked worktree created with the hook, with the record of that first run removed.
  def settled_worktree
    add_worktree
    File.delete(File.join(worktree, "setup-ran.txt"))
    worktree
  end

  def run_hook(checkout, *args)
    _out, _err, status = Open3.capture3(GitSandbox::ENV_OVERRIDES, ".githooks/post-checkout", *args, chdir: checkout)
    status
  end

  it "runs bin/setup --skip-server in a new linked worktree" do
    add_worktree
    expect(File.read(File.join(worktree, "setup-ran.txt")).strip).to eq("--skip-server")
  end

  it "does not run without the hooks path (setup never run in this clone)" do
    git!(main, "config", "--unset", "core.hooksPath")
    add_worktree
    expect(ran_setup?(worktree)).to be(false)
  end

  it "does not run on branch switches", :aggregate_failures do
    git!(main, "switch", "-q", "-c", "other")
    expect(ran_setup?(main)).to be(false)

    git!(settled_worktree, "switch", "-q", "-c", "feature-2")
    expect(ran_setup?(worktree)).to be(false)
  end

  it "does not run on a file checkout in a linked worktree" do
    File.write(File.join(settled_worktree, ".gitignore"), "changed\n")
    git!(worktree, "checkout", "--", ".gitignore")
    expect(ran_setup?(worktree)).to be(false)
  end

  it "does not run in the main checkout even with a new-checkout signature" do
    status = run_hook(main, "0" * 40, "HEAD", "1")
    expect([ status.success?, ran_setup?(main) ]).to eq([ true, false ])
  end

  it "does not run in a fresh clone (a main checkout) when hooks fire on clone" do
    clone = File.join(dir, "clone")
    git!(dir, "clone", "-q", "-c", "core.hooksPath=.githooks", main, clone)
    expect(ran_setup?(clone)).to be(false)
  end

  it "treats a SHA-256-length null previous commit as a new checkout" do
    status = run_hook(settled_worktree, "0" * 64, "HEAD", "1")
    expect([ status.success?, ran_setup?(worktree) ]).to eq([ true, true ])
  end

  it "does not run when the previous commit argument is empty" do
    status = run_hook(settled_worktree, "", "HEAD", "1")
    expect([ status.success?, ran_setup?(worktree) ]).to eq([ true, false ])
  end

  # The hook runs in the caller's environment (Orca's carries the global mise Ruby), so it goes through
  # `mise exec` when mise is there, to get the Ruby that .ruby-version names (#225).
  describe "the Ruby it runs setup with" do
    let(:bin_dir) { File.join(dir, "bin-on-path").tap { FileUtils.mkdir_p(it) } }

    def put_on_path(name, body)
      File.join(bin_dir, name).tap do |path|
        File.write(path, body)
        File.chmod(0o755, path)
      end
    end

    it "runs bin/setup through mise exec when mise is on the PATH", :aggregate_failures do
      put_on_path("mise", "#!/bin/sh\necho \"$@\" > mise-ran.txt\nshift 2\nexec \"$@\"\n")
      add_worktree(env: { "PATH" => "#{bin_dir}:#{ENV.fetch('PATH')}" })
      expect(File.read(File.join(worktree, "mise-ran.txt")).strip).to eq("exec -- bin/setup --skip-server")
      expect(File.read(File.join(worktree, "setup-ran.txt")).strip).to eq("--skip-server")
    end

    it "runs bin/setup directly when mise isn't on the PATH" do
      without_mise = ENV.fetch("PATH").split(File::PATH_SEPARATOR).reject { File.executable?(File.join(it, "mise")) }
      git_path = Open3.capture2("sh", "-c", "command -v git").first.strip
      File.symlink(git_path, File.join(bin_dir, "git"))
      add_worktree(env: { "PATH" => [ bin_dir, *without_mise ].join(File::PATH_SEPARATOR) })
      expect(File.read(File.join(worktree, "setup-ran.txt")).strip).to eq("--skip-server")
    end
  end

  it "keeps the worktree and exits 0 when setup fails", :aggregate_failures do
    _out, err, status = add_worktree(env: { "STUB_SETUP_EXIT" => "1" })
    expect(status.success?).to be(true)
    expect(Dir).to exist(worktree)
    expect(err).to include("bin/setup")
  end
end
