# What the daily refresh needs of price_refresh_runs (spec 089 decision 2; supersedes the run_on column of spec 081).
#
# run_on becomes nullable: a run opens before its file's date is known, and some end before it is (already running, an
# empty catalog, a transient error). job_id is for the stall rule; languages and the counts say what the run did.
#
# price_refresh_runs is a rowid table, so Rails' table rebuild for change_column_null is safe here, unlike for
# current_prices and price_changes (see the first prices migration's warning). The columns are added first and the
# rebuild comes last, so the stored table SQL is the canonical one. `down` gives a nil run_on the date of started_at,
# so it never loses a row.
class PreparePriceRefreshRuns < ActiveRecord::Migration[8.1]
  COUNTS = %i[quotes_seen unchanged changed added removed removals_withheld unknown_printings malformed].freeze

  def up
    add_column :price_refresh_runs, :job_id, :string
    add_column :price_refresh_runs, :languages, :string
    COUNTS.each { |name| add_column :price_refresh_runs, name, :integer, null: false, default: 0 }
    change_column_null :price_refresh_runs, :run_on, true
  end

  def down
    execute "UPDATE price_refresh_runs SET run_on = date(started_at) WHERE run_on IS NULL"
    change_column_null :price_refresh_runs, :run_on, false
    remove_columns :price_refresh_runs, *COUNTS, :languages, :job_id
  end
end
