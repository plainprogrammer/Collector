require "rails_helper"

RSpec.describe NumberEntry::LineForm do
  let(:mh3) { create(:catalog_set, code: "mh3", name: "Modern Horizons 3") }
  let(:key) { "a" * 32 }

  def printing(number, language: "en", finishes: %w[nonfoil foil], **attributes)
    entry = create(:catalog_entry, set: mh3, number:, language:, **attributes)
    create(:mtg_printing, entry:, finishes:) if finishes
    entry
  end

  def line(number, quantity: "1", finish: nil, pick: nil, language: "en")
    described_class.new(set: mh3, language:, number:, quantity:, finish:, line_key: key, pick:)
  end

  describe ".normalize" do
    it "trims, ignores case and leading zeros, keeping one character", :aggregate_failures do
      expect([ " 007 ", "117A", "0", "00", "0a" ].map { described_class.normalize(it) }).to eq(%w[7 117a 0 0 a])
    end
  end

  describe "#matches (decision 8)" do
    it "finds an active entry ignoring spaces, case and leading zeros (AC-2.6)", :aggregate_failures do
      seven = printing("7")
      letter = printing("117a")
      expect(line("007").entry).to eq(seven)
      expect(line(" 7 ").entry).to eq(seven)
      expect(line("117A").entry).to eq(letter)
    end

    it "keeps to the chosen language (AC-2.7)" do
      english = printing("47")
      printing("47", language: "ja")
      expect(line("47").entry).to eq(english)
    end

    it "prefers an exact match over one that differs only in case (AC-2.8)", :aggregate_failures do
      lower = printing("12a")
      printing("12A")
      expect(line("12a")).to have_attributes(entry: lower, choice?: false)
    end

    it "asks for a choice when two entries match only ignoring zeros (AC-2.9)", :aggregate_failures do
      printing("049")
      printing("49")
      form = line("0049")
      expect(form.choice?).to be(true)
      expect(form.matches.map(&:number)).to eq(%w[049 49])
      expect(form.entry).to be_nil
    end

    it "takes a picked match, and refuses a pick that isn't one (AC-2.9, AC-2.10)", :aggregate_failures do
      picked = printing("049")
      printing("49")
      elsewhere = create(:catalog_entry, number: "49")
      expect(line("0049", pick: picked.external_key)).to be_valid
      expect(line("0049", pick: picked.external_key).entry).to eq(picked)
      expect(line("0049", pick: elsewhere.external_key)).not_to be_valid
      expect(line("0049", pick: printing("50").external_key)).not_to be_valid
    end

    it "never matches a retired entry", :aggregate_failures do
      printing("48", retired_at: 1.day.ago)
      form = line("48")
      expect(form).not_to be_valid
      expect(form.errors[:number]).to eq([ "No card numbered 48 in Modern Horizons 3 (EN)." ])
    end
  end

  describe "validation" do
    before { printing("47") }

    it "says when no entry has the number (AC-4.1)" do
      form = line("999")
      form.validate
      expect(form.errors[:number]).to eq([ "No card numbered 999 in Modern Horizons 3 (EN)." ])
    end

    it "takes a whole quantity from 1 to 9,999 (AC-4.2)", :aggregate_failures do
      %w[0 -1 2.5 x 10000].each do |quantity|
        form = line("47", quantity:)
        expect(form).not_to be_valid
        expect(form.errors[:quantity]).to eq([ "must be a whole number from 1 to 9,999" ]), quantity
      end
      expect(line("47", quantity: " 4 ")).to be_valid
    end

    it "refuses a finish the entry doesn't offer (AC-4.3)", :aggregate_failures do
      printing("50", finishes: %w[nonfoil])
      form = line("50", finish: "foil")
      expect(form).not_to be_valid
      expect(form.errors[:finish]).to eq([ "isn't available for this printing" ])
    end

    it "refuses a malformed line key" do
      form = described_class.new(set: mh3, language: "en", number: "47", line_key: "x")
      expect(form).not_to be_valid
    end

    it "treats an empty number as blank, not as an error (AC-4.5)", :aggregate_failures do
      expect(line("  ").blank_number?).to be(true)
      expect(line("47").blank_number?).to be(false)
    end
  end

  describe "#finish (decision 3)" do
    it "defaults to the type's first finish and keeps a chosen one", :aggregate_failures do
      expect(line("47").finish).to eq(Catalog.collecting_for("mtg").finish_order.first)
      expect(line("47", finish: "foil").finish).to eq("foil")
    end
  end

  describe "#add_attributes" do
    it "gives the entry, the quantity, the finish and the key", :aggregate_failures do
      entry = printing("47")
      expect(line("47", quantity: "4", finish: "foil").add_attributes).to eq(entry:, quantity: 4, finish: "foil", line_key: key)
    end

    it "gives no finish for an entry that lists none (AC-2.15)", :aggregate_failures do
      printing("60", finishes: nil)
      form = line("60")
      expect(form).to be_valid
      expect(form.add_attributes[:finish]).to be_nil
    end
  end
end
