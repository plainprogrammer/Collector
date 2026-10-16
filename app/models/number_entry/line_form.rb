# One line of number entry (spec 026 decisions 3, 8 and 10): the number, quantity and finish as typed, the line key,
# and the entry they match among the active entries of the chosen set and language. Errors sit on their own field.
class NumberEntry::LineForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :number, :string
  attribute :quantity, :string, default: "1"
  attribute :finish, :string
  attribute :line_key, :string
  attribute :pick, :string
  attr_accessor :set, :language

  validate :line_key_well_formed, :quantity_in_range, :single_entry, :finish_offered

  # A number as decision 8's second step compares it: trimmed, lower case, without leading zeros, at least one character.
  def self.normalize(number) = number.to_s.strip.downcase.sub(/\A0+(?=.)/, "")

  def vocabulary = Catalog.collecting_for(set.collectible_type)
  def finishes = vocabulary.finish_order

  # The chosen finish, or the type's first one (decision 3).
  def finish = super.presence || finishes.first

  def blank_number? = number.to_s.strip.empty? && pick.blank?

  # More than one entry matches and the collector hasn't picked one (AC-2.9).
  def choice? = !blank_number? && pick.blank? && matches.size > 1

  # The active entries of the set and language this number matches: those equal to the trimmed text, or only if there
  # are none, those equal to it ignoring case and leading zeros (decision 8).
  def matches = @matches ||= find_matches

  # The one entry the line adds: the only match, or the picked one among the matches (AC-2.10).
  def entry
    return matches.find { it.external_key == pick } if pick.present?

    matches.first if matches.one?
  end

  def add_attributes = { entry:, quantity: parsed_quantity, finish: (finish if entry_finishes.any?), line_key: }

  private
    def find_matches
      candidates = Catalog::Entry.active.where(catalog_set_id: set.id, language:)
      typed = number.to_s.strip
      exact = candidates.where(number: typed).includes(:set).to_a
      return exact if exact.any?

      wanted = self.class.normalize(typed)
      ids = candidates.pluck(:id, :number).filter_map { |id, printed| id if self.class.normalize(printed) == wanted }
      ids.empty? ? [] : candidates.where(id: ids).includes(:set).order(:number).to_a
    end

    def parsed_quantity = Integer(quantity.to_s.strip, 10, exception: false)

    def entry_finishes = @entry_finishes ||= vocabulary.finishes_for(entry)

    def line_key_well_formed
      errors.add(:base, "That line couldn't be added. Try again.") unless NumberEntry::KEY_FORMAT.match?(line_key.to_s)
    end

    def quantity_in_range
      errors.add(:quantity, "must be a whole number from 1 to 9,999") unless parsed_quantity&.between?(1, Lot::MAX_QUANTITY)
    end

    def single_entry
      return if entry || choice?

      errors.add(:number, "No card numbered #{number.to_s.strip} in #{set.name} (#{language.upcase}).")
    end

    # An entry that lists finishes takes one of them; one that lists none takes none, whatever the field says.
    def finish_offered
      return unless entry && entry_finishes.any? && entry_finishes.exclude?(finish)

      errors.add(:finish, "isn't available for this printing")
    end
end
