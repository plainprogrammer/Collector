require "rails_helper"
require Rails.root.join("script/upgrade/release").to_s

RSpec.describe Upgrade::Release, :git_sandbox, :upgrade do
  let(:dir) { upgrade_dir }
  let(:tags) { %w[v0.1.0 v0.2.0 v0.2.1 v0.10.0 v0.11.0-rc.1] }
  let(:branch) { { "GITHUB_ACTIONS" => "true", "GITHUB_REF_TYPE" => "branch", "GITHUB_REF_NAME" => "main" } }

  def release(env = {}) = described_class.new(dir, env:)
  def tag_push(name) = { "GITHUB_ACTIONS" => "true", "GITHUB_REF_TYPE" => "tag", "GITHUB_REF_NAME" => name }
  def commit_tags(*names) = build_history(dir, names.index_with { |name| { "f" => name } })

  describe "Version" do
    it "orders by number, not text, and puts a pre-release before its release (semver precedence)", :aggregate_failures do
      order = %w[v0.2.1 v0.9.0 v0.10.0 v1.0.0-alpha v1.0.0-alpha.1 v1.0.0-alpha.beta v1.0.0-beta v1.0.0-beta.2 v1.0.0-beta.11 v1.0.0-rc.1 v1.0.0]
      versions = order.map { described_class::Version.parse(it) }
      expect(versions.shuffle(random: Random.new(1)).sort.map(&:tag)).to eq(order)
      expect(described_class::Version.parse("v0.2.1").number).to eq("0.2.1")
      expect(described_class::Version.parse("v0.2.1-rc.1")).not_to be_stable
    end

    it "parses only release tags" do
      expect(%w[0.2.1 v1.2 release-1 v1.2.3-rc_1 v1.2.3-].map { described_class::Version.parse(it) }).to all(be_nil)
    end
  end

  describe "#previous" do
    before { commit_tags(*tags) }

    it "is the newest stable tag on a branch or pull request, in numeric order, skipping pre-releases (AC-1.1)" do
      expect(release(branch).previous.tag).to eq("v0.10.0")
    end

    it "is the newest stable tag strictly older than the tag being built on a tag push (AC-1.2)" do
      expect(release(tag_push("v0.10.0")).previous.tag).to eq("v0.2.1")
    end

    it "is the newest stable tag below a pre-release's version when a pre-release is built" do
      expect(release(tag_push("v0.3.0-rc.1")).previous.tag).to eq("v0.2.1")
    end

    it "compares a local checkout at an older tag against its own predecessor" do
      git!(dir, "checkout", "-q", "v0.2.1")
      expect(release.previous.tag).to eq("v0.2.0")
    end

    it "is the newest stable tag for a local checkout of an untagged commit" do
      File.write(File.join(dir, "f"), "work")
      git!(dir, "commit", "-q", "-am", "work")
      expect(release.previous.tag).to eq("v0.10.0")
    end
  end

  describe "#previous when there is none" do
    it "is nil for the first tag's run (AC-1.2)" do
      commit_tags("v0.1.0")
      expect(release(tag_push("v0.1.0")).previous).to be_nil
    end

    it "is nil when tags are present and none is stable" do
      commit_tags("v0.1.0-rc.1")
      expect(release(branch).previous).to be_nil
    end

    it "is nil when there are no tags and no remote" do
      commit_tags("work")
      expect(release(branch).previous).to be_nil
    end

    it "fails, saying to fetch tags, when there is a remote and no tags at all (AC-8.5)" do
      commit_tags("work")
      git!(dir, "remote", "add", "origin", "https://example.invalid/collector.git")
      expect { release(branch).previous }.to raise_error(described_class::TagsNotFetched, /fetch/i)
    end

    it "tells a fork's contributor to fetch from the repository that publishes releases" do
      commit_tags("work")
      git!(dir, "remote", "add", "origin", "https://example.invalid/collector.git")
      expect { release(branch).previous }.to raise_error(described_class::TagsNotFetched, /git fetch <upstream> --tags/)
    end

    it "is nil, not a fetch failure, when there is a remote and only a tag that is no release (AC-8.5)" do
      commit_tags("work")
      git!(dir, "tag", "nightly")
      git!(dir, "remote", "add", "origin", "https://example.invalid/collector.git")
      expect(release(branch).previous).to be_nil
    end
  end

  describe "#building (AC-1.7)" do
    it "is no tag for a push to main whose commit is already tagged, and the previous release is the newest stable", :aggregate_failures do
      commit_tags("v0.2.1")
      expect(release(branch).building).to be_nil
      expect(release(branch).previous.tag).to eq("v0.2.1")
    end

    it "is the pushed tag" do
      commit_tags("v0.2.1")
      expect(release(tag_push("v0.2.1")).building.tag).to eq("v0.2.1")
    end

    it "is the tag at HEAD for a local checkout" do
      commit_tags("v0.2.1")
      expect(release.building.tag).to eq("v0.2.1")
    end

    it "is the tag of highest precedence when several point at HEAD" do
      commit_tags("v0.3.0-rc.1")
      git!(dir, "tag", "v0.3.0")
      expect(release.building.tag).to eq("v0.3.0")
    end

    it "refuses a pushed tag that is no release tag" do
      commit_tags("v0.2.1")
      expect { release(tag_push("nightly")).building }.to raise_error(described_class::Error, /not a release tag/)
    end
  end

  describe "the migration tree of a ref" do
    it "lists the files and versions of db/migrate at the ref, and shows a file as it was", :aggregate_failures do
      build_history(dir, "v0.1.0" => { "db/migrate/20261001000001_create_a.rb" => "a\n" },
        "v0.2.0" => { "db/migrate/20261002000001_create_b.rb" => "b\n", "db/migrate/20261001000001_create_a.rb" => "changed\n" })
      files = release.migration_files("v0.1.0")
      expect(files).to eq([ "db/migrate/20261001000001_create_a.rb" ])
      expect(release.migration_versions("v0.2.0")).to eq(%w[20261001000001 20261002000001])
      expect(release.show("v0.1.0", files.first)).to eq("a\n")
      expect(release.ancestor?("v0.1.0")).to be(true)
    end
  end
end
