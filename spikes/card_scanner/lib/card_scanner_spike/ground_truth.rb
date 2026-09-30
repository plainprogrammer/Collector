module CardScannerSpike
  # Builds ground-truth records from the maintainer's manifest (AC-1.1).
  # Manifest columns: file,set,number,foil[,era]. Needs Rails.
  class GroundTruth
    ERAS = [ "pre-M15", "M15–ONE", "MOM+" ].freeze
    M15_RELEASE = Date.new(2014, 7, 18)
    MOM_RELEASE = Date.new(2023, 4, 21)

    def self.era_for(released_on)
      if released_on < M15_RELEASE then "pre-M15"
      elsif released_on < MOM_RELEASE then "M15–ONE"
      else "MOM+"
      end
    end

    def initialize(lookup: PrintingLookup.new)
      @lookup = lookup
    end

    def build(manifest_csv, corpus_files:)
      photos = []
      errors = []
      rows(manifest_csv).each do |row|
        problem, entry = check(row, corpus_files)
        problem ? errors << row.merge("problem" => problem) : photos << record(row, entry)
      end
      { "photos" => photos, "errors" => errors, "counts" => counts(photos) }
    end

    private
      # The manifest has no quoted or comma-bearing values, so a split is enough (csv isn't in the bundle).
      def rows(manifest_csv)
        header, *lines = manifest_csv.lines.map(&:strip).reject(&:empty?)
        keys = header.to_s.split(",").map(&:strip)
        lines.map { |line| keys.zip(line.split(",", -1).map(&:strip)).to_h }
      end

      def check(row, corpus_files)
        return [ "missing photo" ] unless corpus_files.include?(row["file"])
        return [ "unknown era" ] if row["era"].present? && ERAS.exclude?(row["era"])

        outcome = @lookup.call(set_code: row["set"], number: row["number"].to_s.strip)
        outcome.status == :one ? [ nil, outcome.entries.first ] : [ outcome.status.to_s ]
      end

      def record(row, entry)
        printing = MTG::Printing.find_by!(catalog_entry_id: entry.id)
        { "file" => row["file"], "name" => entry.name, "name_bar" => printing.faces.first.fetch("name"),
          "set_code" => entry.set.code, "collector_number" => entry.number, "external_key" => entry.external_key,
          "era" => row["era"].presence || self.class.era_for(entry.released_on || entry.set.released_on),
          "foil" => row["foil"].to_s.strip.casecmp?("yes"),
          "borderless_or_showcase" => printing.border_color == "borderless" || printing.variant_tags.include?("showcase") }
      end

      def counts(photos)
        { "total" => photos.size, "foil" => photos.count { it["foil"] },
          "by_era" => ERAS.index_with { |era| photos.count { it["era"] == era } } }
      end
  end
end
