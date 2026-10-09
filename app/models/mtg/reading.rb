# What the scanner read from one card, and the printings it points to (spec 007 Story 3, spec 009 Story 5, spec 011
# Story 6): the parsed collector line and its printing lookup (one, none or several), the name index's candidates from the
# name strip alone, the art evidence of a live capture's nearest artworks, and the final ranking the page shows. Each
# candidate carries the kinds of evidence behind it, and one rule orders them (spec 009 AC-5.5, spec 011 AC-6.6):
# confident art first, then a strong name match, then collector-line evidence, then weak art, then the name order. Only
# text and artwork ids with distances arrive here; the photo and its fingerprint stay on the device.
class MTG::Reading
  include ActiveModel::Model
  include ActiveModel::Attributes

  COLLECTIBLE_TYPE = "mtg"
  CANDIDATES = 3
  MAX_TEXT_LENGTH = 2_000
  # The top name candidate is a strong match at this Jaro-Winkler similarity to the cleaned query or above (spec 009
  # AC-5.1). Chosen with `bin/rails scanner:strong_sweep` on the stored text of earlier runs; frozen with the settings.
  STRONG_NAME_SCORE = 0.96
  # The nearest artwork is a confident match at this Hamming distance (of 1,024 bits) or below (spec 011 AC-6.2).
  # Provisional, from spec 010's guide-path distances on spec 009's 35 cards; the closing measurement checks it.
  ART_MARGIN = 300

  # evidence: the kinds behind the candidate, from :collector_line, :collector_line_corrected, :name, :art and :art_weak
  # (spec 011 AC-6.6); name_rank: its place among the name candidates, if any; strong_name: it's the top name candidate,
  # strongly matched; artwork_id and art_unique: a confident artwork and whether it belongs to this one printing;
  # art_distance: the card's nearest artwork distance (confident or weak).
  Candidate = Data.define(:entry, :evidence, :name_rank, :strong_name, :artwork_id, :art_unique, :art_distance) do
    def initialize(entry:, evidence:, name_rank:, strong_name:, artwork_id: nil, art_unique: false, art_distance: nil)
      super(entry:, evidence:, name_rank:, strong_name:, artwork_id:, art_unique:, art_distance:)
    end

    def collector_line? = evidence.intersect?(%i[collector_line collector_line_corrected])
    def corrected? = evidence.include?(:collector_line_corrected)
    def name? = evidence.include?(:name)
    def art? = evidence.include?(:art)
    def art_weak? = evidence.include?(:art_weak)
    def printing_confirmed? = collector_line? || (art? && art_unique)

    # The one ranking rule (spec 009 AC-5.5, spec 011 AC-6.6). Without art it orders exactly as spec 009's did.
    def rank_key = [ art? ? 0 : 1, strong_name ? 0 : 1, collector_line? ? 0 : 1, art_weak? ? 0 : 1, name_rank || CANDIDATES ]
  end

  # The ranked candidates and what decided them (spec 011 AC-6.7), in memory only. tier: the first candidate's first
  # qualifying part of the rank rule; overruled: :name or :collector_line when confident art changed the card or
  # printing spec 009's ranking put first (overruled_scope :card or :printing); art_status: :matched, :similar or
  # :no_match when art was sent, else nil; art_usable: the usable artworks, nearest first.
  Ranking = Data.define(:candidates, :tier, :overruled, :overruled_scope, :art_status, :art_usable)

  attribute :name_text, :string, default: ""
  attribute :collector_text, :string, default: ""
  # The page's nearest artworks (MTG::Art::Sent), or nil when none were sent or they were dropped (spec 011 AC-6.1).
  attr_accessor :artworks

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

  def ranking = @ranking ||= ranking_for(STRONG_NAME_SCORE)

  def candidates = ranking.candidates

  delegate :tier, :overruled, :overruled_scope, :art_status, :art_usable, to: :ranking

  # The final ranking with a given strong-name threshold; the findings sweep tries several (spec 009 AC-5.1).
  def ranked(strong_name_score) = ranking_for(strong_name_score).candidates

  def ranking_for(strong_name_score)
    by_card = text_candidates(strong_name_score)
    text_alone = top(by_card.values)
    return Ranking.new(candidates: text_alone, tier: tier_of(text_alone.first), overruled: nil, overruled_scope: nil, art_status: nil, art_usable: []) if artworks.nil?

    evidence = MTG::Art::Evidence.new(artworks, text_identity_ids: by_card.keys, margin: ART_MARGIN)
    confident = evidence.confident
    by_card[confident.identity_id] = art_candidate(confident, by_card[confident.identity_id]) if confident
    add_weak_art(by_card, evidence.card_distances, except: confident&.identity_id)
    final = top(by_card.values)
    overruled, scope = overrule(text_alone.first, confident && final.first)
    Ranking.new(candidates: final, tier: tier_of(final.first), overruled:, overruled_scope: scope,
      art_status: art_status_of(confident, final), art_usable: evidence.usable)
  end

  private
    def name_index = @name_index ||= Catalog::NameIndex.new(COLLECTIBLE_TYPE)

    # Spec 009's ranking by card, before the order is applied: identity id => Candidate, name candidates in name order,
    # then the collector-line card when it isn't one of them.
    def text_candidates(strong_name_score)
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
      by_card
    end

    def top(candidates) = candidates.each_with_index.sort_by { |candidate, index| [ *candidate.rank_key, index ] }.map(&:first).first(CANDIDATES)

    # Spec 011 AC-6.4: the confident artwork's card, with its printing chosen among the artwork's printings (newest
    # first): its only printing; else the collector line's printing (or spec 009's corrected one) when it's among them;
    # else the newest in the read set; else the newest. A collector-line printing with another artwork isn't kept.
    def art_candidate(artwork, text)
      kept = text if text&.collector_line? && artwork.printings.any? { it.id == text.entry.id }
      entry = kept&.entry || artwork.printings.find { it.set.code.casecmp?(collector_line.set_code.to_s) } || artwork.printings.first
      evidence = kept ? kept.evidence + %i[art] : [ :art, *(%i[name] if text&.name?) ]
      Candidate.new(entry:, evidence:, name_rank: text&.name_rank, strong_name: text&.strong_name || false,
        artwork_id: artwork.id, art_unique: artwork.printings.one?, art_distance: artwork.distance)
    end

    # Spec 011 AC-6.5 and the glossary: every other text candidate's card owning one of the usable artworks holds weak
    # art, whatever its distance. It only adds evidence; it never adds a card or changes a printing.
    def add_weak_art(by_card, distances, except:)
      by_card.each do |identity_id, candidate|
        distance = distances[identity_id]
        next if identity_id == except || distance.nil?

        by_card[identity_id] = candidate.with(evidence: candidate.evidence + %i[art_weak], art_distance: distance)
      end
    end

    # Spec 011 AC-6.7: what confident art overruled in spec 009's ranking of the same reading.
    def overrule(text_first, art_first)
      return [ nil, nil ] if text_first.nil? || art_first.nil? || text_first.entry.id == art_first.entry.id

      [ text_first.collector_line? ? :collector_line : :name,
        text_first.entry.catalog_identity_id == art_first.entry.catalog_identity_id ? :printing : :card ]
    end

    def art_status_of(confident, final)
      if confident then :matched
      elsif final.any?(&:art_weak?) then :similar
      else :no_match
      end
    end

    def tier_of(candidate)
      return if candidate.nil?

      if candidate.art? then :art
      elsif candidate.strong_name then :strong_name
      elsif candidate.collector_line? then :collector_line
      elsif candidate.art_weak? then :art_weak
      else :name_rank
      end
    end

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
