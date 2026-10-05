require "did_you_mean"

# Finds catalog identities from text read off a card's name bar (spec 007 AC-3.4, AC-3.5, ADR 0003). The
# text is cleaned and normalised like the names, matched by OR-ing its trigrams in an FTS5 index,
# shortlisted by bm25 and re-ranked by Jaro-Winkler, one candidate per identity. Short queries also
# match names within one edit; text that normalises to nothing is matched exactly against the raw name.
class Catalog::NameIndex
  Candidate = Data.define(:identity_id, :name, :score)
  SHORTLIST = 50
  SHORT_QUERY = 5
  MIN_TOKEN = 3
  # A line is a query only if at least this share of its characters sit in tokens of MIN_TOKEN or more (spec 009
  # AC-6.1): a line of short noise tokens no longer beats the name. A tuning setting, frozen before the live sitting.
  LONG_TOKEN_SHARE = 0.5
  BATCH_SIZE = 1_000

  # The longest mostly-alphabetic line, once tokens shorter than MIN_TOKEN are dropped, among lines mostly made of
  # such tokens; failing that, among every line as before; failing that, the longest such line as read, so a short name
  # like "Ox" is still a query (spec 007 AC-3.4).
  def self.clean(text)
    lines = text.to_s.lines.map(&:strip)
    trimmed = lines.map { |line| line.split.select { |token| token.length >= MIN_TOKEN }.join(" ") }
    worded = trimmed.select.with_index { |_, index| long_token_share(lines[index]) >= LONG_TOKEN_SHARE }
    longest_alphabetic(worded) || longest_alphabetic(trimmed) || longest_alphabetic(lines) || ""
  end

  def self.long_token_share(line)
    tokens = line.split
    total = tokens.sum(&:length)
    total.zero? ? 0 : tokens.select { it.length >= MIN_TOKEN }.sum(&:length).fdiv(total)
  end

  def self.longest_alphabetic(lines) = lines.select { |line| alphabetic?(line) }.max_by(&:length)

  def self.alphabetic?(line)
    characters = line.gsub(/\s/, "")
    characters.present? && characters.scan(/\p{L}/).size * 2 >= characters.size
  end

  def initialize(collectible_type, source_class: Catalog.source_class(collectible_type))
    @collectible_type = collectible_type
    @source_class = source_class
  end

  def populated? = names.exists?

  # Replaces this type's names in one transaction and returns how many were written. Bulk maintenance
  # of derived, global catalog rows: no callbacks or validations apply.
  def rebuild
    rows = (identity_names + alternate_names).uniq { |identity_id, name| [ identity_id, Catalog::NameKey.call(name) ] }
    Catalog::Name.transaction do
      names.delete_all
      rows.each_slice(BATCH_SIZE) do |slice|
        Catalog::Name.insert_all(slice.map { |identity_id, name| { collectible_type: @collectible_type,
          catalog_identity_id: identity_id, name:, normalized: Catalog::NameKey.call(name) } })
      end
      Catalog::Name.connection.execute("INSERT INTO catalog_names_fts (catalog_names_fts) VALUES ('rebuild')")
    end
    rows.size
  end

  def search(text, limit: 3)
    key = Catalog::NameKey.call(self.class.clean(text))
    rows = if key.empty? then exact(text.to_s.strip)
    else (key.length >= 3 ? trigram(key) : []) + (key.length <= SHORT_QUERY ? near(key) : [])
    end
    rank(key, rows).first(limit)
  end

  private
    def names = Catalog::Name.where(collectible_type: @collectible_type)

    def searchable = Catalog::Entry.searchable.where(collectible_type: @collectible_type)

    def identity_names
      Catalog::Identity.where(collectible_type: @collectible_type, id: searchable.select(:catalog_identity_id)).pluck(:id, :name)
    end

    def alternate_names = @source_class.respond_to?(:alternate_names) ? @source_class.alternate_names(searchable).to_a : []

    def trigram(key)
      terms = (0..key.length - 3).map { |start| %("#{key[start, 3]}") }.uniq.join(" OR ")
      names.joins("JOIN catalog_names_fts ON catalog_names_fts.rowid = catalog_names.id")
        .where("catalog_names_fts MATCH ?", terms).order(Arel.sql("bm25(catalog_names_fts)")).limit(SHORTLIST)
        .pluck(:catalog_identity_id, :name, :normalized)
    end

    def near(key)
      names.where("length(normalized) BETWEEN ? AND ?", key.length - 1, key.length + 1)
        .pluck(:catalog_identity_id, :name, :normalized)
        .select { |_, _, normalized| DidYouMean::Levenshtein.distance(key, normalized) <= 1 }
    end

    def exact(raw) = raw.empty? ? [] : names.where(name: raw).pluck(:catalog_identity_id, :name, :normalized)

    def rank(key, rows)
      rows.group_by(&:first).map do |identity_id, matches|
        name, score = matches.map { |_, matched, normalized| [ matched, similarity(key, normalized) ] }.max_by(&:last)
        Candidate.new(identity_id:, name:, score: score.round(4))
      end.sort_by { |candidate| [ -candidate.score, candidate.name ] }
    end

    def similarity(key, normalized) = key.empty? ? 1.0 : DidYouMean::JaroWinkler.distance(key, normalized)
end
