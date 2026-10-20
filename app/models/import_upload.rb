# The account's previewed export file, kept briefly so that it can be applied (spec 028 decisions 1, 9).
class ImportUpload < ApplicationRecord
  EXPIRES_IN = 1.hour

  belongs_to :account
  has_one_attached :file, dependent: false # removal is ImportUpload#remove!, added in Phase 1 (spec 028 decision 9)
end
