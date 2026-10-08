require "rails_helper"

RSpec.describe MTG::Art::Evidence, type: :model do
  let(:bolt) { create(:catalog_identity, name: "Lightning Bolt") }
  let(:plains) { create(:catalog_identity, name: "Plains") }

  def artwork(id, identity:, printings: 1, **entry)
    entries = Array.new(printings) do |i|
      create(:mtg_printing, illustration_id: id, entry: create(:catalog_entry, identity:, released_on: Date.new(2000 + i, 1, 1), **entry)).entry
    end
    create(:mtg_artwork, illustration_id: id, entry: entries.first)
    entries
  end

  def sent(*pairs) = pairs.map { |id, distance| MTG::Art::Sent::Artwork.new(id:, distance:) }

  def evidence(*pairs, text: []) = described_class.new(sent(*pairs), text_identity_ids: text, margin: 300)

  it "keeps only artworks in the table that have English card printings, nearest first (glossary)", :aggregate_failures do
    near = artwork("a" * 8 + "-0000-4000-8000-000000000001", identity: bolt, printings: 2)
    artwork("b" * 8 + "-0000-4000-8000-000000000002", identity: bolt, kind: "art_card")
    create(:mtg_printing, illustration_id: "c" * 8 + "-0000-4000-8000-000000000003") # not in the artwork table

    usable = evidence([ "c" * 8 + "-0000-4000-8000-000000000003", 10 ], [ "b" * 8 + "-0000-4000-8000-000000000002", 20 ],
      [ "a" * 8 + "-0000-4000-8000-000000000001", 150 ]).usable

    expect(usable.map(&:id)).to eq([ "a" * 8 + "-0000-4000-8000-000000000001" ])
    expect(usable.first).to have_attributes(distance: 150, identity_id: bolt.id, printings: near.reverse)
  end

  it "is confident at or below the margin, and says so for the nearest usable artwork only", :aggregate_failures do
    artwork("a" * 8 + "-0000-4000-8000-000000000001", identity: bolt)
    expect(evidence([ "a" * 8 + "-0000-4000-8000-000000000001", 300 ]).confident).to be_present
    expect(evidence([ "a" * 8 + "-0000-4000-8000-000000000001", 301 ]).confident).to be_nil
  end

  it "gives a two-card artwork to the text candidate with the best name rank, or drops it (glossary)", :aggregate_failures do
    shared = "d" * 8 + "-0000-4000-8000-000000000004"
    artwork(shared, identity: bolt)
    create(:mtg_printing, illustration_id: shared, entry: create(:catalog_entry, identity: plains))
    other = "e" * 8 + "-0000-4000-8000-000000000005"
    artwork(other, identity: plains)

    expect(evidence([ shared, 150 ], [ other, 200 ], text: [ plains.id, bolt.id ]).usable.map(&:identity_id)).to eq([ plains.id, plains.id ])
    without = evidence([ shared, 150 ], [ other, 200 ], text: [])
    expect(without.usable.map(&:id)).to eq([ other ])
    expect(without.confident).to have_attributes(id: other, identity_id: plains.id)
  end

  it "keeps each card's smallest distance" do
    artwork("a" * 8 + "-0000-4000-8000-000000000001", identity: bolt)
    artwork("f" * 8 + "-0000-4000-8000-000000000006", identity: bolt)
    distances = evidence([ "a" * 8 + "-0000-4000-8000-000000000001", 340 ], [ "f" * 8 + "-0000-4000-8000-000000000006", 320 ]).card_distances
    expect(distances).to eq(bolt.id => 320)
  end
end
