# The no-script confirmation page for removing a proxy (spec 068 decision 6, AC-3.4), the lot's and the deck's removal pages'
# sibling. It removes nothing; `Decks::ProxiesController#destroy` does. The lookup is the proxy controller's (FindsDeck), so
# another account's proxy, another deck's proxy and a place's or a zone's id as the deck are all 404 (AC-3.6).
# @see file:collection-and-lots.md
class Decks::Proxies::RemovalsController < ApplicationController
  include FindsDeck

  before_action :set_deck
  before_action -> { set_proxy(:proxy_id) }, only: :new

  # Renders the question.
  def new
  end
end
