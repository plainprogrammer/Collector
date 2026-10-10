# What the admin pages share (spec 015): times in UTC (FR-8).
module AdminHelper
  # "9 Oct 2026 03:15 UTC", in a <time> element carrying the exact instant.
  def utc_time(time) = time_tag(time.utc, time.utc.strftime("%-d %b %Y %H:%M UTC"))

  # "2 minutes ago", or "in 3 minutes" for a time still to come.
  def relative_time(time)
    words = distance_of_time_in_words(Time.current, time)
    time.future? ? "in #{words}" : "#{words} ago"
  end

  # The UTC time with the relative form after it: "9 Oct 2026 03:15 UTC (2 minutes ago)".
  def utc_time_with_relative(time) = safe_join([ utc_time(time), " (#{relative_time(time)})" ])

  JOBS_TIME_HEADINGS = { "failed" => "Failed", "running" => "Started", "queued" => "Queued", "scheduled" => "Due" }.freeze

  # The heading of the jobs list's time column: the time that matters to the state shown.
  def admin_jobs_time_heading(state) = JOBS_TIME_HEADINGS.fetch(state)
end
