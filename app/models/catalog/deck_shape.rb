# What the deck page asks a collectible's vocabulary for beside its zone tables: the shape panel (spec 069, #256), a second
# optional answer of the collecting vocabulary like `Catalog::DeckCards`. The core draws the page and each copy's frame and
# never names a collectible, a format or a zone; the vocabulary decides which zones count and what the parts say.
#
# An extension contract: a vocabulary that wants a panel provides `deck_shape(zones)` returning an {Answer} or nil.
# * `zones` is `Deck::Page#zones` as the page built it: every zone of the deck (Considering included), each a
#   `Deck::Page::Zone` whose `location.zone` is the zone's key, with its `name` and `groups` of rows. The vocabulary chooses the zones
#   that count and reads only what the rows already hold (the printings' loaded extension records); it runs a fixed number of
#   statements however many rows there are, and none when no card counts.
# * `partial` is the view that draws the panel's parts, rendered with a local `figures`; `figures` is what it draws;
#   `scope` is the scope line (the counted zones' names and their card count) and `facts` the fold's facts line.
# A vocabulary without `deck_shape`, a type no longer registered and a nil answer give the page no panel.
# @see file:collection-and-lots.md
module Catalog::DeckShape
  # What the page shows: see the module's contract for each member.
  Answer = Data.define(:partial, :figures, :scope, :facts)

  # The panel of one deck.
  #
  # @param deck_type [String] the deck's collectible type
  # @param zones [Array<Deck::Page::Zone>] `Deck::Page#zones`
  # @return [Answer, nil] nil when the type, its vocabulary or the answer is missing; never raises for an unregistered type
  def self.answer(deck_type, zones)
    return unless Catalog.collecting.key?(deck_type)

    vocabulary = Catalog.collecting_for(deck_type)
    vocabulary.deck_shape(zones) if vocabulary.respond_to?(:deck_shape)
  end
end
