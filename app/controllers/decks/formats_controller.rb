# Spec 064: the Change format page and the change. The lookup is by the deck's location id through the account, so another
# account's deck, a place and a zone are all 404 (AC-3.3, AC-3.4); the one permitted parameter is the format pair (AC-3.2).
# @see file:collection-and-lots.md
class Decks::FormatsController < ApplicationController
  before_action :set_deck

  def edit
    @change = Deck::FormatChange.new(deck: @deck, format: helpers.deck_format_selection(@deck))
  end

  # A format the deck has is no change (AC-1.6); a merge past the cap re-renders the page with the alert and writes nothing
  # (AC-2.6), and so does a merge of proxies past it (spec 068 AC-6.4); an unregistered pair re-renders it with "Choose a format." on the field (AC-3.1).
  def update
    @change = Deck::FormatChange.new(deck: @deck, format: params.expect(deck: [ :format ])[:format])
    if @change.save
      redirect_to decks_path, notice: helpers.format_changed_message(@deck, @change), status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  rescue Lot::CapExceeded => error
    flash.now[:alert] = helpers.over_cap_message("Nothing changed.", error.lot)
    render :edit, status: :unprocessable_content
  rescue Deck::Proxy::CapExceeded => error
    flash.now[:alert] = helpers.over_proxy_cap_message("Nothing changed.", error.proxy)
    render :edit, status: :unprocessable_content
  end

  private
    def set_deck = @deck = Current.account.decks.includes(:location).find_by!(location_id: params[:deck_id])
end
