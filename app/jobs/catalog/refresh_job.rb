# Runs a catalog refresh in the background. Queued weekly by
# config/recurring.yml and on demand by `bin/rails "catalog:refresh[mtg]"`.
class Catalog::RefreshJob < ApplicationJob
  queue_as :sync

  # A second refresh for the same type waits for the first (Catalog::RefreshRun.start! guards the edge cases).
  limits_concurrency to: 1, key: ->(collectible_type, *) { collectible_type }, duration: Catalog::RefreshRun::STALE_AFTER

  retry_on Catalog::Sources::TransientError, ActiveRecord::StatementTimeout, wait: :polynomially_longer, attempts: 3

  def perform(collectible_type, trigger = "manual")
    Catalog::Refresh.new(collectible_type, trigger:).call
  end
end
