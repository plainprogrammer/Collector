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

  # Records a new attempt. A run left "running" for STALE_AFTER is marked
  # failed ("interrupted"); a younger one makes this attempt a skip.
  def self.start!(collectible_type, trigger:)
    transaction do
      runs = for_type(collectible_type)
      runs.running.where(started_at: ..STALE_AFTER.ago).find_each { |run| run.finish!(:failed, message: "interrupted") }

      already_running = runs.running.exists?
      run = create!(collectible_type:, trigger:, status: :running, started_at: Time.current)
      run.finish!(:skipped, message: "already running") if already_running
      run
    end
  end

  def self.applied?(collectible_type, source_version:, languages:)
    for_type(collectible_type).applied.exists?(source_version:, languages:)
  end

  def self.last_applied = applied.order(finished_at: :desc).first

  def finish!(status, message: nil, counts: {})
    update!(status:, message:, finished_at: Time.current, **counts.transform_keys { |name| :"#{name}_count" })
    Rails.logger.info(ActiveSupport::JSON.encode(event: "catalog.refresh.finished", collectible_type:,
      trigger:, status:, source_version:, languages:, message:, **self.counts))
  end

  def counts = COUNTS.index_with { |name| public_send(:"#{name}_count") }

  def status_line
    [ started_at.utc.iso8601, finished_at&.utc&.iso8601 || "-", status, trigger, source_version || "-",
      counts.map { |name, value| "#{name}=#{value}" }.join(" "), message ].compact.join("  ")
  end
end
