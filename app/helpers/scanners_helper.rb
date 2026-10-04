module ScannersHelper
  COLLECTOR_OUTCOMES = { one: "Matched one printing", none: "No printing", several: "Several printings", unread: "Not read" }.freeze

  def collector_outcome(reading) = COLLECTOR_OUTCOMES.fetch(reading.collector_status)

  def ocr_engine_path = "/ocr/#{::Collector::OcrEngine::VERSION}"

  def scanner_finish(printing, finish) = finish && Catalog.collecting_for(printing.collectible_type).finish_label(finish)

  # "Tome Shredder (STX · 117, Foil)": a scanner add's card, printing and finish (spec 009 AC-1.3, AC-4.1).
  def scanner_copy(printing, finish) = "#{printing.name} (#{[ set_number(printing), scanner_finish(printing, finish) ].compact.join(", ")})"
end
