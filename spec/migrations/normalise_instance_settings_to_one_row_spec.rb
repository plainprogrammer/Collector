require "rails_helper"
require Rails.root.join("db/migrate/20261109200001_normalise_instance_settings_to_one_row")
require Rails.root.join("db/migrate/20261109200002_add_one_row_check_to_instance_settings")

# #229: the data step before the guard leaves the one row an instance may hold, with id 1, keeping the lowest id's values
# (what `first` read before) and removing the rest, which only the old first-read race could have made. The examples call the
# migration's own migrate, with the guard lifted by hand to build the old states; :committed empties the database around them.
RSpec.describe NormaliseInstanceSettingsToOneRow, :backup, :committed, type: :model do
  around do |example|
    ActiveRecord::Migration.verbose = false
    lift_guard
    example.run
  ensure
    connection.execute("DELETE FROM instance_settings")
    context.run(:up, 2026_11_09_200002) unless guarded?
    InstanceSetting.reset_column_information
    ActiveRecord::Migration.verbose = true
  end

  def context = ActiveRecord::Base.connection_pool.migration_context

  def connection = ActiveRecord::Base.connection

  def guarded? = connection.check_constraints(:instance_settings).any? { it.expression == "id = 1" }

  def lift_guard = (context.run(:down, 2026_11_09_200002) if guarded?)

  def insert_row(id, open:, created_at: "2026-11-01")
    connection.execute("INSERT INTO instance_settings (id, sign_up_open, created_at, updated_at) VALUES (#{id}, #{open ? 1 : 0}, '#{created_at}', '#{created_at}')")
  end

  def rows = connection.select_rows("SELECT id, sign_up_open, created_at, updated_at FROM instance_settings ORDER BY id")

  def run_up = described_class.new.migrate(:up)

  it "keeps the lowest id's values as row 1 and removes the others (the race's leftovers)", :aggregate_failures do
    insert_row(4, open: true, created_at: "2026-11-02")
    insert_row(9, open: false, created_at: "2026-11-03")
    insert_row(12, open: false, created_at: "2026-11-04")

    run_up

    expect(rows).to eq([ [ 1, 1, "2026-11-02", "2026-11-02" ] ])
  end

  it "leaves a table with the one row, id 1, as it is", :aggregate_failures do
    insert_row(1, open: true)
    before = rows

    run_up

    expect(rows).to eq(before)
  end

  it "gives the one row id 1 when it has another id" do
    insert_row(6, open: true)

    run_up

    expect(rows).to eq([ [ 1, 1, "2026-11-01", "2026-11-01" ] ])
  end

  it "passes on a table with no row, and makes none (current makes it on first use)", :aggregate_failures do
    expect { run_up }.not_to raise_error
    expect(rows).to be_empty
  end

  it "is safe to run twice" do
    insert_row(3, open: true)
    insert_row(8, open: false)

    run_up
    after_first = rows
    run_up

    expect(rows).to eq(after_first)
  end

  it "changes nothing going down" do
    insert_row(5, open: true)
    before = rows

    described_class.new.migrate(:down)

    expect(rows).to eq(before)
  end

  it "leaves a table the guard accepts, whatever it held before", :aggregate_failures do
    insert_row(2, open: false)
    insert_row(3, open: true)

    run_up
    expect { context.run(:up, 2026_11_09_200002) }.not_to raise_error

    expect(rows.size).to eq(1)
    expect { insert_row(2, open: false) }.to raise_error(ActiveRecord::StatementInvalid, /CHECK constraint failed/)
  end
end
