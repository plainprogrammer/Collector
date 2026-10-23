# The tenant: owns every piece of collection data. One per user (spec 004 FR-3).
class Account < ApplicationRecord
  has_one :user, dependent: nil
  has_many :lots, dependent: :delete_all
  has_many :locations, dependent: :delete_all # the foreign key cascades too, as for `import_uploads` and `number_entries` (spec 029 AC-4.6)
  has_one :scanner_sitting, class_name: "Scanner::Sitting", dependent: :destroy
  has_one :number_entry, dependent: :destroy
  has_one :import_upload, dependent: :destroy
  has_many :bulk_selections, dependent: nil # the foreign keys cascade; here for the apply to name them
  has_many :bulk_removals, dependent: nil

  def copies_count = lots.sum(:quantity)
end
