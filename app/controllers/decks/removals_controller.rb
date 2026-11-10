# The no-script confirmation page for removing a deck (spec 062 AC-3.1, AC-3.3), the Locations one's sibling: the question
# for an empty deck, the refusal for one that holds copies. The lookup is by the deck's location id through the account, so
# another account's deck, a place and a zone are all 404 (AC-3.8, AC-9.7). It removes nothing; `DecksController#destroy` does.
# @see file:collection-and-lots.md
class Decks::RemovalsController < ApplicationController
  # Renders the question, or the refusal page when the deck's zones hold any lot.
  def new
    @deck = Current.account.decks.includes(:location).find_by!(location_id: params[:deck_id])
    @holdings = @deck.holdings
    render :refused if @holdings.any?
  end
end
