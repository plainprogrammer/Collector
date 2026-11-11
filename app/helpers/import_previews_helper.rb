# Spec 025: how the import preview writes a lot or a row, and its copy counts.
module ImportPreviewsHelper
  PRICE = /\A(0|[1-9][0-9]*)\.[0-9]{2}\z/

  # Set code and number, language, then whatever finish, condition and price it has: "DMR · 27 · EN · Foil · $12.50".
  # A price the file doesn't write in the format's form is shown as the file gives it.
  # From version 3 a lot in a location ends "in <location>" (spec 032 AC-10.9). The price is in `currency`, a
  # Collector::Currency::Unit: the account's for a held lot, the file's for a file's row (spec 038 decision 8).
  def import_lot_line(set_code:, collector_number:, language:, finish:, condition:, price_paid:, currency:, location: nil)
    price = price_paid&.match?(PRICE) ? number_to_currency(price_paid, unit: currency.symbol) : price_paid
    [ [ set_code&.upcase, collector_number ].compact.join(" · ").presence, language&.upcase, finish&.humanize, condition&.humanize, price,
      ("in #{location}" if location) ].compact.join(" · ")
  end

  # Set code and number, language, finish and place of a proxy as the preview writes it: "MH2 · 138 · EN · Foil · in Izzet Tempo › Main".
  # Takes the keywords a proxy's `described` gives, a held proxy's and a file row's alike (spec 068 AC-7.6, AC-7.7).
  def import_proxy_line(set_code:, collector_number:, language:, finish:, place:)
    [ [ set_code&.upcase, collector_number ].compact.join(" · ").presence, language&.upcase, finish&.humanize, ("in #{place}" if place) ].compact.join(" · ")
  end

  def import_copies(count) = pluralize(number_with_delimiter(count), "copy")

  # "6 copies become 9", "1 copy becomes 2".
  def import_change(tally) = "#{import_copies(tally.copies)} #{tally.copies == 1 ? "becomes" : "become"} #{number_with_delimiter(tally.copies_after)}"

  # What an apply removes, in words: "3 lots (12 copies), 2 locations and 1 deck" (spec 028 decision 6, spec 029 decision 11,
  # spec 062 AC-7.6, spec 068 AC-7.9): "3 lots (12 copies), 2 locations, 1 deck and 4 proxies". The lots include those in a deck's zones.
  def import_removals(import)
    plan = import.plan
    parts = []
    parts << "#{pluralize(number_with_delimiter(plan.removed_lots.size), "lot")} (#{import_copies(import.removed.copies)})" if plan.removed_lots.any?
    parts.concat(import_removed_places_and_decks(plan))
    parts.to_sentence(last_word_connector: " and ")
  end

  # The counts in the checkbox's label: "1 lot", "3 lots and 2 locations", "3 lots, 2 locations, 1 deck and 4 proxies".
  def import_removed_counts(plan)
    parts = []
    parts << pluralize(number_with_delimiter(plan.removed_lots.size), "lot") if plan.removed_lots.any?
    parts.concat(import_removed_places_and_decks(plan))
    parts.to_sentence(last_word_connector: " and ")
  end

  # "Elves: First format → Second format": a format-changed deck by the names its formats are shown by, each prefixed by its
  # collectible's heading when the two formats belong to different collectibles (spec 062 AC-7.1).
  def import_format_change(change)
    held = change.held
    prefix = held.collectible_type != change.collectible_type
    "#{held.name}: #{import_format_name(held.collectible_type, held.format, prefix)} → #{import_format_name(change.collectible_type, change.format, prefix)}"
  end

  # What the page says of the decks for a file that says nothing of them (version 1 to 3): they stay, and so do the copies in
  # them unless a lot of one is among the lots the file's rows don't name, which applying removes (spec 062 AC-7.4). The view
  # adds the proxies' sentence (spec 068 AC-7.8).
  def import_decks_stay(plan)
    lots = plan.removed_zone_lots.size
    note = "This file was written before decks existed, so your decks would stay"
    lots.positive? ? "#{note}, but the copies in them (#{pluralize(number_with_delimiter(lots), "lot")}) would be removed." : "#{note}."
  end

  private
    def import_removed_places_and_decks(plan)
      parts = []
      parts << pluralize(number_with_delimiter(plan.locations.removed.size), "location") if plan.locations.removes?
      parts << pluralize(number_with_delimiter(plan.decks.removed.size), "deck") if plan.decks.removes?
      parts << pluralize(number_with_delimiter(plan.proxies.removed.size), "proxy") if plan.proxies.removes?
      parts
    end

    def import_format_name(type, key, with_category)
      name = Catalog::Formats.name_for(type, key)
      with_category ? "#{Catalog::Formats.category_name(type)} #{name}" : name
    end
end
