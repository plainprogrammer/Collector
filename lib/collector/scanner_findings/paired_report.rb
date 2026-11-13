module Collector
  module ScannerFindings
    # Spec 082 Story 7: the paired re-measure. Scores each framing's run (its first capture per row) against the ground truth,
    # lists the cards one framing got right first and the other didn't, and applies bar A: the full framing passes when its
    # right card first is at most one card below the shipped framing's and its exact printing at most two below (maintainer,
    # 2026-11-13). Text is re-ranked as `rescore` does; where the run recorded readings (art matching on), the first candidate
    # as recorded is the right-card-first figure the bar reads.
    class PairedReport
      RIGHT_FIRST_SLACK = 1
      EXACT_PRINTING_SLACK = 2

      # @param runs [Hash{String => Scanner::MeasurementRun}] "full" and "shipped"
      # @param truth [Hash{String => Hash}] ground-truth records by file
      def initialize(runs:, truth:)
        @runs = runs
        @truth = truth
      end

      # Each framing's scored records for the cards both framings measured (bar A compares the same cards): `right_first` from
      # the recorded first candidate where readings were recorded, else the re-ranked text's.
      #
      # @return [Hash{String => Array<Hash>}]
      def records
        @records ||= all_records.transform_values { |rows| rows.select { shared.include?(it["file"]) } }
      end

      # Files one framing measured and the other didn't, left out of the comparison and listed in the report.
      #
      # @return [Array<String>]
      def unpaired = all_records.values.flat_map { |rows| rows.map { it["file"] } }.uniq - shared.to_a

      # Whether the full framing passes bar A on the shared cards.
      #
      # @return [Symbol] :passes or :fails
      def bar
        full, shipped = records.values_at("full", "shipped")
        right = ->(rows) { rows.count { it["right_first"] } }
        exact = ->(rows) { rows.count { SET_LINE_ERAS.include?(it["era"]) && ScannerFindings.printing_identified?(it) } }
        right.(full) >= right.(shipped) - RIGHT_FIRST_SLACK && exact.(full) >= exact.(shipped) - EXACT_PRINTING_SLACK ? :passes : :fails
      end

      # The shared cards one framing put right first and the other didn't, with which.
      #
      # @return [Array<String>]
      def discordant
        full = records["full"].to_h { [ it["file"], it["right_first"] ] }
        records["shipped"].filter_map do |record|
          next if full[record["file"]] == record["right_first"]

          "#{record["file"]}: #{full[record["file"]] ? "full" : "shipped"} only"
        end
      end

      # The report for research.md: a table per framing (right card first, top 3, exact printing with its foil and non-foil
      # split, name read), the frame and stage sizes seen, the discordant and unpaired cards, and bar A's outcome.
      #
      # @return [String]
      def to_markdown
        rows = { "right card first" => ->(r) { r["right_first"] }, "top 3" => ->(r) { ScannerFindings.in_top?(r, "final_candidates", 3) },
                 "name read" => ->(r) { ScannerFindings.name_read?(r) } }
        table = rows.map { |label, hit| "| #{label} | #{records.values.map { ScannerFindings.rate(it, &hit) }.join(" | ")} |" }
        exact = [ [ "exact printing", ->(_) { true } ], [ "  foils", ->(r) { r["foil"] } ], [ "  non-foils", ->(r) { !r["foil"] } ] ].map do |label, kind|
          "| #{label} | #{records.values.map { |rows_of| exact_rate(rows_of.select { kind.(it) }) }.join(" | ")} |"
        end
        sizes = records.transform_values { |rows_of| rows_of.map { it["sizes"].values.join("×") }.uniq.join(", ") }
        [ "| Rate | #{records.keys.join(" | ")} |", "|---|#{"---|" * records.size}", *table, *exact, "",
          "Sizes (video × stage): #{sizes.map { |framing, seen| "#{framing} #{seen}" }.join("; ")}.",
          "Discordant: #{discordant.join("; ").presence || "none"}.", "Unpaired (left out): #{unpaired.join(", ").presence || "none"}.", "", "Bar A: #{bar}." ].join("\n")
      end

      private
        # The exact-printing rate of the set-line eras among some records.
        def exact_rate(rows)
          ScannerFindings.rate(rows.select { SET_LINE_ERAS.include?(it["era"]) }) { ScannerFindings.printing_identified?(it) }
        end

        # Every measured row of each framing, scored.
        def all_records
          @all_records ||= @runs.transform_values do |run|
            recorded = run.readings.to_h { [ it["reading_key"], it["candidates"].to_a.first ] }
            captures = run.measured_captures.index_by { it["file"] }
            ScannerFindings.rescore(@truth, captures.values).map do |record|
              capture = captures[record["file"]]
              first = recorded[capture["reading_key"]]
              record.merge("right_first" => first ? Catalog::Entry.find_by(external_key: first)&.name == record["name"] : ScannerFindings.in_top?(record, "final_candidates", 1),
                "sizes" => capture.slice("video_width", "video_height", "stage_width", "stage_height"))
            end
          end
        end

        # The files both framings measured.
        def shared = @shared ||= all_records.values.map { |rows| rows.to_set { it["file"] } }.reduce(:&)
    end
  end
end
