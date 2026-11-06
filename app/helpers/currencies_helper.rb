module CurrenciesHelper
  # The 20 codes in Collector::Currency's order, each as "EUR — €" (spec 038 AC-1.2).
  def currency_options = Collector::Currency::SYMBOLS.map { |code, symbol| [ "#{code} — #{symbol.strip}", code ] }
end
