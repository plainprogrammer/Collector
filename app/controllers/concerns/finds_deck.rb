# Finds the deck, and a proxy of it, for the proxy controllers (spec 068): by the deck's location id and the proxy's id through
# the signed-in account, so another account's deck, a place's id, a zone's id, an id that isn't digits only and another deck's
# proxy are all 404 (AC-1.7, AC-3.6). Nothing in a request names an account.
module FindsDeck
  extend ActiveSupport::Concern

  private
    # @param param [Symbol] the path parameter holding the deck's location id
    def set_deck(param = :deck_id)
      raise ActiveRecord::RecordNotFound, "not a deck id" unless params[param].to_s.match?(Location::ID_TEXT)

      @deck = Current.account.decks.includes(:location).find_by!(location_id: params[param])
    end

    # The proxy with the path's id among the deck's own (its zones'), with the entry and set the pages name it by.
    #
    # @param param [Symbol] the path parameter holding the proxy's id (`:id`; the removal page's route calls it `:proxy_id`)
    def set_proxy(param = :id)
      raise ActiveRecord::RecordNotFound, "not a proxy id" unless params[param].to_s.match?(Location::ID_TEXT)

      @proxy = @deck.proxies.includes(:zone, entry: :set).find(params[param])
    end
end
