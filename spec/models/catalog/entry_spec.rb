require "rails_helper"

RSpec.describe Catalog::Entry, type: :model do
  describe ".named_like" do
    it "matches part of the name, ignoring ASCII case", :aggregate_failures do
      bolt = create(:catalog_entry, name: "Lightning Bolt")
      create(:catalog_entry, name: "Lightning Helix")

      expect(described_class.named_like("LIGHTNING bo")).to contain_exactly(bolt)
    end

    it "matches the localized name" do
      ja = create(:catalog_entry, name: "Lightning Bolt", localized_name: "稲妻", language: "ja")

      expect(described_class.named_like("稲妻")).to contain_exactly(ja)
    end

    it "treats % and _ literally" do
      create(:catalog_entry, name: "Fires of Yavimaya")

      expect(described_class.named_like("Fire_")).to be_empty
    end
  end

  describe ".searchable" do
    it "excludes retired entries and non-card kinds" do
      card = create(:catalog_entry)
      create(:catalog_entry, :retired)
      create(:catalog_entry, kind: "token")

      expect(described_class.searchable).to contain_exactly(card)
    end
  end

  describe ".in_set" do
    it "restricts to one set code and ignores a blank code", :aggregate_failures do
      a = create(:catalog_entry, set: create(:catalog_set, code: "aaa"))
      b = create(:catalog_entry, set: create(:catalog_set, code: "bbb"))

      expect(described_class.in_set("aaa")).to contain_exactly(a)
      expect(described_class.in_set("")).to contain_exactly(a, b)
    end
  end

  describe ".printed_as" do
    it "finds active printings by set code, number and language", :aggregate_failures do
      set = create(:catalog_set, code: "mom")
      match = create(:catalog_entry, set:, number: "123")
      create(:catalog_entry, set:, number: "123", language: "ja")
      create(:catalog_entry, :retired, set:, number: "123")
      expect(described_class.printed_as(set_code: "MOM", number: "123", language: "en")).to eq([ match ])
      expect(described_class.printed_as(set_code: "mom", number: "124", language: "en")).to be_empty
    end
  end

  describe ".newest_first" do
    it "orders by release date, then set code, number and language" do
      old = create(:catalog_entry, released_on: Date.new(2001, 1, 1))
      new_b = create(:catalog_entry, released_on: Date.new(2020, 1, 1), set: create(:catalog_set, code: "bbb"))
      new_a = create(:catalog_entry, released_on: Date.new(2020, 1, 1), set: create(:catalog_set, code: "aaa"))

      expect(described_class.newest_first.to_a).to eq([ new_a, new_b, old ])
    end

    # Collector numbers compare numerically, with the text as the tiebreak (#204 ruling 3).
    context "with the printings of one card in one set" do
      let(:forest) { create(:catalog_identity, name: "Forest") }
      let(:znr) { create(:catalog_set, code: "znr", name: "Zendikar Rising", released_on: Date.new(2020, 9, 25)) }

      def printed(number, **attributes) = create(:catalog_entry, identity: forest, set: znr, number:, **attributes)

      it "compares collector numbers as numbers, not as text", :aggregate_failures do
        entries = %w[12a 100 10 2 12 1].map { |number| printed(number) }

        expect(described_class.newest_first.map(&:number)).to eq(%w[1 2 10 12 12a 100])
        expect(described_class.newest_first.to_a).to match_array(entries)
      end

      it "breaks a tie in the number's value by its text, then by language", :aggregate_failures do
        %w[10 010 10a 9★ 10 ].each_with_index { |number, i| printed(number, language: i == 4 ? "ja" : "en") }

        expect(described_class.newest_first.map { |entry| [ entry.number, entry.language ] })
          .to eq([ [ "9★", "en" ], [ "010", "en" ], [ "10", "en" ], [ "10", "ja" ], [ "10a", "en" ] ])
      end

      it "puts a number with no leading digits after the numbered ones, in text order", :aggregate_failures do
        [ "★", "301", "P2", "2", "★2", "0", "P10", "s1", "-1", "#5" ].each { |number| printed(number) }

        expect(described_class.newest_first.map(&:number)).to eq([ "0", "2", "301", "#5", "-1", "P10", "P2", "s1", "★", "★2" ])
      end

      it "lets the set order outrank the number", :aggregate_failures do
        later = create(:catalog_set, code: "afr", released_on: Date.new(2021, 7, 23))
        low = create(:catalog_entry, identity: forest, set: later, number: "300")
        high_in_old = printed("2")
        same_day = create(:catalog_set, code: "zzz", released_on: Date.new(2021, 7, 23))
        tail = create(:catalog_entry, identity: forest, set: same_day, number: "1")

        expect(described_class.newest_first.to_a).to eq([ low, tail, high_in_old ])
      end

      it "stays chainable with the other conditions, a limit and an offset", :aggregate_failures do
        printed("10")
        two = printed("2")
        printed("1", retired_at: 1.day.ago)
        scope = described_class.searchable.in_set("znr").where(catalog_identity_id: forest.id)

        expect(scope.newest_first.limit(1).to_a).to eq([ two ])
        expect(scope.newest_first.offset(1).map(&:number)).to eq(%w[10])
      end
    end
  end

  describe "#display_name" do
    it "uses the printed name of a non-English printing" do
      expect(build(:catalog_entry, name: "Lightning Bolt", localized_name: "稲妻", language: "ja").display_name).to eq("稲妻")
    end

    it "uses the card name of an English printing with a stylized printed name" do
      expect(build(:catalog_entry, name: "Serra Angel", localized_name: "SERRA ANGEL", language: "en").display_name).to eq("Serra Angel")
    end

    it "falls back to the card name without a printed name" do
      expect(build(:catalog_entry, name: "Opt", localized_name: nil, language: "de").display_name).to eq("Opt")
    end
  end

  it "is addressed by its external key" do
    expect(build(:catalog_entry, external_key: "abc-123").to_param).to eq("abc-123")
  end

  describe "#deck_addable? (spec 071 decision 2)" do
    it "is true for a live card of a type with a vocabulary and a source, and reads nothing from the database", :aggregate_failures do
      entry = create(:catalog_entry)
      expect(entry).to be_deck_addable
      expect(count_queries { entry.deck_addable? }).to eq(0)
    end

    it "is false for a retired printing and a token", :aggregate_failures do
      expect(create(:catalog_entry, :retired)).not_to be_deck_addable
      expect(create(:catalog_entry, kind: "token")).not_to be_deck_addable
    end

    it "is false for a type that has a vocabulary and no source, and for one that has neither", :aggregate_failures, :other_collecting do
      expect(Catalog.collecting).to have_key("other") # the control: the vocabulary is there, the source is not
      expect(Catalog.sources).not_to have_key("other")
      expect(create(:catalog_entry, collectible_type: "other")).not_to be_deck_addable
      expect(create(:catalog_entry, collectible_type: "unregistered")).not_to be_deck_addable
    end
  end
end
