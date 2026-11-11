# spec/models/collection_import/decks_spec.rb
require "rails_helper"

# Spec 062 AC-7.1 to AC-7.3: what applying a file would do with the collector's decks (replace by comparison key, as places).
RSpec.describe CollectionImport::Decks, type: :model do
  def held(id, name, type: "mtg", format: "modern") = described_class::Held.new(id:, name:, key: Location::Name.key(name), collectible_type: type, format:)

  def entry(name, type: "mtg", format: "modern") = described_class::Entry.new(name:, collectible_type: type, format:)

  def outcomes(held_decks, file_decks) = described_class.new(held_decks.each_with_index.map { |(name, options), index| held(index + 1, name, **(options || {})) }, file_decks)

  it "adds, renames, changes the format of, keeps and removes by comparison key (AC-7.2)", :aggregate_failures do
    result = outcomes([ [ "Trade deck" ], [ "izzet tempo" ], [ "Old deck" ], [ "Elves", { format: "commander" } ] ],
      [ entry("Blue deck"), entry("Izzet Tempo"), entry("Trade deck"), entry("Elves", format: "casual") ])

    expect(result.added.map(&:name)).to eq([ "Blue deck" ])
    expect(result.renamed.map { |renamed| [ renamed.held.name, renamed.name ] }).to eq([ [ "izzet tempo", "Izzet Tempo" ] ])
    expect(result.format_changed.map { |changed| [ changed.held.name, changed.held.format, changed.format ] }).to eq([ %w[Elves commander casual] ])
    expect(result.unchanged).to eq(1)
    expect(result.removed.map(&:name)).to eq([ "Old deck" ])
    expect(result.counts).to eq(added: 1, renamed: 1, format_changed: 1, unchanged: 1, removed: 1)
    expect([ result.counted?, result.nothing_to_change?, result.removes? ]).to eq([ true, false, true ])
  end

  it "counts a deck renamed and format-changed in both lists, keeping the held deck's id (AC-7.2)", :aggregate_failures do
    result = outcomes([ [ "elves" ] ], [ entry("Elves", format: "pauper") ])

    expect(result.renamed.map { |renamed| [ renamed.held.id, renamed.name ] }).to eq([ [ 1, "Elves" ] ])
    expect(result.format_changed.map { |changed| [ changed.held.id, changed.collectible_type, changed.format ] }).to eq([ [ 1, "mtg", "pauper" ] ])
    expect([ result.added, result.removed, result.unchanged ]).to eq([ [], [], 0 ])
  end

  it "reads a changed collectible type as a change of format (AC-7.2)" do
    result = outcomes([ [ "Elves" ] ], [ entry("Elves", type: "other") ])

    expect(result.format_changed.map { |changed| [ changed.collectible_type, changed.format ] }).to eq([ %w[other modern] ])
  end

  it "removes every held deck for a file with none (AC-7.2)", :aggregate_failures do
    result = outcomes([ [ "a" ], [ "b" ] ], [])

    expect(result.removed.map(&:name)).to eq(%w[a b])
    expect(result.counts).to eq(added: 0, renamed: 0, format_changed: 0, unchanged: 0, removed: 2)
  end

  it "has nothing to change when the decks are the held ones, in any order" do
    expect(outcomes([ [ "Box" ], [ "Binder" ] ], [ entry("Binder"), entry("Box") ]).nothing_to_change?).to be(true)
  end

  it "counts nothing and has nothing to change for a file that says nothing of decks, whatever is held (AC-7.4)", :aggregate_failures do
    result = outcomes([ [ "Izzet Tempo" ] ], nil)

    expect([ result.counted?, result.nothing_to_change?, result.removes? ]).to eq([ false, true, false ])
    expect([ result.added, result.renamed, result.format_changed, result.removed, result.unchanged ]).to eq([ [], [], [], [], 0 ])
  end

  it "orders each list by comparison key then name, in code-point order" do
    result = outcomes([], [ entry("box"), entry("Binder 2"), entry("Éclair"), entry("Binder 10") ])

    expect(result.added.map(&:name)).to eq([ "Binder 10", "Binder 2", "box", "Éclair" ])
  end

  it "lists the first LIST_LIMIT of each list and counts the rest" do
    result = outcomes(Array.new(CollectionImport::LIST_LIMIT + 2) { |n| [ "Deck #{n}" ] }, [])

    expect([ result.listed_removed.size, result.more_removed ]).to eq([ CollectionImport::LIST_LIMIT, 2 ])
  end

  it "takes from the decks, for the plan's fingerprint, what a change is and no id (AC-7.10)", :aggregate_failures do
    result = outcomes([ [ "izzet" ], [ "Old" ], [ "Elves" ] ], [ entry("Izzet"), entry("New"), entry("Elves", format: "casual") ])

    expect(result.fingerprint_part).to eq([ %w[New], [ %w[izzet Izzet] ], [ [ "Elves", "mtg", "modern", "mtg", "casual" ] ], [ [ "Old" ] ] ])
    expect(result.fingerprint_part.flatten).not_to include(1, 2, 3)
  end
end
