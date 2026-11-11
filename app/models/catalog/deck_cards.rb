# What a deck page asks a collectible's vocabulary about one card of a deck (spec 066 decision 5): the group the card's
# row sits under, whether the extension draws its cost, and the legality marker's word in the deck's format. Like
# `Catalog::Formats`, an optional answer on the collecting vocabulary (`Catalog.collecting_for`), so the core renders the
# page and never names a collectible.
#
# An extension contract: a vocabulary that wants its cards grouped, costed and marked may provide
# * `deck_card(entry, format_key)` returning an {Answer} (or nil for none). `entry` is a `Catalog::Entry` of the vocabulary's
#   own type with its `extension` already loaded (`Catalog::Entry.preload_extensions` ran once per type), so the method
#   reads memory and runs no query. `format_key` is the deck's stored format key, registered or not: answer no legality for
#   a key the collectible has no rules for.
# * `group` is the group's shown name and `position` its place among the groups (lower first); both are nil for a flat row.
# * `legality` is nil for a legal card and for a format with no rules, or the word the page shows beside a cross ("Banned").
# * `costed` is true when the extension has a `deck_cost` partial for the entry, drawn with
#   `render_catalog_extension(entry, :deck_cost)`; the partial draws a muted dash itself for a card with no cost.
# A vocabulary without `deck_card`, an entry of another type than the deck's and a type no longer registered get {NONE}:
# one flat table with a muted dash in Cost and no marker.
# @see file:collection-and-lots.md
module Catalog::DeckCards
  # What the deck page shows for one card; see the module's contract for each member.
  Answer = Data.define(:group, :position, :legality, :costed)
  # The answer for a card the vocabulary does not describe: no group, no marker, no cost display.
  NONE = Answer.new(group: nil, position: nil, legality: nil, costed: false)

  # The deck page's answer for one card.
  #
  # @param deck_type [String] the deck's collectible type
  # @param entry [Catalog::Entry] the card, its `extension` loaded
  # @param format_key [String] the deck's stored format key
  # @return [Answer] the vocabulary's, or {NONE}; never nil and never raises for an unregistered type
  def self.answer(deck_type, entry, format_key)
    return NONE unless entry.collectible_type == deck_type && Catalog.collecting.key?(deck_type)

    vocabulary = Catalog.collecting_for(deck_type)
    return NONE unless vocabulary.respond_to?(:deck_card)

    vocabulary.deck_card(entry, format_key) || NONE
  end
end
