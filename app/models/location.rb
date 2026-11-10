# A named place a collector keeps part of their collection (spec 029): a name, unique among the account's top-level
# locations by comparison key, in the database as well as here. Collectible-agnostic.
#
# A location has a `kind` (spec 062, ADR 0028): a `place` (the only kind there was), a `deck`, whose own data is a `decks`
# row, or a `deck_zone`, a child of a deck that holds its copies. A top-level location is a place or a deck and shares one
# name space and the 500 limit with the others; a zone's name is unique within its deck and no zone counts toward the limit.
# Every list of "places" must say which kind it means: `places` for a picker or a filter, `top_level` for everything the
# collector names, and no scope when the reader follows a lot to where it is (a lot may sit in a zone).
# @see file:collection-and-lots.md
class Location < ApplicationRecord
  MAX_PER_ACCOUNT = 500
  KINDS = %w[place deck deck_zone].freeze
  ZONE_SEPARATOR = " › ".freeze
  MESSAGES = {
    blank: "Give the location a name.",
    control: "Names can't contain control characters.",
    too_long: "Names can be at most #{Name::MAX_LENGTH} characters."
  }.freeze
  # The one refusal of the limit, for a place and for a deck: it says decks count, wherever it shows (spec 062 AC-1.7a).
  FULL = "You can have at most #{MAX_PER_ACCOUNT} places and decks together.".freeze

  belongs_to :account
  belongs_to :parent, class_name: "Location", optional: true
  has_many :zones, -> { where(kind: "deck_zone") }, class_name: "Location", foreign_key: :parent_id, inverse_of: :parent,
    dependent: nil # the foreign key cascades from a deck to its zones
  has_many :lots, dependent: nil # a location that holds lots can't be deleted: the foreign key refuses it (spec 032 decision 3)

  def holdings = Holdings.new(self)

  # The kind of location a collector can put a copy in by choice: a picker or a filter offers these until zones are offered.
  scope :places, -> { where(kind: "place") }
  scope :decks, -> { where(kind: "deck") }
  scope :zones_of_decks, -> { where(kind: "deck_zone") }
  # What the collector names and what the 500 limit counts: places and decks, never a zone.
  scope :top_level, -> { where(parent_id: nil) }

  def place? = kind == "place"
  def deck? = kind == "deck"
  def zone? = kind == "deck_zone"

  # "Izzet Tempo › Main" for a zone, the name for anything else: the one label wherever a lot's place is shown (spec 062 D6).
  # A zone needs its parent loaded; a list preloads it (`includes(location: :parent)`).
  def label = zone? ? Placement.label(name, parent.name) : name

  # By comparison key then name, both in code-point order: SQLite compares UTF-8 text by bytes (decision 2).
  scope :ordered, -> { order(:name_key, :name) }

  validate :name_is_acceptable
  validate :kind_is_consistent
  validate :name_is_free
  validate :account_has_room, on: :create

  # The name is stored as the normal form of what was assigned; the text as typed stays for a refused form to show.
  def name=(value)
    @typed = value.to_s
    super(Name.normalise(value))
    self.name_key = Name.key(name)
  end

  def typed = @typed || name.to_s

  # Two requests that race to add one name leave one location and one clean error: the unique index refuses the
  # second save, which answers false like a failed validation; save!, update! and create! raise RecordInvalid.
  def save(**)
    super
  rescue ActiveRecord::RecordNotUnique
    errors.add(:name, taken)
    false
  end

  def save!(**)
    super
  rescue ActiveRecord::RecordNotUnique
    errors.add(:name, taken)
    raise ActiveRecord::RecordInvalid, self
  end

  private
    def name_is_acceptable
      fault = Name.fault(name.to_s)
      errors.add(:name, MESSAGES.fetch(fault)) if fault
    end

    def name_is_free
      return if errors.any?

      errors.add(:name, taken) if self.class.where(account_id:, parent_id:, name_key:).where.not(id:).exists?
    end

    # What the schema can't state (spec 062 AC-9.5): a place and a deck have neither parent nor zone key; a zone has a parent
    # that is a deck of its account, so the tree is one level deep, and a zone key. (That the key is one of the deck's
    # format's needs the deck's data and is checked where a zone is built.)
    def kind_is_consistent
      return errors.add(:kind, "is not a kind of location") unless KINDS.include?(kind)

      if zone?
        errors.add(:parent, "must be a deck of the account") unless parent&.deck? && parent.account_id == account_id
        errors.add(:zone, "needs a zone key") if zone.blank?
      else
        errors.add(:parent, "is only for a zone of a deck") unless parent_id.nil?
        errors.add(:zone, "is only for a zone of a deck") unless self.zone.nil?
      end
    end

    # Write transactions are IMMEDIATE and validations run inside save's transaction, so counting and inserting is
    # one step per writer (AC-1.13). Only a new top-level row counts and is counted: a zone never does (spec 062 AC-5.9).
    def account_has_room
      return if errors.any? || !parent_id.nil?

      errors.add(:name, FULL) if self.class.where(account_id:, parent_id: nil).count >= MAX_PER_ACCOUNT
    end

    def taken = "You already have a location called “#{name}”."
end
