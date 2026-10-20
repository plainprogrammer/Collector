module ScannersHelper
  COLLECTOR_OUTCOMES = { one: "Matched one printing", none: "No printing", several: "Several printings", unread: "Not read" }.freeze

  def collector_outcome(reading) = COLLECTOR_OUTCOMES.fetch(reading.collector_status)

  ART_OUTCOMES = { matched: "Matched", similar: "Looks similar", no_match: "No match" }.freeze

  # The Artwork row of "What the scanner read" (spec 011 AC-7.1): nil when no artworks were sent.
  def scanner_art_outcome(reading) = reading.art_status && ART_OUTCOMES.fetch(reading.art_status)

  # One sentence when confident art overruled what the text suggested (spec 011 AC-7.4).
  def scanner_overrule_note(reading)
    return unless reading.overruled

    what = reading.overruled_scope == :card ? "card" : "printing"
    by = reading.overruled == :collector_line ? "collector line" : "name"
    "The artwork matches a different #{what} from the one the #{by} suggests. The artwork's match is first."
  end

  def ocr_engine_path = "/ocr/#{::Collector::OcrEngine::VERSION}"

  def scanner_finish(printing, finish) = finish && Catalog.collecting_for(printing.collectible_type).finish_label(finish)

  # "Tome Shredder (STX · 117, Foil)": a scanner add's card, printing and finish (spec 009 AC-1.3, AC-4.1).
  def scanner_copy(printing, finish) = "#{printing.name} (#{[ set_number(printing), scanner_finish(printing, finish) ].compact.join(", ")})"
end
