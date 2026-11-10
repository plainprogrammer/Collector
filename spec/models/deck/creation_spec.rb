require "rails_helper"

# Spec 062 AC-1.3, AC-1.7 to AC-1.9, AC-1.11: the New deck form's object writes a deck and its zones, or nothing.
RSpec.describe Deck::Creation, type: :model do
  let(:account) { create(:user).account }

  def creation(name: "Izzet Tempo", format: "mtg/modern", in_account: account) = described_class.new(account: in_account, name:, format:)

  def top_level(count, kind: "place")
    Location.insert_all!(Array.new(count) { |index| { account_id: account.id, name: "#{kind} #{index}", name_key: "#{kind} #{index}", kind: } })
  end

  def written = [ Location.count, Deck.count ]

  describe "#save" do
    it "writes one deck with the format's type and key and one zone per zone of the format, in its order (AC-1.3)", :aggregate_failures do
      form = creation(format: "mtg/commander")

      expect(form.save).to be(true)
      deck = form.deck
      expect(deck).to have_attributes(collectible_type: "mtg", format: "commander", account_id: account.id)
      expect(deck.location).to have_attributes(kind: "deck", name: "Izzet Tempo", parent_id: nil, account_id: account.id)
      expect(deck.zones.map { [ it.zone, it.name, it.kind, it.parent_id, it.account_id ] }).to eq(
        [ [ "commander", "Commander", "deck_zone", deck.location_id, account.id ], [ "main", "Main", "deck_zone", deck.location_id, account.id ],
          [ "considering", "Considering", "deck_zone", deck.location_id, account.id ] ])
      expect(written).to eq([ 4, 1 ])
    end

    it "gives a format its own zones" do
      form = creation(format: "mtg/pauper")
      form.save!

      expect(form.deck.zones.map(&:zone)).to eq(%w[main sideboard considering])
    end

    it "keeps the name as it was typed and normalises the stored one", :aggregate_failures do
      form = creation(name: "  Izzet   Tempo ")
      form.save!

      expect(form.typed).to eq("  Izzet   Tempo ")
      expect(form.deck.name).to eq("Izzet Tempo")
    end

    it "refuses a name that is blank, has a control character, is over 60 characters or is taken, writing nothing (AC-1.7)", :aggregate_failures do
      create(:deck, account:, name: "Taken")
      before = written

      { "" => Location::MESSAGES[:blank], "Bad\u0007name" => Location::MESSAGES[:control], ("a" * 61) => Location::MESSAGES[:too_long],
        "taken" => "You already have a location called “taken”." }.each do |typed, sentence|
        form = creation(name: typed)
        expect(form.save).to be(false), typed.dump
        expect(form.errors[:name]).to eq([ sentence ])
        expect(form.typed).to eq(typed)
        expect(form.format).to eq("mtg/modern")
        expect(form.deck).to be_nil
      end
      expect(written).to eq(before)
    end

    it "refuses a name a place has" do
      create(:location, account:, name: "Binder")

      expect(creation(name: "BINDER").tap(&:save).errors[:name]).to eq([ "You already have a location called “BINDER”." ])
    end

    it "refuses a blank, unregistered or foreign-key format with `Choose a format.` and writes nothing (AC-1.8)", :aggregate_failures do
      [ "", nil, "modern", "mtg/", "mtg/nope", "nope/modern", "mtg/modern/extra", "other/standard" ].each do |value|
        form = creation(format: value)
        expect(form.save).to be(false), value.inspect
        expect(form.errors[:format]).to eq([ "Choose a format." ])
        expect(form.errors[:name]).to be_empty
      end
      expect(written).to eq([ 0, 0 ])
    end

    it "reports both a bad name and a bad format" do
      form = creation(name: "", format: "x")
      form.save

      expect([ form.errors[:name], form.errors[:format] ]).to eq([ [ Location::MESSAGES[:blank] ], [ "Choose a format." ] ])
    end

    it "refuses an account at 500 places and decks, writing nothing (AC-1.7a)", :aggregate_failures do
      top_level(400)
      top_level(100, kind: "deck")
      form = creation

      expect(form.save).to be(false)
      expect(form.errors[:name]).to eq([ Location::FULL ])
      expect(Location.count).to eq(500)
    end

    it "ends at 500, not 501, when an account at 499 adds one place and one deck (AC-1.9)", :aggregate_failures do
      top_level(499)
      place = account.locations.new(name: "Binder")
      form = creation

      expect(place.save).to be(true)
      expect(form.save).to be(false)
      expect(account.locations.top_level.count).to eq(500)
      expect(Deck.count).to eq(0)
    end

    it "answers false, never raises, for a second creation of one name (AC-1.9)", :aggregate_failures do
      first = creation
      second = creation(name: "izzet TEMPO")

      expect(first.save).to be(true)
      expect(second.save).to be(false)
      expect(second.errors[:name]).to eq([ "You already have a location called “izzet TEMPO”." ])
      expect(written).to eq([ 4, 1 ])
    end

    it "answers false and leaves nothing when the unique index refuses the deck after the check passed (AC-1.9, a race)", :aggregate_failures do
      racing = true
      other = nil
      watcher = lambda do |*, payload|
        next unless racing && payload[:sql].match?(/SELECT 1 AS one FROM "locations".*"name_key"/m)

        racing = false # a competing request commits its deck right after this request's check (here on the same connection, so inside the transaction)
        other = Location.insert!({ account_id: account.id, name: "Izzet Tempo", name_key: "izzet tempo", kind: "deck" })
      end
      form = creation

      saved = ActiveSupport::Notifications.subscribed(watcher, "sql.active_record") { form.save }

      expect(other).not_to be_nil
      expect(saved).to be(false)
      expect(form.errors[:name]).to eq([ "You already have a location called “Izzet Tempo”." ])
      expect(written).to eq([ 0, 0 ]) # the competing row rolled back with the transaction only because this spec shares its connection
    end

    it "leaves no deck and no zone when a zone can't be written (AC-1.11)", :aggregate_failures do
      allow(Location).to receive(:insert_all!).and_raise(ActiveRecord::StatementInvalid, "disk full")

      expect { creation.save }.to raise_error(ActiveRecord::StatementInvalid)
      expect(written).to eq([ 0, 0 ])
    end

    it "costs at most ten statements for the format with the most zones" do
      form = creation(format: "mtg/commander")

      expect(count_queries { form.save }).to be <= 10
    end

    it "lets two accounts use one name", :aggregate_failures do
      other = create(:user).account
      creation(in_account: other).save!

      expect(creation.save).to be(true)
      expect(account.decks.count).to eq(1)
      expect(other.decks.count).to eq(1)
    end
  end

  describe "#save!" do
    it "raises RecordInvalid with the errors for a refusal" do
      expect { creation(name: "").save! }.to raise_error(ActiveRecord::RecordInvalid, /Give the location a name/)
    end
  end
end
