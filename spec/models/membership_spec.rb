require "rails_helper"

RSpec.describe Membership, type: :model do
  # Puts +member+ into +manager+'s household as a plain member, the way a later issue's join will, by SQL (spec only).
  def join(member, manager)
    described_class.where(user_id: member.id).update_all(household_id: manager.membership.household_id, role: "member")
    Account.where(id: member.account_id).update_all(household_id: manager.membership.household_id)
    member.reload
  end

  let(:manager) { create(:user) }
  let(:member) { join(create(:user), manager) }

  it "has a role of manager or member only (AC-2.1)", :aggregate_failures do
    expect(described_class.new(role: "boss").tap(&:validate).errors[:role]).to be_present
    bare = create(:user)
    described_class.where(user_id: bare.id).delete_all # a user with no membership, by SQL
    expect { described_class.insert!({ household_id: manager.membership.household_id, user_id: bare.id, role: "boss" }) }.to raise_error(ActiveRecord::StatementInvalid, /memberships_role_known/)
  end

  it "is one per user (AC-2.2)", :aggregate_failures do
    second = described_class.new(household: create(:household), user: manager, role: "member")
    expect(second).not_to be_valid
    expect { described_class.insert!({ household_id: create(:household).id, user_id: manager.id, role: "member" }) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "can't be removed on its own, a household of one's included (AC-2.4)", :aggregate_failures do
    expect(manager.membership.destroy).to be(false)
    expect(member.membership.destroy).to be(false)
    expect(described_class.count).to eq(2)
  end

  it "keeps a manager: the last one can't be demoted, one of two can (AC-2.3)", :aggregate_failures do
    member # joins manager's household
    expect(manager.membership.update(role: "member")).to be(false)
    expect(manager.membership.errors[:role]).to be_present
    member.membership.update!(role: "manager")
    expect(manager.membership.reload.update(role: "member")).to be(true)
  end

  it "keeps a user from being deleted when they are the last manager of a household with others (AC-2.3, decision 7)", :aggregate_failures do
    member
    expect { manager.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)
    expect([ User.exists?(manager.id), described_class.exists?(user_id: manager.id) ]).to eq([ true, true ])
  end

  it "lets a plain member's user be deleted, leaving the household and its manager (decision 7)", :aggregate_failures do
    household = member.membership.household
    member.destroy!
    expect([ Household.exists?(household.id), described_class.where(household_id: household.id).pluck(:user_id) ]).to eq([ true, [ manager.id ] ])
  end
end
