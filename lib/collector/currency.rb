module Collector
  # Currencies price paid can be shown in (spec 004 FR-6). Amounts are stored in minor units and
  # always shown with two decimals.
  module Currency
    Unit = Data.define(:code, :symbol)

    SYMBOLS = {
      "USD" => "$", "CAD" => "CA$", "AUD" => "A$", "NZD" => "NZ$", "EUR" => "€", "GBP" => "£", "CHF" => "CHF ",
      "SEK" => "kr ", "NOK" => "kr ", "DKK" => "kr ", "PLN" => "zł ", "CZK" => "Kč ", "JPY" => "¥", "CNY" => "CN¥",
      "KRW" => "₩", "SGD" => "S$", "HKD" => "HK$", "BRL" => "R$", "MXN" => "MX$", "ZAR" => "R "
    }.freeze

    def self.fetch!(code)
      normalized = code.to_s.strip.upcase
      symbol = SYMBOLS.fetch(normalized) do
        raise ArgumentError, "COLLECTOR_CURRENCY #{code.inspect} is not supported; use one of #{SYMBOLS.keys.join(', ')}"
      end
      Unit.new(code: normalized, symbol:)
    end
  end
end
