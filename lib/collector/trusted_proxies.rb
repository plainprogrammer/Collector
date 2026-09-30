require "ipaddr"
require "action_dispatch"

module Collector
  # Reverse proxies whose X-Forwarded-For is trusted: Rails' private/loopback defaults plus the
  # comma-separated IPs or CIDRs in COLLECTOR_TRUSTED_PROXIES (spec 004 AC-4.8).
  module TrustedProxies
    def self.parse(value)
      ActionDispatch::RemoteIp::TRUSTED_PROXIES +
        value.to_s.split(",").map(&:strip).reject(&:empty?).map { |proxy| IPAddr.new(proxy) }
    end
  end
end
