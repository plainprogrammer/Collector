# What a job does when its source turned it away (Catalog::Sources::RateLimitedError, issue #74): it runs again no
# sooner than the source asked, so the queue holds the wait instead of a worker. That holds for this job only. While
# its retry waits it holds no concurrency lock, so another job of its class (the schedule's, or one started by hand)
# can start meanwhile and ask the source at once; nothing here stops that.
#
# Include it after the job's own retry_on lines: Active Job tries the handler declared last first, and this one must
# come before a rule for Catalog::Sources::TransientError, whose few seconds are sooner than a source asks.
#
# - The wait is what the source asked for (the error's #retry_after), and SHORTEST_WAIT at least: that covers a source
#   that never said, and one whose last answer asked for less than its own rate limit lasts.
# - A source that asks for more than LONGEST_WAIT isn't waited for: the job fails, and shows under Failed.
# - So does a job turned away again after MAX_RETRIES such retries.
module Catalog::RateLimitRetry
  extend ActiveSupport::Concern

  SHORTEST_WAIT = 30.seconds
  LONGEST_WAIT = 1.hour
  MAX_RETRIES = 3
  # Where the job keeps its count of these retries; Active Job serializes exception_executions with the job.
  COUNTED_AS = "[Catalog::Sources::RateLimitedError]".freeze

  included do
    rescue_from(Catalog::Sources::RateLimitedError) { |error| retry_when_asked(error) }
  end

  private
    def retry_when_asked(error)
      wait = [ error.retry_after.to_i.seconds, SHORTEST_WAIT ].max
      retries = exception_executions[COUNTED_AS].to_i
      raise error if wait > LONGEST_WAIT || retries >= MAX_RETRIES

      exception_executions[COUNTED_AS] = retries + 1
      retry_job(wait:, error:)
    end
end
