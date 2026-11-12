# Check deck (spec 079): the deck page with its checks' results. A read-only request, so the link to it needs no form and the
# result is never stored: any later request of the deck page has none (decision 7). The deck comes from the signed-in
# account's decks, so another account's is a 404 (`FindsDeck`). It builds the page and the shape panel as
# `DecksController#show` does and adds one report; the report reads the loaded rows and runs no statement of its own (AC-5.1).
class Decks::ChecksController < ApplicationController
  include FindsDeck

  before_action :set_deck

  # Renders the deck page with `@check` set.
  def show
    @page = Deck::Page.new(@deck)
    @shape = Catalog::DeckShape.answer(@deck.collectible_type, @page.zones)
    @check = Catalog::DeckChecks.report(@deck.collectible_type, @deck.format, @page.zones)
    render "decks/show"
  end
end
