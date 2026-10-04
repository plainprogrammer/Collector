# What the scanner read from one card, and the printings it points to (spec 007 Story 3, spec 009 Story 5): the parsed
# collector line and its printing lookup (one, none or several), the name index's candidates from the name strip alone,
# and the final ranking the page shows. Each candidate carries the kinds of evidence behind it, and one rule orders them
# (AC-5.5): a strong name match first, then collector-line evidence, then the name order. Only text arrives here; the
# photo stays on the device (FR-3).
class MTG::Reading
  include ActiveModel::Model
  include ActiveModel::Attributes

  COLLECTIBLE_TYPE = "mtg"
  CANDIDATES = 3
  MAX_TEXT_LENGTH = 2_000
  # The top name candidate is a strong match at this Jaro-Winkler similarity to the cleaned query or above (spec 009
  # AC-5.1). Chosen with `bin/rails scanner:strong_sweep` on the stored text of earlier runs; frozen with the settings.
  STRONG_NAME_SCORE = 0.96

  # evidence: the kinds behind the candidate, from :collector_line, :collector_line_corrected and :name (AC-5.5);
  # name_rank: its place among the name candidates, if any; strong_name: it's the top name candidate, strongly matched.
  Candidate = Data.define(:entry, :evidence, :name_rank, :strong_name) do
    def collector_line? = evidence.intersect?(%i[collector_line collector_line_corrected])
    def corrected? = evidence.include?(:collector_line_corrected)
    def name? = evidence.include?(:name)

    # The one ranking rule (AC-5.5). A later kind of evidence, such as an art match, joins here.
    def rank_key = [ strong_name ? 0 : 1, collector_line? ? 0 : 1, name_rank || CANDIDATES ]
  end

  attribute :name_text, :string, default: ""
  attribute :collector_text, :string, default: ""

  validates :name_text, :collector_text, length: { maximum: MAX_TEXT_LENGTH }

  # Runs every query once, so the view only reads memoised results; the candidates' finishes come with them (AC-1.1).
  def resolve
    catalog_ready? && Catalog::Entry.preload_extensions(candidates.map(&:entry))
    self
  end

  def catalog_ready? = @catalog_ready.nil? ? (@catalog_ready = name_index.populated?) : @catalog_ready

  def nothing_read? = name_text.blank? && collector_text.blank?

  def collector_line
    @collector_line ||= MTG::CollectorLine.parse(collector_text,
      known_set_codes: Catalog::Set.where(collectible_type: COLLECTIBLE_TYPE).pluck(:code))
  end

  def collector_status = collector_match.first

  def collector_entries = collector_match.last

  def name_candidates = @name_candidates ||= name_index.search(name_text, limit: CANDIDATES)

  # The finish the collector line suggests: the foil marker printed on foil cards from M15 on (spec 009 AC-6.5). A
  # hint for the page to mark; it never adds or chooses anything.
  def finish_hint = collector_line.foil ? "foil" : nil

  def candidates = @candidates ||= ranked(STRONG_NAME_SCORE)

  # The final ranking with a given strong-name threshold; the findings sweep tries several (AC-5.1).
  def ranked(strong_name_score)
    matched = collector_status == :one ? collector_entries.first : nil
    strong = strong_name?(strong_name_score)
    by_card = {}
    name_printings(correct: correction_due?(matched, strong)).each_with_index do |(entry, corrected), rank|
      by_card[entry.catalog_identity_id] = Candidate.new(entry:, evidence: corrected ? %i[name collector_line_corrected] : %i[name],
        name_rank: rank, strong_name: rank.zero? && strong)
    end
    if matched
      named = by_card[matched.catalog_identity_id]
      by_card[matched.catalog_identity_id] = Candidate.new(entry: matched, evidence: named ? %i[collector_line name] : %i[collector_line],
        name_rank: named&.name_rank, strong_name: named&.strong_name || false)
    end
    by_card.values.each_with_index.sort_by { |candidate, index| [ *candidate.rank_key, index ] }.map(&:first).first(CANDIDATES)
  end

  private
    def name_index = @name_index ||= Catalog::NameIndex.new(COLLECTIBLE_TYPE)

    # [:one | :none | :several | :unread, entries] (spec 007 AC-3.2, AC-3.3); English when no language was read.
    def collector_match
      @collector_match ||= if collector_line.set_code.blank? || collector_line.number.blank? then [ :unread, [] ]
      else
        entries = Catalog::Entry.where(collectible_type: COLLECTIBLE_TYPE).includes(:set, :identity)
          .printed_as(set_code: collector_line.set_code, number: collector_line.number, language: collector_line.language || "en").to_a
        [ { 0 => :none, 1 => :one }.fetch(entries.size, :several), entries ]
      end
    end

    def strong_name?(threshold) = name_candidates.first.present? && name_candidates.first.score >= threshold

    # The one-digit cross-check (AC-5.3) runs for the top name candidate when a strong name match names another card
    # than the collector line's printing, or when the line parsed but matched no printing. It never runs when the
    # collector-line printing ranks first (AC-5.2).
    def correction_due?(matched, strong)
      top = name_candidates.first
      return false unless top

      collector_status == :none || (matched.present? && strong && matched.catalog_identity_id != top.identity_id)
    end

    # One printing per name candidate, in candidate order: for the top one, when due, the one-digit correction; otherwise
    # its printing in the parsed set when it has one there, else its newest English printing. [entry, corrected?] pairs.
    def name_printings(correct:)
      name_candidates.map(&:identity_id).each_with_index.filter_map do |id, rank|
        options = printings_by_identity.fetch(id, [])
        corrected = corrected_printing(options) if correct && rank.zero?
        entry = corrected || options.find { it.set.code.casecmp?(collector_line.set_code.to_s) } || options.first
        [ entry, corrected.present? ] if entry
      end
    end

    def printings_by_identity
      @printings_by_identity ||= Catalog::Entry.searchable
        .where(collectible_type: COLLECTIBLE_TYPE, catalog_identity_id: name_candidates.map(&:identity_id), language: "en")
        .newest_first.includes(:set, :identity).to_a.group_by(&:catalog_identity_id)
    end

    # The named card's one printing in the read set whose number is a digit away from the read number (AC-5.3).
    def corrected_printing(options)
      near = options.select do |entry|
        entry.set.code.casecmp?(collector_line.set_code.to_s) && MTG::CollectorNumber.one_digit_apart?(entry.number, collector_line.number)
      end
      near.first if near.one?
    end
end
