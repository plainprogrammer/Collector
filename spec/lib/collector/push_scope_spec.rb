require "rails_helper"
require "tmpdir"
require Rails.root.join("lib/collector/push_scope").to_s

# The pre-push hook's fast path (spec 035 decision 3, Story 3).
RSpec.describe Collector::PushScope do
  describe ".documentation_only?" do
    it "is true for documentation outside the code directories (AC-3.1)", :aggregate_failures do
      [
        "docs/adr/0001-x.md", "docs/specs/035-ci-shards/screenshots/a.png", "README.md",
        ".claude/memory/x.md", ".claude/rules/y.md"
      ].each do |path|
        expect(described_class.documentation_only?([ path ])).to be(true), path
      end
      expect(described_class.documentation_only?([ "docs/adr/0001-x.md", "README.md" ])).to be(true)
    end

    it "is false when a path is one of the exclusions (AC-3.1)", :aggregate_failures do
      [
        "docs/export-format/README.md", "docs/export-format/v3.schema.json",
        ".claude/settings.json", ".claude/settings.local.json", ".claude/hooks/notes.md", "config/ci.rb"
      ].each do |path|
        expect(described_class.documentation_only?([ "docs/a.md", path ])).to be(false), path
      end
    end

    it "is false for a Markdown file under every code directory (AC-3.1)", :aggregate_failures do
      expect(described_class::CODE_DIRS).to include("spec/")
      described_class::CODE_DIRS.each do |dir|
        expect(described_class.documentation_only?([ "#{dir}x.md" ])).to be(false), dir
      end
    end

    it "is false for a rename from code to Markdown, given as both names (AC-3.1)" do
      expect(described_class.documentation_only?([ "app/x.rb", "docs/x.md" ])).to be(false)
    end

    it "is false for a deleted code file (AC-3.1)" do
      expect(described_class.documentation_only?([ "lib/gone.rb", "docs/a.md" ])).to be(false)
    end

    it "is false for an empty list (AC-3.1)" do
      expect(described_class.documentation_only?([])).to be(false)
    end
  end

  describe ".push?" do
    it "detects a push with a git -C path, quoted or not", :aggregate_failures do
      [
        "git push", "cd /x && git push", "git -C /x push", "git -C \"/a b\" push", "git -C '/a b' push origin"
      ].each do |command|
        expect(described_class.push?(command)).to be(true), command
      end
    end

    it "ignores a command that only mentions push", :aggregate_failures do
      [ "grep push log", "git log --grep push", "echo pushed" ].each do |command|
        expect(described_class.push?(command)).to be(false), command
      end
    end
  end

  describe ".parse" do
    def parse(command, branch: "035-ci-shards") = described_class.parse(command, current_branch: branch)

    it "accepts the forms decision 3 lists (AC-3.2)", :aggregate_failures do
      [
        "git push", "git push origin", "git push -u origin 035-ci-shards",
        "git push --set-upstream origin HEAD", "git push origin 035-ci-shards",
        "cd /x && git push origin HEAD", "git -C /x push", "git -C \"/a b\" push",
        "git push origin 035-ci-shards 2>&1 | tail -3", "git push 2>&1"
      ].each do |command|
        result = parse(command)
        expect(result.accepted).to be(true), "#{command}: #{result.reason}"
      end
    end

    it "fills cd and git_c from the command", :aggregate_failures do
      expect(parse("cd /x && git push origin HEAD")).to have_attributes(cd: "/x", git_c: nil)
      expect(parse("git -C /x push")).to have_attributes(cd: nil, git_c: "/x")
      expect(parse("git -C \"/a b\" push")).to have_attributes(cd: nil, git_c: "/a b")
      expect(parse("git push")).to have_attributes(cd: nil, git_c: nil)
    end

    it "fills cd and git_c for a refused command too", :aggregate_failures do
      expect(parse("cd ../wt && git push --tags")).to have_attributes(accepted: false, cd: "../wt")
      expect(parse("git -C ../wt push --all")).to have_attributes(accepted: false, git_c: "../wt")
    end

    # Each refused command and the text its reason must contain.
    def refused_forms
      {
        "git push -u" => "-u",
        "git push origin other" => "other",
        "git push origin a:b" => "a:b",
        "git push origin a b" => "refspecs",
        "git push --tags" => "--tags",
        "git push origin v1.0.0" => "v1.0.0",
        "git push --all" => "--all",
        "git push --mirror" => "--mirror",
        "git push --delete origin x" => "--delete",
        "git push && git push" => "more than one",
        "make && git push" => "chain",
        "git push || git push --tags" => "||",
        "git push; git push --tags" => ";",
        "git push | tail -3 && git push --tags" => "more than one",
        "git push &" => "&",
        "git push | grep x" => "pipe",
        # Forms bash would expand or split into other words or commands (FR-4).
        "git push {origin,+HEAD:main}" => "`{`",
        "git push $(echo${IFS}origin${IFS}+HEAD:main)" => "`$`",
        "git push `echo origin`" => "`` ` ``",
        "git push \"$(x)\"" => "`$`",
        "git push *" => "`*`",
        "git push origin 035-ci-shard?" => "`?`",
        "git push origin [0]35-ci-shards" => "`[`",
        "git push ~/x" => "`~`",
        "git push < /dev/null" => "`<`",
        "git push > log" => "`>`",
        "cd \"$CLAUDE_PROJECT_DIR\" && git push" => "`$`",
        "git push\n./script/x" => "newline",
        "git push\nmake" => "newline",
        "git push\r./script/x" => "carriage return"
      }
    end

    it "refuses every other form with a reason naming it (AC-3.2)", :aggregate_failures do
      refused_forms.each do |command, form|
        result = parse(command)
        expect(result.accepted).to be(false), command
        expect(result.reason).to include(form), "#{command}: #{result.reason.inspect}"
      end
    end

    it "accepts HEAD but not a branch name when HEAD is detached" do
      expect([ parse("git push origin HEAD", branch: nil).accepted, parse("git push origin main", branch: nil).accepted ])
        .to eq([ true, false ])
    end
  end

  context "with a sandbox repository", :git_sandbox do
    let(:dir) { File.realpath(Dir.mktmpdir("push_scope")) }
    let(:repo) do
      new_repo(File.join(dir, "repo")).tap do |path|
        git!(dir, "init", "-q", "--bare", "origin.git")
        git!(path, "remote", "add", "origin", File.join(dir, "origin.git"))
        git!(path, "push", "-q", "origin", "main")
        git!(path, "switch", "-q", "-c", "feature")
      end
    end

    after { FileUtils.remove_entry(dir) }

    def commit(files)
      files.each do |path, body|
        FileUtils.mkdir_p(File.dirname(File.join(repo, path)))
        File.write(File.join(repo, path), body)
      end
      git!(repo, "add", "-A")
      git!(repo, "commit", "-q", "-m", "change")
    end

    describe ".changed_paths" do
      it "returns the branch's paths since the merge base, unquoted (AC-3.5)" do
        commit("docs/café.md" => "x\n", "README.md" => "y\n")

        expect(described_class.changed_paths(repo)).to contain_exactly("docs/café.md", "README.md")
      end

      it "returns both names of a rename" do
        commit("app/x.rb" => "puts 1\n" * 20)
        git!(repo, "push", "-q", "origin", "feature:main")
        git!(repo, "fetch", "-q", "origin")
        FileUtils.mkdir_p(File.join(repo, "docs"))
        git!(repo, "mv", "app/x.rb", "docs/x.md")
        git!(repo, "commit", "-q", "-m", "rename")

        expect(described_class.changed_paths(repo)).to contain_exactly("app/x.rb", "docs/x.md")
      end

      it "raises Unknown without origin/main" do
        git!(repo, "update-ref", "-d", "refs/remotes/origin/main")

        expect { described_class.changed_paths(repo) }.to raise_error(described_class::Unknown, /origin\/main/)
      end

      it "raises Unknown on a detached HEAD" do
        commit("docs/a.md" => "x\n")
        git!(repo, "switch", "-q", "--detach")

        expect { described_class.changed_paths(repo) }.to raise_error(described_class::Unknown, /detached/)
      end

      it "raises Unknown without a merge base" do
        git!(repo, "switch", "-q", "--orphan", "lonely")
        commit("docs/a.md" => "x\n")

        expect { described_class.changed_paths(repo) }.to raise_error(described_class::Unknown, /merge base/)
      end

      it "raises Unknown when git fails" do
        expect { described_class.changed_paths(dir) }.to raise_error(described_class::Unknown)
      end

      it "ignores the GIT_* variables of an enclosing hook" do
        commit("docs/a.md" => "x\n")
        previous = ENV.slice("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_COMMON_DIR")
        ENV.update("GIT_DIR" => File.join(dir, "nowhere"), "GIT_WORK_TREE" => dir,
                   "GIT_INDEX_FILE" => File.join(dir, "index"), "GIT_COMMON_DIR" => File.join(dir, "nowhere"))

        expect(described_class.changed_paths(repo)).to eq([ "docs/a.md" ])
      ensure
        %w[GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR].each { ENV[it] = previous&.fetch(it, nil) }
      end
    end

    describe ".current_branch" do
      it "names the branch, or nil when HEAD is detached", :aggregate_failures do
        expect(described_class.current_branch(repo)).to eq("feature")
        git!(repo, "switch", "-q", "--detach")
        expect(described_class.current_branch(repo)).to be_nil
      end
    end

    describe ".decide" do
      def decide(command, **options) = described_class.decide(command, directory: repo, current_branch: "feature", **options)

      it "runs bin/ci checks for a documentation-only branch and an accepted form (AC-3.3)" do
        commit("docs/a.md" => "x\n", "README.md" => "y\n")

        expect(decide("git push origin feature")).to eq([ [ "checks" ], "documentation-only branch (2 files): skipping RSpec" ])
      end

      it "runs the full bin/ci when the branch changes another path (AC-3.4)", :aggregate_failures do
        commit("docs/a.md" => "x\n", "docs/export-format/examples/valid/empty-v2.json" => "{}\n")

        args, reason = decide("git push")
        expect(args).to eq([])
        expect(reason).to include("not documentation-only")
      end

      it "runs the full bin/ci for a refused push form, saying why (AC-3.5)", :aggregate_failures do
        commit("docs/a.md" => "x\n")

        args, reason = decide("git push --tags")
        expect(args).to eq([])
        expect(reason).to include("--tags")
      end

      it "runs the full bin/ci when the changed paths are unknown (AC-3.5)", :aggregate_failures do
        commit("docs/a.md" => "x\n")
        git!(repo, "switch", "-q", "--detach")

        args, reason = decide("git push")
        expect(args).to eq([])
        expect(reason).to include("detached")
      end

      it "runs the full bin/ci when the classifier raises (AC-3.5)", :aggregate_failures do
        commit("docs/a.md" => "x\n")
        broken = Object.new
        def broken.documentation_only?(_paths) = raise(ArgumentError, "boom")

        args, reason = decide("git push", classifier: broken)
        expect(args).to eq([])
        expect(reason).to include("ArgumentError: boom")
      end
    end
  end
end
