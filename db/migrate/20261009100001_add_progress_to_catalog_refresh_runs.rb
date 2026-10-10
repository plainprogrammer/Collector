# Spec 015 FR-1: a refresh run records where it is while it runs (its stage, and how far through it), when it last made
# progress (the heartbeat the stall rule reads) and which job runs it (so a job that starts again closes its own run).
# Additive and nullable: runs recorded before this migration keep working, with no stage, heartbeat or job.
class AddProgressToCatalogRefreshRuns < ActiveRecord::Migration[8.1]
  def change
    change_table :catalog_refresh_runs, bulk: true do |t|
      t.string :stage
      t.bigint :stage_done
      t.bigint :stage_total
      t.string :job_id
      t.datetime :heartbeat_at
    end
  end
end
