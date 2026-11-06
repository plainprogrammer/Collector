# What a job does when its source turned it away (Catalog::Sources::RateLimitedError, issue #74): it runs again no
# sooner than the source asked, so the queue holds the wait instead of a worker. While its retry waits it holds no
# concurrency lock, so another job of its class (the schedule's, or one started by hand) can be queued meanwhile; the
# operation's start guard skips that one while this one waits (Catalog::Operation::Queue#waiting_to_retry?, issue #78).
#
# Include it after the job's own retry_on lines: Active Job tries the handler declared last first, and this one must
# come before a rule for Catalog::Sources::TransientError, whose few seconds are sooner than a source asks.
#
# - The wait is what the source asked for (the error's #retry_after), and SHORTEST_WAIT at least: that covers a source
#   that never said, and one whose last answer asked for less than its own rate limit lasts. SHORTEST_WAIT is the 30
#   seconds for which the one source so far says a "too many requests" answer limits access, plus a margin of 15: the
#   wait runs from when the error is handled, a little after the answer, on this host's clock, so 30 exactly would
#   leave the next request clear of that window only by however long the queue takes to dispatch the job.
# - A source that asks for more than LONGEST_WAIT isn't waited for: the job fails, and shows under Failed.
# - The job is retried while its rate limits come with progress between them, and MAX_RETRIES times in a row without it
#   (spec 043, issue #86). When a rate limit ends an attempt that made progress (the job's answer to
#   #rate_limit_progress?: durable new work, as its own operation judges it), the count starts again at 1; otherwise it
#   goes up by one, and the job fails when that would pass MAX_RETRIES, that is on the fourth rate limit in a row with no
#   progress between them. A job that says nothing about progress has made none: every rate limit counts. The question
#   is about the attempt the rate limit ended, alone.
module Catalog::RateLimitRetry
  extend ActiveSupport::Concern

  SHORTEST_WAIT = 45.seconds
  LONGEST_WAIT = 1.hour
  MAX_RETRIES = 3
  # Where the job keeps its count of rate limits in a row without progress; Active Job serializes exception_executions with the job (a job queued before spec 043 keeps its count).
  COUNTED_AS = "[Catalog::Sources::RateLimitedError]".freeze

  included do
    rescue_from(Catalog::Sources::RateLimitedError) { |error| retry_when_asked(error) }
  end

  private
    def retry_when_asked(error)
      wait = [ error.retry_after.to_i.seconds, SHORTEST_WAIT ].max
      raise error if wait > LONGEST_WAIT

      counted = rate_limit_progress? ? 0 : exception_executions[COUNTED_AS].to_i
      raise error if counted >= MAX_RETRIES

      exception_executions[COUNTED_AS] = counted + 1
      retry_job(wait:, error:)
    end

    # Asked of the job when a rate limit ended its attempt: did that attempt do durable new work (spec 043)? A job that
    # includes this rule overrides it from its own operation; one that doesn't answers no, so every rate limit counts.
    def rate_limit_progress? = false
end
