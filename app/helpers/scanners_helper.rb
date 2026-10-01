module ScannersHelper
  COLLECTOR_OUTCOMES = { one: "Matched one printing", none: "No printing", several: "Several printings", unread: "Not read" }.freeze

  def collector_outcome(reading) = COLLECTOR_OUTCOMES.fetch(reading.collector_status)

  def ocr_engine_path = "/ocr/#{::Collector::OcrEngine::VERSION}"
end
