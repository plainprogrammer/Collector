# Gives every user that has no household one of their own, as its manager (spec 090 decision 5 (b), decision 2). Plain SQL and no
# application model (.claude/rules/sqlite-and-migrations.md). Without a transaction, so each batch of users is its own short write
# transaction: a large instance never holds the write lock for more than one batch, and a run that stopped is finished by the next
# boot. Idempotent: it reads only users with no membership. It sets accounts.household_id and nothing else, updated_at included, so
# the upgrade proof's comparison of accounts needs no expected change. The name is the user's first 88 characters and "'s household"
# (`Household.name_for`; a spec holds the two equal). Nothing to undo going down: the tables go with the first migration.
class BackfillHouseholds < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  BATCH = 500

  def up
    now = connection.quote(Time.current.utc.strftime("%Y-%m-%d %H:%M:%S.%6N"))
    loop do
      users = connection.select_rows("SELECT id, account_id FROM users WHERE NOT EXISTS (SELECT 1 FROM memberships WHERE memberships.user_id = users.id) ORDER BY id LIMIT #{BATCH.to_i}") # Safe: an integer constant
      break if users.empty?

      connection.transaction do
        users.each do |user_id, account_id|
          household = connection.insert("INSERT INTO households (name, created_at, updated_at) SELECT substr(name, 1, 88) || '''s household', #{now}, #{now} FROM users WHERE id = #{user_id.to_i}") # Safe: integer ids from the query above
          raise ActiveRecord::MigrationError, "no household was made for user #{user_id}" unless connection.select_value("SELECT changes()").to_i == 1

          connection.execute "INSERT INTO memberships (household_id, user_id, role, created_at, updated_at) VALUES (#{household.to_i}, #{user_id.to_i}, 'manager', #{now}, #{now})" # Safe: integers
          connection.execute "UPDATE accounts SET household_id = #{household.to_i} WHERE id = #{account_id.to_i}" # Safe: integers
        end
      end
    end
  end

  def down; end
end
