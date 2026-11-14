# The invariants of a household, checked on the test database (spec 090 AC-2.8): the same four the upgrade proof's tier 1 checks.
module HouseholdInvariants
  # Fails the example, naming the broken rule, unless every user has exactly one membership, every household has a
  # manager, every account has a household and a personal account's household is its user's.
  def expect_household_invariants!
    connection = ActiveRecord::Base.connection
    expect(connection.select_values("SELECT users.id FROM users LEFT JOIN memberships ON memberships.user_id = users.id GROUP BY users.id HAVING COUNT(memberships.id) <> 1")).to be_empty, "a user without exactly one membership"
    expect(connection.select_values("SELECT households.id FROM households WHERE NOT EXISTS (SELECT 1 FROM memberships m WHERE m.household_id = households.id AND m.role = 'manager')")).to be_empty, "a household without a manager"
    expect(connection.select_values("SELECT id FROM accounts WHERE household_id IS NULL")).to be_empty, "an account without a household"
    expect(connection.select_values("SELECT accounts.id FROM accounts JOIN users ON users.account_id = accounts.id JOIN memberships ON memberships.user_id = users.id WHERE accounts.kind = 'personal' AND accounts.household_id <> memberships.household_id")).to be_empty, "a personal account outside its user's household"
  end
end

RSpec.configure { |config| config.include HouseholdInvariants }
