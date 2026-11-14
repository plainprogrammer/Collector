require "rails_helper"

RSpec.describe Household, type: :model do
  describe ".name_for" do
    it "is the user's name and \"'s household\", the name cut to its first 88 characters (spec 090 decision 2, AC-1.5)", :aggregate_failures do
      expect(described_class.name_for("Ada")).to eq("Ada's household")
      expect(described_class.name_for("A")).to eq("A's household")
      long = described_class.name_for("é" * 100)
      expect([ long.length, long ]).to eq([ 100, "#{"é" * 88}'s household" ])
      expect(described_class.name_for("O'Neil")).to eq("O'Neil's household")
    end
  end

  it "needs a name of 1 to 100 characters (AC-2.7)", :aggregate_failures do
    expect(build(:household, name: "").tap(&:validate).errors[:name]).to be_present
    expect(build(:household, name: "a" * 101).tap(&:validate).errors[:name]).to be_present
    expect(build(:household, name: "a" * 100)).to be_valid
  end

  it "can't be destroyed while it holds an account or a member, by the model or by the database (AC-2.9)", :aggregate_failures do
    user = create(:user)
    household = user.membership.household

    expect(household.destroy).to be(false)
    expect(described_class.exists?(household.id)).to be(true)
    expect { described_class.connection.execute("DELETE FROM households WHERE id = #{household.id}") }.to raise_error(ActiveRecord::InvalidForeignKey)
    expect(create(:household).destroy).to be_truthy
  end
end
