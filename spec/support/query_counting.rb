# Counts the SQL queries a block runs, leaving out cached ones, schema lookups and transaction statements, so a spec
# can show a page's database work doesn't grow with its data.
module QueryCounting
  def count_queries
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:cached] || %w[SCHEMA TRANSACTION].include?(payload[:name]) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    count
  end
end

RSpec.configure { |config| config.include QueryCounting, type: :request }
