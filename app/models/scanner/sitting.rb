# The account's run of scanner adds, open until "Done" (spec 009 Story 3, FR-2). An account has at most one: adding opens
# it, and ending it deletes it with its entries, which are workflow state rather than collection data (not exported).
# SQLite's IMMEDIATE transactions serialise writers, so two adds can't both open a sitting or reuse a key.
class Scanner::Sitting < ApplicationRecord
  KEY_FORMAT = /\A[0-9a-f]{32}\z/
  SHOWN = 10

  # Why an add was turned away before anything changed (FR-1): :key, :unavailable or :finish.
  class Refused < StandardError
    attr_reader :reason

    def initialize(reason)
      @reason = reason
      super(reason.to_s)
    end
  end

  # One add's outcome: its entry, and whether an earlier request with the same reading key made it (AC-1.5).
  Added = Data.define(:entry, :replayed)

  belongs_to :account
  has_many :entries, class_name: "Scanner::SittingEntry", foreign_key: :scanner_sitting_id, inverse_of: :sitting,
    dependent: :delete_all

  # Adds one copy of a printing for a reading, at most once per reading key in the account's open sitting (AC-1.2,
  # AC-1.5, AC-3.1). The copy merges into its lot as the catalog's Add does; Lot.add! raises RecordInvalid at the
  # 9,999 cap (AC-1.6), and nothing is recorded then.
  def self.add!(account:, printing:, finish:, reading_key:)
    finish = finish.presence
    raise Refused, :key unless KEY_FORMAT.match?(reading_key.to_s)
    raise Refused, :unavailable unless printing && Catalog::Entry.searchable.exists?(printing.id)
    raise Refused, :finish unless finish_offered?(printing, finish)

    transaction do
      sitting = find_or_create_by!(account:)
      existing = sitting.entries.find_by(reading_key:)
      next Added.new(entry: existing, replayed: true) if existing

      lot = Lot.add!(account:, entry: printing, finish:)
      Added.new(entry: sitting.entries.create!(account:, printing:, lot:, finish:, reading_key:), replayed: false)
    end
  end

  # A printing with finishes takes one of them; one with none listed takes none (AC-1.1).
  def self.finish_offered?(printing, finish)
    finishes = Catalog.collecting_for(printing.collectible_type).finishes_for(printing)
    finishes.empty? ? finish.nil? : finishes.include?(finish)
  end

  # Every entry not undone, newest first, including those whose lot changed (AC-3.2, AC-3.6).
  def kept_entries = entries.kept.newest_first.includes(printing: :set)

  # Ends the sitting (AC-3.5): the copies stay in the collection; the entries go. Returns how many were kept.
  def end!
    count = entries.kept.count
    destroy!
    count
  end
end
