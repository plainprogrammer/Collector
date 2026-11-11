# A move that would put more than 9,999 proxies of one printing and finish in one zone (spec 068 decision 10). It names the
# first such proxy by card name, set code, collector number, language and finish, as the format change's refusal says.
class Deck::Proxy::CapExceeded < StandardError
  # The proxy that would overflow.
  # @return [Deck::Proxy]
  attr_reader :proxy

  # @param proxy [Deck::Proxy] the proxy that would overflow, with its entry and set loaded
  def initialize(proxy)
    @proxy = proxy
    super("#{proxy.entry.name} would have more than #{Deck::Proxy::MAX_QUANTITY} proxies in one zone")
  end
end
