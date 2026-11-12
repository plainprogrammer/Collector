# Spec 070 Story 4: Add a new copy, the Add a copy form for a proxy's printing whose copy lands in the proxy's zone while the
# proxy is lowered by the same quantity. The printing and the zone are the proxy's: no entry, location, zone or account is read
# from the request (AC-4.7). A proxy whose printing's collectible the instance no longer registers is 404 (decision 1).
# @see file:collection-and-lots.md
class Decks::Proxies::CopiesController < ApplicationController
  include FindsDeck

  before_action :set_deck
  before_action -> { set_proxy(:proxy_id) }
  before_action :require_replaceable

  # The form with the proxy's finish chosen, the zone read-only and Quantity from 1 to the proxy's count.
  def new
    @form = Lot::Form.new(entry: @proxy.entry, finish: @proxy.finish)
    @shown_quantity = @proxy.quantity
  end

  # Adds the copy to the zone and lowers the proxy (one transaction), or shows the form again with the sentences (422).
  def create
    @form = Lot::Form.new(**lot_params.to_h.symbolize_keys, entry: @proxy.entry)
    copy = Deck::Proxy::AddCopy.new(proxy: @proxy, form: @form, shown_quantity: params[:shown_quantity])
    if copy.save
      redirect_to deck_path(@deck), status: :see_other,
        notice: "Added #{helpers.number_with_delimiter(copy.added)} × #{@proxy.entry.name} (#{helpers.set_number(@proxy.entry)}) to " \
                "#{helpers.proxy_zone_label(@deck, @proxy.zone)}, replacing #{helpers.pluralize(helpers.number_with_delimiter(copy.added), "proxy", "proxies")}."
    else
      @shown_quantity = @proxy.quantity
      render :new, status: :unprocessable_content
    end
  end

  private
    def require_replaceable
      raise ActiveRecord::RecordNotFound, "no vocabulary" unless Deck::Proxy.replaceable?(@proxy.entry)
    end

    # No location: the zone is the proxy's.
    def lot_params = params.expect(lot: %i[quantity finish condition price_paid])
end
