# Counts the SQL queries a block runs, leaving out cached ones, schema lookups and transaction statements, so a spec
# can show a page's database work doesn't grow with its data.
module QueryCounting
  def count_queries
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:cached] || %w[SCHEMA TRANSACTION].include?(payload[:name]) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    count
  end

  # The write statements (INSERT, UPDATE, DELETE) a block runs against one table, for "this request wrote nothing to it".
  def write_statements_to(table)
    statements = []
    counter = ->(*, payload) { statements << payload[:sql] if payload[:sql].match?(/\A\s*(INSERT|UPDATE|DELETE)\b.*"#{table}"/i) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    statements
  end
end

RSpec.configure do |config|
  config.include QueryCounting, type: :request
  config.include QueryCounting, type: :job
  config.include QueryCounting, type: :model
end
