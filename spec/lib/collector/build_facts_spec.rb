require "rails_helper"

# Spec 084 decisions 2, 4, 6 and 10: what the running build's facts read, from the environment and, in development, git.
RSpec.describe Collector::BuildFacts, type: :model do
  let(:sha) { "a9f6de7c0ffee1234567890abcdef1234567890a" } # 40 hexadecimal characters

  # Counts git's calls: a git that raised would be swallowed by the reader's rescue, so a stray call is caught by count.
  def git_calls = @git_calls ||= []

  def counting_git(answer = sha) = -> { git_calls.push(:asked).then { answer } }

  # Braceless `"NAME" => value` arguments bind as keywords, so `**given` collects them with an explicit hash.
  def read(env = {}, rails_env: "production", git: counting_git, **given) = described_class.read(env: env.merge(given), rails_env:, git:)

  def text(facts) = facts.licence_parts.map(&:first).join

  def links(facts) = facts.licence_parts.select(&:last)

  describe ".read" do
    it "takes a release's facts as given (AC-2.1)", :aggregate_failures do
      facts = read("COLLECTOR_VERSION" => "0.3.0", "COLLECTOR_REVISION" => sha,
        "COLLECTOR_SOURCE_URL" => "https://github.com/plainprogrammer/Collector/tree/#{sha}")

      expect([ facts.version, facts.revision, facts.short_revision ]).to eq([ "0.3.0", sha, "a9f6de7" ])
      expect(facts.source_url).to eq("https://github.com/plainprogrammer/Collector/tree/#{sha}")
    end

    it "knows nothing, and links upstream, when nothing is given outside development (AC-2.4)" do
      expect([ read.version, read.revision, read.source_url ]).to eq([ nil, nil, "https://github.com/plainprogrammer/Collector" ])
    end

    it "reads development and HEAD from git in development (AC-2.5)" do
      facts = read(rails_env: "development", git: -> { "#{sha}\n" })

      expect([ facts.version, facts.revision, facts.source_url ]).to eq([ "development", sha, "https://github.com/plainprogrammer/Collector" ])
    end

    it "keeps a given fact in development and asks git only for the revision it lacks (decision 4)", :aggregate_failures do
      expect(read({ "COLLECTOR_VERSION" => "0.3.0" }, rails_env: "development").version).to eq("0.3.0")
      expect(git_calls.size).to eq(1)
      expect(read({ "COLLECTOR_REVISION" => sha }, rails_env: "development").revision).to eq(sha)
      expect(git_calls.size).to eq(1)
    end

    it "gives no revision, and raises nothing, when git is missing, fails or answers no SHA (AC-2.6)", :aggregate_failures do
      [ -> { raise Errno::ENOENT, "git" }, -> { nil }, -> { "fatal: not a git repository\n" }, -> { sha.first(7) } ].each do |git|
        facts = read(rails_env: "development", git:)
        expect([ facts.version, facts.revision ]).to eq([ "development", nil ])
      end
    end

    it "never asks git in test or production (AC-2.10)" do
      %w[test production].each { |rails_env| read(rails_env:) }

      expect(git_calls).to be_empty
    end

    it "never raises, on a byte that isn't UTF-8 or an address URI can't parse (decision 6)", :aggregate_failures do
      facts = read("COLLECTOR_VERSION" => "0.3.0\xFF", "COLLECTOR_REVISION" => "\xFF" * 40, "COLLECTOR_SOURCE_URL" => "https://\xFF")

      expect([ facts.version, facts.revision, facts.source_url ]).to eq([ nil, nil, "https://github.com/plainprogrammer/Collector" ])
      expect(read("COLLECTOR_SOURCE_URL" => "https://exa mple.test/%zz").source_url).to eq("https://github.com/plainprogrammer/Collector")
    end

    it "drops a version that breaks the rule (AC-2.7)", :aggregate_failures do
      [ "", "x" * 65, "0.3 .0", "<b>", "0.3.0;rm" ].each do |version|
        expect(read("COLLECTOR_VERSION" => version).version).to be_nil, version.inspect
      end
      expect(read("COLLECTOR_VERSION" => "0.4.0-rc.1+b_2").version).to eq("0.4.0-rc.1+b_2")
      expect(read("COLLECTOR_VERSION" => "x" * 64).version).to eq("x" * 64)
    end

    it "drops a revision that isn't 40 hexadecimal characters (AC-2.8)", :aggregate_failures do
      [ sha.first(7), sha.first(39), "g#{sha.first(39)}", "#{sha}0" ].each do |revision|
        expect(read("COLLECTOR_REVISION" => revision).revision).to be_nil, revision
      end
    end

    it "links upstream for an address that isn't absolute https with a host (AC-2.9)", :aggregate_failures do
      [ "http://example.test/src", "javascript:alert(1)", "/src", "https://", "https:///x", "not a uri" ].each do |address|
        expect(read("COLLECTOR_SOURCE_URL" => address).source_url).to eq("https://github.com/plainprogrammer/Collector"), address
      end
    end

    it "trims each fact and lowercases the revision (AC-2.11, AC-2.12)", :aggregate_failures do
      facts = read("COLLECTOR_VERSION" => " 0.3.0\n", "COLLECTOR_REVISION" => "#{sha.upcase}\n",
        "COLLECTOR_SOURCE_URL" => " https://example.test/src \n")

      expect([ facts.version, facts.revision, facts.short_revision ]).to eq([ "0.3.0", sha, "a9f6de7" ])
      expect(facts.source_url).to eq("https://example.test/src")
    end
  end

  describe "#licence_parts" do
    it "reads each row of decision 2's table", :aggregate_failures do
      tail = " is free software under the AGPL-3.0. Get the source code."
      expect(text(read("COLLECTOR_VERSION" => "0.3.0", "COLLECTOR_REVISION" => sha))).to eq("Collector 0.3.0 (a9f6de7)#{tail}")
      expect(text(read("COLLECTOR_VERSION" => "0.3.0"))).to eq("Collector 0.3.0#{tail}")
      expect(text(read("COLLECTOR_VERSION" => "bad version", "COLLECTOR_REVISION" => sha))).to eq("Collector (unknown version, a9f6de7)#{tail}")
      expect(text(read)).to eq("Collector (unknown version)#{tail}")
    end

    it "puts its two links on the fixed words, whatever the version says (AC-1.4, AC-2.13)", :aggregate_failures do
      [ "AGPL-3.0", "source-code" ].each do |version|
        facts = read("COLLECTOR_VERSION" => version, "COLLECTOR_REVISION" => sha, "COLLECTOR_SOURCE_URL" => "https://example.test/src")
        expect(links(facts)).to eq([ [ "AGPL-3.0", "https://www.gnu.org/licenses/agpl-3.0.html" ], [ "source code", "https://example.test/src" ] ])
        expect(facts.licence_parts.first).to eq([ "Collector #{version} (a9f6de7) is free software under the ", nil ])
      end
    end
  end

  describe ".current" do
    it "is read at boot from nothing in the test environment (AC-2.4, decision 10)" do
      expect([ described_class.current.version, described_class.current.revision ]).to eq([ nil, nil ])
    end

    it "is replaced by the spec helper with raw values, cleaned as the image's would be (decision 10)", :aggregate_failures do
      build_facts(version: " 0.3.0\n", revision: "A" * 40, source_url: "http://insecure.test")

      expect([ described_class.current.version, described_class.current.revision ]).to eq([ "0.3.0", "a" * 40 ])
      expect(described_class.current.source_url).to eq("https://github.com/plainprogrammer/Collector")
    end

    it "puts the boot reading back (the suite's after hook)" do
      boot = described_class.current
      build_facts(version: "1.0.0")
      restore_build_facts

      expect(described_class.current).to equal(boot)
    end
  end
end
