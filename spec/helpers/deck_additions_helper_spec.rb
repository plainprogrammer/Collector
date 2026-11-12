require "rails_helper"

# Spec 071 decision 7: the "N free: …" sentence of the My copies option.
RSpec.describe DeckAdditionsHelper, type: :helper do
  def free(*places) = instance_double(Lot::FreeCopies, total: places.sum(&:count), places:)
  def place(name, count) = Lot::FreeCopies::Place.new(name:, count:)

  it "names each place with its copies" do
    expect(helper.free_copies_sentence(free(place("Blue binder", 2), place("Red box", 1)))).to eq("3 free: 2 in Blue binder, 1 in Red box")
  end

  it "says copies with no location in words" do
    expect(helper.free_copies_sentence(free(place(nil, 1)))).to eq("1 free: 1 with no location")
  end

  it "names five places and counts the rest, in the singular for one", :aggregate_failures do
    seven = (1..7).map { |n| place("P#{n}", 1) }
    expect(helper.free_copies_sentence(free(*seven))).to eq("7 free: 1 in P1, 1 in P2, 1 in P3, 1 in P4, 1 in P5, and 2 more places")
    six = (1..6).map { |n| place("P#{n}", 1) }
    expect(helper.free_copies_sentence(free(*six))).to end_with(", and 1 more place")
  end

  it "writes thousands with a delimiter" do
    expect(helper.free_copies_sentence(free(place("Bulk", 1_234)))).to eq("1,234 free: 1,234 in Bulk")
  end
end
