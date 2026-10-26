# A named place a collector keeps part of their collection (spec 029). One attribute, its name (decision 4); unique per
# account by comparison key, in the database as well as here. Collectible-agnostic.
class Location < ApplicationRecord
  MAX_PER_ACCOUNT = 500
  MESSAGES = {
    blank: "Give the location a name.",
    control: "Names can't contain control characters.",
    too_long: "Names can be at most #{Name::MAX_LENGTH} characters."
  }.freeze
  FULL = "You can have at most #{MAX_PER_ACCOUNT} locations.".freeze

  belongs_to :account
  has_many :lots, dependent: nil # a location that holds lots can't be deleted: the foreign key refuses it (spec 032 decision 3)

  def holdings = Holdings.new(self)

  # By comparison key then name, both in code-point order: SQLite compares UTF-8 text by bytes (decision 2).
  scope :ordered, -> { order(:name_key, :name) }

  validate :name_is_acceptable
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

      errors.add(:name, taken) if self.class.where(account_id:, name_key:).where.not(id:).exists?
    end

    # Write transactions are IMMEDIATE and validations run inside save's transaction, so counting and inserting is
    # one step per writer (AC-1.13).
    def account_has_room
      return if errors.any?

      errors.add(:name, FULL) if self.class.where(account_id:).count >= MAX_PER_ACCOUNT
    end

    def taken = "You already have a location called “#{name}”."
end
