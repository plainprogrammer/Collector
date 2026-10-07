module CardScannerPhase3
  # Scores the art replay (spec 010 AC-4.4 to AC-4.7) against ground truth and spec 009's text results. results: { path =>
  # { file => replay record } }; truth: { file => ground-truth record }; entries: { printing id => front artwork id }; owners:
  # ArtworkOwners; text and same_capture_text: { file => { "top3" => names, "lookup" => {…} } }.
  class ArtFindings
    PATHS = { "guide" => "Live, guide box", "detected" => "Live, detected (shipped detector incl. 8a6c712)", "photo" => "Unguided photo, detected" }.freeze

    def initialize(results:, truth:, entries:, owners:, text:, same_capture_text: {})
      @results, @truth, @entries, @owners, @text, @same = results, truth, entries, owners, text, same_capture_text
    end

    def paths = PATHS.keys & @results.keys

    def scored(path)
      @truth.values.sort_by { it["file"] }.map do |truth|
        record = @results.dig(path, truth["file"]) || { "top" => [] }
        right = @entries[truth["external_key"]]
        top = Array(record["top"])
        first = top.first&.fetch("id")
        { "file" => truth["file"], "name" => truth["name"], "foil" => truth["foil"], "right" => right, "found" => record.fetch("found", true),
          "art_first" => !right.nil? && first == right, "card_first" => !first.nil? && Array(@owners.dig(first, "names")).include?(truth["name"]),
          "art_top3" => !right.nil? && top.first(3).any? { it["id"] == right }, "right_distance" => record["rightDistance"],
          "nearest_wrong" => top.find { it["id"] != right }&.fetch("distance"), "unique_printing" => Array(@owners.dig(right, "printings")).size == 1,
          "first" => first, "missing_artwork" => right.nil? }
      end
    end

    # Cards whose printing has no artwork id in the bulk file are left out of every rate and listed (Error Scenarios).
    def rated(path) = scored(path).reject { it["missing_artwork"] }

    def rates(path)
      groups = { "all" => rated(path), "foil" => rated(path).select { it["foil"] }, "non-foil" => rated(path).reject { it["foil"] } }
      groups.transform_values { |rows| %w[art_first card_first art_top3].to_h { |key| [ key, rate(rows) { it[key] } ] } }
    end

    def comparison(path, text = @text)
      rows = rated(path)
      text_top3 = ->(r) { Array(text.dig(r["file"], "top3")).first(3).include?(r["name"]) }
      missed = rows.select { |r| printing_missed?(r["file"], text) }
      { "text_top3" => rate(rows, &text_top3), "text_or_art" => rate(rows) { text_top3.call(it) || it["card_first"] }, "printing_missed" => missed.size,
        "art_names_printing" => missed.count { it["art_first"] && it["unique_printing"] } }
    end

    def to_h
      { "paths" => paths.to_h do |path|
        same = @same.empty? ? {} : { "same_capture_comparison" => comparison(path, @same) }
        [ path, { "rates" => rates(path), "comparison" => comparison(path), **same, "records" => scored(path) } ]
      end }
    end

    def to_markdown
      sections = paths.map do |path|
        r, c = rates(path), comparison(path)
        same = @same.empty? ? "" : "\n\nSame-capture text: #{prose(comparison(path, @same))}"
        scored_rows = rated(path)
        right = scored_rows.filter_map { it["right_distance"] }
        wrong = scored_rows.filter_map { it["nearest_wrong"] }
        misses = scored_rows.reject { it["art_first"] }.map { "| #{it["file"]} | #{it["name"]} | #{it["first"] || "—"} | #{it["right_distance"] || "—"} | #{it["nearest_wrong"] || "—"} | #{note(it)} |" }
        left_out = scored(path).select { it["missing_artwork"] }.map { "#{it["file"]} #{it["name"]}" }
        [ "### #{PATHS[path]}", "| Group | Right artwork first | Right card first by art | Right artwork in top 3 |", "|---|---|---|---|",
          *r.map { |group, v| "| #{group} | #{v["art_first"]} | #{v["card_first"]} | #{v["art_top3"]} |" }, "",
          "#{prose(c).capitalize}#{same}", "",
          "Median distance: right #{median(right)}, nearest wrong #{median(wrong)} (n=#{right.size}, #{wrong.size}).", "",
          "| File | Card | First artwork | Right distance | Nearest wrong | Note |", "|---|---|---|---|---|---|", *misses, "",
          "Left out (no artwork id): #{left_out.empty? ? "none" : left_out.join(", ")}." ].join("\n")
      end
      named = NAMED.filter_map do |file|
        truth = @truth[file] or next
        cells = paths.map { |path| "#{path}: #{outcome(scored(path).find { it["file"] == file })}" }
        "| #{file} | #{truth["name"]} (#{truth["set_code"].to_s.upcase} · #{truth["collector_number"]}) | #{cells.join(" | ")} |"
      end
      table = [ "| File | Card | #{paths.join(" | ")} |", "|---|---|#{"---|" * paths.size}", *named ].join("\n")
      [ *sections, "### Spec 009's misses and corrections", table ].join("\n\n")
    end

    private
      def prose(c)
        "text top 3 #{c["text_top3"]}; text or art #{c["text_or_art"]}; printings the text missed #{c["printing_missed"]}, of which art names the printing #{c["art_names_printing"]}."
      end

      # "no outline" (detected paths), "missing image" (the right artwork isn't in the index, so no distance was measured).
      def note(row)
        if !row["found"] then "no outline"
        elsif row["right_distance"].nil? then "missing image"
        else ""
        end
      end

      def printing_missed?(file, text)
        lookup = text.dig(file, "lookup") || {}
        !(lookup["status"] == "one" && lookup["external_keys"] == [ @truth.dig(file, "external_key") ])
      end

      def outcome(row)
        return "no outline" unless row["found"]

        verdict = if row["art_first"] then "artwork first" elsif row["card_first"] then "card first" else "miss" end
        "#{verdict}, right #{row["right_distance"] || "—"}, nearest wrong #{row["nearest_wrong"] || "—"}#{row["unique_printing"] ? ", unique to its printing" : ""}"
      end

      def rate(rows, &) = "#{rows.count(&)}/#{rows.size} (#{rows.empty? ? "n/a" : format("%.1f%%", 100.0 * rows.count(&) / rows.size)})"
      def median(values) = CardScannerPhase2.median(values) || "n/a"
  end
end
