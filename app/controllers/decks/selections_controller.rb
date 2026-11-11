# The deck refusal page's shortcut into bulk mode (spec 067, #302), the place shortcut's sibling
# (`Locations::SelectionsController`, spec 059). The lookup is `Decks::RemovalsController`'s: by the deck's location id
# through the account, so another account's deck, a place and a zone are all 404 (spec 067 AC-4.1, AC-4.2). The selection is
# under the filter that means every zone of the deck (`CollectionFilter::Place.deck_value`, `deck:<id>`, spec 065
# decision 4); what pressing does is `BulkModeShortcut`'s. The deck in the path is the only parameter read.
#
# @see file:collection-and-lots.md
class Decks::SelectionsController < ApplicationController
  include BulkModeShortcut

  # Starts the selection of every lot of the deck and answers 303 to the bulk table under it.
  def create
    deck = Current.account.decks.find_by!(location_id: params[:deck_id])
    open_in_bulk_mode(CollectionFilter::Place.deck_value(deck.location_id))
  end
end
