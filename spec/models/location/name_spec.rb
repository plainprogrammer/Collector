require "rails_helper"

# Spec 029 decision 5: one function makes what a collector types, and what a file holds, into a name.
RSpec.describe Location::Name, type: :model do
  describe ".normalise" do
    it "makes NFC (AC-1.11)" do
      expect(described_class.normalise("Café")).to eq("Café")
    end

    it "trims White_Space at both ends and makes each run inside one space (AC-1.5)", :aggregate_failures do
      expect(described_class.normalise("  Blue   binder ")).to eq("Blue binder")
      [ " ", "　", "\t", "\u0085", " ", "\n" ].each do |space|
        expect(described_class.normalise("Blue#{space}binder")).to eq("Blue binder"), space.dump
        expect(described_class.normalise("#{space}Blue binder#{space}")).to eq("Blue binder"), space.dump
      end
    end

    it "leaves a Cc or Cf character that isn't White_Space for .fault to refuse", :aggregate_failures do
      expect(described_class.normalise("a​b")).to eq("a​b")
      expect(described_class.normalise("a\u0007b")).to eq("a\u0007b")
      expect(described_class.normalise("日本語のバインダー")).to eq("日本語のバインダー")
    end

    it "returns text that isn't valid UTF-8 as it is, and nil as empty", :aggregate_failures do
      broken = "a\xFFb".dup.force_encoding(Encoding::UTF_8)

      expect(described_class.normalise(broken)).to eq(broken)
      expect(described_class.normalise(nil)).to eq("")
    end
  end

  describe ".key" do
    it "is the Unicode full case folding of the normalised name (decision 5)", :aggregate_failures do
      expect(described_class.key("Blue binder")).to eq("blue binder")
      expect(described_class.key("Straße")).to eq(described_class.key("STRASSE"))
      expect(described_class.key(described_class.normalise("Café"))).to eq(described_class.key("CAFÉ"))
    end
  end

  describe ".fault" do
    it "is nil for a name of 1 to 60 code points with no Cc or Cf character", :aggregate_failures do
      expect(described_class.fault("Blue binder")).to be_nil
      expect(described_class.fault("a" * 60)).to be_nil
      expect(described_class.fault("本" * 60)).to be_nil # 180 bytes of UTF-8, 60 code points (AC-1.7)
    end

    it "names each fault", :aggregate_failures do
      expect(described_class.fault("")).to eq(:blank)
      expect(described_class.fault("a" * 61)).to eq(:too_long)
      expect(described_class.fault("本" * 61)).to eq(:too_long)
      [ "\u0000", "\u0007", "​", "‎", "﻿" ].each { |char| expect(described_class.fault("a#{char}b")).to eq(:control), char.dump }
      expect(described_class.fault("a\xFFb".dup.force_encoding(Encoding::UTF_8))).to eq(:control)
    end
  end
end
