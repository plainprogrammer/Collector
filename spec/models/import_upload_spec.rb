require "rails_helper"

RSpec.describe ImportUpload, type: :model do
  it "allows one per account (FR-10)", :aggregate_failures do
    account = create(:user).account
    described_class.create!(account:, fingerprint: "a", expires_at: 1.hour.from_now)

    expect { described_class.create!(account:, fingerprint: "b", expires_at: 1.hour.from_now) }
      .to raise_error(ActiveRecord::RecordNotUnique)
    expect(account.reload.import_upload.fingerprint).to eq("a")
  end
end
