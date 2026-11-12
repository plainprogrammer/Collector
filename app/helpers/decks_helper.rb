# The Decks pages' words (spec 062 FR-4); the markup is in `app/views/decks`.
module DecksHelper
  # "6 decks · 379 cards" for the Decks page's head: the decks, then their cards, owned plus proxy, in all their zones
  # (Considering included).
  #
  # @param listing [Deck::Listing]
  # @return [String]
  def deck_count_line(listing)
    cards = listing.rows.sum(&:cards)
    "#{pluralize(number_with_delimiter(listing.count), "deck")} · #{pluralize(number_with_delimiter(cards), "card")}"
  end

  # "Format name · 58 owned": the line a narrow table shows under a deck's name; the proxy tag follows it in the view.
  #
  # @param row [Deck::Listing::Row]
  # @return [String]
  def deck_sub_line(row) = "#{row.deck.format_name} · #{number_with_delimiter(row.owned)} owned"

  # "60 cards · 52 owned · 8 proxy": a zone's counts and the tail of the page head (spec 068 decision 7). Cards are owned plus
  # proxy, and "proxy" has no plural.
  #
  # @param owned [Integer] the copies counted
  # @param proxy [Integer] the proxies counted (quantities)
  # @return [String]
  def deck_counts_line(owned, proxy = 0) = "#{pluralize(number_with_delimiter(owned + proxy), "card")} · #{number_with_delimiter(owned)} owned · #{number_with_delimiter(proxy)} proxy"

  # The deck page's muted head line: the format's name (its key when no longer registered), then the counts of every zone.
  #
  # @param page [Deck::Page]
  # @return [String]
  def deck_page_line(page) = "#{page.deck.format_name} · #{deck_counts_line(page.owned, page.proxy)}"

  # "4 copies in 2 decks · 2 proxy": the count beside the card page's "In decks" (spec 073 decision 5). The copies and the decks
  # come first, only when copies are in decks; the proxies follow, as the deck pages count them ("proxy" has no plural).
  #
  # @param uses [Deck::CardUses]
  # @return [String] empty when the card is in no deck zone and has no proxy
  def card_decks_count_line(uses)
    parts = []
    parts << "#{pluralize(number_with_delimiter(uses.owned), "copy")} in #{pluralize(number_with_delimiter(uses.deck_count), "deck")}" if uses.owned.positive?
    parts << "#{number_with_delimiter(uses.proxy)} proxy" if uses.proxy.positive?
    parts.join(" · ")
  end

  # The dashed tag of a proxy count: `<span class="c-proxy">Proxy <b>2</b></span>` (ProxyTag, spec 060 FR-1).
  #
  # @param count [Integer]
  # @return [ActiveSupport::SafeBuffer]
  def proxy_tag(count) = tag.span(class: "c-proxy") { safe_join([ "Proxy ", tag.b(number_with_delimiter(count)) ]) }

  # "Izzet Tempo › Main": a zone as the pages say it, from the deck's name and the zone's own, without loading the parent.
  #
  # @param deck [Deck]
  # @param zone [Location]
  # @return [String]
  def proxy_zone_label(deck, zone) = Location::Placement.label(zone.name, deck.name)

  # "Lightning Bolt (MH2 · 138, Foil)": a proxy as the pages and notices name it, the finish after the number only when it has one.
  #
  # @param proxy [Deck::Proxy] with its entry and set loaded
  # @return [String]
  def proxy_name(proxy)
    detail = [ set_number(proxy.entry), proxy.finish_label ].compact.join(", ")
    "#{proxy.entry.name} (#{detail})"
  end

  # A row menu item's words (spec 068 decision 5, spec 070 decision 1): "Use my copy", "Add a new copy", "Change proxy count",
  # "Remove proxy", with the finish named when the row has proxies of more than one finish: "Use my copy for Foil proxy",
  # "Add a new copy for Foil proxy", "Change Foil proxy count", "Remove Foil proxy".
  #
  # @param verb [String] "Use", "Add", "Change" or "Remove"
  # @param line [Deck::Page::Line]
  # @param row [Deck::Page::Row]
  # @return [String]
  def proxy_item_label(verb, line, row)
    finish = line.finish && row.lines.size > 1 ? "#{proxy_finish_label(row.entry, line.finish)} " : ""
    case verb
    when "Use" then finish.empty? ? "Use my copy" : "Use my copy for #{finish}proxy"
    when "Add" then finish.empty? ? "Add a new copy" : "Add a new copy for #{finish}proxy"
    when "Change" then "Change #{finish}proxy count"
    else "Remove #{finish}proxy"
    end
  end

  # "Replaces 2 proxies in Izzet Tempo › Main · 2X2 · 117, Foil": the muted line of both replacement pages (spec 070 AC-2.1,
  # AC-4.1). The printing is `deck_set_line`'s (with ` · LANG` for a language other than English), the finish the vocabulary's
  # label, only when the proxy has one.
  #
  # @param deck [Deck]
  # @param proxy [Deck::Proxy] with its zone, entry and set loaded
  # @return [ActiveSupport::SafeBuffer]
  def replaces_line(deck, proxy)
    printing = safe_join([ tag.span(deck_set_line(proxy.entry), class: "is-data"), (", #{proxy.finish_label}" if proxy.finish) ])
    safe_join([ "Replaces #{pluralize(number_with_delimiter(proxy.quantity), "proxy", "proxies")} in #{proxy_zone_label(deck, proxy.zone)} · ", printing ])
  end

  # A free lot's row text on Use my copy (spec 070 decision 4): the printing, the finish and the condition as the vocabulary
  # labels them (each only when the lot has one), "paid $1.25" in the account's currency when it has a price, the place ("No
  # location" when unplaced) and "×N free". It names the row's number field.
  #
  # Needs `Current.account` set: for a lot with a price paid it reads the account's currency (`Current.account.currency_unit`),
  # and a view outside a signed-in request has no account to read it from.
  #
  # @param lot [Lot] with its entry and location loaded
  # @return [ActiveSupport::SafeBuffer]
  def lot_pick_label(lot)
    vocabulary = lot.vocabulary
    finish = vocabulary.finish_label(lot.finish) if lot.finish
    condition = vocabulary.conditions.fetch(lot.condition) { [ lot.condition.humanize ] }.first if lot.condition
    price = "paid #{number_to_currency(lot.price_paid, unit: Current.account.currency_unit.symbol)}" if lot.price_paid
    rest = [ condition, price, lot.place_label || "No location", "×#{number_with_delimiter(lot.quantity)} free" ].compact.join(", ")
    safe_join([ tag.span(deck_set_line(lot.entry), class: "is-data"), (" #{finish}" if finish), ", ", rest ])
  end

  # The finish as its collectible's vocabulary labels it; the humanised key for a collectible this instance no longer has.
  #
  # @param entry [Catalog::Entry]
  # @param finish [String]
  # @return [String]
  def proxy_finish_label(entry, finish)
    Catalog.collecting.key?(entry.collectible_type) ? Catalog.collecting_for(entry.collectible_type).finish_label(finish) : finish.humanize
  end

  # "S1 · 52" under a card's name, with " · DE" after the number for a printing whose language is not English (spec 066 AC-2.5).
  #
  # @param entry [Catalog::Entry] with its set loaded
  # @return [String]
  def deck_set_line(entry) = entry.language == "en" ? set_number(entry) : "#{set_number(entry)} · #{entry.language.upcase}"

  # The Format select's options: every format the registered collectibles give, in their registered order, as
  # `<type>/<key>` values. With formats of more than one type each type's formats sit under its category name; with one
  # the list is flat (spec 062 AC-1.2).
  #
  # @param selected [String, nil] the value to mark selected, as `<type>/<key>`
  # @return [ActiveSupport::SafeBuffer] option and optgroup tags
  def deck_format_options(selected)
    options = Catalog::Formats.options
    return options_for_select(options.map { [ it.format.name, it.value ] }, selected) unless Catalog::Formats.grouped?

    groups = options.group_by(&:type).map do |type, in_type|
      [ Catalog::Formats.category_name(type), in_type.map { [ it.format.name, it.value ] } ]
    end
    grouped_options_for_select(groups, selected)
  end

  # The value the Change format select starts on: the deck's own pair when the instance registers it, else the default format
  # (a deck whose registration was lost; the page head still shows its stored key, spec 064 AC-1.7).
  #
  # @param deck [Deck]
  # @return [String, nil] `<type>/<key>`
  def deck_format_selection(deck)
    Catalog::Formats.find(deck.collectible_type, deck.format) ? "#{deck.collectible_type}/#{deck.format}" : Catalog::Formats.default_option&.value
  end

  # The notice after a change of format: "Changed “Izzet Tempo” to <Format>. 12 cards moved to Considering. 3 proxies moved to
  # Considering." (the second sentence only when copies moved and the third only when proxies moved, "1 proxy" for one, each
  # naming the zone as its row does), or that the deck already has the format (AC-1.3, AC-1.6; spec 068 AC-6.3).
  #
  # @param deck [Deck] after the change
  # @param change [Deck::FormatChange] after {Deck::FormatChange#save}
  # @return [String]
  def format_changed_message(deck, change)
    return "“#{deck.name}” is already #{deck.format_name}." unless change.changed?

    parts = [ "Changed “#{deck.name}” to #{deck.format_name}." ]
    parts << "#{pluralize(number_with_delimiter(change.moved), "card")} moved to #{change.considering_name}." if change.moved.positive?
    parts << "#{number_with_delimiter(change.proxies_moved)} #{change.proxies_moved == 1 ? "proxy" : "proxies"} moved to #{change.considering_name}." if change.proxies_moved.positive?
    parts.join(" ")
  end

  # The alert of a format change a proxy merge would break (spec 068 AC-6.4): "Nothing changed. Lightning Bolt (MH2 · 138) would
  # have more than 9,999 proxies in one zone."
  #
  # @param prefix [String]
  # @param proxy [Deck::Proxy] with its entry and set loaded
  # @return [String]
  def over_proxy_cap_message(prefix, proxy)
    "#{prefix} #{proxy.entry.name} (#{set_number(proxy.entry)}) would have more than #{number_with_delimiter(Deck::Proxy::MAX_QUANTITY)} proxies in one zone."
  end

  # The confirmation's first sentence (spec 068 AC-5.4): the zones go with the deck, and so do its proxies when it has any.
  #
  # @param proxies [Integer] the quantities of proxies in the deck
  # @return [String]
  def deck_removal_sentence(proxies)
    what = proxies.positive? ? "its zones and its #{pluralize(number_with_delimiter(proxies), "proxy", "proxies")} are" : "its zones are"
    "This removes the deck, and #{what} removed with it. No copy in your collection is removed or changed."
  end
end
