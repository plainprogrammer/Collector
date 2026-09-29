# One attempt to apply a catalog source's data, with its outcome and counts.
class Catalog::RefreshRun < ApplicationRecord
  STALE_AFTER = 6.hours
  TRIGGERS = %w[scheduled manual].freeze
  COUNTS = %i[seen inserted updated retired restored malformed].freeze

  enum :status, { running: "running", applied: "applied", skipped: "skipped", failed: "failed" }, validate: true

  validates :collectible_type, :started_at, presence: true
  validates :trigger, inclusion: { in: TRIGGERS }

  scope :for_type, ->(collectible_type) { where(collectible_type:) }
  scope :recent, -> { order(started_at: :desc, id: :desc) }
end
