require "rails_helper"

RSpec.describe "A household with every user (spec 090 Story 1)", type: :request do
  let(:password) { "correct horse battery" }

  def sign_up(**extra) = post(registration_path, params: { user: { name: "Ann", email_address: "ann@example.test", password:, password_confirmation: password, **extra } })

  def expect_a_household_of_one(user, named: "#{user.name}'s household")
    expect(user.membership).to have_attributes(role: "manager", household: have_attributes(name: named))
    expect(user.account).to have_attributes(kind: "personal", household: user.membership.household)
    expect(user.membership.household.memberships.count).to eq(1)
    expect_household_invariants!
  end

  it "gives the first visitor a household of one and lands them in the collection (AC-1.1)", :aggregate_failures do
    sign_up
    expect(response).to redirect_to(collection_path)
    expect_a_household_of_one(User.sole)
    expect_household_invariants!
  end

  it "gives a person who signs up while sign-up is open their own household (AC-1.2)", :aggregate_failures do
    first = create(:admin)
    InstanceSetting.current.update!(sign_up_open: true)
    sign_up
    expect_a_household_of_one(User.find_by!(email_address: "ann@example.test"))
    expect(first.membership.household.memberships.count).to eq(1)
  end

  it "gives a user an admin adds a household of one and leaves the admin's own alone (AC-1.3)", :aggregate_failures do
    admin = sign_in_as(create(:admin))
    household = admin.membership.household
    post admin_users_path, params: { user: { name: "Bo", email_address: "bo@example.test", password: } }
    expect(response).to redirect_to(admin_users_path)
    expect_a_household_of_one(User.find_by!(email_address: "bo@example.test"))
    expect(admin.reload.membership.household).to eq(household)
  end

  it "gives the operator command's admin a household of one (AC-1.4)", :aggregate_failures do
    user, = User::Command.call(email: "ops@example.test", password:)
    expect_a_household_of_one(user, named: "ops's household")
  end

  it "makes nothing for a sign-up that is invalid: a blank name on an empty instance, a used email while sign-up is open (AC-1.6)", :aggregate_failures do
    expect { sign_up(name: "") }.not_to change { [ Household.count, Membership.count, Account.count ] }
    expect(response).to have_http_status(:unprocessable_content)
    create(:admin, email_address: "ann@example.test")
    InstanceSetting.current.update!(sign_up_open: true)
    expect { sign_up }.not_to change { [ Household.count, Membership.count, Account.count ] }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "makes nothing for a sign-up that finds a user already there, as when it loses the first-user race (AC-1.6)", :aggregate_failures do
    get new_registration_path
    create(:admin)
    expect { sign_up }.not_to change { [ Household.count, Membership.count, Account.count ] }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "ignores a household, role or kind in the parameters of a sign-up and of an admin's form (AC-1.7)", :aggregate_failures do
    other = create(:user).membership.household # a household with a manager, so the invariants helper holds
    InstanceSetting.current.update!(sign_up_open: true) # an instance with a user refuses a sign-up unless it is open
    sign_up(household_id: other.id, role: "member", kind: "shared")
    ann = User.find_by!(email_address: "ann@example.test")
    expect_a_household_of_one(ann)
    expect(ann.membership.household).not_to eq(other)

    delete session_path # the sign-up signed Ann in, and a signed-in visitor can't sign in as someone else
    sign_in_as(create(:admin))
    post admin_users_path, params: { user: { name: "Bo", email_address: "bo@example.test", password:, household_id: other.id, role: "member", kind: "shared" } }
    expect_a_household_of_one(User.find_by!(email_address: "bo@example.test"))
  end

  it "removes a deleted user's household, membership and account, and no other (AC-4.4)", :aggregate_failures do
    admin = sign_in_as(create(:admin))
    bo = create(:user, name: "Bo")
    delete admin_user_path(bo)
    expect(response).to redirect_to(admin_users_path)
    expect([ Household.where(name: "Bo's household").count, Membership.where(user_id: bo.id).count, Account.where(id: bo.account_id).count ]).to eq([ 0, 0, 0 ])
    expect(admin.reload.membership).to be_present
    expect_household_invariants!
  end
end
