# Active Record reserves the attribute name `changed` (ActiveRecord::DangerousAttributeError), so the count of repriced
# quotes that 20261113190001 added under that name is `repriced` (spec 089 decision 2, v0.4.3). A rowid table, so the
# table rebuild of rename_column is safe; the migration before it is unreleased and stays as built.
class RenamePriceRefreshRunsChanged < ActiveRecord::Migration[8.1]
  def change
    rename_column :price_refresh_runs, :changed, :repriced
  end
end
