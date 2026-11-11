require "rails_helper"

# Spec 068 AC-1.5, AC-1.8, AC-1.9: the add page's form parses text and puts a sentence on the field it belongs to.
RSpec.describe Deck::Proxy::Addition, type: :model do
  let(:account) { create(:user).account }
  let(:deck) { create(:deck, account:) }
  let(:entry) { create(:mtg_printing).entry }

  def addition(**attrs) = described_class.new(account:, zone: deck.zone("main"), entry:, finish: "foil", quantity: "2", **attrs)

  it "saves a valid add and exposes the proxy", :aggregate_failures do
    form = addition

    expect(form.save).to be(true)
    expect(form.proxy.quantity).to eq(2)
  end

  it "reads the quantity as whole text from 1 to 9,999 (AC-1.8)", :aggregate_failures do
    [ "", "0", "-1", "2.5", "abc", "10000", " " ].each do |text|
      form = addition(quantity: text)

      expect(form.save).to be(false), text.inspect
      expect(form.errors[:quantity]).to eq([ "Enter a number from 1 to 9,999." ])
    end
    expect(Deck::Proxy.count).to eq(0)
  end

  it "puts the finish sentences on :finish (AC-1.8)", :aggregate_failures do
    expect(addition(finish: "").tap(&:save).errors[:finish]).to eq([ "Choose a finish." ])
    expect(addition(finish: "etched").tap(&:save).errors[:finish]).to eq([ "That finish isn't available for this printing." ])
  end

  it "puts the cap sentence on :quantity and keeps the proxy as it was (AC-1.9)", :aggregate_failures do
    addition(quantity: "9990").save
    form = addition(quantity: "10")

    expect(form.save).to be(false)
    expect(form.errors[:quantity]).to eq([ Deck::Proxy::FULL_MESSAGE ])
    expect(Deck::Proxy.pick(:quantity)).to eq(9_990)
  end
end
