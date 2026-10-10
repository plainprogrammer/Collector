# What the admin catalog and jobs pages share (spec 015): times in UTC (FR-8) and the words for facts and stages.
module AdminHelper
  STAGE_WORDS = { done: "Done", current: "In progress", stopped: "Stopped here", pending: "Waiting" }.freeze

  # "9 Oct 2026 03:15 UTC", in a <time> element carrying the exact instant.
  def utc_time(time) = time_tag(time.utc, time.utc.strftime("%-d %b %Y %H:%M UTC"))

  # "2 minutes ago", or "in 3 minutes" for a time still to come.
  def relative_time(time)
    words = distance_of_time_in_words(Time.current, time)
    time.future? ? "in #{words}" : "#{words} ago"
  end

  # The UTC time with the relative form after it: "9 Oct 2026 03:15 UTC (2 minutes ago)".
  def utc_time_with_relative(time) = safe_join([ utc_time(time), " (#{relative_time(time)})" ])

  # A Catalog::Operation::Fact's value as the page shows it: a time in UTC, a number with delimiters, or the text.
  def fact_value(fact)
    case fact.value
    when Time then fact.relative ? utc_time_with_relative(fact.value) : utc_time(fact.value)
    when Integer then number_with_delimiter(fact.value)
    else fact.value.to_s
    end
  end

  JOBS_TIME_HEADINGS = { "failed" => "Failed", "running" => "Started", "queued" => "Queued", "scheduled" => "Due" }.freeze

  # The heading of the jobs list's time column: the time that matters to the state shown.
  def admin_jobs_time_heading(state) = JOBS_TIME_HEADINGS.fetch(state)

  def stage_word(stage) = STAGE_WORDS.fetch(stage.state)

  # What a finished refresh run did, in a few words, for the recent-runs list.
  def refresh_run_outcome(run)
    return run.message.to_s unless run.applied?

    changed = run.inserted_count + run.updated_count + run.retired_count + run.restored_count
    "#{number_with_delimiter(run.seen_count)} seen · #{number_with_delimiter(changed)} changed"
  end
end
