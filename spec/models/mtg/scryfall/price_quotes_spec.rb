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
end
