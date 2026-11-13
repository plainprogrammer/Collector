require "rails_helper"

RSpec.describe Prices::Sources, type: :model do
  let(:series) { described_class::Series.new(finish: "plain", currency: "USD", kind: "market") }
  let(:reported_on) { Date.new(2026, 11, 13) }

  describe "::Series (spec 085 decisions 1 and 2)" do
    it "refuses a blank finish or kind and a currency that is not three upper-case letters (AC-1.2)", :aggregate_failures do
      expect { described_class::Series.new(finish: " ", currency: "USD", kind: "market") }.to raise_error(ArgumentError, /finish/)
      expect { described_class::Series.new(finish: "plain", currency: "USD", kind: "") }.to raise_error(ArgumentError, /kind/)
      expect { described_class::Series.new(finish: "plain", currency: "usd", kind: "market") }.to raise_error(ArgumentError, /currency/)
      expect { described_class::Series.new(finish: "plain", currency: "USDX", kind: "market") }.to raise_error(ArgumentError, /currency/)
    end

    it "is equal to another with the same parts, so it can key a hash" do
      expect({ series => :row }[described_class::Series.new(finish: "plain", currency: "USD", kind: "market")]).to eq(:row)
    end
  end

  describe "::Quote (spec 085 decision 2, AC-1.5)" do
    let(:arguments) { { external_key: "abc-1", finish: "plain", currency: "USD", kind: "market", cents: 142, reported_on: } }

    it "offers its series" do
      expect(described_class::Quote.new(**arguments).series).to eq(series)
    end

    it "refuses each invalid argument", :aggregate_failures do
      [ { external_key: "" }, { external_key: nil }, { finish: " " }, { kind: "" }, { currency: "usd" }, { cents: -1 },
        { cents: 1.5 }, { cents: "142" }, { reported_on: "2026-11-13" }, { reported_on: nil } ].each do |invalid|
        expect { described_class::Quote.new(**arguments, **invalid) }.to raise_error(ArgumentError), "expected #{invalid} to be refused"
      end
    end

    it "accepts a price of zero cents" do
      expect(described_class::Quote.new(**arguments, cents: 0).cents).to eq(0)
    end
  end

  describe "::Malformed" do
    it "carries the series of a price the source could not read, and none for a line it could not read", :aggregate_failures do
      expect(described_class::Malformed.new(external_key: "abc-1", error: "unreadable", series:).series).to eq(series)
      expect(described_class::Malformed.new(external_key: nil, error: "not JSON").series).to be_nil
    end
  end

  describe ".verify! (spec 085 decision 1, AC-1.1, AC-1.2)" do
    it "returns a class that provides every member" do
      expect(described_class.verify!(FakePriceSource)).to eq(FakePriceSource)
    end

    it "refuses a member that is wrong and names it", :aggregate_failures do
      {
        key: "Bad Key", collectible_type: " ", title: "", attribution: nil, attribution_url: "http://prices.example.test",
        hosted_paid_allowed?: nil, series: []
      }.each do |member, value|
        expect { described_class.verify!(FakePriceSource.with(member => value)) }
          .to raise_error(described_class::ConfigurationError, /#{Regexp.escape(member.to_s)}/), "expected #{member}: #{value.inspect} to be refused"
      end
    end

    it "refuses a key that is blank, upper case or has a character outside a-z, 0-9 and underscore", :aggregate_failures do
      [ "", "UPPER", "with-dash", "with space" ].each do |key|
        expect { described_class.verify!(FakePriceSource.with(key:)) }.to raise_error(described_class::ConfigurationError, /key/), "expected #{key.inspect} to be refused"
      end
    end

    it "refuses an address that is not an https URL, a series list with a repeat, and a series that is not a Series", :aggregate_failures do
      expect { described_class.verify!(FakePriceSource.with(attribution_url: "not a url")) }.to raise_error(described_class::ConfigurationError, /attribution_url/)
      expect { described_class.verify!(FakePriceSource.with(series: [ series, series ])) }.to raise_error(described_class::ConfigurationError, /series/)
      expect { described_class.verify!(FakePriceSource.with(series: [ "plain" ])) }.to raise_error(described_class::ConfigurationError, /series/)
    end

    it "accepts no address" do
      expect(described_class.verify!(FakePriceSource.with(attribution_url: nil))).to be_a(Class)
    end

    it "refuses a class that lacks a class member or an instance method", :aggregate_failures do
      expect { described_class.verify!(Class.new { def self.key = "x" }) }.to raise_error(described_class::ConfigurationError, /collectible_type/)
      expect { described_class.verify!(Class.new(FakePriceSource) { undef_method :each_quote }) }.to raise_error(described_class::ConfigurationError, /each_quote/)
      expect { described_class.verify!(Class.new(FakePriceSource) { undef_method :reported_on }) }.to raise_error(described_class::ConfigurationError, /reported_on/)
    end
  end

  describe "the contract shown by a fake source (AC-1.4)" do
    let(:quote) { described_class::Quote.new(external_key: "abc-1", finish: "plain", currency: "USD", kind: "market", cents: 142, reported_on:) }
    let(:records) { [ quote, described_class::Malformed.new(external_key: "abc-2", error: "unreadable", series:), described_class::Malformed.new(external_key: nil, error: "not JSON") ] }

    it "yields its records to a block, and as an enumerator without one", :aggregate_failures do
      source = FakePriceSource.new(records:)
      yielded = []
      source.each_quote("any.file", languages: [ "en" ]) { |record| yielded << record }

      expect(yielded).to eq(records)
      expect(source.each_quote("any.file", languages: [ "en" ])).to be_an(Enumerator)
      expect(source.each_quote("any.file", languages: [ "en" ]).to_a).to eq(records)
    end

    it "answers the day its data is from, or raises IntegrityError", :aggregate_failures do
      expect(FakePriceSource.new.reported_on("any.file")).to eq(reported_on)
      expect { FakePriceSource.new(reported_on: described_class::IntegrityError.new("no date")).reported_on("any.file") }
        .to raise_error(described_class::IntegrityError, "no date")
    end
  end
end
