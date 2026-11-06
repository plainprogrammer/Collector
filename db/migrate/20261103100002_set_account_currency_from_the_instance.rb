# Carries the instance's current currency to every account, so an upgrade changes nothing a collector sees (spec 038
# decision 3). The codes are copied inline: a released migration must not change when Collector::Currency does. An
# unsupported code stops the migration rather than relabel a collector's prices; the boot check normally refuses it first.
class SetAccountCurrencyFromTheInstance < ActiveRecord::Migration[8.1]
  CODES = %w[USD CAD AUD NZD EUR GBP CHF SEK NOK DKK PLN CZK JPY CNY KRW SGD HKD BRL MXN ZAR].freeze

  def up
    code = ENV.fetch("COLLECTOR_CURRENCY", "USD").strip.upcase
    raise "COLLECTOR_CURRENCY #{ENV["COLLECTOR_CURRENCY"].inspect} is not supported; use one of #{CODES.join(", ")}" unless CODES.include?(code)

    execute ActiveRecord::Base.sanitize_sql_array([ "UPDATE accounts SET currency = ?", code ])
  end

  def down
    # The data stays: the schema step's rollback removes the column.
  end
end
