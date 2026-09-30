require "rails_helper"

RSpec.describe Registration, type: :model do
  let(:params) { { name: "Ann", email_address: "ann@example.test", password: "correct horse battery", password_confirmation: "correct horse battery" } }

  it "makes the first user an admin and closes sign-up", :aggregate_failures do
    user = described_class.new(params).save
    expect(user).to be_admin
    expect(InstanceSetting.current).not_to be_sign_up_open
  end

  it "creates non-admin users while sign-up is open" do
    create(:admin)
    InstanceSetting.current.update!(sign_up_open: true)
    expect(described_class.new(params).save).not_to be_admin
  end

  it "refuses when another user exists and sign-up is closed", :aggregate_failures do
    create(:admin)
    registration = described_class.new(params)
    expect(registration.save).to be(false)
    expect(registration).to be_closed
  end

  it "ignores admin and account values in the submission" do
    create(:admin)
    InstanceSetting.current.update!(sign_up_open: true)
    user = described_class.new(params.merge(admin: true, account_id: 999)).save
    expect([ user.admin?, user.account_id ]).not_to include(true, 999)
  end

  it "reports mismatched confirmations on the confirmation field" do
    registration = described_class.new(params.merge(password_confirmation: "something else!"))
    registration.save
    expect(registration.user.errors[:password_confirmation]).to include("doesn't match Password")
  end
end
