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
  belongs_to :location, optional: true # where its adds go (spec 040 decision 2); the database nulls it when the location goes
  has_many :entries, class_name: "Scanner::SittingEntry", foreign_key: :scanner_sitting_id, inverse_of: :sitting,
    dependent: :delete_all

  # Adds one copy of a printing for a reading, into the sitting's place (spec 040 AC-1.3), at most once per reading key in the account's open sitting (AC-1.2,
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

      lot = Lot.add!(account:, entry: printing, finish:, location: sitting.location) # read in the transaction (spec 040 FR-2)
      Added.new(entry: sitting.entries.create!(account:, printing:, lot:, finish:, reading_key:), replayed: false)
    end
  end

  # A printing with finishes takes one of them; one with none listed takes none (AC-1.1).
  def self.finish_offered?(printing, finish)
    finishes = Catalog.collecting_for(printing.collectible_type).finishes_for(printing)
    finishes.empty? ? finish.nil? : finishes.include?(finish)
  end

  CHOICES = %i[condition location].freeze

  # Sets, changes or clears the account's sitting choices (spec 042 decisions 4, 8; spec 040 decision 2): a condition (a
  # vocabulary key the caller has checked) and a place. A choice left out is kept; one given as nil is cleared. Choosing opens
  # a sitting as an add does; a sitting left with no kept card, no condition and no place is deleted, so the page is as before
  # any sitting (AC-1.8), the check and the delete in one write transaction. Returns the sitting (destroyed when it was
  # deleted), or nil when there was none to clear.
  def self.choose!(account:, **choices)
    raise ArgumentError, "give :condition, :location or both" if choices.empty? || (choices.keys - CHOICES).any?

    transaction do
      sitting = find_by(account:)
      next if sitting.nil? && choices.values.none? # clearing with none open opens none

      sitting ||= create!(account:)
      sitting.update!(choices)
      sitting.destroy! if sitting.condition.nil? && sitting.location_id.nil? && !sitting.entries.kept.exists?
      sitting
    end
  end

  # A sitting with no entries at all, no place and no condition says nothing, so the scanner drops it before it renders (spec 040
  # AC-3.2, spec 042 AC-3.3): what a removed location leaves of a sitting that was only opened by choosing that place.
  def pointless? = location_id.nil? && condition.nil? && !entries.exists?

  # Deletes this sitting if it is pointless, reading it again in the write transaction so an add or a place from another
  # tab since it was loaded keeps it. Returns whether it went.
  def drop_if_pointless!
    transaction do
      reload
      pointless?.tap { |gone| destroy! if gone }
    end
  rescue ActiveRecord::RecordNotFound
    true
  end

  # Every entry not undone, newest first, including those whose lot changed (AC-3.2, AC-3.6), with each lot and its place
  # (spec 040 decision 4).
  def kept_entries = entries.kept.newest_first.includes(printing: :set, lot: :location)

  # Ends the sitting (AC-3.5): the copies stay in the collection; the entries go. Returns how many were kept.
  def end!
    count = entries.kept.count
    destroy!
    count
  end
end
