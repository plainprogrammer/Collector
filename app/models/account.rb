# The tenant: owns every piece of collection data. One per user (spec 004 FR-3).
class Account < ApplicationRecord
  has_one :user, dependent: nil
  # Order matters: the foreign key from a lot to its location refuses deleting a location a lot is in, so the lots go first.
  # spec/models/account_spec.rb guards it (spec 032 AC-6.6).
  has_many :lots, dependent: :delete_all
  has_many :locations, dependent: :delete_all # the foreign key cascades too, as for `import_uploads` and `number_entries` (spec 029 AC-4.6)
  has_one :scanner_sitting, class_name: "Scanner::Sitting", dependent: :destroy
  has_one :number_entry, dependent: :destroy
  has_one :import_upload, dependent: :destroy
  has_many :bulk_selections, dependent: nil # the foreign keys cascade; here for the apply to name them
  has_many :bulk_removals, dependent: nil

  # The currency every price of the account is shown in; a new account starts at the instance default (spec 038 decision 1–2).
  attribute :currency, :string, default: -> { Rails.configuration.x.default_currency.code }
  validates :currency, inclusion: { in: Collector::Currency::SYMBOLS.keys, message: "Choose one of the listed currencies." }

  def copies_count = lots.sum(:quantity)

  # What a price of this account is shown with: the code and the symbol (spec 038 decision 1).
  def currency_unit = Collector::Currency.fetch!(currency, setting: "accounts.currency")
end
