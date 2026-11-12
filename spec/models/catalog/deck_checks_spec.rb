require "rails_helper"

RSpec.describe Catalog::DeckChecks, type: :model do
  def zone(key, name, *rows)
    location = Struct.new(:zone, :name).new(key, name)
    Deck::Page::Zone.new(location:, groups: rows.empty? ? [] : [ Deck::Page::Group.new(name: nil, rows:) ])
  end

  def card(name, id, type: "game")
    build_stubbed(:catalog_entry, identity: build_stubbed(:catalog_identity, id:, name:), name:, collectible_type: type)
  end

  def row(entry, owned: 0, proxy: 0)
    lines = proxy.zero? ? [] : [ Deck::Page::Line.new(id: 1, finish: "nonfoil", quantity: proxy) ]
    Deck::Page::Row.new(entry:, owned:, lines:, answer: Catalog::DeckCards::NONE)
  end

  def size(keys, min: nil, max: nil) = Catalog::DeckChecks::SizeRule.new(zone_keys: keys, min:, max:)
  def limit(count, reason = nil) = ->(_entry) { Catalog::DeckChecks::Limit.new(count:, reason:) }
  def copies(keys, limit_for) = Catalog::DeckChecks::CopyRule.new(zone_keys: keys, limit_for:)

  def register(sizes: [], copies: nil)
    rules = Catalog::DeckChecks::Rules.new(sizes:, copies:)
    stub_const("GameVocabulary", Module.new { define_singleton_method(:deck_rules) { |_key| rules } })
    Catalog.collecting["game"] = "GameVocabulary"
  end

  def report(*zones) = described_class.report("game", "tight", zones)
  def lines(report) = report.lines.map { [ it.status, it.sentence ] }

  after { Catalog.collecting.delete("game") }

  describe ".report with no rules" do
    it "says the format has no rules and still runs owned-plus-proxy", :aggregate_failures do
      result = described_class.report("game", "tight", [ zone("main", "Main", row(card("Bolt", 1), owned: 2, proxy: 1)) ])
      expect(lines(result)).to eq([ [ nil, "tight has no rules to check." ], [ "Owned and proxy", "Bolt in Main: 2 owned, 1 proxy." ] ])
      expect([ result.lines.first.fault, result.summary ]).to eq([ false, "1 finding" ])
    end

    it "treats a missing method, a nil answer and an unregistered type alike (AC-5.5)", :aggregate_failures do
      stub_const("SilentVocabulary", Module.new)
      stub_const("NilVocabulary", Module.new { def self.deck_rules(_key) = nil })
      expected = [ [ nil, "tight has no rules to check." ], [ "Pass", "No card has both owned copies and proxies in one zone." ] ]
      %w[SilentVocabulary NilVocabulary].each do |vocabulary|
        Catalog.collecting["game"] = vocabulary
        expect(lines(described_class.report("game", "tight", []))).to eq(expected)
      end
      expect(described_class.report("gone", "tight", []).summary).to eq("No findings")
    end
  end

  describe "owned-plus-proxy results" do
    let(:bolt) { card("Lightning Bolt", 1) }

    it "flags a zone that holds both, across printings, naming the split", :aggregate_failures do
      result = report(zone("main", "Main", row(bolt, owned: 2), row(card("Lightning Bolt", 1), proxy: 1)))
      expect(lines(result)).to include([ "Owned and proxy", "Lightning Bolt in Main: 2 owned, 1 proxy." ])
      expect(result.faults).to eq(1)
    end

    it "judges each zone alone, includes zones no rule names, and skips Considering's lone proxy", :aggregate_failures do
      zones = [ zone("main", "Main", row(bolt, owned: 1), row(bolt, proxy: 1)), zone("stash", "Stash", row(bolt, owned: 2, proxy: 3)),
                zone("considering", "Considering", row(bolt, proxy: 1)) ]
      sentences = lines(report(*zones)).map(&:last)
      expect(sentences).to include("Lightning Bolt in Main: 1 owned, 1 proxy.", "Lightning Bolt in Stash: 2 owned, 3 proxy.")
      expect(sentences).not_to include(a_string_matching(/Considering/))
    end

    it "does not flag owned only, proxy only, owned in one zone with a proxy in another, or another collectible", :aggregate_failures do
      stray = card("Other", 9, type: "stranger")
      zones = [ zone("main", "Main", row(bolt, owned: 2)), zone("considering", "Considering", row(bolt, proxy: 1), row(stray, owned: 1, proxy: 1)) ]
      expect(lines(report(*zones)).last).to eq([ "Pass", "No card has both owned copies and proxies in one zone." ])
    end

    it "delimits the split's numbers as the deck page's heads do", :aggregate_failures do
      result = report(zone("main", "Main", row(bolt, owned: 1_234, proxy: 5_678)))
      expect(lines(result)).to include([ "Owned and proxy", "Lightning Bolt in Main: 1,234 owned, 5,678 proxy." ])
    end

    it "orders findings by zone, then name, then identity", :aggregate_failures do
      zones = [ zone("a", "Alpha", row(card("Zed", 1), owned: 1, proxy: 1), row(card("Abe", 2), owned: 1, proxy: 1)), zone("b", "Beta", row(card("Abe", 2), owned: 1, proxy: 1)) ]
      expect(lines(report(*zones)).drop(1).map(&:last)).to eq([ "Abe in Alpha: 1 owned, 1 proxy.", "Zed in Alpha: 1 owned, 1 proxy.", "Abe in Beta: 1 owned, 1 proxy." ])
    end
  end
end
