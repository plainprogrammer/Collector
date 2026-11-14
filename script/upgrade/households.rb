# The household facts of a snapshot of the primary database (spec 090 decision 10, ADR 0030). Tier 1 is the invariants of a
# household, true on every snapshot of every release from this one on, so it names no count: it must stay true when joined households
# and shared accounts exist (#381, #384). Tier 2 is the backfill's own facts, checked only when the old snapshot had no households.
# It reads the snapshot with SQLite directly, never through the application, as `compare.rb` does.
require_relative "compare"

module Upgrade
  module Households
    SUFFIX = "'s household".freeze

    # What is wrong with the households of +db+, as sentences naming the rule and the first row.
    #
    # @param db [SQLite3::Database] a snapshot, opened read-only
    # @param backfill [Boolean] also check the facts a backfill of a database with no households leaves (decision 10, tier 2)
    # @return [Array<String>] empty when the snapshot holds every rule checked
    def self.problems(db, backfill: false)
      tables = Compare.tables(db)
      return [ "the snapshot has no households or memberships table" ] unless (%w[households memberships] - tables).empty?

      found = invariants(db)
      found += backfilled(db) if backfill
      found
    end

    # Tier 1: the rules every household snapshot holds, whatever joined households or shared accounts exist later.
    #
    # @api private
    def self.invariants(db)
      found = []
      db.execute("SELECT users.id, COUNT(memberships.id) FROM users LEFT JOIN memberships ON memberships.user_id = users.id GROUP BY users.id HAVING COUNT(memberships.id) <> 1 LIMIT 3").each do |id, count|
        found << "user #{id} has #{count} memberships, not exactly one"
      end
      db.execute("SELECT id FROM households WHERE NOT EXISTS (SELECT 1 FROM memberships WHERE household_id = households.id AND role = 'manager') LIMIT 3").flatten.each do |id|
        found << "household #{id} has no manager"
      end
      db.execute("SELECT id FROM accounts WHERE household_id IS NULL OR household_id NOT IN (SELECT id FROM households) LIMIT 3").flatten.each do |id|
        found << "account #{id} has no household"
      end
      db.execute("SELECT accounts.id FROM accounts JOIN users ON users.account_id = accounts.id JOIN memberships ON memberships.user_id = users.id WHERE accounts.kind = 'personal' AND accounts.household_id <> memberships.household_id LIMIT 3").flatten.each do |id|
        found << "account #{id} is in a household other than its user's"
      end
      found
    end
    private_class_method :invariants

    # Tier 2: the facts a backfill of a database that had no households leaves (one household of one per user, named by the rule).
    #
    # @api private
    def self.backfilled(db)
      found = []
      users = db.get_first_value("SELECT COUNT(*) FROM users")
      households = db.get_first_value("SELECT COUNT(*) FROM households")
      found << "the households' count #{households} is not the users' #{users}" unless users == households
      found << "a membership's role is not manager" if db.get_first_value("SELECT COUNT(*) FROM memberships WHERE role <> 'manager'").positive?
      found << "an account's kind is not personal" if db.get_first_value("SELECT COUNT(*) FROM accounts WHERE kind <> 'personal'").positive?
      db.execute("SELECT users.id FROM users JOIN memberships ON memberships.user_id = users.id JOIN households ON households.id = memberships.household_id WHERE households.name <> substr(users.name, 1, 88) || '#{SUFFIX.gsub("'", "''")}' LIMIT 3").flatten.each do |id|
        found << "the name of user #{id}'s household is not the form of spec 090 decision 2"
      end
      found
    end
    private_class_method :backfilled
  end
end
