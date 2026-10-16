# The set and language number entry adds from (spec 026 decision 2): the sets on offer, the typed text resolved to one
# of them, and the languages of its active entries. The offered sets are loaded once and matched in Ruby, so a code or
# name in any case matches the way the page's suggestions show it.
class NumberEntry::SetChoice
  ENGLISH = "en"
  LABELLED = /\A(?<name>.+) \((?<code>[^()\s]+)\)\z/

  attr_reader :text, :set, :language

  # Every set with an active entry of any kind (decision 9), newest first, undated last.
  def self.offered = Catalog::Set.where(id: Catalog::Entry.active.select(:catalog_set_id)).newest_first

  # Parameters arrive from the request, so anything that isn't a string (a forged hash or array) counts as absent.
  def initialize(text:, type: nil, language: nil)
    @text = string(text).strip
    @set = find_set(string(type).strip.presence)
    @language = pick_language(string(language).strip) if @set
  end

  # Loaded only when asked for (the set form, or resolving typed text), so a line's add never loads them all.
  def sets = @sets ||= self.class.offered.to_a

  def asked? = text.present?
  def chosen? = set.present? && language.present?

  # The set's active entries per language code (AC-1.5).
  def languages
    @languages ||= set ? Catalog::Entry.active.where(catalog_set_id: set.id).group(:language).count : {}
  end

  def to_params = { type: set.collectible_type, set: set.code, language: }

  # True when the request already names the set and language as the page links them, so it needn't redirect.
  def canonical?(params) = to_params.all? { |name, value| params[name] == value }

  def label(set) = "#{set.name} (#{set.code.upcase})"

  def unmatched_message = "No set matches “#{text}”. Type a set code or choose a set from the list."

  private
    def string(value) = value.is_a?(String) ? value : ""

    # The page's own link names the type and the exact code: one lookup, and #languages is empty for a set with no
    # active entry, which leaves it unchosen. Typed text is matched against the offered sets.
    def find_set(type)
      return if text.empty?

      linked = Catalog::Set.find_by(collectible_type: type, code: text) if type
      return linked if linked

      candidates = type ? sets.select { it.collectible_type == type } : sets
      labelled = LABELLED.match(text)
      (labelled && candidates.find { it.code.casecmp?(labelled[:code]) && it.name.casecmp?(labelled[:name]) }) ||
        candidates.find { it.code.casecmp?(text) } || candidates.find { it.name.casecmp?(text) }
    end

    # The requested language when the set has it; none when the request names one it lacks (AC-1.11); otherwise EN
    # when the set has it, else the language most of its entries have, ties to the first code (AC-1.5, AC-1.6).
    def pick_language(requested)
      return languages.key?(requested) ? requested : nil if requested.present?
      return ENGLISH if languages.key?(ENGLISH)

      languages.min_by { |code, count| [ -count, code ] }&.first
    end
end
