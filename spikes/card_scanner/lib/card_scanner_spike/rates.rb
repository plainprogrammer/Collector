module CardScannerSpike
  # Hit rates over records, overall and per era, foil and frame treatment, with sample sizes (FR-4).
  module Rates
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

    module_function

    def breakdown(records, &hit)
      GROUPINGS.to_h do |label, key|
        [ label, records.group_by(&key).sort_by(&:first).to_h { |value, rows| [ value, Rate.new(hits: rows.count(&hit), total: rows.size) ] } ]
      end
    end

    def markdown(title, breakdown)
      rows = breakdown.flat_map { |label, groups| groups.map { |value, rate| "| #{label} | #{value} | #{rate} |" } }
      [ "| #{title} | Group | Hits / n (rate) |", "|---|---|---|", *rows ].join("\n")
    end
  end
end
