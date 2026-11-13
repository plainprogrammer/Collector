# The price source for Magic: The Gathering, backed by the `prices` object of Scryfall's bulk data file, the same file
# the catalog refresh reads (implements the contract in app/models/prices/sources.rb; spec 085). It stores what the file
# carries per printing, including the EUR a non-English printing copies from its English twin (research 083, ruling 41);
# which price a page shows for such a printing is a display rule, not a quote.
class MTG::Scryfall::PriceQuotes
  # The key in a card's `prices` object, in the order quotes are yielded, and the series it quotes. The 2026-11-13 file
  # has no etched EUR key in any object (research 083); it is read anyway, so one that appears is a quote. `tix`, the
  # MTGO price, and any other key are left out on purpose (spec 085 decision 5).
  SERIES_BY_KEY = {
    "usd" => Prices::Sources::Series.new(finish: "nonfoil", currency: "USD", kind: "market"),
    "usd_foil" => Prices::Sources::Series.new(finish: "foil", currency: "USD", kind: "market"),
    "usd_etched" => Prices::Sources::Series.new(finish: "etched", currency: "USD", kind: "market"),
    "eur" => Prices::Sources::Series.new(finish: "nonfoil", currency: "EUR", kind: "market"),
    "eur_foil" => Prices::Sources::Series.new(finish: "foil", currency: "EUR", kind: "market"),
    "eur_etched" => Prices::Sources::Series.new(finish: "etched", currency: "EUR", kind: "market")
  }.freeze

  # The UTC timestamp Scryfall puts at the end of a bulk file's name, the string the catalog keeps as the version.
  FILE_STAMP = /-(\d{4})(\d{2})(\d{2})\d{6}\.jsonl(?:\.gz)?\z/

  # The key this source is registered and stored under (price_sources.key); never changed once released.
  def self.key = "scryfall"

  # The catalog type whose printings these prices are for (a key of `Catalog.sources`).
  def self.collectible_type = "mtg"

  # The source's name, stored as price_sources.name.
  def self.title = "Scryfall"

  # Where a page links the attribution to.
  def self.attribution_url = "https://scryfall.com"

  # Spec 085 decision 10: what a page may say beside these prices.
  def self.attribution
    "Prices are provided by Scryfall. USD prices are TCGplayer's market price and EUR prices are Cardmarket's, " \
      "as Scryfall reports them. Scryfall updates them once a day."
  end

  # The series this source quotes: the six of SERIES_BY_KEY, in its order.
  #
  # @return [Array<Prices::Sources::Series>]
  def self.series = SERIES_BY_KEY.values

  # The day the file's data is from: the date in the UTC timestamp of its name (spec 085 decision 4).
  #
  # @param path [Pathname, String] a bulk file, such as `default-cards-20261113100623.jsonl.gz`; only its name is read
  # @return [Date]
  # @raise [Prices::Sources::IntegrityError] when the name has no timestamp, or its digits are not a date
  def reported_on(path)
    name = File.basename(path.to_s)
    year, month, day = FILE_STAMP.match(name)&.captures&.map(&:to_i)
    raise Prices::Sources::IntegrityError, "#{name}: the file's name carries no date, so no price can be given one" unless year && Date.valid_date?(year, month, day)

    Date.new(year, month, day)
  end
end
