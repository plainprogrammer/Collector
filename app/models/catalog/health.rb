# One catalog type as the admin catalog page shows it (spec 015 Story 5): how many entries it holds, its last applied
# refresh, when the next one is scheduled, what an admin can start for it, and its recent runs.
class Catalog::Health
  RECENT_RUNS = 5

  attr_reader :collectible_type

  def self.all = Catalog.sources.keys.sort.map { |collectible_type| new(collectible_type) }

  # Raises ActiveRecord::RecordNotFound for a type that isn't registered, so a request naming one answers 404.
  def self.find(collectible_type)
    raise ActiveRecord::RecordNotFound, "unknown catalog type" unless Catalog.sources.key?(collectible_type.to_s)

    new(collectible_type.to_s)
  end

  def initialize(collectible_type)
    @collectible_type = collectible_type
  end

  def title = Catalog.title_for(collectible_type)

  def loaded? = last_applied.present?

  def entries_count = @entries_count ||= Catalog::Entry.active.where(collectible_type:).count

  def last_applied
    return @last_applied if defined?(@last_applied)

    @last_applied = Catalog::RefreshRun.for_type(collectible_type).last_applied
  end

  # When the schedule next queues a refresh for this type, or nil when nothing is scheduled (as in development).
  def next_refresh_at
    SolidQueue::RecurringTask.where(class_name: Catalog::RefreshJob.name)
      .select { |task| Array(task.arguments).first == collectible_type }.filter_map(&:next_time).min
  end

  # The languages the source is set to take, or the reason the setting can't be read.
  def languages
    Catalog.source_for(collectible_type).languages.map(&:upcase).join(", ")
  rescue Catalog::Sources::ConfigurationError => error
    error.message
  end

  def refresh = operations.first

  # The refresh first, then whatever the source adds (optional hook, app/models/catalog/sources.rb).
  def operations
    @operations ||= begin
      source = Catalog.source_class(collectible_type)
      [ Catalog::RefreshOperation.new(collectible_type), *(source.operations(collectible_type) if source.respond_to?(:operations)) ]
    end
  end

  def operation(key) = operations.find { |operation| operation.key == key.to_s }

  def in_flight? = operations.any?(&:in_flight?)

  def recent_runs = @recent_runs ||= Catalog::RefreshRun.for_type(collectible_type).recent.limit(RECENT_RUNS).to_a
end
