# Deletes expired sessions every night (spec 049 decision 8). Idempotent: a second run right after the first deletes nothing.
# One at a time, as the sweep is cross-tenant and SQLite has one writer; a busy database is retried with a backoff. A run that
# is missed is harmless: the request path already refuses an expired session, and the next run deletes what is left.
class Session::SweepJob < ApplicationJob
  queue_as :default

  limits_concurrency to: 1, key: "session_sweep", duration: 15.minutes
  retry_on SQLite3::BusyException, ActiveRecord::StatementTimeout, wait: :polynomially_longer, attempts: 3

  def perform = Session.sweep!
end
