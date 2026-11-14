require "rails_helper"

# Spec 090 AC-5.2: an apply writes the collection and the currency and never the account's household, kind or membership.
RSpec.describe "Applying an export and the household (spec 090 AC-5.2)", type: :model do
  let(:source) { create(:user, name: "Source", email_address: "source@example.test") }
  let!(:target) { create(:user, name: "Target", email_address: "target@example.test") }

  def export(user) = JSON.parse(CollectionExport.new(account: user.account, at: Time.utc(2026, 11, 13, 12)).to_json)

  def apply!(user, data)
    upload = store_import!(account: user.account, data:)
    CollectionImport::Apply.new(account: user.account.reload, fingerprint: upload&.fingerprint, confirmed: true).call
  end

  def household_facts(user)
    user.reload
    [ user.membership.household_id, user.membership.role, user.account.household_id, user.account.kind, Household.pluck(:id, :name).sort ]
  end

  before { held_lot(source.account, import_printing, quantity: 3, finish: "foil") }

  it "changes no household, role or kind, whether the file restores a collection or replaces one (AC-5.2)", :aggregate_failures do
    document = export(source)
    expect(document.keys).not_to include("household", "households", "memberships")
    before = [ household_facts(source), household_facts(target) ]

    apply!(target, document)
    apply!(source, document.merge("lots" => []))

    expect([ household_facts(source), household_facts(target) ]).to eq(before)
    expect(target.account.lots.sum(:quantity)).to eq(3)
    expect_household_invariants!
  end
end
