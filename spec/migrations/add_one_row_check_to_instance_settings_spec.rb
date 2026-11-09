require "rails_helper"
require Rails.root.join("db/migrate/20261109200002_add_one_row_check_to_instance_settings")

# #229: the schema step puts the guard on the table (CHECK (id = 1), so with the primary key at most one row can exist), and
# its rollback takes the guard off and keeps the row. Down and up go through the Migrator, as db:rollback does (see
# add_currency_to_accounts_spec.rb); the examples commit their rows (:committed empties the database around them).
RSpec.describe AddOneRowCheckToInstanceSettings, :backup, :committed, type: :model do
  around do |example|
    ActiveRecord::Migration.verbose = false
    example.run
  ensure
    up unless guarded?
    InstanceSetting.reset_column_information
    ActiveRecord::Migration.verbose = true
  end

  def context = ActiveRecord::Base.connection_pool.migration_context

  def down = context.run(:down, 2026_11_09_200002)

  def up = context.run(:up, 2026_11_09_200002)

  def connection = ActiveRecord::Base.connection

  def guarded? = connection.check_constraints(:instance_settings).any? { it.expression == "id = 1" }

  def rows = connection.select_rows("SELECT id, sign_up_open, created_at, updated_at FROM instance_settings ORDER BY id")

  def insert_row(id)
    connection.execute("INSERT INTO instance_settings (id, sign_up_open, created_at, updated_at) VALUES (#{id}, 0, '2026-11-09', '2026-11-09')")
  end

  it "is in place after the schema is loaded: a row with another id is refused", :aggregate_failures do
    expect(guarded?).to be(true)
    expect { insert_row(2) }.to raise_error(ActiveRecord::StatementInvalid, /CHECK constraint failed/)
  end

  it "going down accepts another row again, and the row there stays", :aggregate_failures do
    insert_row(1)
    before = rows

    down

    expect(guarded?).to be(false)
    expect(rows).to eq(before)
    expect { insert_row(2) }.not_to raise_error
    connection.execute("DELETE FROM instance_settings WHERE id = 2")
  end

  it "going up again keeps the row and its columns, whether the table holds one row or none", :aggregate_failures do
    insert_row(1)
    before = rows
    columns = connection.columns(:instance_settings).map { [ it.name, it.sql_type, it.null, it.default ] }

    down
    up

    expect(guarded?).to be(true)
    expect(rows).to eq(before)
    expect(connection.columns(:instance_settings).map { [ it.name, it.sql_type, it.null, it.default ] }).to eq(columns)

    connection.execute("DELETE FROM instance_settings")
    down
    expect { up }.not_to raise_error
    expect(rows).to be_empty
  end

  it "is recorded in db/schema.rb as a named check, so a fresh database has it too" do
    expect(File.read(Rails.root.join("db/schema.rb"))).to match(/create_table "instance_settings".*?t\.check_constraint "id = 1", name: "instance_settings_one_row"/m)
  end
end
