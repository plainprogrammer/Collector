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
      expect(reasons(refused)).to eq([ "You can have at most 500 locations." ])
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

  describe "a lot in it (spec 032 AC-5.5)" do
    it "can't be deleted while a lot is in it, even by SQL", :aggregate_failures do
      location = create(:location, account:)
      create(:lot, account:, location:)
      expect { described_class.where(id: location.id).delete_all }.to raise_error(ActiveRecord::InvalidForeignKey)
      expect(described_class.exists?(location.id)).to be(true)
    end
  end
end
