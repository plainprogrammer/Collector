module Collector
  # Currencies price paid can be shown in (spec 004 FR-6): an account's own (accounts.currency) and the default a new
  # account starts with (spec 038). Amounts are stored in minor units and always shown with two decimals.
  module Currency
    Unit = Data.define(:code, :symbol)

    SYMBOLS = {
      "USD" => "$", "CAD" => "CA$", "AUD" => "A$", "NZD" => "NZ$", "EUR" => "€", "GBP" => "£", "CHF" => "CHF ",
      "SEK" => "kr ", "NOK" => "kr ", "DKK" => "kr ", "PLN" => "zł ", "CZK" => "Kč ", "JPY" => "¥", "CNY" => "CN¥",
      "KRW" => "₩", "SGD" => "S$", "HKD" => "HK$", "BRL" => "R$", "MXN" => "MX$", "ZAR" => "R "
    }.freeze

    # +setting+ names where the code came from, for the error: the environment variable at boot, or an account's column.
    def self.fetch!(code, setting: "COLLECTOR_CURRENCY")
      normalized = code.to_s.strip.upcase
      symbol = SYMBOLS.fetch(normalized) do
        raise ArgumentError, "#{setting} #{code.inspect} is not supported; use one of #{SYMBOLS.keys.join(', ')}"
      end
      Unit.new(code: normalized, symbol:)
    end
  end
end
