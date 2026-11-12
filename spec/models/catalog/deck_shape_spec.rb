require "rails_helper"

# Spec 069 decision 1: the deck page's optional panel of a collectible's vocabulary, and the core's nil default.
RSpec.describe Catalog::DeckShape, type: :model do
  let(:zones) { [] }

  def register(type, vocabulary)
    stub_const("ShapeVocabulary#{type.capitalize}", vocabulary)
    Catalog.collecting[type] = "ShapeVocabulary#{type.capitalize}"
  end

  after { %w[answering silent].each { Catalog.collecting.delete(it) } }

  describe ".answer" do
    it "gives the vocabulary's answer, handing it the deck's zones untouched", :aggregate_failures do
      given = nil
      answer = described_class::Answer.new(partial: "p", figures: :f, scope: "s", facts: "t")
      register("answering", Module.new { define_singleton_method(:deck_shape) { |zones| given = zones; answer } })

      expect(described_class.answer("answering", zones)).to eq(answer)
      expect(given).to equal(zones)
    end

    it "gives nil for a type no longer registered" do
      expect(described_class.answer("gone", zones)).to be_nil
    end

    it "gives nil when the vocabulary has no deck_shape" do
      register("silent", Module.new)

      expect(described_class.answer("silent", zones)).to be_nil
    end

    it "gives nil when the vocabulary answers nil" do
      register("answering", Module.new { def self.deck_shape(_zones) = nil })

      expect(described_class.answer("answering", zones)).to be_nil
    end
  end
end
