# Something an admin can start for a catalog type and watch on the admin catalog page (spec 015 FR-2). The core has
# one, the refresh (Catalog::RefreshOperation); a source adds others through its optional .operations hook
# (app/models/catalog/sources.rb). The page knows only this interface, so it never names a source or what it builds.
#
# A subclass provides:
#   key                 String naming it in the start request ("refresh")
#   title               what the panel calls it ("Refresh")
#   start_label         its button ("Refresh now")
#   queued_notice       said after it was queued ("Refresh queued.")
#   in_flight_notice    said when it was already queued or running
#   job_class           the job that does the work, and job_arguments for it
#   summary             one sentence on where it stands, starting with its state in a word
#   record_running?     true while its own run record says it is working
# and may provide queue_argument, stages, meter, facts and unavailable_reason.
class Catalog::Operation
  # One step of an operation: its state is :done, :current, :stopped (where a run failed or was interrupted) or :pending.
  Stage = Data.define(:label, :state, :meter, :note)

  # How far through something is. Without a total there is no percentage, only the text.
  Meter = Data.define(:label, :done, :total, :text) do
    def percent = total.to_i.positive? ? (done.to_i * 100 / total).clamp(0, 100) : nil
  end

  # A labelled fact under the summary. The value is a String, an Integer or a Time; relative asks for "2 minutes ago" too.
  Fact = Data.define(:label, :value, :relative)

  attr_reader :collectible_type

  def initialize(collectible_type)
    @collectible_type = collectible_type
  end

  def to_param = key
  def job_arguments = []

  # The job's first argument when its jobs are per catalog type; nil when the job takes none.
  def queue_argument = nil

  def stages = []
  def meter = nil
  def facts = []

  # Why it can't be started at all right now, whatever is in flight (a setting that is off, something missing).
  def unavailable_reason = nil

  def queue = @queue ||= Queue.new(job_class, queue_argument)

  # Spec 015 glossary: an unfinished job for it is in the queue, or its run record is running.
  def in_flight? = queue.any? || record_running?

  # True when a job of its is in the queue's failed list, so the page links there.
  def failed_job? = queue.failed?

  def startable? = unavailable_reason.nil? && !in_flight?

  # Queues its job unless it is unavailable or already in flight. True when it queued one.
  def start = startable? && job_class.perform_later(*job_arguments).present?

  private
    def fact(label, value, relative: false) = Fact.new(label:, value:, relative:)
end
