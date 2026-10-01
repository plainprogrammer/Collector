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
  scope :newest_first, -> {
    joins(:set).order(released_on: :desc).order(Catalog::Set.arel_table[:code].asc).order(number: :asc, language: :asc)
  }

  def retired? = retired_at.present?

  def to_param = external_key

  # The printed name for non-English printings; English printed names can be
  # stylized (e.g. "SERRA ANGEL"), so English printings use the card name.
  def display_name = (language != "en" && localized_name.presence) || name

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
