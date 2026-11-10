require "rails_helper"

# Spec 029: a location is a name in an account, unique by comparison key.
RSpec.describe Location, type: :model do
  let(:user) { create(:user) }
  let(:account) { user.account }

  def add(name, to: account) = to.locations.new(name:).tap(&:save)

  def reasons(location) = location.errors.messages_for(:name)

  describe "a name" do
    it "is stored in normal form with its comparison key (AC-1.5, AC-1.11)", :aggregate_failures do
      location = add("  Café   Box ")

      expect(location).to be_persisted
      expect(location.name).to eq("Café Box")
      expect(location.name_key).to eq("café box")
      expect(location.typed).to eq("  Café   Box ")
    end

    it "is refused when blank, with the reason (AC-1.6)", :aggregate_failures do
      [ "", "   ", "　\t" ].each do |blank|
        location = add(blank)
        expect(location).not_to be_persisted
        expect(reasons(location)).to eq([ "Give the location a name." ])
      end
    end

    it "is refused over 60 code points, whatever the bytes (AC-1.7)", :aggregate_failures do
      expect(add("a" * 61).errors.messages_for(:name)).to eq([ "Names can be at most 60 characters." ])
      expect(add("a" * 60)).to be_persisted
      expect(add("本" * 60)).to be_persisted
      expect(add("本" * 61)).not_to be_persisted
    end

    it "is refused with a control or format character, and collapses the White_Space between words (AC-1.8)", :aggregate_failures do
      [ "\u0000", "\u0007", "​", "‎", "﻿" ].each do |char|
        expect(reasons(add("a#{char}b"))).to eq([ "Names can't contain control characters." ]), char.dump
      end
      [ "\t", "\u0085", " " ].each_with_index do |space, index|
        expect(add("Box#{index}#{space}two").name).to eq("Box#{index} two")
      end
    end

    it "is refused when it has the key of another location, quoting the normalised name (AC-1.9)", :aggregate_failures do
      add("Blue binder")
      add("Straße")
      add("Café")

      expect(reasons(add("  blue   BINDER "))).to eq([ "You already have a location called “blue BINDER”." ])
      expect(reasons(add("STRASSE"))).to eq([ "You already have a location called “STRASSE”." ])
      expect(reasons(add("Café"))).to eq([ "You already have a location called “Café”." ])
      expect(account.locations.count).to eq(3)
    end

    it "may repeat another account's name (AC-4.2)" do
      add("Blue binder", to: create(:user).account)

      expect(add("Blue binder")).to be_persisted
    end

    it "is judged again on a rename: its own key is allowed, another's is not (AC-2.3, AC-2.4)", :aggregate_failures do
      box = add("box")
      add("Trade binder")

      box.name = "Box"
      expect(box.save).to be(true)
      expect(box.reload.name).to eq("Box")

      box.name = "TRADE binder"
      expect(box.save).to be(false)
      expect(reasons(box)).to eq([ "You already have a location called “TRADE binder”." ])
      expect(box.reload.name).to eq("Box")

      box.name = "Box"
      expect(box.save).to be(true) # its own name (AC-2.6)
    end
  end

  describe "the limit (decision 7, AC-1.10, AC-1.13)" do
    def fill(count)
      Location.insert_all!(Array.new(count) { |index| { account_id: account.id, name: "Place #{index}", name_key: "place #{index}" } })
    end

    it "refuses the 501st location and allows the 500th", :aggregate_failures do
      fill(499)

      expect(add("The 500th")).to be_persisted
      refused = add("The 501st")
      expect(refused).not_to be_persisted
      expect(reasons(refused)).to eq([ "You can have at most 500 places and decks together." ])
      expect(account.locations.count).to eq(500)
    end

    it "counts only this account's locations" do
      fill(500)

      expect(add("Elsewhere", to: create(:user).account)).to be_persisted
    end
  end

  describe "the database's own rules" do
    it "answers false with the duplicate message when the unique index refuses a save that validation let through (race)", :aggregate_failures do
      location = account.locations.new(name: "Box")
      described_class.insert!({ account_id: account.id, name: "box", name_key: "box" }) # another request won the race

      expect(location.save(validate: false)).to be(false)
      expect(reasons(location)).to eq([ "You already have a location called “Box”." ])
      expect(account.locations.count).to eq(1)
    end

    it "raises RecordInvalid with the duplicate message from save!, update! and create! when the unique index refuses (race)", :aggregate_failures do
      described_class.insert!({ account_id: account.id, name: "box", name_key: "box" }) # another request won the race
      lost = account.locations.new(name: "Box")
      renamed = account.locations.create!(name: "Other")
      renamed.name = "Box"

      expect { lost.save!(validate: false) }.to raise_error(ActiveRecord::RecordInvalid, /You already have a location called “Box”/)
      expect { renamed.save!(validate: false) }.to raise_error(ActiveRecord::RecordInvalid, /You already have a location called “Box”/)
      expect(reasons(lost)).to eq([ "You already have a location called “Box”." ])
      expect(account.locations.pluck(:name)).to contain_exactly("box", "Other")
    end

    it "refuses a name outside 1 to 60 characters, and an empty key, at the table", :aggregate_failures do
      expect { described_class.insert!({ account_id: account.id, name: "", name_key: "x" }) }.to raise_error(ActiveRecord::StatementInvalid)
      expect { described_class.insert!({ account_id: account.id, name: "a" * 61, name_key: "x" }) }.to raise_error(ActiveRecord::StatementInvalid)
      expect { described_class.insert!({ account_id: account.id, name: "x", name_key: "" }) }.to raise_error(ActiveRecord::StatementInvalid)
    end
  end

  describe ".ordered (decision 2, AC-1.4)" do
    it "lists by comparison key then name, in code-point order, with no numeric or locale ordering" do
      [ "box", "Binder 2", "Binder 10", "Éclair", "eclair" ].each { |name| add(name) }

      expect(account.locations.ordered.pluck(:name)).to eq([ "Binder 10", "Binder 2", "box", "eclair", "Éclair" ])
    end
  end

  it "goes with its account (AC-4.6)" do
    add("Blue binder")
    add("Box")

    expect { user.destroy! }.to change(described_class, :count).by(-2)
  end

  describe "kinds (spec 062 decision 1, ADR 0028)" do
    def deck(name = "Izzet Tempo", in_account: account) = in_account.locations.create!(name:, kind: "deck")

    def zone(of, name = "Main", key: "main") = Location.new(account_id: of.account_id, parent: of, kind: "deck_zone", name:, zone: key)

    def top_level(count, kind: "place")
      Location.insert_all!(Array.new(count) { |index| { account_id: account.id, name: "#{kind} #{index}", name_key: "#{kind} #{index}", kind: } })
    end

    it "is a place unless it is made another kind, and the kinds and scopes tell them apart", :aggregate_failures do
      place = add("Binder")
      izzet = deck
      main = zone(izzet).tap(&:save!)

      expect([ place, izzet, main ].map(&:kind)).to eq(%w[place deck deck_zone])
      expect([ place.place?, izzet.deck?, main.zone? ]).to all(be(true))
      expect([ place.deck?, place.zone?, izzet.place?, main.place? ]).to all(be(false))
      expect(described_class.places).to contain_exactly(place)
      expect(described_class.decks).to contain_exactly(izzet)
      expect(described_class.zones_of_decks).to contain_exactly(main)
      expect(described_class.top_level).to contain_exactly(place, izzet)
      expect(izzet.zones).to contain_exactly(main)
      expect(main.parent).to eq(izzet)
    end

    it "labels a zone with its deck and anything else with its name (spec 062 D6)", :aggregate_failures do
      izzet = deck
      main = zone(izzet).tap(&:save!)

      expect(main.label).to eq("Izzet Tempo › Main")
      expect(izzet.label).to eq("Izzet Tempo")
      expect(add("Binder").label).to eq("Binder")
      expect(described_class::Placement.label("Main", "Izzet Tempo")).to eq("Izzet Tempo › Main")
    end

    describe "the limit (AC-1.7a, AC-5.9)" do
      it "says decks count toward it", :aggregate_failures do
        expect(described_class::FULL).to eq("You can have at most 500 places and decks together.")
        expect(described_class::MAX_PER_ACCOUNT).to eq(500)
      end

      it "counts places and decks together: 400 places and 100 decks refuse a 501st place and a 501st deck", :aggregate_failures do
        top_level(400)
        top_level(100, kind: "deck")

        [ "place", "deck" ].each do |kind|
          refused = account.locations.new(name: "One more #{kind}", kind:).tap(&:save)
          expect(refused).not_to be_persisted
          expect(reasons(refused)).to eq([ "You can have at most 500 places and decks together." ])
        end
        expect(account.locations.count).to eq(500)
      end

      it "does not count zones: 499 top-level rows and 3 zones accept a 500th", :aggregate_failures do
        top_level(498)
        izzet = deck
        3.times { |index| described_class.insert!({ account_id: account.id, parent_id: izzet.id, kind: "deck_zone", name: "Zone #{index}", name_key: "zone #{index}", zone: "z#{index}" }) }

        expect(add("The 500th")).to be_persisted
        expect(add("The 501st")).not_to be_persisted
      end

      it "does not refuse to save a zone or a rename when the account is full", :aggregate_failures do
        top_level(499)
        izzet = deck

        expect(zone(izzet).save).to be(true)
        izzet.name = "Izzet Tempo 2"
        expect(izzet.save).to be(true)
      end
    end

    describe "names (AC-1.5, AC-1.6)" do
      it "is shared by places and decks: a deck can't have a place's key and a place can't have a deck's", :aggregate_failures do
        add("Main")
        deck("Izzet")

        refused_deck = account.locations.new(name: "  main ", kind: "deck").tap(&:save)
        refused_place = add("IZZET")

        expect(reasons(refused_deck)).to eq([ "You already have a location called “main”." ])
        expect(reasons(refused_place)).to eq([ "You already have a location called “IZZET”." ])
      end

      it "may repeat a zone's name in two decks and not in one", :aggregate_failures do
        one = deck("One")
        two = deck("Two")
        zone(one).save!

        expect(zone(two).save).to be(true)
        again = zone(one, "main", key: "other")
        expect(again.save).to be(false)
        expect(reasons(again)).to eq([ "You already have a location called “main”." ])
      end

      it "lets a zone have the name of a place or a deck", :aggregate_failures do
        add("Main")
        izzet = deck

        expect(zone(izzet).save).to be(true)
      end

      it "is refused by the index too when a duplicate is inserted past validation (race)", :aggregate_failures do
        deck("Izzet")
        late = account.locations.new(name: "izzet", kind: "deck")

        expect(late.save(validate: false)).to be(false)
        expect(reasons(late)).to eq([ "You already have a location called “izzet”." ])
      end
    end

    describe "consistency (AC-9.5)" do
      it "refuses a place or a deck with a parent or a zone", :aggregate_failures do
        izzet = deck
        faulty = [
          account.locations.new(name: "A", parent: izzet),
          account.locations.new(name: "B", zone: "main"),
          account.locations.new(name: "C", kind: "deck", parent: izzet),
          account.locations.new(name: "D", kind: "deck", zone: "main")
        ]

        faulty.each { |location| expect(location).not_to be_valid, location.name }
        expect(faulty.map { it.errors.attribute_names }).to eq([ [ :parent ], [ :zone ], [ :parent ], [ :zone ] ])
      end

      it "needs a zone to have a parent that is a deck of its account, and a zone key", :aggregate_failures do
        izzet = deck
        other_deck = deck("Other", in_account: create(:user).account)
        place = add("Binder")
        main = zone(izzet).tap(&:save!)

        expect(account.locations.new(name: "Main", kind: "deck_zone", zone: "main")).not_to be_valid # no parent
        expect(zone(place)).not_to be_valid # a place's zone
        expect(zone(other_deck).tap { it.account_id = account.id }).not_to be_valid # another account's deck
        expect(zone(main, "Deeper", key: "deeper")).not_to be_valid # a zone of a zone
        expect(account.locations.new(name: "Main 2", kind: "deck_zone", parent: izzet)).not_to be_valid # no zone key
        expect(zone(izzet, "Side", key: "side")).to be_valid
      end

      it "refuses an unknown kind", :aggregate_failures do
        location = account.locations.new(name: "Odd", kind: "shelf")

        expect(location).not_to be_valid
        expect(location.errors.where(:kind).size).to eq(1)
      end

      it "says nothing about the kind of a valid record", :aggregate_failures do
        izzet = deck

        expect(zone(izzet)).to be_valid
        expect(izzet.errors).to be_empty
      end
    end

    it "takes its zones with it when the deck is deleted, as the foreign key says (AC-9.4)", :aggregate_failures do
      izzet = deck
      zone(izzet).save!

      expect { described_class.where(id: izzet.id).delete_all }.to change(described_class, :count).by(-2)
    end
  end

  describe "a lot in it (spec 032 AC-5.5)" do
    it "can't be deleted while a lot is in it, even by SQL", :aggregate_failures do
      location = create(:location, account:)
      create(:lot, account:, location:)
      expect { described_class.where(id: location.id).delete_all }.to raise_error(ActiveRecord::InvalidForeignKey)
      expect(described_class.exists?(location.id)).to be(true)
    end
  end
end
