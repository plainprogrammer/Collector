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

  it "uses the first letter of the name as the avatar initial" do
    expect(build(:user, name: "james").initial).to eq("J")
  end
end
