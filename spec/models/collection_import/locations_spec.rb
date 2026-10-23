# spec/models/collection_import/locations_spec.rb
require "rails_helper"

# Spec 029 decision 10: what applying a file would do with the collector's locations (replace by comparison key).
RSpec.describe CollectionImport::Locations, type: :model do
  def held(id, name) = described_class::Held.new(id:, name:, key: Location::Name.key(name))

  def outcomes(held_names, file_names) = described_class.new(held_names.each_with_index.map { |name, index| held(index + 1, name) }, file_names)

  it "adds, renames, keeps and removes by comparison key (AC-8.2)", :aggregate_failures do
    result = outcomes([ "Trade binder", "box", "Old crate" ], [ "Blue binder", "Box", "Trade binder" ])

    expect(result.added).to eq([ "Blue binder" ])
    expect(result.renamed.map { |renamed| [ renamed.held.name, renamed.name ] }).to eq([ %w[box Box] ])
    expect(result.unchanged).to eq(1)
    expect(result.removed.map(&:name)).to eq([ "Old crate" ])
    expect(result.counts).to eq(added: 1, renamed: 1, unchanged: 1, removed: 1)
    expect([ result.counted?, result.nothing_to_change?, result.removes? ]).to eq([ true, false, true ])
  end

  it "removes every held location for a file with none (AC-8.3)", :aggregate_failures do
    result = outcomes(%w[a b c], [])

    expect(result.removed.map(&:name)).to eq(%w[a b c])
    expect(result.counts).to eq(added: 0, renamed: 0, unchanged: 0, removed: 3)
  end

  it "has nothing to change when the names are the held ones, in any order" do
    expect(outcomes(%w[Box Binder], %w[Binder Box]).nothing_to_change?).to be(true)
  end

  it "matches a name in another case or form to the held location, and keeps a held NFC spelling unchanged (AC-9.18)", :aggregate_failures do
    result = outcomes([ "Café" ], [ "Café" ]) # the reader normalises each file name, so NFD arrives here as NFC
    expect(result.unchanged).to eq(1)

    renamed = outcomes([ "Café" ], [ "CAFÉ" ])
    expect(renamed.renamed.map(&:name)).to eq([ "CAFÉ" ])
    expect(renamed.added).to eq([])
  end

  it "says nothing for a version 1 file, whatever is held (AC-8.4)", :aggregate_failures do
    result = outcomes(%w[a b], nil)

    expect(result.counted?).to be(false)
    expect([ result.added, result.renamed, result.removed, result.unchanged ]).to eq([ [], [], [], 0 ])
    expect([ result.nothing_to_change?, result.removes? ]).to eq([ true, false ])
  end

  it "lists the first 100 renamed and removed, in the page's order, and counts the rest (AC-8.9)", :aggregate_failures do
    held_names = (1..300).map { |number| format("old %03d", number) }
    file = (1..150).map { |number| format("OLD %03d", number) } # 150 renamed by case, 150 removed
    result = outcomes(held_names, file)

    expect(result.renamed.size).to eq(150)
    expect(result.removed.size).to eq(150)
    expect(result.listed_renamed.size).to eq(100)
    expect(result.more_renamed).to eq(50)
    expect(result.listed_removed.map(&:name).first(2)).to eq([ "old 151", "old 152" ])
    expect(result.more_removed).to eq(50)
  end

  it "gives the part of a fingerprint from what changes, by name and holding no id, and nothing for unchanged ones (decision 11, ruled 2026-10-21)", :aggregate_failures do
    part = outcomes([ "box", "Old crate", "Same" ], %w[Box Same New]).fingerprint_part

    expect(part).to eq([ [ "New" ], [ %w[box Box] ], [ [ "Old crate" ] ] ])
    expect(outcomes([ "box", "Old crate", "Same" ], %w[Box Same New]).fingerprint_part).to eq(
      described_class.new([ held(7, "box"), held(8, "Old crate"), held(9, "Same") ], %w[Box Same New]).fingerprint_part) # other ids, the same part
  end
end
