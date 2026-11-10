# Spec 062: the signed-in collector's decks. Every lookup is through Current.account and by the deck's location id, so another
# account's deck, a place or a zone is a 404 (AC-9.7, AC-3.8); nothing in a request names an account, a kind or a parent.
# @see file:collection-and-lots.md
class DecksController < ApplicationController
  def index
    @listing = Deck::Listing.new(Current.account)
  end
end
