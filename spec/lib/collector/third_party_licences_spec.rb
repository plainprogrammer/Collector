require "rails_helper"
require "tmpdir"

# Spec 087 decisions 2 to 5: the third-party software and assets in the image, read from the bundle and the manifest.
RSpec.describe Collector::ThirdPartyLicences, type: :model do
  let(:dir) { Pathname(Dir.mktmpdir("third-party-licences")) }

  after { FileUtils.remove_entry(dir) }

  describe ".gem_components" do
    it "shows a gem's licence files under their file names, in name order, and not other files (AC-3.1)", :aggregate_failures do
      gem = stand_in_gem(dir, files: { "MIT-LICENSE" => "mit text", "BSDL" => "bsd text", "LEGAL.rdoc" => "legal text", "README.md" => "readme" })
      dir.join("example/lib").mkpath
      dir.join("example/lib/LICENSE").write("nested")

      component = described_class.gem_components([ gem ]).first

      expect(component.texts).to eq([ [ "BSDL", "bsd text" ], [ "LEGAL.rdoc", "legal text" ], [ "MIT-LICENSE", "mit text" ] ])
    end

    it "takes the identifiers, version and home from the gem's metadata (AC-3.2)", :aggregate_failures do
      gem = stand_in_gem(dir, name: "multi", version: "4.5.6", licenses: [ "MIT", "Ruby" ], homepage: "https://multi.test/gem")

      component = described_class.gem_components([ gem ]).first

      expect([ component.name, component.version, component.identifiers, component.home ]).to eq([ "multi", "4.5.6", [ "MIT", "Ruby" ], "https://multi.test/gem" ])
      expect([ component.copyright, component.note ]).to eq([ nil, nil ])
    end

    it "shows no text for a gem that declares a licence and ships no file (AC-3.3)", :aggregate_failures do
      component = described_class.gem_components([ stand_in_gem(dir, licenses: [ "MIT" ]) ]).first

      expect(component.identifiers).to eq([ "MIT" ])
      expect(component.texts).to eq([])
    end

    it "sorts components by name, ignoring case" do
      specs = %w[zeta Alpha beta].map { stand_in_gem(dir, name: it) }

      expect(described_class.gem_components(specs).map(&:name)).to eq(%w[Alpha beta zeta])
    end

    it "shows no text for a gem whose directory isn't there (a default gem)" do
      gem = ThirdPartyLicencesHelpers::StandIn.new(name: "bundler", version: Gem::Version.new("2.7.0"), licenses: [ "MIT" ],
        homepage: nil, full_gem_path: dir.join("gone").to_s)

      expect(described_class.gem_components([ gem ]).first.texts).to eq([])
    end
  end

  describe ".texts_in" do
    it "skips a directory named like a licence file" do
      dir.join("LICENSE").mkpath
      dir.join("COPYING").write("copying text")

      expect(described_class.texts_in(dir)).to eq([ [ "COPYING", "copying text" ] ])
    end

    it "leaves out a file it can't read and keeps the others (AC-4.3)", :aggregate_failures do
      skip "root reads a file of mode 000" if Process.uid.zero?
      dir.join("LICENSE").write("secret")
      dir.join("LICENSE").chmod(0o000)
      dir.join("COPYING").write("copying text")

      expect { described_class.texts_in(dir) }.not_to raise_error
      expect(described_class.texts_in(dir)).to eq([ [ "COPYING", "copying text" ] ])
    end

    it "leaves out a file over 1 MiB and an empty one (AC-4.3)" do
      dir.join("LICENSE").write("x" * (described_class::MAX_TEXT_BYTES + 1))
      dir.join("COPYING").write("")
      dir.join("NOTICE").write("notice text")

      expect(described_class.texts_in(dir)).to eq([ [ "NOTICE", "notice text" ] ])
    end

    it "scrubs invalid UTF-8 (AC-4.3)", :aggregate_failures do
      dir.join("LICENSE").binwrite("caf\xE9 text".b)

      text = described_class.texts_in(dir).first.last

      expect(text).to be_valid_encoding
      expect(text).to include("text")
    end

    it "returns nothing for a directory that isn't there" do
      expect(described_class.texts_in(dir.join("nowhere"))).to eq([])
    end
  end

  describe ".safe_home" do
    it "keeps an absolute http or https address (AC-4.1)", :aggregate_failures do
      expect(described_class.safe_home("https://example.test/path")).to eq("https://example.test/path")
      expect(described_class.safe_home("http://example.test")).to eq("http://example.test")
    end

    it "gives no home for anything else (AC-4.1)", :aggregate_failures do
      [ "javascript:alert(1)", "", nil, "/relative", "ftp://example.test", "https://", "https://exa mple.test" ].each do |address|
        expect(described_class.safe_home(address)).to be_nil, "expected no home for #{address.inspect}"
      end
    end
  end

  describe ".build" do
    let(:text_dir) { dir.join("texts").tap(&:mkpath) }

    def write_manifest(sections)
      dir.join("manifest.yml").tap { it.write(sections.to_yaml) }
    end

    def build(sections, specs: [])
      described_class.build(specs:, manifest: write_manifest(sections), text_dir:)
    end

    def entry(name, **more) = { "name" => name, "version" => "1.0", "spdx" => "MIT", "home" => "https://#{name}.test" }.merge(more.transform_keys(&:to_s))

    it "has the five sections in page order with their titles (AC-1.5)", :aggregate_failures do
      sections = build({}).sections

      expect(sections.map(&:key)).to eq(%i[javascript ocr fonts icons gems])
      expect(sections.map(&:title)).to eq([ "JavaScript", "OCR engine", "Fonts", "Icons", "Ruby gems" ])
    end

    it "sorts each section's components by name, ignoring case", :aggregate_failures do
      instance = build({ "fonts" => [ entry("beta"), entry("Alpha"), entry("zeta") ] }, specs: [ stand_in_gem(dir, name: "b"), stand_in_gem(dir, name: "A") ])

      expect(instance.sections.find { it.key == :fonts }.components.map(&:name)).to eq(%w[Alpha beta zeta])
      expect(instance.sections.find { it.key == :gems }.components.map(&:name)).to eq(%w[A b])
    end

    it "shows an entry's texts under their titles and the fields it gives (AC-3.4)", :aggregate_failures do
      text_dir.join("one.txt").write("first text")
      text_dir.join("two.txt").write("second text")
      instance = build({ "ocr" => [ entry("engine", copyright: "Copyright 2020 Someone", texts: [ { "title" => "LICENSE.md", "file" => "one.txt" }, { "title" => "More", "file" => "two.txt" } ]) ] })

      component = instance.sections.find { it.key == :ocr }.components.first

      expect(component.texts).to eq([ [ "LICENSE.md", "first text" ], [ "More", "second text" ] ])
      expect([ component.version, component.identifiers, component.home, component.copyright ]).to eq([ "1.0", [ "MIT" ], "https://engine.test", "Copyright 2020 Someone" ])
    end

    it "shows no texts for an entry that says text: none, with its note and not its reason (AC-3.5)", :aggregate_failures do
      instance = build({ "ocr" => [ entry("data", text: "none", reason: "ships no text", note: "as the package declares") ] })

      component = instance.sections.find { it.key == :ocr }.components.first

      expect(component.texts).to eq([])
      expect(component.note).to eq("as the package declares")
      expect(component.to_h.values.flatten).not_to include("ships no text")
    end

    it "takes a gem entry's texts from that gem's files under their file names (AC-3.4)", :aggregate_failures do
      gem = stand_in_gem(dir, name: "turbo-rails", files: { "MIT-LICENSE" => "mit text" })
      instance = build({ "javascript" => [ entry("Turbo", gem: "turbo-rails") ] }, specs: [ gem ])

      expect(instance.sections.first.components.first.texts).to eq([ [ "MIT-LICENSE", "mit text" ] ])
    end

    it "shows no texts for a gem entry whose gem isn't in the bundle" do
      instance = build({ "javascript" => [ entry("Turbo", gem: "turbo-rails") ] }, specs: [ stand_in_gem(dir, name: "other", files: { "LICENSE" => "text" }) ])

      expect(instance.sections.first.components.first.texts).to eq([])
    end

    it "leaves out a text whose file is missing, empty or unreadable (AC-4.3)", :aggregate_failures do
      text_dir.join("empty.txt").write("")
      text_dir.join("ok.txt").write("ok text")
      texts = [ { "title" => "Gone", "file" => "gone.txt" }, { "title" => "Empty", "file" => "empty.txt" }, { "title" => "Ok", "file" => "ok.txt" } ]

      component = build({ "icons" => [ entry("Icons", texts:) ] }).sections.find { it.key == :icons }.components.first

      expect(component.texts).to eq([ [ "Ok", "ok text" ] ])
    end

    it "reads the gems of the running bundle, each answering the five readers (AC-1.5)", :aggregate_failures do
      specs = Bundler.load.specs.to_a

      expect(specs).not_to be_empty
      expect(specs.map { [ it.name, it.version, it.licenses, it.homepage, it.full_gem_path ] }.size).to eq(specs.size)
      expect(described_class.gem_components(specs).map(&:name)).to include("rails")
    end
  end

  describe ".load_manifest" do
    it "reads a manifest with string keys" do
      path = dir.join("manifest.yml")
      path.write("fonts:\n  - name: Plain\n")

      expect(described_class.load_manifest(path)).to eq({ "fonts" => [ { "name" => "Plain" } ] })
    end

    it "refuses an object tag instead of building the object (decision 3)" do
      path = dir.join("manifest.yml")
      path.write("fonts:\n  - !ruby/object:Object {}\n")

      expect { described_class.load_manifest(path) }.to raise_error(Psych::DisallowedClass)
    end
  end

  describe ".current" do
    after { described_class.reset }

    def counting_builder(calls) = -> { calls.push(:built).then { described_class.new([]) } }

    it "builds once and returns the same list afterwards (AC-1.8)", :aggregate_failures do
      calls = []
      builder = counting_builder(calls)

      first = described_class.current(builder:)

      expect(described_class.current(builder:)).to equal(first)
      expect(calls.size).to eq(1)
    end

    it "doesn't keep a build that raised, and tries again on the next call (AC-1.8)", :aggregate_failures do
      expect { described_class.current(builder: -> { raise "no manifest" }) }.to raise_error("no manifest")

      calls = []
      expect(described_class.current(builder: counting_builder(calls))).to be_a(described_class)
      expect(calls.size).to eq(1)
    end

    it "serves the list set with .current= until .reset", :aggregate_failures do
      replacement = described_class.new([ described_class::Section.new(key: :gems, title: "Ruby gems", components: []) ])
      described_class.current = replacement

      expect(described_class.current(builder: -> { raise "not asked" })).to equal(replacement)
      expect(replacement.sections.map(&:key)).to eq([ :gems ])
    end
  end

  describe "the third_party_licences helper" do
    def sections = [ described_class::Section.new(key: :gems, title: "Ruby gems", components: []) ]

    def counting_builder(calls) = -> { calls.push(:built).then { described_class.new([]) } }

    it "serves the sections it is given, and a reset brings the builder back", :aggregate_failures do
      replacement = third_party_licences(sections)
      expect(described_class.current(builder: -> { raise "not asked" })).to equal(replacement)

      described_class.reset
      calls = []
      described_class.current(builder: counting_builder(calls))

      expect(calls).to eq([ :built ])
    end

    context "when two examples run in order", order: :defined do
      it "replaces the list in the first" do
        expect(third_party_licences(sections).sections.map(&:key)).to eq([ :gems ])
      end

      it "finds the replacement gone in the next, with no reset of its own" do
        calls = []
        described_class.current(builder: counting_builder(calls))

        expect(calls).to eq([ :built ])
      end
    end
  end
end
