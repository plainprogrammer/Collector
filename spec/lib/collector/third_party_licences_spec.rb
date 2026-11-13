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
end
