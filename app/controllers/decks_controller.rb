# Spec 062: the signed-in collector's decks. Every lookup is through Current.account and by the deck's location id, so another
# account's deck, a place or a zone is a 404 (AC-9.7, AC-3.8); nothing in a request names an account, a kind or a parent.
# @see file:collection-and-lots.md
class DecksController < ApplicationController
  def index
    @listing = Deck::Listing.new(Current.account)
  end

  def new
    @creation = Deck::Creation.new(account: Current.account, name: "", format: Catalog::Formats.default_option&.value)
  end

  def create
    @creation = Deck::Creation.new(account: Current.account, name: deck_params[:name], format: deck_params[:format])
    if @creation.save
      redirect_to decks_path, notice: "Added “#{@creation.deck.name}”.", status: :see_other
    else
      render :new, status: :unprocessable_content
    end
  end

  private
    # The two permitted parameters; a request without the deck parameter is a 400. An account, a kind, a parent, a zone or a
    # collectible type in the request is never read: the type comes from the checked format pair (AC-1.8, AC-1.10).
    def deck_params = params.expect(deck: %i[name format])
end
