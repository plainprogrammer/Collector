require "rails_helper"

# Spec 018 FR-1 and FR-2: the lines every page's footer shows, and how one line's links are read.
RSpec.describe Catalog::ContentNotice, type: :model do
  describe ".lines" do
    # Only test-only types are registered here, so these examples hold whatever the app's own types supply.
    around { |example| with_catalog_sources({}) { example.run } }

    let(:owner) { notice_line("Zeta is shown with its owner's leave.") }
    let(:credit) { notice_line("Data from Zeta Base.", "Zeta Base" => "https://zeta.test") }

    it "gives types in registration order, each type's lines in the order its source supplies them (AC-2.1)" do
      register_notice_catalog("zeta", owner, credit)
      register_notice_catalog("eta", notice_line("Data from Eta."))

      expect(described_class.lines.map(&:text)).to eq([ "Zeta is shown with its owner's leave.", "Data from Zeta Base.", "Data from Eta." ])
    end

    it "takes nothing from a source without the hook (AC-2.2)" do
      Catalog.sources["other"] = "OtherCatalogSource"
      register_notice_catalog("zeta", owner)

      expect(described_class.lines).to eq([ owner ])
    end

    it "takes nothing from a hook that gives nil or no lines" do
      register_notice_catalog("eta") { nil }
      register_notice_catalog("theta")
      register_notice_catalog("zeta", owner)

      expect(described_class.lines).to eq([ owner ])
    end

    it "is empty when no type supplies a notice, or none is registered (AC-2.3)", :aggregate_failures do
      expect(described_class.lines).to eq([])

      Catalog.sources["other"] = "OtherCatalogSource"
      expect(described_class.lines).to eq([])
    end

    it "shows a line two types supply once, where the first type puts it (AC-2.4)" do
      register_notice_catalog("zeta", owner, credit)
      register_notice_catalog("eta", notice_line("Data from Eta."), notice_line("  #{credit.text} ", credit.links))

      expect(described_class.lines.map(&:text)).to eq([ owner.text, credit.text, "Data from Eta." ])
    end

    it "keeps two lines with the same text and different links apart" do
      register_notice_catalog("zeta", notice_line(credit.text), credit)

      expect(described_class.lines.map(&:links)).to eq([ {}, { "Zeta Base" => "https://zeta.test" } ])
    end

    it "never gives a blank line" do
      register_notice_catalog("zeta", notice_line(""), notice_line(" \n "), notice_line(nil), owner)

      expect(described_class.lines).to eq([ owner ])
    end

    it "doesn't rescue a hook that raises" do
      register_notice_catalog("zeta") { raise "broken source" }

      expect { described_class.lines }.to raise_error("broken source")
    end
  end

  describe "Line#parts" do
    it "is the whole text when the line has no links" do
      expect(notice_line("Data from Zeta Base.").parts).to eq([ [ "Data from Zeta Base.", nil ] ])
    end

    it "splits the text around a link's phrase" do
      expect(notice_line("Data from Zeta Base.", "Zeta Base" => "https://zeta.test/about").parts)
        .to eq([ [ "Data from ", nil ], [ "Zeta Base", "https://zeta.test/about" ], [ ".", nil ] ])
    end

    it "puts links in reading order whatever order they were given in, with nothing empty between them" do
      line = notice_line("Zeta Base and Eta", "Eta" => "https://eta.test", "Zeta Base" => "https://zeta.test")

      expect(line.parts).to eq([ [ "Zeta Base", "https://zeta.test" ], [ " and ", nil ], [ "Eta", "https://eta.test" ] ])
    end

    it "accepts an https scheme in any case" do
      expect(notice_line("Zeta", "Zeta" => "HTTPS://zeta.test").parts).to eq([ [ "Zeta", "HTTPS://zeta.test" ] ])
    end

    [ [ "a phrase that isn't in the text", { "Eta" => "https://eta.test" } ],
      [ "a phrase in another case", { "zeta base" => "https://zeta.test" } ],
      [ "a phrase that occurs twice", { "Zeta" => "https://zeta.test" } ],
      [ "phrases that overlap", { "Zeta Base" => "https://zeta.test", "Base of" => "https://eta.test" } ],
      [ "an empty phrase", { "" => "https://zeta.test" } ],
      [ "an http address", { "Zeta Base" => "http://zeta.test" } ],
      [ "a script address", { "Zeta Base" => "javascript:alert(1)" } ],
      [ "a relative address", { "Zeta Base" => "/about" } ],
      [ "a bare host", { "Zeta Base" => "zeta.test" } ],
      [ "an address that isn't a URI", { "Zeta Base" => "https://zeta test" } ],
      [ "one good link and one bad", { "Zeta Base" => "https://zeta.test", "data" => "http://eta.test" } ]
    ].each do |fault, links|
      it "is plain text, with no link at all, for #{fault}" do
        text = "Zeta Base of Zeta data."

        expect(notice_line(text, links).parts).to eq([ [ text, nil ] ])
      end
    end

    it "counts a phrase that overlaps itself as occurring twice" do
      expect(notice_line("aaa", "aa" => "https://zeta.test").parts).to eq([ [ "aaa", nil ] ])
    end
  end

  describe "Line" do
    it "trims its text and compares by text and links", :aggregate_failures do
      expect(notice_line("  Data from Zeta Base.\n")).to eq(notice_line("Data from Zeta Base."))
      expect(notice_line("Zeta", "Zeta" => "https://zeta.test")).not_to eq(notice_line("Zeta"))
      expect(notice_line("Zeta", Zeta: "https://zeta.test")).to eq(notice_line("Zeta", "Zeta" => "https://zeta.test"))
    end

    it "keeps a phrase plain text even when a source marked it html_safe" do
      phrase, address = notice_line("Zeta".html_safe, "Zeta".html_safe => "https://zeta.test".html_safe).parts.first

      expect([ phrase, address ].map(&:html_safe?)).to eq([ false, false ])
    end
  end
end
