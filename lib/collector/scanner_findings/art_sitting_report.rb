# Spec 011 Story 9: the art sitting on spec 009's 35 cards, scored. Spec 009's SittingReport gives each card's outcome (the
# printing and finish it ended as, and its corrections); the readings measurement mode recorded (AC-9.3) give the art
# side, joined by the first capture's reading key: the tier that put the first candidate there, the nearest and second-
# nearest distances, the overrule note, and whether the right card was first. Run it before "Done". Medians are
# conventional (the mean of the middle two for an even count). `captures:` scores a row on another capture (manifest file
# → 1-based capture number) when its first capture read the wrong card, e.g. the previous one scanned again after the
# manifest advanced; the table, the summary and the fixture say so.
class Collector::ScannerFindings::ArtSittingReport
  Row = Data.define(:file, :outcome, :tier, :right_card_first, :confident_wrong, :nearest, :second, :second_other_card,
    :overruled, :overruled_scope, :art_ms, :capture) do
    def to_h = super.merge(outcome: outcome.kind).transform_keys(&:to_s)
  end

  # CAPTURES="IMG_6835.jpeg=2,IMG_6836.jpeg=2" → { "IMG_6835.jpeg" => 2, "IMG_6836.jpeg" => 2 }.
  def self.parse_captures(value)
    value.to_s.split(",").map(&:strip).reject(&:empty?).to_h do |pair|
      file, number = pair.split("=", 2).map(&:strip)
      unless file.present? && number&.match?(/\A\d+\z/)
        raise ArgumentError, "CAPTURES needs file=number pairs separated by commas, not #{pair.inspect}."
      end

      [ file, Integer(number, 10) ]
    end
  end

  def initialize(run:, account:, ground_truth:, captures: {})
    @run = run
    @captures = captures.to_h { |file, number| [ file, check_capture(file, number) ] }
    @sitting = Collector::ScannerFindings::SittingReport.new(run:, account:, ground_truth:)
    @readings = run.readings.index_by { it["reading_key"] }
  end

  def rows
    @rows ||= @sitting.outcomes.map do |outcome|
      number = @captures.fetch(outcome.file, 1)
      capture = @run.captures(@run.row(outcome.file))[number - 1] || {}
      reading = @readings.fetch(capture["reading_key"], {})
      right = right_card_first?(reading, outcome.truth)
      Row.new(file: outcome.file, outcome:, tier: reading["tier"], right_card_first: right,
        confident_wrong: reading["tier"] == "art" && !right, nearest: reading["nearest"], second: reading["second"],
        second_other_card: reading["second_other_card"], overruled: reading["overruled"], overruled_scope: reading["overruled_scope"],
        art_ms: capture["art_ms"], capture: number)
    end
  end

  def to_markdown
    art_ms = rows.filter_map(&:art_ms)
    [ @sitting.to_markdown, "", *summary(art_ms), "",
      "| File | Outcome | Tier | Right card first | Nearest | Second | Second another card | Overruled | Art ms |",
      "|---|---|---|---|---|---|---|---|---|",
      *rows.map { table_row(it) } ].join("\n")
  end

  # The art sitting's fixture (AC-9.6), keyed by manifest file.
  def fixture = { "format_version" => 1, "spec" => "011", "rows" => rows.map(&:to_h) }

  private
    def summary(art_ms)
      wrong = rows.select(&:confident_wrong)
      [ "Right card first: #{rows.count(&:right_card_first)}/#{rows.size}. Confident art on the wrong card: #{wrong.size}/#{rows.size}" \
          "#{" (#{wrong.map(&:file).join(", ")})" if wrong.any?}.",
        "Overrule note shown: #{rows.count(&:overruled)}/#{rows.size}; art overruled a collector-line printing of the same card: " \
          "#{rows.count { it.overruled == "collector_line" && it.overruled_scope == "printing" }}/#{rows.size}.",
        "Art search per capture (phone): median #{median(art_ms) || "n/a"} ms, slowest #{art_ms.max || "n/a"} ms (n=#{art_ms.size}).",
        "Compared with spec 009's text-only sitting on these cards (30/35 right first time, 32/35 in the end) and spec 010's " \
          "guide path (33/35 right artwork first). The 300-bit margin was derived from these same cards, so these rates are biased upwards.",
        *overrides ]
    end

    def overrides
      overridden = rows.reject { it.capture == 1 }
      [ "Scored on another capture: #{overridden.map { file_cell(it) }.join(", ")}." ] if overridden.any?
    end

    def file_cell(row) = row.capture == 1 ? row.file : "#{row.file} (capture #{row.capture})"

    def check_capture(file, number)
      row = @run.row(file) or raise ArgumentError, "Capture override for #{file}: no such file in the manifest."
      count = @run.captures(row).size
      unless number.is_a?(Integer) && number.between?(1, count)
        raise ArgumentError, "Capture override for #{file}: no capture #{number} (it has #{count})."
      end

      number
    end

    def table_row(row)
      another = row.second_other_card.nil? ? "—" : (row.second_other_card ? "yes" : "no")
      overruled = [ row.overruled, row.overruled_scope ].compact.join(" / ").presence || "—"
      "| #{file_cell(row)} | #{row.outcome.kind} | #{row.tier || "—"} | #{row.right_card_first ? "yes" : "no"} | #{row.nearest || "—"} | " \
        "#{row.second || "—"} | #{another} | #{overruled} | #{row.art_ms || "—"} |"
    end

    def right_card_first?(reading, truth)
      first = Catalog::Entry.find_by(collectible_type: "mtg", external_key: reading.dig("candidates", 0))
      right = Catalog::Entry.find_by(collectible_type: "mtg", external_key: truth["external_key"])
      first.present? && right.present? && first.catalog_identity_id == right.catalog_identity_id
    end

    def median(values)
      return nil if values.empty?

      sorted = values.sort
      middle = sorted.size / 2
      sorted.size.odd? ? sorted[middle] : ((sorted[middle - 1] + sorted[middle]) / 2.0).round(1)
    end
end
