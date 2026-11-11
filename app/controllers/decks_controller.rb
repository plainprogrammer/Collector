# Spec 062: the signed-in collector's decks. Every lookup is through Current.account and by the deck's location id, so another
# account's deck, a place or a zone is a 404 (AC-9.7, AC-3.8); nothing in a request names an account, a kind or a parent.
# @see file:collection-and-lots.md
class DecksController < ApplicationController
  before_action :set_deck, only: %i[edit update destroy]

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

  def edit
  end

  def update
    before = @deck.name
    if @deck.rename(deck_name)
      redirect_to decks_path, notice: "Renamed “#{before}” to “#{@deck.name}”.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  # A deck that holds copies is refused (spec 062 AC-3.4), here and in the database: a lot put in a zone after the
  # confirmation page opened is caught by the check, one put in between the check and the delete by the lots' foreign key,
  # which refuses the whole delete so no zone is left removed without its deck (AC-3.5). Removing a deck never changes a lot.
  def destroy
    holdings = @deck.holdings
    return refuse(holdings) if holdings.any?

    @deck.remove!
    redirect_to decks_path, notice: "Removed “#{@deck.name}”.", status: :see_other
  rescue ActiveRecord::InvalidForeignKey
    refuse(@deck.holdings) # a fresh read, which is the point: a lot landed after the check above
  end

  private
    # The refusal page with the 409 the Locations page uses for the same case; the lots listed are the ones that block.
    def refuse(holdings)
      @holdings = holdings
      render "decks/removals/refused", status: :conflict
    end

    # `find_by!` raises RecordNotFound (404) for another account's deck and for a place's or a zone's location id, which no
    # deck row points at.
    def set_deck = @deck = Current.account.decks.includes(:location).find_by!(location_id: params[:id])

    # The one permitted parameter of a rename, the location's name as the Locations page's form sends it; a request without
    # the location parameter is a 400.
    def deck_name = params.expect(location: [ :name ])[:name]

    # The two permitted parameters; a request without the deck parameter is a 400. An account, a kind, a parent, a zone or a
    # collectible type in the request is never read: the type comes from the checked format pair (AC-1.8, AC-1.10).
    def deck_params = params.expect(deck: %i[name format])
end
