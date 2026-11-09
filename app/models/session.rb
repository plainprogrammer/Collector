class Session < ApplicationRecord
  # A session unused for this long is no session (spec 049 decisions 1 and 4); the cookie's lifetime is the same (decision 7).
  IDLE_LIMIT = 30.days
  # Use is recorded at most this often, so ordinary requests don't write (decision 2).
  STAMP_INTERVAL = 1.day
  # Expired sessions are deleted this many to a statement (decision 10).
  SWEEP_BATCH = 1_000

  belongs_to :user
  # The database removes these with the session (ON DELETE CASCADE): sessions also end through
  # delete_all (User#end_sessions!, user deletion), which runs no callbacks (spec 006 FR-4, FR-6).
  has_one :bulk_selection
  has_many :bulk_removals

  attribute :last_used_at, default: -> { Time.current }

  scope :expired, ->(now = Time.current) { where(last_used_at: ..(now - IDLE_LIMIT)) }

  def expired?(now = Time.current) = last_used_at <= now - IDLE_LIMIT

  # Due for a new stamp: a day old, or later than now (the host's clock was set back, AC-2.8).
  def stale?(now = Time.current) = last_used_at <= now - STAMP_INTERVAL || last_used_at > now
end
