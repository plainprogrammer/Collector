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

  # A price as Scryfall writes it: whole dollars or euros with at most two decimals. Nine integer digits (below a
  # billion) keep a garbled value from becoming a price (spec 085 decision 6).
  PRICE = /\A\d{1,9}(\.\d{1,2})?\z/

  # The key this source is registered and stored under (price_sources.key); never changed once released.
  def self.key = "scryfall"

  # The catalog type whose printings these prices are for (a key of `Catalog.sources`).
  def self.collectible_type = "mtg"

  # The source's name, stored as price_sources.name.
  def self.title = "Scryfall"

  # Where a page links the attribution to.
  def self.attribution_url = "https://scryfall.com"

  # Spec 085 decision 9, ruled true by the maintainer on 2026-11-13: ruling 27 allows this source's data on a hosted instance
  # with paid plans while it stays publicly accessible, and rulings 37 and 38 show prices to everyone who can see the
  # card. The one place the value is written; issue #362 (Scryfall's written answer) is open and may change it.
  def self.hosted_paid_allowed? = true

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

  # Yields a quote for every price the bulk file carries, for the paper printings in the given languages, one card at a
  # time (spec 085 decisions 3, 5 and 6). It makes no network call, writes nothing and applies no twin rule. A price
  # that is null or missing has no quote; one that can't be read is a `Malformed` that names its series (so it isn't
  # taken for an absence), and a card that can't be read at all is a `Malformed` too. Blank lines are skipped.
  #
  # @param path [Pathname, String] the gzip'd JSON Lines file the catalog refresh downloaded
  # @param languages [Array<String>] the languages the catalog holds (`MTG::Scryfall::Source#languages`)
  # @yieldparam record [Prices::Sources::Quote, Prices::Sources::Malformed]
  # @return [Enumerator, nil] an Enumerator when no block is given
  # @raise [Prices::Sources::IntegrityError] before yielding anything, when the file's name carries no date
  # @raise [Zlib::Error] from the reader, when the file is corrupt or cut short; quotes already yielded stay yielded
  def each_quote(path, languages:, &block)
    return enum_for(:each_quote, path, languages:) unless block

    date = reported_on(path)
    allowed = languages.to_set
    File.open(path, "rb") do |file|
      Zlib::GzipReader.wrap(file) do |gzip|
        gzip.each_line { |line| each_card_record(line, allowed, date, &block) }
      end
    end
    nil
  end

  private
    def each_card_record(line, allowed, date)
      return yield(malformed(nil, "the line is not valid UTF-8")) unless line.valid_encoding?
      return if line.strip.empty?

      card = parse(line)
      return yield(card) if card.is_a?(Prices::Sources::Malformed)
      return yield(malformed(nil, "the line is not a JSON object")) unless card.is_a?(Hash)
      return unless allowed.include?(card["lang"]) && MTG::Scryfall::Mapper.paper?(card)

      id = card["id"]
      return yield(malformed(nil, "the card has no id")) unless id.is_a?(String) && !id.strip.empty?

      prices = card["prices"]
      return if prices.nil?
      return yield(malformed(id, "prices is not an object")) unless prices.is_a?(Hash)

      each_price_record(id, prices, date) { |record| yield record }
    end

    def each_price_record(id, prices, date)
      SERIES_BY_KEY.each do |key, series|
        value = prices[key]
        next if value.nil?

        cents = cents_from(value)
        if cents
          yield Prices::Sources::Quote.new(external_key: id, finish: series.finish, currency: series.currency, kind: series.kind, cents:, reported_on: date)
        else
          yield malformed(id, "prices.#{key} #{value.inspect} is not a price of whole cents", series)
        end
      end
    end

    def parse(line)
      JSON.parse(line)
    rescue JSON::ParserError => error
      malformed(nil, "#{error.class}: #{error.message}")
    end

    def malformed(external_key, error, series = nil) = Prices::Sources::Malformed.new(external_key:, error:, series:)

    # Whole cents from the digits of a price string; nil for anything else. No Float: 0.29 * 100 is 28.999…
    def cents_from(value)
      return unless value.is_a?(String) && value.match?(PRICE)

      whole, fraction = value.split(".")
      (whole.to_i * 100) + fraction.to_s.ljust(2, "0").to_i
    end
end
