class Session < ApplicationRecord
  belongs_to :user
  # The database removes these with the session (ON DELETE CASCADE): sessions also end through
  # delete_all (User#end_sessions!, user deletion), which runs no callbacks (spec 006 FR-4, FR-6).
  has_one :bulk_selection
  has_many :bulk_removals
end
