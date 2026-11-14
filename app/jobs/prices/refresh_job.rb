# Runs the daily price refresh for a price source, in the background (spec 089). Queued daily by config/recurring.yml,
# or by hand from `bin/rails runner`; there is no button or task until the admin page (#367).
#
# No error is discarded: a failed job shows under Failed on `/admin/jobs`, which is how an operator learns of a guard that
# fired before #367 shows the runs. A departure from `background-jobs.md`'s `discard_on` advice, whose example is a
# `DeserializationError`: the argument is a string, and a discarded job would hide a guard that fired (spec 089 decision 7).
#
# @see file:prices.md
class Prices::RefreshJob < ApplicationJob
  # How long the queue holds a second refresh of the source back when the first never reports its end: a waiting refresh
  # must never start while another's job may still be working (the catalog refresh's value, spec 089 decision 7). The
  # run's own stall rule is `PriceRefreshRun::STALL_AFTER`, in minutes.
  LOCK_FOR = 6.hours

  queue_as :sync

  limits_concurrency to: 1, key: ->(source_key, *) { source_key }, duration: LOCK_FOR

  # The download's size error is retried too: a file republished mid-download gives exactly it, and the retry asks the
  # index again (spec 089 decision 7).
  retry_on Catalog::Sources::TransientError, Catalog::Sources::IntegrityError, ActiveRecord::StatementTimeout,
    wait: :polynomially_longer, attempts: 3
  # After retry_on, so that it is tried first: a rate-limited source is a TransientError too, but the job comes back when
  # the source asked. It reports no progress: a rate limit ends a refresh before any row is written.
  include Catalog::RateLimitRetry

  # @param source_key [String] a key of `Prices.sources`
  def perform(source_key) = Prices::Refresh.new(source_key, job_id:).call
end
