# The tenant: owns every piece of collection data. One per user (spec 004 FR-3).
class Account < ApplicationRecord
  has_one :user, dependent: nil
  has_many :lots, dependent: :delete_all

  def copies_count = lots.sum(:quantity)
end
