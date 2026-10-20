# The account's list of number entry adds, open until Done (spec 026 decisions 4–6). An account has at most one: the
# first add opens it, and Done deletes it with its lines, which are working state rather than collection data (left out
# of the export). SQLite's IMMEDIATE transactions serialise writers, so two adds can't both open a list or reuse a key.
class NumberEntry < ApplicationRecord
  KEY_FORMAT = /\A[0-9a-f]{32}\z/
  SHOWN = 10

  # One add's outcome: its line, and whether an earlier request with the same line key made it (decision 10).
  Added = Data.define(:line, :replayed)

  belongs_to :account
  has_many :lines, class_name: "NumberEntry::Line", foreign_key: :number_entry_id, inverse_of: :list, dependent: :delete_all

  def self.new_line_key = SecureRandom.hex(16)

  # Adds quantity copies of entry, at most once per line key in the account's list (FR-3, AC-2.11). The copies merge
  # into their lot through Lot.add!, which raises RecordInvalid at the 9,999 cap (AC-4.4); nothing is recorded then.
  def self.add!(account:, entry:, quantity:, finish:, line_key:)
    raise ArgumentError, "malformed line key" unless KEY_FORMAT.match?(line_key.to_s)

    transaction do
      list = find_or_create_by!(account:)
      existing = list.lines.find_by(line_key:)
      next Added.new(line: existing, replayed: true) if existing

      lot = Lot.add!(account:, entry:, quantity:, finish:)
      Added.new(line: list.lines.create!(account:, entry:, lot:, quantity:, finish:, line_key:), replayed: false)
    end
  end

  # Lines not undone, newest first, with what the page shows of each (AC-3.1).
  def kept_lines = lines.kept.newest_first.includes(:lot, entry: :set)
end
