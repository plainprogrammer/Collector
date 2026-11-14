require "rails_helper"
require "tmpdir"

# Spec 091 decisions 1, 2, 5 and 6 and Stories 1 and 2: the rules over injected sections and policy data, so each fails on a
# small fixture and passes on the baseline. The real tree is judged by the bin/ci checks step (AC-4.2).
RSpec.describe Collector::ThirdPartyLicences::Policy, type: :model do
  let(:path) { "config/licence_policy.yml" }

  def component(name, *identifiers, version: "1.0", texts: [])
    Collector::ThirdPartyLicences::Component.new(name:, version:, identifiers:, home: nil, copyright: nil, texts:, note: nil)
  end

  def section(key, *components, title: key.to_s.capitalize)
    Collector::ThirdPartyLicences::Section.new(key:, title:, components:)
  end

  def data(allowed: %w[MIT BSD-2-Clause Ruby], exceptions: [])
    { "allowed" => allowed.map { { "id" => it, "reason" => "a reason" } }, "exceptions" => exceptions }
  end

  def problems_for(*sections, data: data(), locked: [])
    described_class.new(data:, path:, sections:, locked_names: locked).problems
  end

  it "passes a bundle of allowed licences, a dual among them (AC-1.5)" do
    sections = [ section(:gems, component("rake", "MIT"), component("erb", "BSD-2-Clause", "Ruby")) ]

    expect(problems_for(*sections)).to be_empty
  end

  it "fails a gem under a licence off the list, naming the gem, its version, the licence and the policy file (AC-1.1)", :aggregate_failures do
    problems = problems_for(section(:gems, component("viral", "GPL-3.0-only", version: "2.1.0")))

    expect(problems.size).to eq(1)
    expect(problems.first).to include("gem viral 2.1.0", "GPL-3.0-only", path)
  end

  it "passes a gem with any one allowed licence and fails one with none, listing every one (AC-1.2)", :aggregate_failures do
    expect(problems_for(section(:gems, component("dual", "GPL-2.0-only", "MIT")))).to be_empty
    expect(problems_for(section(:gems, component("copyleft", "GPL-2.0-only", "Artistic-1.0-Perl"))).first)
      .to include("GPL-2.0-only", "Artistic-1.0-Perl")
  end

  it "fails a gem that declares no licence, and one whose string is not an exact allowed id (AC-1.3, AC-1.4)", :aggregate_failures do
    expect(problems_for(section(:gems, component("bare"))).first).to include("gem bare 1.0", "no licence")
    expect(problems_for(section(:gems, component("filed", texts: [ [ "LICENSE", "text" ] ]))).first).to include("gem filed 1.0", "no licence")
    %w[MIT\ License Apache\ 2.0 MIT\ OR\ Apache-2.0].each do |string|
      expect(problems_for(section(:gems, component("odd", string))).first).to include(string)
    end
  end

  it "reports every offender once, in the order the sections list them, each naming the file (AC-1.6)", :aggregate_failures do
    problems = problems_for(section(:javascript, component("alpha", "GPL-3.0-only")),
      section(:gems, component("charlie", "AGPL-3.0-only"), component("bravo", "LGPL-3.0-only")))

    expect(problems.size).to eq(3)
    expect(problems).to all(include(path))
    expect(problems.map { it[/alpha|bravo|charlie/] }).to eq(%w[alpha charlie bravo])
  end

  it "judges a manifest entry of every section by its identifiers, with decision 2's rule (AC-2.1, AC-2.2)", :aggregate_failures do
    %i[javascript ocr fonts icons].each do |key|
      problems = problems_for(section(key, component("pkg", "GPL-3.0-only"), title: "Kind"))

      expect(problems.first).to include("Kind", "\"pkg\"", "GPL-3.0-only", path)
    end
    expect(problems_for(section(:fonts, component("two", "OFL-1.1", "MIT")))).to be_empty
    expect(problems_for(section(:icons, component("none"))).first).to include("no licence")
  end

  describe "the policy's own shape (AC-3.3)" do
    def shape_problems(value) = problems_for(section(:gems), data: value)

    it "names an allowed entry without an id or a reason, a duplicate id, and a data that is not a mapping", :aggregate_failures do
      expect(shape_problems({ "allowed" => [ { "id" => "MIT" } ] }).first).to include(path, "allowed entry 1")
      expect(shape_problems({ "allowed" => [ { "reason" => "r" } ] }).first).to include("allowed entry 1")
      expect(shape_problems({ "allowed" => [ { "id" => "MIT", "reason" => "r" }, { "id" => "MIT", "reason" => "r" } ] }).first).to include("MIT", "twice")
      expect(shape_problems([ "MIT" ]).first).to include(path, "mapping")
    end

    it "names an exception missing its gem, licences or reason, and a duplicate gem", :aggregate_failures do
      bad = { "gem" => "x", "licences" => [], "reason" => "r" }
      ok = { "gem" => "y", "licences" => [ "GPL-3.0-only" ], "reason" => "r" }

      expect(shape_problems(data(exceptions: [ bad ])).first).to include("exception entry 1", "(x)")
      expect(shape_problems(data(exceptions: [ ok.except("reason") ])).first).to include("exception entry 1")
      expect(shape_problems(data(exceptions: [ ok, ok ])).first).to include("gem y", "twice")
    end

    it "judges nothing while the policy is malformed (it would report every gem)" do
      expect(problems_for(section(:gems, component("viral", "GPL-3.0-only")), data: { "allowed" => "MIT" }).size).to eq(1)
    end
  end

  describe ".for_repository" do
    it "reads the lockfile's gem names once each, with no `bundler` (AC-3.5)", :aggregate_failures do
      names = described_class.locked_names

      expect(names).to include("rails", "sqlite3")
      expect(names).to eq(names.uniq)
      expect(names).not_to include("bundler")
    end

    it "raises for a policy file it can't read, and reports a file that isn't a mapping (AC-3.3)", :aggregate_failures do
      Dir.mktmpdir("licence-policy") do |dir|
        list = File.join(dir, "list.yml")
        File.write(list, "- MIT\n")

        expect { described_class.for_repository(policy_path: File.join(dir, "absent.yml"), sections: []) }.to raise_error(SystemCallError)
        expect(described_class.for_repository(policy_path: list, sections: []).problems.first).to include(list.delete_prefix("#{Rails.root}/"), "mapping")
      end
    end
  end

  describe "exceptions (decision 3)" do
    let(:viral) { component("viral", "GPL-3.0-only") }
    let(:exception) { { "gem" => "viral", "licences" => [ "GPL-3.0-only" ], "reason" => "a tool, never loaded" } }

    def judged(exceptions, *components, locked: %w[viral], allowed: %w[MIT])
      problems_for(section(:gems, *components), data: data(allowed:, exceptions:), locked:)
    end

    it "lets a gem through that an exception names with exactly its licences, in any order (AC-3.1)", :aggregate_failures do
      expect(judged([ exception ], viral)).to be_empty
      two = { "gem" => "two", "licences" => %w[B A], "reason" => "r" }
      expect(judged([ two ], component("two", "A", "B"), locked: %w[two])).to be_empty
    end

    it "calls an exception stale when the lockfile no longer names the gem, the gem's licences changed, or it is allowed without it (AC-3.2)", :aggregate_failures do
      expect(judged([ exception ], locked: [])).to contain_exactly(a_string_including("viral", "lockfile"))
      changed = judged([ exception ], component("viral", "AGPL-3.0-only"))
      expect(changed).to include(a_string_including("viral", "AGPL-3.0-only", "GPL-3.0-only", "stale"))
      expect(changed.size).to eq(2) # the stale exception and the disallowed licence
      expect(judged([ exception ], viral, allowed: %w[MIT GPL-3.0-only])).to contain_exactly(a_string_including("viral", "allowed without it"))
    end

    it "judges nothing of a gem the lockfile names and the bundle doesn't hold, and calls no exception for it stale (AC-3.5)" do
      expect(judged([ exception ], locked: %w[viral])).to be_empty
    end

    it "applies to gems only: a manifest entry of the same name is judged by the list (AC-2.3)" do
      problems = problems_for(section(:javascript, viral, title: "JavaScript"), data: data(exceptions: [ exception ]), locked: %w[viral])

      expect(problems).to include(a_string_including("JavaScript entry", "GPL-3.0-only"))
    end

    describe "`all_required`" do
      let(:vcr) { component("vcr", "Hippocratic-2.1", "MIT") }
      let(:strict) { { "gem" => "vcr", "licences" => %w[Hippocratic-2.1 MIT], "all_required" => true, "reason" => "its MIT is not trusted" } }

      it "passes a dual gem as its allowed id with no exception, and by name with the exception (AC-3.6)", :aggregate_failures do
        expect(judged([], vcr, locked: %w[vcr])).to be_empty
        expect(judged([ strict ], vcr, locked: %w[vcr])).to be_empty
      end

      it "fails a gem whose exception's licences no longer match, because every licence must then be allowed (AC-3.6)", :aggregate_failures do
        problems = judged([ strict ], component("vcr", "Hippocratic-2.1", "MIT", "BSD-2-Clause"), locked: %w[vcr], allowed: %w[MIT BSD-2-Clause])

        expect(problems).to include(a_string_including("vcr", "Hippocratic-2.1", "every licence"))
        expect(problems).to include(a_string_including("stale"))
      end

      it "calls the exception stale once every licence is allowed (AC-3.6)" do
        expect(judged([ strict ], vcr, locked: %w[vcr], allowed: %w[MIT Hippocratic-2.1])).to contain_exactly(a_string_including("vcr", "stale", "allowed without it"))
      end
    end
  end
end
