# A move that would put more than 9,999 proxies of one printing and finish in one zone (spec 068 decision 10). The error carries
# the proxy the caller chose as first: `Deck::FormatChange` picks it by card name, set code, collector number, language and finish
# (`first_by_shown_order`), and the refusal names that one.
class Deck::Proxy::CapExceeded < StandardError
  # The proxy the caller chose to name, one that would overflow.
  # @return [Deck::Proxy]
  attr_reader :proxy

  # @param proxy [Deck::Proxy] the proxy that would overflow, with its entry and set loaded
  def initialize(proxy)
    @proxy = proxy
    super("#{proxy.entry.name} would have more than #{Deck::Proxy::MAX_QUANTITY} proxies in one zone")
  end
end
