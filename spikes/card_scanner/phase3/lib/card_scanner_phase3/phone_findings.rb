module CardScannerPhase3
  # The phone timings for research.md and the fixture (spec 010 Story 2): one row per load (cold, warm), slower-link
  # arithmetic for the cold download, and the queries whose top artwork differs from the desktop reference.
  class PhoneFindings
    LINKS = [ 50, 10, 2 ].freeze

    def initialize(results:, desktop:)
      @results, @desktop = results, desktop
    end

    def to_h = { "loads" => @results, "desktop" => @desktop, "differing_tops" => differing_tops }

    def to_markdown
      rows = @results.map do |r|
        "| #{r["mode"]} | #{num(r.dig("index", "encodedBodySize") || r.dig("index", "contentLength"))} | #{num(r.dig("index", "decodedBytes"))} | #{r["downloadMs"].round} | " \
          "#{r["readyMs"].round} | #{r.dig("search", "medianMs").round} | #{r.dig("search", "slowestMs").round} | #{r.dig("fingerprint", "medianMs").round} | " \
          "#{r.dig("fingerprint", "slowestMs").round} | #{r.dig("fingerprint", "maxBits")} | #{r.dig("responsive", "maxGapMs").round} | #{r.dig("responsive", "completed") ? "yes" : "no"} |"
      end
      cold = @results.find { it["mode"] == "cold" }
      bytes = cold && (cold.dig("index", "encodedBodySize") || cold.dig("index", "contentLength"))
      links = bytes ? LINKS.map { "#{it} Mbit/s: #{(bytes * 8.0 / (it * 1_000_000)).round(1)} s" }.join(", ") : "n/a"
      diffs = differing_tops.map { "#{it["file"]} (phone #{it["phone"]}, desktop #{it["desktop"]})" }
      [ "| Load | Encoded bytes | Decoded bytes | Download ms | Ready ms | Search median ms | Search slowest ms | Fingerprint median ms | " \
        "Fingerprint slowest ms | Fingerprint max bits | Longest gap ms (100 searches) | Completed |", "|---|---|---|---|---|---|---|---|---|---|---|---|", *rows, "",
        "Cold download at slower links (arithmetic, not measured): #{links}.", "",
        "Tops that differ from the desktop's: #{diffs.empty? ? "none" : diffs.join(", ")}.", "",
        *@results.map { memory_line(it) }, "",
        "Device and browser: #{@results.map { it["userAgent"] }.uniq.join("; ")}; measured over the LAN." ].join("\n")
    end

    private
      def differing_tops
        reference = @desktop.dig("search", "tops").to_h { [ it["file"], it.dig("top", "id") ] }
        @results.flat_map { |r| r.dig("search", "tops") }.uniq { it["file"] }.filter_map do |t|
          { "file" => t["file"], "phone" => t.dig("top", "id"), "desktop" => reference[t["file"]] } if reference[t["file"]] != t.dig("top", "id")
        end
      end

      def num(value) = value.to_s.reverse.scan(/\d{1,3}/).join(",").reverse

      # AC-2.5: what the page holds; WebKit exposes no heap measure.
      def memory_line(load)
        memory = load["memory"]
        "Memory held (#{load["mode"]}): index #{num(memory["decodedBytes"])} bytes, words #{num(memory["wordsBytes"])} bytes, " \
          "#{num(memory["ids"])} ids in at most #{num(memory["idsBytes"])} bytes (no heap figure in WebKit)."
      end
  end
end
