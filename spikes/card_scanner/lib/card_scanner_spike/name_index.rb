require "did_you_mean"
require "sqlite3"

module CardScannerSpike
  # Trigram full-text index of card names in its own SQLite file (Story 3): OR the
  # query's trigrams, shortlist by bm25, re-rank by Jaro-Winkler, one row per card.
  class NameIndex
    Candidate = Data.define(:card_name, :matched, :score)
    SHORTLIST = 50
    SCHEMA = [
      "CREATE TABLE IF NOT EXISTS names (id INTEGER PRIMARY KEY, card_name TEXT NOT NULL, indexed TEXT NOT NULL, " \
      "norm TEXT NOT NULL, UNIQUE (card_name, norm))",
      "CREATE VIRTUAL TABLE IF NOT EXISTS names_fts USING fts5 (norm, content='names', content_rowid='id', " \
      "tokenize='trigram remove_diacritics 1')"
    ].freeze

    def initialize(path)
      @db = SQLite3::Database.new(path)
      SCHEMA.each { @db.execute(it) }
    end

    def rebuild(rows)
      @db.transaction do
        @db.execute("DELETE FROM names")
        rows.each do |card_name, indexed|
          @db.execute("INSERT OR IGNORE INTO names (card_name, indexed, norm) VALUES (?, ?, ?)",
            [ card_name, indexed, Normaliser.call(indexed) ])
        end
        @db.execute("INSERT INTO names_fts (names_fts) VALUES ('rebuild')")
      end
      count
    end

    def count = @db.get_first_value("SELECT count(*) FROM names")

    def search(text, limit: 3)
      query = Normaliser.call(text)
      return [] if query.empty?

      rank(query, query.length < 3 ? short(query) : trigram(query)).first(limit)
    end

    def short_names = @db.execute("SELECT card_name, indexed FROM names WHERE length(norm) < 3 ORDER BY card_name")

    def card_names_for(text)
      @db.execute("SELECT DISTINCT card_name FROM names WHERE norm = ? ORDER BY card_name", [ Normaliser.call(text) ]).flatten
    end

    private
      def trigram(query)
        terms = (0..query.length - 3).map { %("#{query[it, 3]}") }.uniq.join(" OR ")
        @db.execute(<<~SQL, [ terms, SHORTLIST ])
          SELECT names.card_name, names.norm FROM names_fts JOIN names ON names.id = names_fts.rowid
          WHERE names_fts MATCH ? ORDER BY bm25(names_fts) LIMIT ?
        SQL
      end

      def short(query)
        @db.execute("SELECT card_name, norm FROM names WHERE norm = ? OR norm LIKE ? LIMIT ?", [ query, "#{query}%", SHORTLIST ])
      end

      def rank(query, rows)
        rows.group_by(&:first).map do |card_name, matches|
          norm, score = matches.map { |(_, matched)| [ matched, DidYouMean::JaroWinkler.distance(query, matched) ] }.max_by(&:last)
          Candidate.new(card_name:, matched: norm, score: score.round(4))
        end.sort_by { [ -it.score, it.card_name ] }
      end
  end
end
