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

  describe "size results" do
    it "judges a minimum with the true count in every sentence", :aggregate_failures do
      register(sizes: [ size(%w[main], min: 60) ])
      bolt = card("Bolt", 1)
      expect(lines(report(zone("main", "Main", row(bolt, owned: 58))))).to include([ "Short", "Main: 58 cards; tight needs at least 60." ])
      expect(lines(report(zone("main", "Main", row(bolt, owned: 59, proxy: 1))))).to include([ "Pass", "Main: 60 cards; tight needs at least 60." ])
      expect(lines(report(zone("main", "Main", row(bolt, owned: 61))))).to include([ "Pass", "Main: 61 cards; tight needs at least 60." ])
    end

    it "names a rule's zones in its key order and a zone the deck lacks by its key", :aggregate_failures do
      register(sizes: [ size(%w[bench], max: 15), size(%w[lead main], min: 100, max: 100) ])
      zones = [ zone("main", "Main", row(card("A", 1), owned: 98)), zone("lead", "Lead", row(card("B", 2), owned: 1)) ]
      expect(lines(report(*zones))).to start_with([ "Pass", "bench: 0 cards; tight allows at most 15." ], [ "Short", "Lead + Main: 99 cards; tight needs exactly 100." ])
    end

    it "says Over past a maximum and past an exact size, and the singular for one card", :aggregate_failures do
      register(sizes: [ size(%w[bench], max: 15), size(%w[main], min: 1, max: 1) ])
      zones = [ zone("bench", "Bench", row(card("A", 1), owned: 16)), zone("main", "Main", row(card("B", 2), owned: 2)) ]
      expect(lines(report(*zones))).to start_with([ "Over", "Bench: 16 cards; tight allows at most 15." ], [ "Over", "Main: 2 cards; tight needs exactly 1." ])
      expect(lines(report(zone("main", "Main", row(card("B", 2), owned: 1))))).to include([ "Pass", "Main: 1 card; tight needs exactly 1." ])
    end

    it "counts nothing in Considering or an unnamed zone, and passes at exactly the exact size", :aggregate_failures do
      register(sizes: [ size(%w[main], min: 100, max: 100) ])
      zones = [ zone("main", "Main", row(card("A", 1), owned: 100)), zone("considering", "Considering", row(card("B", 2), owned: 30)) ]
      expect(lines(report(*zones)).first).to eq([ "Pass", "Main: 100 cards; tight needs exactly 100." ])
    end

    it "counts nothing in Considering even when a rule names it, and still names it in the subject (decision 3)" do
      register(sizes: [ size(%W[main #{Catalog::Formats::CONSIDERING}], min: 5) ])
      zones = [ zone("main", "Main", row(card("A", 1), owned: 3)), zone(Catalog::Formats::CONSIDERING, "Considering", row(card("B", 2), owned: 10)) ]
      expect(lines(report(*zones)).first).to eq([ "Short", "Main + Considering: 3 cards; tight needs at least 5." ])
    end

    it "separates thousands in a count" do
      register(sizes: [ size(%w[main], min: 60) ])
      expect(lines(report(zone("main", "Main", row(card("A", 1), owned: 1_234)))).first.last).to eq("Main: 1,234 cards; tight needs at least 60.")
    end

    it "leaves out another collectible's cards and zones no rule names", :aggregate_failures do
      register(sizes: [ size(%w[main], min: 1) ])
      zones = [ zone("main", "Main", row(card("Other", 9, type: "stranger"), owned: 5)), zone("stash", "Stash", row(card("A", 1), owned: 7)) ]
      expect(lines(report(*zones)).first).to eq([ "Short", "Main: 0 cards; tight needs at least 1." ])
    end
  end

  describe "copy results" do
    let(:bolt) { card("Lightning Bolt", 1) }

    it "names a card over its limit across zones, printings and owned plus proxy", :aggregate_failures do
      register(copies: copies(%w[main bench], limit(4)))
      zones = [ zone("main", "Main", row(bolt, owned: 3), row(card("Lightning Bolt", 1), proxy: 1)), zone("bench", "Bench", row(bolt, owned: 1)) ]
      expect(lines(report(*zones))).to include([ "Over the limit", "Lightning Bolt: 5 copies; the limit is 4." ])
    end

    it "passes at the limit and counts no copy in an unnamed zone", :aggregate_failures do
      register(copies: copies(%w[main], limit(4)))
      zones = [ zone("main", "Main", row(bolt, owned: 4)), zone("considering", "Considering", row(bolt, owned: 9)) ]
      expect(lines(report(*zones))).to include([ "Pass", "No card is over its limit." ])
    end

    it "counts no copy in Considering even when the rule names it (decision 3)" do
      register(copies: copies(%W[main #{Catalog::Formats::CONSIDERING}], limit(4)))
      zones = [ zone("main", "Main", row(bolt, owned: 3)), zone(Catalog::Formats::CONSIDERING, "Considering", row(bolt, owned: 3)) ]
      expect(lines(report(*zones)).first).to eq([ "Pass", "No card is over its limit." ])
    end

    it "passes at the limit across two named zones (4 of 3 + 1)" do
      register(copies: copies(%w[main bench], limit(4)))
      zones = [ zone("main", "Main", row(bolt, owned: 3)), zone("bench", "Bench", row(bolt, owned: 1)) ]
      expect(lines(report(*zones))).to include([ "Pass", "No card is over its limit." ])
    end

    it "breaks a tie on the lowest limit by the first printing in page order", :aggregate_failures do
      first = card("Black Lotus", 2)
      second = card("Black Lotus", 2)
      answer = ->(entry) { Catalog::DeckChecks::Limit.new(count: 1, reason: entry.equal?(first) ? "restricted to 1" : "banned past 1") }
      register(copies: copies(%w[main], answer))
      expect(lines(report(zone("main", "Main", row(second, owned: 1), row(first, owned: 1))))).to include([ "Over the limit", "Black Lotus: 2 copies; banned past 1." ])
    end

    it "orders two findings of one zone by name, then by identity when the names match", :aggregate_failures do
      register(copies: copies(%w[main], limit(0)))
      zones = [ zone("main", "Main", row(card("Zed", 1), owned: 1), row(card("Abe", 5), owned: 2), row(card("Abe", 2), owned: 1)) ]
      expect(lines(report(*zones)).first(3).map(&:last)).to eq([ "Abe: 1 copy; the limit is 0.", "Abe: 2 copies; the limit is 0.", "Zed: 1 copy; the limit is 0." ])
    end

    it "holds a card to the lowest limit its printings answer, with that reason", :aggregate_failures do
      one = card("Black Lotus", 2)
      two = card("Black Lotus", 2)
      answer = ->(entry) { entry.equal?(one) ? Catalog::DeckChecks::Limit.new(count: 4, reason: nil) : Catalog::DeckChecks::Limit.new(count: 1, reason: "restricted to 1") }
      register(copies: copies(%w[main], answer))
      expect(lines(report(zone("main", "Main", row(one, owned: 1), row(two, owned: 1))))).to include([ "Over the limit", "Black Lotus: 2 copies; restricted to 1." ])
    end

    it "treats nil as above every number: unlimited only when every printing says nil", :aggregate_failures do
      free = card("Plains", 3)
      mixed = card("Plains", 3)
      register(copies: copies(%w[main], ->(entry) { Catalog::DeckChecks::Limit.new(count: 4, reason: nil) unless entry.equal?(free) }))
      expect(lines(report(zone("main", "Main", row(free, owned: 20))))).to include([ "Pass", "No card is over its limit." ])
      expect(lines(report(zone("main", "Main", row(free, owned: 3), row(mixed, owned: 2))))).to include([ "Over the limit", "Plains: 5 copies; the limit is 4." ])
    end

    it "orders findings by first zone, then name, then identity; leaves out another collectible", :aggregate_failures do
      register(copies: copies(%w[main bench], limit(1)))
      zones = [ zone("main", "Main", row(card("Zed", 1), owned: 2)), zone("bench", "Bench", row(card("Abe", 2), owned: 2), row(card("Other", 3, type: "stranger"), owned: 9)) ]
      expect(lines(report(*zones)).map(&:last)).to start_with("Zed: 2 copies; the limit is 1.", "Abe: 2 copies; the limit is 1.")
      expect(lines(report(*zones)).map(&:last)).not_to include(a_string_matching(/Other/))
    end

    it "says the singular for one copy" do
      register(copies: copies(%w[main], limit(0)))
      expect(lines(report(zone("main", "Main", row(bolt, owned: 1))))).to include([ "Over the limit", "Lightning Bolt: 1 copy; the limit is 0." ])
    end
  end
end
