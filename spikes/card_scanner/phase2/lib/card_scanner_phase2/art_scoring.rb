module CardScannerPhase2
  # Art-matching rates (AC-3.2 to AC-3.6) over scored records: each carries its text result (text_top3,
  # lookup) from score.json and the browser's ranked artworks from art.json.
  module ArtScoring
    GROUPINGS = { "overall" => ->(_) { "all" }, "era" => ->(r) { r["era"] }, "foil" => ->(r) { r["foil"] ? "foil" : "non-foil" },
                  "frame treatment" => ->(r) { r["borderless_or_showcase"] ? "borderless/showcase" : "regular" } }.freeze

    module_function

    def score(records, data)
      records.map do |record|
        right = data["entries"][record["external_key"]]
        ranked = Array(record["art"])
        rank = ranked.index { it["id"] == right }&.+(1)
        nearest_wrong = ranked.find { it["id"] != right }&.dig("distance")
        exact = record.dig("lookup", "status") == "one" && record["printing_identified"]
        record.merge("right_artwork" => right, "art_rank" => rank, "right_distance" => rank && ranked[rank - 1]["distance"], "nearest_wrong_distance" => nearest_wrong,
          "art_first" => rank == 1, "art_top3" => !rank.nil? && rank <= 3, "right_nearer" => !rank.nil? && (nearest_wrong.nil? || ranked[rank - 1]["distance"] < nearest_wrong),
          "share_name" => data["names"][record["name"]], "share_artwork" => right && data["artworks"].dig(right, "entries"), "no_exact_printing" => !exact)
      end
    end

    def rate(rows, &hit) = "#{rows.count(&hit)}/#{rows.size} (#{rows.empty? ? "n/a" : format("%.1f%%", 100.0 * rows.count(&hit) / rows.size)})"

    # The same table shape as Collector::ScannerFindings.comparison, reimplemented so this unit doesn't need Rails.
    def comparison(title, sources, &hit)
      groups = sources.values.flat_map { |rs| GROUPINGS.flat_map { |label, key| rs.map { [ label, key.call(it) ] } } }.uniq.sort
      rows = groups.map { |label, value| "| #{label} | #{value} | #{sources.values.map { |rs| rate(rs.select { GROUPINGS[label].call(it) == value }, &hit) }.join(" | ")} |" }
      [ "| #{title} | Group | #{sources.keys.join(" | ")} |", "|---|---|#{"---|" * sources.size}", *rows ].join("\n")
    end

    def markdown(scored)
      sources = { "All photos" => scored, "Classed found" => scored.select { it["class"] == "found" } } # the by-eye class (AC-2.4), per AC-3.3
      distances = scored.select { it["art_rank"] }
      parts = [ comparison("Right artwork first", sources) { it["art_first"] }, comparison("Right artwork in top 3", sources) { it["art_top3"] } ]
      parts << "Distances (right artwork ranked): median right #{median(distances.map { it["right_distance"] })}, median nearest wrong " \
               "#{median(distances.map { it["nearest_wrong_distance"] }.compact)}, right nearer than every wrong #{distances.count { it["right_nearer"] }} of #{distances.size}"
      missed = scored.reject { it["text_top3"] }
      parts << "Text missed #{missed.size}; of those art first #{missed.count { it["art_first"] }}; text top 3 or art first #{scored.count { it["text_top3"] || it["art_first"] }} of #{scored.size}"
      narrowing = scored.select { it["no_exact_printing"] }
      parts << "| File | Card | Printings sharing the name | Printings sharing the artwork |\n|---|---|---|---|\n" +
        narrowing.map { "| #{it["file"]} | #{it["name"]} | #{it["share_name"]} | #{it["share_artwork"]} |" }.join("\n")
      parts << "Narrowing: median sharing name #{median(narrowing.map { it["share_name"] }.compact)}, median sharing artwork #{median(narrowing.map { it["share_artwork"] }.compact)}, " \
               "artwork belongs to exactly one printing #{narrowing.count { it["share_artwork"] == 1 }} of #{narrowing.size}"
      parts << "| File | Right artwork's distance | Nearest wrong artwork's distance | Rank |\n|---|---|---|---|\n" +
        scored.map { "| #{it["file"]} | #{it["right_distance"] || "not ranked"} | #{it["nearest_wrong_distance"] || "-"} | #{it["art_rank"] || "-"} |" }.join("\n")
      parts.join("\n\n")
    end

    def median(values) = values.empty? ? "n/a" : values.sort[values.size / 2]

    def misses(scored) = scored.reject { it["art_first"] }
  end
end
