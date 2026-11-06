require "rails_helper"
require Rails.root.join("db/migrate/20261103100002_set_account_currency_from_the_instance")

# Spec 038 AC-4.1–4.5: the data step gives every account the instance's current COLLECTOR_CURRENCY. The Migrator's run is a
# no-op here (schema load records every version), so the examples call the migration's own migrate.
RSpec.describe SetAccountCurrencyFromTheInstance, type: :model do
  let!(:accounts) { Array.new(3) { create(:user).account } }

  around do |example|
    ActiveRecord::Migration.verbose = false
    example.run
  ensure
    ActiveRecord::Migration.verbose = true
  end

  def with_variable(value)
    env = ENV.to_h.except("COLLECTOR_CURRENCY")
    env["COLLECTOR_CURRENCY"] = value unless value.nil?
    stub_const("ENV", env)
  end

  def currencies = accounts.map { |account| account.reload.currency }

  it "gives every account the instance's currency (AC-4.1)" do
    with_variable("EUR")
    described_class.new.migrate(:up)
    expect(currencies).to eq(%w[EUR EUR EUR])
  end

  it "gives USD when the variable is unset (AC-4.2)" do
    Account.update_all(currency: "GBP") # rubocop:disable Rails/SkipsModelValidations -- a state to overwrite, not a flow
    with_variable(nil)
    described_class.new.migrate(:up)
    expect(currencies).to eq(%w[USD USD USD])
  end

  it "normalises the variable as boot does (AC-4.2)" do
    with_variable(" eur ")
    described_class.new.migrate(:up)
    expect(currencies).to eq(%w[EUR EUR EUR])
  end

  it "stops on an unsupported code, naming the variable and the value, and changes no account (AC-4.3)", :aggregate_failures do
    with_variable("XYZ")
    expect { described_class.new.migrate(:up) }.to raise_error(/COLLECTOR_CURRENCY "XYZ" is not supported/)
    expect(currencies).to eq(%w[USD USD USD])
  end

  it "passes with no account (AC-4.4)", :aggregate_failures do
    User.destroy_all
    with_variable("EUR")
    expect { described_class.new.migrate(:up) }.not_to raise_error
    expect(Account.count).to eq(0)
  end

  it "changes no account going down (AC-4.5)" do
    Account.update_all(currency: "GBP") # rubocop:disable Rails/SkipsModelValidations -- a state to keep, not a flow
    with_variable("EUR")
    described_class.new.migrate(:down)
    expect(currencies).to eq(%w[GBP GBP GBP])
  end
end
