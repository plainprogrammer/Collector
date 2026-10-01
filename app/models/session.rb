class Session < ApplicationRecord
  belongs_to :user
  # The database removes this with the session (ON DELETE CASCADE): sessions also end through
  # delete_all (User#end_sessions!, user deletion), which runs no callbacks (spec 006 FR-4).
  has_one :bulk_selection
end
