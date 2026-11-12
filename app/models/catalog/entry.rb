# One catalogued collectible as the source identifies it: for MTG, a printing.
class Catalog::Entry < ApplicationRecord
  PRIMARY_KIND = "card"

  belongs_to :set, class_name: "Catalog::Set", foreign_key: :catalog_set_id, inverse_of: :entries
  belongs_to :identity, class_name: "Catalog::Identity", foreign_key: :catalog_identity_id, inverse_of: :entries

  # The collectible-specific record (e.g. MTG::Printing); see .preload_extensions.
  attr_accessor :extension

  validates :collectible_type, :external_key, :number, :language, :name, :kind, :content_digest, presence: true
  validates :external_key, uniqueness: { scope: :collectible_type }

  scope :active, -> { where(retired_at: nil) }
  scope :searchable, -> { active.where(kind: PRIMARY_KIND) }
  scope :named_like, ->(query) {
    pattern = "%#{sanitize_sql_like(query)}%"
    where(arel_table[:name].matches(pattern, "\\"))
      .or(where(arel_table[:localized_name].matches(pattern, "\\")))
  }
  scope :in_set, ->(code) { code.present? ? joins(:set).where(catalog_sets: { code: }) : all }
  # Active printings with this set code, collector number and language (spec 007 FR-4).
  scope :printed_as, ->(set_code:, number:, language:) {
    active.joins(:set).where(number:, language:, catalog_sets: { code: set_code.to_s.downcase })
  }
  # A collector number as a person reads it: the digits it starts with, as a number ("2" < "10" < "12" < "12a"). A
  # number with no leading digit ("★", "P3", "") sorts after every numbered one, by its text; equal values fall back to
  # the text ("010" before "10" before "10a"). Fixed SQL, no value interpolated (#204 ruling 3).
  NUMBER_HAS_DIGITS_FIRST = Arel.sql("CASE WHEN catalog_entries.number GLOB '[0-9]*' THEN 0 ELSE 1 END")
  NUMBER_VALUE = Arel.sql("CASE WHEN catalog_entries.number GLOB '[0-9]*' THEN CAST(catalog_entries.number AS INTEGER) END")

  scope :newest_first, -> {
    joins(:set).order(released_on: :desc).order(Catalog::Set.arel_table[:code].asc)
      .order(NUMBER_HAS_DIGITS_FIRST, NUMBER_VALUE, arel_table[:number].asc, arel_table[:language].asc)
  }

  def retired? = retired_at.present?

  # Whether a collector can add this printing to a deck from its page (spec 071 decision 2): a live card of the primary kind
  # (what the search lists, and what a proxy can be made of: spec 068) whose collectible type has both a vocabulary, for its
  # finishes, and a source. The page and the card page's link both ask, so they can't disagree.
  #
  # @return [Boolean]
  def deck_addable? = !retired? && kind == PRIMARY_KIND && Catalog.collecting.key?(collectible_type) && Catalog.sources.key?(collectible_type)

  def to_param = external_key

  # The printed name for non-English printings; English printed names can be
  # stylized (e.g. "SERRA ANGEL"), so English printings use the card name.
  def display_name = (language != "en" && localized_name.presence) || name

  # `#display_name` as SQL, for an ORDER BY or a pluck (spec 066 decision 3): the localized name of a non-English printing
  # that has one, else the card's name. Fixed text, nothing interpolated; `spec/models/catalog/entry_display_name_sql_spec.rb`
  # holds it equal to the Ruby rule.
  DISPLAY_NAME_SQL = Arel.sql(
    "CASE WHEN catalog_entries.language <> 'en' AND TRIM(COALESCE(catalog_entries.localized_name, '')) <> '' " \
    "THEN catalog_entries.localized_name ELSE catalog_entries.name END"
  )

  # Loads each entry's collectible-specific record in one query per type.
  def self.preload_extensions(entries)
    entries.group_by(&:collectible_type).each do |collectible_type, group|
      model = Catalog.source_class(collectible_type).entry_extension_model
      next if model.nil?

      extensions = model.where(catalog_entry_id: group.map(&:id)).index_by(&:catalog_entry_id)
      group.each { |entry| entry.extension = extensions[entry.id] }
    end
    entries
  end
end
