# Spec 070 Stories 2 and 3: Use my copy, the page that replaces a proxy by free copies the collector owns. The deck is found by
# its location id through the account and the proxy among the deck's; nothing in a request names an account, a zone or a
# location (AC-3.13). A proxy whose printing's collectible the instance no longer registers is 404: the page needs its
# vocabulary (decision 1).
# @see file:collection-and-lots.md
class Decks::Proxies::ReplacementsController < ApplicationController
  include FindsDeck

  before_action :set_deck
  before_action -> { set_proxy(:proxy_id) }
  before_action :require_replaceable

  # The free copies of the proxy's card, each with a number field.
  def new
    @replacement = Deck::Proxy::UseCopies.new(proxy: @proxy)
  end

  # Replaces the proxy by the copies chosen (one transaction), or shows the page again with the sentences (422).
  def create
    @replacement = Deck::Proxy::UseCopies.new(proxy: @proxy, typed: submitted[:lots], shown: submitted[:shown])
    if @replacement.save
      redirect_to deck_path(@deck), status: :see_other,
        notice: "Replaced #{helpers.pluralize(helpers.number_with_delimiter(@replacement.used), "proxy", "proxies")} of #{helpers.proxy_name(@proxy)} " \
                "in #{helpers.proxy_zone_label(@deck, @proxy.zone)} with copies you own."
    else
      render :new, status: :unprocessable_content
    end
  end

  private
    def require_replaceable
      raise ActiveRecord::RecordNotFound, "no vocabulary" unless Deck::Proxy.replaceable?(@proxy.entry)
    end

    # The two hashes the page posts: lot id => text. Any other parameter is never read.
    def submitted = params.permit(lots: {}, shown: {})
end
