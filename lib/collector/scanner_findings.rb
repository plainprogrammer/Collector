module Collector
  # Scores card scanner runs for spec 007's findings (AC-6.2–AC-6.6) with spec 005's definitions (research.md
  # §3 and §5): every rate overall, per era, foil and frame treatment, with its sample size. A record is one
  # card's ground truth (ground_truth.json's fields) merged with what a run read and ranked.
  module ScannerFindings
    Rate = Data.define(:hits, :total) do
      def percent = total.zero? ? nil : (100.0 * hits / total).round(1)
      def to_s = "#{hits}/#{total} (#{percent.nil? ? "n/a" : "#{percent}%"})"
    end
    GROUPINGS = {
      "overall" => ->(_) { "all" },
      "era" => ->(record) { record["era"] },
      "foil" => ->(record) { record["foil"] ? "foil" : "non-foil" },
      "frame treatment" => ->(record) { record["borderless_or_showcase"] ? "borderless/showcase" : "regular" }
    }.freeze
    SET_LINE_ERAS = [ "M15–ONE", "MOM+" ].freeze
    LOOKUP_STATUSES = { one: "one", several: "ambiguous", none: "none", unread: "none" }.freeze
    M15_RELEASE = Date.new(2014, 7, 18)
    MOM_RELEASE = Date.new(2023, 4, 21)

    module_function

    def breakdown(records, &hit)
      GROUPINGS.to_h do |label, key|
        [ label, records.group_by(&key).sort_by(&:first).to_h { |value, rows| [ value, Rate.new(hits: rows.count(&hit), total: rows.size) ] } ]
      end
    end

    # One Markdown table with a column per source ({ "Phase 0" => records, … }) and a row per group.
    def comparison(title, sources, &hit)
      columns = sources.transform_values { breakdown(it, &hit) }
      groups = columns.values.flat_map { |rates| rates.flat_map { |label, values| values.keys.map { [ label, it ] } } }.uniq
      rows = groups.map { |label, value| "| #{label} | #{value} | #{columns.values.map { it.dig(label, value) || "—" }.join(" | ")} |" }
      [ "| #{title} | Group | #{columns.keys.join(" | ")} |", "|---|---|#{"---|" * columns.size}", *rows ].join("\n")
    end

    def percentile(values, percent)
      return nil if values.empty?

      sorted = values.sort
      sorted[((percent / 100.0) * (sorted.size - 1)).round]
    end

    def name_read?(record, against: "name_bar") = Catalog::NameKey.call(record["name_text"]) == Catalog::NameKey.call(record[against])

    def printing_identified?(record)
      record.dig("lookup", "status") == "one" && record.dig("lookup", "external_keys") == [ record["external_key"] ]
    end

    def in_top?(record, ranking, count) = Array(record[ranking]).first(count).include?(record["name"])

    # Phase 0's committed fixtures as records: its OCR text, its lookup and its name-only ranking.
    def phase0(truth, ocr_results, name_matches)
      matches = name_matches.fetch("matches").to_h { [ it["file"], it ] }
      ocr_results.fetch("results").filter_map do |result|
        truth[result["file"]]&.merge(result.slice("file", "name_text", "collector_text", "lookup"),
          "name_candidates" => matches.dig(result["file"], "candidates").to_a.map { it["card_name"] })
      end
    end

    # Any run's text read again through MTG::Reading: the parsed line, the lookup, both rankings and the time
    # the lookup took on this machine.
    def rescore(truth, results)
      results.filter_map do |result|
        next unless truth.key?(result["file"])

        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        reading = MTG::Reading.new(name_text: result["name_text"].to_s, collector_text: result["collector_text"].to_s).resolve
        lookup_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round(2)
        truth[result["file"]].merge(result.slice("file", "name_text", "collector_text", "ms", "user_agent", "captured_at"),
          "parsed" => reading.collector_line.to_h.to_h { |key, value| [ key.to_s, value.is_a?(Symbol) ? value.to_s : value ] },
          "lookup" => { "status" => LOOKUP_STATUSES.fetch(reading.collector_status), "external_keys" => reading.collector_entries.map(&:external_key) },
          "lookup_ms" => lookup_ms, "name_candidates" => identity_names(reading.name_candidates.map(&:identity_id)),
          "final_candidates" => reading.candidates.map { it.entry.name })
      end
    end

    def identity_names(ids)
      names = Catalog::Identity.where(id: ids).pluck(:id, :name).to_h
      ids.map { names.fetch(it) }
    end

    # Ground truth for a manifest the committed ground_truth.json doesn't cover (a tuning run, AC-6.1), built
    # as spec 005 built it. The manifest has no quoted or comma-bearing values, so a split is enough.
    def ground_truth(manifest_text)
      header, *lines = manifest_text.lines.map(&:strip).reject(&:empty?)
      keys = header.split(",").map(&:strip)
      lines.map { keys.zip(it.split(",", -1).map(&:strip)).to_h }.each_with_object({ "photos" => [], "errors" => [] }) do |row, truth|
        entries = Catalog::Entry.where(collectible_type: "mtg").includes(:set)
          .printed_as(set_code: row["set"], number: row["number"], language: "en").to_a
        next truth["errors"] << row.merge("problem" => entries.empty? ? "none" : "ambiguous") unless entries.one?

        truth["photos"] << truth_record(row, entries.first)
      end
    end

    def truth_record(row, entry)
      printing = MTG::Printing.find_by!(catalog_entry_id: entry.id)
      { "file" => row["file"], "name" => entry.name, "name_bar" => printing.faces.first.fetch("name"), "set_code" => entry.set.code,
        "collector_number" => entry.number, "external_key" => entry.external_key,
        "era" => row["era"].presence || era_for(entry.released_on || entry.set.released_on), "foil" => row["foil"].to_s.casecmp?("yes"),
        "borderless_or_showcase" => printing.border_color == "borderless" || printing.variant_tags.include?("showcase") }
    end

    def era_for(released_on)
      if released_on < M15_RELEASE then "pre-M15"
      elsif released_on < MOM_RELEASE then "M15–ONE"
      else "MOM+"
      end
    end
  end
end
