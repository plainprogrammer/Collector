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

    # Orca's environment carries the global mise Ruby, not .ruby-version's (#225).
    it "runs bin/setup through mise, so it uses the Ruby that .ruby-version names" do
      expect(setup_script).to include("mise exec -- bin/setup --skip-server")
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

  describe "YARD (spec 054)" do
    it "ignores the generated site and its cache (AC-3.1)", :aggregate_failures do
      expect(git_ignored?("doc/index.html")).to be(true)
      expect(git_ignored?(".yardoc/checksums")).to be(true)
    end

    it "keeps the extension and YARD out of the app's boot (AC-3.7)", :aggregate_failures do
      expect(Rails.autoloaders.main.dirs).not_to include(a_string_starting_with(Rails.root.join("script").to_s))
      expect(defined?(YARD)).to be_nil
    end

    it "is a development-only gem that nothing requires, which the image's bundle leaves out (AC-3.4, AC-3.5)", :aggregate_failures do
      yard = Bundler.definition.dependencies.find { it.name == "yard" }

      expect(yard.groups).to eq([ :development ])
      expect(yard.autorequire).to eq([])
      expect(Rails.root.join("Dockerfile").read).to include('BUNDLE_WITHOUT="development"')
    end
  end
end
