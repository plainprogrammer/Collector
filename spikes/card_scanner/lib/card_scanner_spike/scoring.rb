module CardScannerSpike
  # Hit predicates and statistics for the Story 1 and Story 3 reports.
  module Scoring
    LOOKALIKES = { "l" => "1", "i" => "l", "o" => "0", "e" => "c", "n" => "m", "a" => "o" }.freeze
    STRIPS = %w[name_text collector_text].freeze

    module_function

    def name_read?(result, truth) = Normaliser.call(result["name_text"]) == Normaliser.call(truth["name_bar"])

    def printing_identified?(result, truth)
      result.dig("lookup", "status") == "one" && result.dig("lookup", "external_keys") == [ truth["external_key"] ]
    end

    def in_top?(match, truth, count) = match["candidates"].first(count).any? { it["card_name"] == truth["name"] }

    def percentile(values, percent)
      return nil if values.empty?

      sorted = values.sort
      sorted[((percent / 100.0) * (sorted.size - 1)).round]
    end

    def differences(run_a, run_b)
      others = run_b.to_h { [ it["file"], it ] }
      run_a.flat_map do |result|
        other = others.fetch(result["file"], {})
        STRIPS.filter_map do |field|
          { "file" => result["file"], "field" => field, "a" => result[field], "b" => other[field] } unless result[field] == other[field]
        end
      end
    end

    def misread(name)
      middle = name.length / 2
      name.dup.tap { it[middle] = LOOKALIKES.fetch(name[middle], "x") }
    end
  end
end
