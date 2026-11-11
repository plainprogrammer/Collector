require "rails_helper"

# Spec 065 decision 2: the options of a location select, one rendering for every picker and the filter.
RSpec.describe LocationChoicesHelper, type: :helper do
  let(:account) { create(:user).account }

  def options_of(html) = Nokogiri::HTML5.fragment("<select>#{html}</select>")

  it "is flat with no deck: the leading options then the places", :aggregate_failures do
    create(:location, account:, name: "Box")
    html = options_of(helper.location_options(Location::Choices.new(account), leading: [ [ "No location", "" ] ]))
    expect(html.css("optgroup")).to be_empty
    expect(html.css("option").map(&:text)).to eq([ "No location", "Box" ])
  end

  it "groups Places then Decks, the leading options outside any group, zones as Deck › Zone", :aggregate_failures do
    create(:location, account:, name: "Box")
    deck = create(:deck, account:, name: "Izzet Tempo")
    html = options_of(helper.location_options(Location::Choices.new(account), selected: deck.zone("main").id.to_s, leading: [ [ "No location", "" ] ]))
    expect(html.css("select > option").map(&:text)).to eq([ "No location" ])
    expect(html.css("optgroup").map { it["label"] }).to eq(%w[Places Decks])
    expect(html.css('optgroup[label="Decks"] option').map(&:text)).to eq(deck.zones.map { "Izzet Tempo › #{it.name}" })
    expect(html.at_css("option[selected]").text).to eq("Izzet Tempo › Main")
  end

  it "omits the Places group when there is no place", :aggregate_failures do
    create(:deck, account:)
    html = options_of(helper.location_options(Location::Choices.new(account)))
    expect(html.css("optgroup").map { it["label"] }).to eq([ "Decks" ])
  end

  it "adds each deck's all-zones option first, valued deck:<id>, only for the filter", :aggregate_failures do
    deck = create(:deck, account:, name: "Izzet Tempo")
    plain = options_of(helper.location_options(Location::Choices.new(account)))
    all = options_of(helper.location_options(Location::Choices.new(account), deck_values: true))
    expect(plain.css("option").map(&:text)).not_to include("Izzet Tempo (all zones)")
    expect(all.css("optgroup[label=Decks] option").first.text).to eq("Izzet Tempo (all zones)")
    expect(all.css("optgroup[label=Decks] option").first["value"]).to eq("deck:#{deck.location_id}")
  end

  it "leaves out the except id and a deck left with no zone, and escapes names", :aggregate_failures do
    deck = create(:deck, account:, name: "A <b>&\" deck")
    html = options_of(helper.location_options(Location::Choices.new(account), except: deck.zone("main").id))
    expect(html.css("option").map(&:text)).not_to include("A <b>&\" deck › Main")
    expect(html.css("option").map(&:text)).to include("A <b>&\" deck › Sideboard")
    expect(html.css("b")).to be_empty
  end
end
