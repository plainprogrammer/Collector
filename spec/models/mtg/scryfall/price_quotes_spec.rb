require "rails_helper"

RSpec.describe MTG::Scryfall::PriceQuotes, type: :model do
  subject(:source) { described_class.new }

  let(:dir) { Pathname(Dir.mktmpdir) }

  after { FileUtils.rm_rf(dir) }

  def write_file(cards, name: "default-cards-20261113100623.jsonl.gz")
    dir.join(name).tap { |path| path.binwrite(gzip_jsonl(cards)) }
  end

  def read(cards, languages: [ "en" ], name: "default-cards-20261113100623.jsonl.gz")
    source.each_quote(write_file(cards, name:), languages:).to_a
  end

  def series(finish, currency) = Prices::Sources::Series.new(finish:, currency:, kind: "market")

  describe "its declaration (spec 085 decisions 5 and 10, AC-2.11)" do
    it "names Scryfall, with an attribution that says where each price comes from", :aggregate_failures do
      expect(described_class.key).to eq("scryfall")
      expect(described_class.collectible_type).to eq("mtg")
      expect(described_class.title).to eq("Scryfall")
      expect(described_class.attribution_url).to eq("https://scryfall.com")
      expect(described_class.attribution).to include("Scryfall", "TCGplayer's market price", "Cardmarket", "once a day")
    end

    it "quotes six series of kind market, with the finish names the collectible's vocabulary uses", :aggregate_failures do
      expect(described_class.series).to eq([ series("nonfoil", "USD"), series("foil", "USD"), series("etched", "USD"),
                                             series("nonfoil", "EUR"), series("foil", "EUR"), series("etched", "EUR") ])
      expect(MTG::Collecting.finish_order).to include(*described_class.series.map(&:finish))
    end
  end

  describe "#reported_on (spec 085 decision 4, AC-2.4)" do
    it "takes the day from the timestamp in the file's name, for a file with no cards too", :aggregate_failures do
      {
        "default-cards-20261113100623.jsonl.gz" => Date.new(2026, 11, 13),
        "all-cards-20261112235959.jsonl.gz" => Date.new(2026, 11, 12)
      }.each do |name, date|
        expect(source.reported_on(write_file([], name:))).to eq(date)
      end
    end

    it "refuses a name with no timestamp, or whose digits are not a date", :aggregate_failures do
      %w[cards.jsonl.gz default-cards-20261113.jsonl.gz default-cards-20261340100623.jsonl.gz].each do |name|
        expect { source.reported_on(dir.join(name)) }.to raise_error(Prices::Sources::IntegrityError, /#{Regexp.escape(name)}/)
      end
    end
  end

  describe "#each_quote (spec 085 decisions 5 and 6)" do
    let(:all_prices) do
      { "usd" => "1.42", "usd_foil" => "3.10", "usd_etched" => "5.00", "eur" => "1.20", "eur_foil" => "2.55", "eur_etched" => "4.10" }
    end

    it "yields a quote for each of the six prices, dated by the file (AC-2.1, AC-2.4)", :aggregate_failures do
      quotes = read([ scryfall_card("id" => "card-1", "prices" => all_prices) ])

      expect(quotes).to all(be_a(Prices::Sources::Quote))
      expect(quotes.map { |quote| [ quote.finish, quote.currency, quote.cents ] }).to eq(
        [ [ "nonfoil", "USD", 142 ], [ "foil", "USD", 310 ], [ "etched", "USD", 500 ], [ "nonfoil", "EUR", 120 ], [ "foil", "EUR", 255 ], [ "etched", "EUR", 410 ] ]
      )
      expect(quotes.map(&:external_key).uniq).to eq([ "card-1" ])
      expect(quotes.map(&:kind).uniq).to eq([ "market" ])
      expect(quotes.map(&:reported_on).uniq).to eq([ Date.new(2026, 11, 13) ])
    end

    it "takes each quote's day from the file's name (AC-2.4)" do
      quotes = read([ scryfall_card("prices" => { "usd" => "1.00" }) ], name: "all-cards-20261112235959.jsonl.gz")

      expect(quotes.map(&:reported_on)).to eq([ Date.new(2026, 11, 12) ])
    end

    it "yields a quote only for a price that is there, and no Malformed for one that isn't (AC-2.2)", :aggregate_failures do
      cards = [ scryfall_card("id" => "a", "prices" => { "usd" => nil, "usd_foil" => "2.00" }), scryfall_card("id" => "b", "prices" => {}),
                scryfall_card("id" => "c").except("prices"), scryfall_card("id" => "d", "prices" => nil) ]
      records = read(cards)

      expect(records.map { |record| [ record.class, record.external_key, record.finish ] }).to eq([ [ Prices::Sources::Quote, "a", "foil" ] ])
    end

    it "leaves out tix and a key it doesn't know (AC-2.3)" do
      expect(read([ scryfall_card("prices" => { "tix" => "0.03", "usd_gold" => "9.00" }) ])).to eq([])
    end

    it "leaves out a card that is not a paper printing or not in a requested language (AC-2.5)", :aggregate_failures do
      cards = [ scryfall_card("id" => "digital", "digital" => true), scryfall_card("id" => "no-paper", "games" => [ "mtgo" ]),
                scryfall_card("id" => "ja", "lang" => "ja"), scryfall_card("id" => "en") ]

      expect(read(cards).map(&:external_key)).to eq([ "en" ])
      expect(read(cards, languages: [ "en", "ja" ]).map(&:external_key)).to eq([ "ja", "en" ])
    end

    it "turns a price into cents from its digits, never through a float (AC-2.6)" do
      prices = { "0.05" => 5, "10" => 1000, "1234.5" => 123_450, "0.00" => 0, "0.29" => 29, "999999999.99" => 99_999_999_999 }
      cards = prices.keys.each_with_index.map { |value, index| scryfall_card("id" => "c#{index}", "prices" => { "usd" => value }) }

      expect(read(cards).map(&:cents)).to eq(prices.values)
    end

    it "yields a Malformed that names the series for a price it can't read, and goes on with the card's others (AC-2.6)", :aggregate_failures do
      bad = [ "1.234", "-1", "+1", "abc", "", "1,42", ".5", "1.", " 1.42", "1e2", "1234567890.00", 1.42 ]
      cards = bad.each_with_index.map { |value, index| scryfall_card("id" => "c#{index}", "prices" => { "usd" => value, "usd_foil" => "2.00" }) }
      records = read(cards)

      malformed = records.grep(Prices::Sources::Malformed)
      expect(malformed.map(&:external_key)).to eq(bad.each_index.map { |index| "c#{index}" })
      expect(malformed.map(&:series).uniq).to eq([ series("nonfoil", "USD") ])
      expect(malformed.map(&:error)).to all(include("prices.usd"))
      expect(records.grep(Prices::Sources::Quote).map(&:cents)).to all(eq(200))
      expect(records.grep(Prices::Sources::Quote).size).to eq(bad.size)
    end

    it "yields a Malformed for a line it can't read as a card, and goes on (AC-2.7)", :aggregate_failures do
      lines = [ "not json", scryfall_card("id" => "x").except("id"), scryfall_card("id" => "c3", "prices" => "oops"), "",
                scryfall_card("digital" => true, "games" => [ "mtgo" ]).except("id"), scryfall_card("id" => "good", "prices" => { "usd" => "1.00" }) ]
      records = read(lines)

      expect(records.map(&:class)).to eq([ Prices::Sources::Malformed ] * 3 + [ Prices::Sources::Quote ])
      expect(records.first(3).map { |record| [ record.external_key, record.series ] }).to eq([ [ nil, nil ], [ nil, nil ], [ "c3", nil ] ])
      expect(records.last.external_key).to eq("good")
    end
  end
end
