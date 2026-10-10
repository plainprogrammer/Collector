# Runs a catalog refresh in the background. Queued weekly by
# config/recurring.yml and on demand by `bin/rails "catalog:refresh[mtg]"`.
class Catalog::RefreshJob < ApplicationJob
  # How long the queue holds a second refresh for the same type back when the first never reports its end. It is not
  # the run's stall threshold (Catalog::RefreshRun::STALL_AFTER, minutes): a waiting refresh must never start while
  # another's job may still be working (spec 015 FR-1).
  LOCK_FOR = 6.hours

  queue_as :sync

  # A second refresh for the same type waits for the first (Catalog::RefreshRun.start! guards the edge cases).
  limits_concurrency to: 1, key: ->(collectible_type, *) { collectible_type }, duration: LOCK_FOR

  retry_on Catalog::Sources::TransientError, ActiveRecord::StatementTimeout, wait: :polynomially_longer, attempts: 3

  def perform(collectible_type, trigger = "manual")
    Catalog::Refresh.new(collectible_type, trigger:, job_id:).call
  end
end
