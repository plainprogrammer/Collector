# The refresh of one catalog type as the admin catalog page shows it (spec 015 Stories 2 and 3): the latest run that
# wasn't skipped because another was running (AC-2.16), what the job queue holds, and what follows from the two.
class Catalog::RefreshOperation < Catalog::Operation
  STAGES = { "download" => "Download", "sync" => "Sync cards", "retire" => "Retire missing cards",
             "index" => "Rebuild name index" }.freeze
  DOING = { "download" => "downloading", "sync" => "syncing cards", "retire" => "retiring missing cards",
            "index" => "rebuilding the name index" }.freeze
  SYNC_COUNTS = %i[seen inserted updated].freeze

  def key = "refresh"
  def title = "Refresh"
  def start_label = "Refresh now"
  def queued_notice = "Refresh queued."
  def in_flight_notice = "A refresh is already queued or running."
  def job_class = Catalog::RefreshJob
  def job_arguments = [ collectible_type, "manual" ]
  def queue_argument = collectible_type

  def run
    return @run if defined?(@run)

    @run = Catalog::RefreshRun.for_type(collectible_type).attempted.recent.first
  end

  # :never, :queued, :running, :stalled, :interrupted, :applied, :skipped or :failed.
  def state
    @state ||=
      if run&.running? then running_state
      elsif queue.any? then :queued
      else run ? run.status.to_sym : :never
      end
  end

  def record_running? = %i[running stalled].include?(state)

  # The page links to the failed list only for the failed run on show (spec 015 AC-3.1).
  def failed_job? = state == :failed && super

  # What `catalog:status` and the recent-runs list call a run: a stalled one is interrupted unless its job is still
  # claimed by a worker (spec 015 AC-3.2, AC-3.5, AC-3.6).
  def status_label(run) = run.status_label(job_claimed: job_claimed?(run))

  def summary
    case state
    when :never then "No refresh has run yet."
    when :queued then retrying? ? "Queued to retry. The last run #{failed_summary.downcase_first}" : "Queued."
    when :running then "Running."
    when :stalled then "Running, no progress for #{run.stalled_minutes} minutes."
    when :interrupted then [ "Interrupted", doing ].compact.join(" while ") + "."
    when :applied then "Applied."
    when :skipped then "Skipped: #{run.message}."
    when :failed then failed_summary
    end
  end

  # The four stages of the run in view, while it runs and after it failed or was interrupted.
  def stages
    return [] unless shown_run&.stage && (shown_run.running? || shown_run.failed?)

    reached = STAGES.keys.index(shown_run.stage)
    STAGES.each_with_index.map do |(name, label), index|
      here = index == reached
      Stage.new(label:, state: stage_state(index, reached), meter: (stage_meter(name) if here), note: (stage_note(name) if here))
    end
  end

  def facts
    retry_fact = [ (fact("Retrying at", queue.retry_at) if state == :queued && queue.retry_at) ].compact
    return retry_fact unless shown_run

    retry_fact + [
      fact("Started", shown_run.started_at), fact("Trigger", shown_run.trigger),
      (fact("Last progress", shown_run.last_progress_at, relative: true) if shown_run.running?),
      (fact("Finished", shown_run.finished_at) if shown_run.finished_at),
      (fact("Source version", shown_run.source_version) if shown_run.source_version),
      (fact("Counts", counts_text(Catalog::RefreshRun::COUNTS)) if shown_run.applied?)
    ].compact
  end

  private
    def running_state
      return :running unless run.stalled?

      job_claimed?(run) ? :stalled : :interrupted
    end

    def job_claimed?(run) = run.job_id.present? && queue.claimed?(run.job_id)

    # A failed run whose job waits to run again (spec 015 AC-3.7).
    def retrying? = state == :queued && queue.retry_at.present? && run&.failed?

    # The run the stages and facts describe: none while a new refresh is queued, unless it is the failed run's retry.
    def shown_run = (run if state != :queued || retrying?)

    def doing = DOING[run.stage]

    def failed_summary = [ "Failed", doing ].compact.join(" while ") + ": #{run.message}"

    def stage_state(index, reached)
      return :done if index < reached
      return :pending if index > reached

      record_running? ? :current : :stopped
    end

    def stage_meter(name)
      return unless run.stage_done

      Meter.new(label: STAGES.fetch(name), done: run.stage_done, total: run.stage_total, text: (bytes_text if name == "download"))
    end

    def bytes_text
      [ run.stage_done, run.stage_total ].compact.map { |bytes| ActiveSupport::NumberHelper.number_to_human_size(bytes) }.join(" of ")
    end

    def stage_note(name) = (counts_text(SYNC_COUNTS) if name == "sync")

    def counts_text(names)
      names.map { |name| "#{ActiveSupport::NumberHelper.number_to_delimited(run.counts.fetch(name))} #{name}" }.join(" · ")
    end
end
