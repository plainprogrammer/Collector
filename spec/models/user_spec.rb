require "rails_helper"

RSpec.describe User, type: :model do
  describe "validations" do
    it "normalises the email and requires a well-formed, unique one", :aggregate_failures do
      create(:user, email_address: "Ann@Example.test")

      expect(build(:user, email_address: "  ANN@example.TEST ").tap(&:validate).errors[:email_address]).to include("is already used")
      expect(build(:user, email_address: "no-at-sign").tap(&:validate).errors[:email_address]).to include("must look like name@example.com")
      expect(build(:user, email_address: "two@@x.test").tap(&:validate).errors[:email_address]).to be_present
      expect(build(:user, email_address: "sp ace@x.test").tap(&:validate).errors[:email_address]).to be_present
    end

    it "requires a name of at most 100 characters and a password of at least 12", :aggregate_failures do
      expect(build(:user, name: "").tap(&:validate).errors[:name]).to be_present
      expect(build(:user, name: "a" * 101).tap(&:validate).errors[:name]).to be_present
      expect(build(:user, password: "short").tap(&:validate).errors[:password]).to include("must be at least 12 characters")
    end
  end

  it "creates its own account" do
    expect { create(:user) }.to change(Account, :count).by(1)
  end

  it "starts its account at the instance default however it is created (spec 038 AC-3.1)", :aggregate_failures do
    allow(Rails.configuration.x).to receive(:default_currency).and_return(Collector::Currency.fetch!("EUR"))
    registration = Registration.new(name: "Ann", email_address: "ann@example.test", password: "a long enough secret", password_confirmation: "a long enough secret")
    registration.save

    expect(create(:user).account.currency).to eq("EUR")
    expect(User::Command.call(email: "bo@example.test", password: "a long enough secret").first.account.currency).to eq("EUR")
    expect(registration.user.reload.account.currency).to eq("EUR")
  end

  it "uses the first letter of the name as the avatar initial" do
    expect(build(:user, name: "james").initial).to eq("J")
  end

  describe "household (spec 090)" do
    it "is made with a household named for it, an account in it and a manager membership (AC-1.1)", :aggregate_failures do
      user = create(:user, name: "Ada")

      expect(user.membership).to have_attributes(role: "manager", household: have_attributes(name: "Ada's household"))
      expect(user.account).to have_attributes(kind: "personal", household: user.membership.household)
      expect(Household.count).to eq(1)
    end

    it "gives a user with 100 characters a name of exactly 100 (AC-1.5)" do
      expect(create(:user, name: "n" * 100).membership.household.name).to eq("#{"n" * 88}'s household")
    end

    it "makes nothing for a user that is invalid (AC-1.6)", :aggregate_failures do
      expect { build(:user, name: "").save }.not_to change { [ Household.count, Membership.count, Account.count ] }
    end

    it "is refused when its membership is in another household than its account's (AC-2.6)", :aggregate_failures do
      user = create(:user)
      user.account.household = create(:household)

      expect(user).not_to be_valid
      expect(user.errors[:membership]).to be_present
      expect(create(:user)).to be_valid
    end

    it "removes its membership, its account and its household when it is deleted (AC-4.4)", :aggregate_failures do
      user = create(:user)
      household = user.membership.household

      user.destroy!

      expect([ Household.exists?(household.id), Membership.exists?(user_id: user.id), Account.exists?(user.account_id) ]).to eq([ false, false, false ])
    end

    it "reads no household or membership when a user loaded as a session loads it is validated, twice (AC-4.5)", :aggregate_failures do
      user = create(:user)
      loaded = Session.includes(user: :account).find(user.sessions.create!.id).user
      seen = []
      ActiveSupport::Notifications.subscribed(->(*, payload) { seen << payload[:sql] if payload[:sql].match?(/\b(households|memberships)\b/i) }, "sql.active_record") do
        2.times { expect(loaded).to be_valid }
        loaded.update!(collection_view: "table")
      end
      expect(seen).to be_empty
    end

    it "keeps the invariants however it is made and deleted (AC-2.8)" do
      create(:user)
      create(:admin).destroy!
      expect_household_invariants!
    end
  end
end
