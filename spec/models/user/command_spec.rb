require "rails_helper"

RSpec.describe User::Command, type: :model do
  it "creates an admin named after the email, which ends first run", :aggregate_failures do
    user, created = described_class.call(email: "Owner@Example.test", password: "a long enough secret")
    expect([ created, user.admin?, user.name ]).to eq([ true, true, "owner" ])
    expect(Registration).not_to be_open
  end

  it "leaves an open sign-up open when other users exist" do
    create(:admin)
    InstanceSetting.current.update!(sign_up_open: true)
    described_class.call(email: "later@example.test", password: "a long enough secret")
    expect(InstanceSetting.current.sign_up_open?).to be(true)
  end

  it "resets an existing user's password and ends their sessions" do
    existing = create(:user, email_address: "bo@example.test")
    existing.sessions.create!
    user, created = described_class.call(email: "bo@example.test", password: "a long enough secret")
    expect([ created, user.authenticate("a long enough secret").present?, user.sessions.count ]).to eq([ false, true, 0 ])
  end

  it "refuses a malformed email" do
    expect { described_class.call(email: "not an email", password: "a long enough secret") }
      .to raise_error(ActiveRecord::RecordInvalid)
  end
end
