# What the scanner read from one card, and the printings it points to (spec 007 Story 3): the parsed
# collector line and its printing lookup (one, none or several), the name index's candidates from the
# name strip alone (Phase 0's ranking, kept for the findings), and the final ranking the page shows,
# with a collector-line match first. Only text arrives here; the photo stays on the device (FR-3).
class MTG::Reading
  include ActiveModel::Model
  include ActiveModel::Attributes

  COLLECTIBLE_TYPE = "mtg"
  CANDIDATES = 3
  MAX_TEXT_LENGTH = 2_000

  Candidate = Data.define(:entry, :source)

  attribute :name_text, :string, default: ""
  attribute :collector_text, :string, default: ""

  validates :name_text, :collector_text, length: { maximum: MAX_TEXT_LENGTH }

  # Runs every query once, so the view only reads memoised results.
  def resolve
    catalog_ready? && candidates
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

  def candidates
    @candidates ||= begin
      matched = collector_status == :one ? [ Candidate.new(entry: collector_entries.first, source: :collector_line) ] : []
      named = name_printings.reject { |entry| matched.any? { it.entry.catalog_identity_id == entry.catalog_identity_id } }
      (matched + named.map { Candidate.new(entry: it, source: :name) }).first(CANDIDATES)
    end
  end

  private
    def name_index = @name_index ||= Catalog::NameIndex.new(COLLECTIBLE_TYPE)

    # [:one | :none | :several | :unread, entries] (AC-3.2, AC-3.3); English when no language was read.
    def collector_match
      @collector_match ||= if collector_line.set_code.blank? || collector_line.number.blank? then [ :unread, [] ]
      else
        entries = Catalog::Entry.where(collectible_type: COLLECTIBLE_TYPE).includes(:set)
          .printed_as(set_code: collector_line.set_code, number: collector_line.number, language: collector_line.language || "en").to_a
        [ { 0 => :none, 1 => :one }.fetch(entries.size, :several), entries ]
      end
    end

    # One printing per name candidate, in candidate order: in the parsed set when the card has one
    # there, otherwise its newest English printing.
    def name_printings
      ids = name_candidates.map(&:identity_id)
      printings = Catalog::Entry.searchable.where(collectible_type: COLLECTIBLE_TYPE, catalog_identity_id: ids, language: "en")
        .newest_first.includes(:set).to_a.group_by(&:catalog_identity_id)
      ids.filter_map do |id|
        options = printings.fetch(id, [])
        options.find { it.set.code.casecmp?(collector_line.set_code.to_s) } || options.first
      end
    end
end
