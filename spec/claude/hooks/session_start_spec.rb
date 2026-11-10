require "rails_helper"
require "open3"
require "tmpdir"

# .claude/hooks/session-start.sh runs at the start of every Claude Code session. In a cloud session it builds
# the pinned Ruby with rbenv; in a local one (an Orca worker's too) it must put .ruby-version's Ruby first on
# the PATH of the session's commands, because Orca starts the session with macOS's Ruby 2.6 first (#289).
# Each example runs the real script against a sandbox project with a fake mise and a temp CLAUDE_ENV_FILE.
RSpec.describe ".claude/hooks/session-start.sh", type: :model do # rubocop:disable RSpec/DescribeClass -- a shell script, no class
  let(:dir) { File.realpath(Dir.mktmpdir) }
  let(:project) { File.join(dir, "project") }
  let(:env_file) { File.join(dir, "claude-env") }
  let(:hook) { Rails.root.join(".claude/hooks/session-start.sh").to_s }
  let(:base_path) { "/usr/bin:/bin" }

  before do
    FileUtils.mkdir_p(File.join(project, "script/worktree"))
    FileUtils.cp(Rails.root.join("script/worktree/with_mise"), File.join(project, "script/worktree/with_mise"))
    File.write(File.join(project, ".ruby-version"), "ruby-4.0.7\n")
  end

  after { FileUtils.remove_entry(dir) }

  def executable(path, body)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "#!/bin/sh\n#{body}\n")
    File.chmod(0o755, path)
  end

  # A mise whose `exec -- COMMAND` runs COMMAND with a fake Ruby's directory first on the PATH.
  def fake_mise(ruby_dir)
    executable(File.join(ruby_dir, "ruby"), "echo fake ruby")
    executable(File.join(dir, "brew/mise"), %(shift 2\nPATH="#{ruby_dir}:$PATH"\nexport PATH\nexec "$@"))
  end

  def run_hook(env = {})
    Open3.capture3({ "PATH" => base_path, "HOME" => dir, "CLAUDE_PROJECT_DIR" => project,
                     "CLAUDE_ENV_FILE" => env_file, "COLLECTOR_MISE_SEARCH" => File.join(dir, "brew") }.merge(env),
                   "bash", hook)
  end

  def env_file_text = File.exist?(env_file) ? File.read(env_file) : ""

  # What a session's next command sees: the env file sourced into a shell that has the session's PATH.
  def ruby_after_sourcing(times: 1, path: base_path)
    sourcing = Array.new(times) { %(. "#{env_file}") }.join("; ")
    out, = Open3.capture3({ "PATH" => path }, "bash", "-c", "#{sourcing}; command -v ruby; echo \"$PATH\"")
    out.lines.map(&:strip)
  end

  context "when it runs in a local session (not CLAUDE_CODE_REMOTE)" do
    it "puts the Ruby mise resolves first on the PATH of the session's commands", :aggregate_failures do
      fake_mise(File.join(dir, "mise-ruby/bin"))
      _out, err, status = run_hook
      ruby, path = ruby_after_sourcing

      expect(status.success?).to be(true), err
      expect(ruby).to eq("#{dir}/mise-ruby/bin/ruby")
      expect(path).to eq("#{dir}/mise-ruby/bin:#{base_path}")
    end

    # Orca's login shell keeps mise's directories in the PATH but behind /usr/bin (#268), so "somewhere in the
    # PATH" is not "first".
    it "moves the Ruby first when mise's directory is already in the PATH, behind the system's", :aggregate_failures do
      fake_mise(File.join(dir, "mise-ruby/bin"))
      path = "/usr/bin:#{dir}/mise-ruby/bin:/bin"
      _out, err, status = run_hook("PATH" => path)
      ruby, after = ruby_after_sourcing(path: path)

      expect(status.success?).to be(true), err
      expect(ruby).to eq("#{dir}/mise-ruby/bin/ruby")
      expect(after).to eq("#{dir}/mise-ruby/bin:#{path}")
    end

    it "quotes a Ruby directory that has spaces", :aggregate_failures do
      fake_mise(File.join(dir, "mise ruby/4.0.7 bin"))
      run_hook
      ruby, path = ruby_after_sourcing

      expect(ruby).to eq("#{dir}/mise ruby/4.0.7 bin/ruby")
      expect(path).to eq("#{dir}/mise ruby/4.0.7 bin:#{base_path}")
    end

    it "adds the directory once when the hook runs again on resume or compact", :aggregate_failures do
      fake_mise(File.join(dir, "mise-ruby/bin"))
      2.times { run_hook }
      _ruby, path = ruby_after_sourcing(times: 2)

      expect(env_file_text.lines.size).to eq(1)
      expect(path).to eq("#{dir}/mise-ruby/bin:#{base_path}")
    end

    it "writes nothing when mise is nowhere (CI runners and containers)", :aggregate_failures do
      _out, err, status = run_hook
      expect(status.success?).to be(true), err
      expect(env_file_text).to eq("")
    end

    it "writes nothing when the session's Ruby is already the one mise resolves", :aggregate_failures do
      fake_mise(File.join(dir, "mise-ruby/bin"))
      _out, err, status = run_hook("PATH" => "#{dir}/mise-ruby/bin:#{base_path}")
      expect(status.success?).to be(true), err
      expect(env_file_text).to eq("")
    end

    it "writes nothing when mise has no Ruby for the checkout", :aggregate_failures do
      executable(File.join(dir, "brew/mise"), "exit 1")
      _out, err, status = run_hook
      expect(status.success?).to be(true), err
      expect(env_file_text).to eq("")
    end

    it "succeeds when the session has no CLAUDE_ENV_FILE", :aggregate_failures do
      fake_mise(File.join(dir, "mise-ruby/bin"))
      _out, err, status = run_hook("CLAUDE_ENV_FILE" => "")
      expect(status.success?).to be(true), err
      expect(File.exist?(env_file)).to be(false)
    end
  end

  # The cloud path is unchanged: rbenv's shims go to the env file and mise is never asked.
  context "when it runs in a cloud session (CLAUDE_CODE_REMOTE=true)" do
    def rbenv = File.join(dir, "rbenv")

    before do
      executable(File.join(rbenv, "versions/4.0.7/bin/ruby"), "echo fake ruby")
      %w[rbenv bundle].each { executable(File.join(dir, "stubs", it), "exit 0") }
      %w[bin/fetch-ocr-engine bin/rails].each { executable(File.join(project, it), "exit 0") }
      fake_mise(File.join(dir, "mise-ruby/bin"))
    end

    it "writes the rbenv PATH and leaves mise out of it", :aggregate_failures do
      _out, err, status = run_hook("CLAUDE_CODE_REMOTE" => "true", "RBENV_ROOT" => rbenv,
                                   "PATH" => "#{dir}/stubs:#{base_path}")

      expect(status.success?).to be(true), err
      expect(env_file_text).to include(%(export RBENV_ROOT="#{rbenv}"), %(export PATH="#{rbenv}/shims:#{rbenv}/bin:$PATH"))
      expect(env_file_text).not_to include("mise-ruby")
    end
  end
end
