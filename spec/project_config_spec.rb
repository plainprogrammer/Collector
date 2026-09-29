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
