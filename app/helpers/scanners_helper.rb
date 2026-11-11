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

  # "NM": a lot's or a sitting's condition as its short label, from the vocabulary of the printing's own collectible (spec 042
  # decision 3); nil when none is set or the vocabulary doesn't list it. No query: the vocabulary is a constant.
  def scanner_condition(printing, condition) = condition && Catalog.collecting_for(printing.collectible_type).conditions[condition]&.last

  # "Tome Shredder (STX · 117, Foil, NM)": a scanner add's card, printing, finish and, when given, condition (spec 009 AC-1.3,
  # spec 042 decision 3). The Undo announcement and the accessible names call it without a condition (spec 042 decision 3).
  def scanner_copy(printing, finish, condition = nil)
    "#{printing.name} (#{[ set_number(printing), scanner_finish(printing, finish), scanner_condition(printing, condition) ].compact.join(", ")})"
  end

  # The sitting's choices as words, only those that are set: "Near mint", "in Blue binder" (spec 042 decision 3). The scale is
  # the Hash the caller gives (condition key => [ long label, short label ]).
  def sitting_choices(sitting, conditions)
    [ sitting.condition && conditions.dig(sitting.condition, 0), ("in #{sitting.location.label}" if sitting.location) ].compact
  end

  # The data of a redrawn sitting panel that puts keyboard focus back (spec 047 decision 3): nil on a page render and after an
  # add, so nothing is focused by them. `focus` is :set or :heading, a word of ours; the Stimulus controller reads it once.
  def sitting_focus_data(focus) = (focus ? { controller: "sitting-focus", sitting_focus_to_value: focus } : nil)
end
