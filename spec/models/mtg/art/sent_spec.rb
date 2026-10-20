require "rails_helper"

RSpec.describe MTG::Art::Sent, type: :model do
  let(:id) { "aaaaaaaa-0000-4000-8000-000000000001" }

  def params(artworks) = ActionController::Parameters.new(reading: { name_text: "x", artworks: })

  it "reads up to 10 artwork ids with whole-number distances from 0 to 1,024 (AC-6.1)", :art_matching do
    sent = described_class.from_params(params([ { id:, distance: "189" }, { id: id.tr("a", "b"), distance: "0" } ]))
    expect(sent).to eq([ described_class::Artwork.new(id:, distance: 189), described_class::Artwork.new(id: id.tr("a", "b"), distance: 0) ])
  end

  it "drops the whole art part when any entry is malformed, or there are more than 10 (AC-6.1)", :aggregate_failures, :art_matching do
    [ [ { id: id.upcase, distance: "1" } ], [ { id:, distance: "1025" } ], [ { id:, distance: "-1" } ], [ { id:, distance: "1.5" } ],
      [ { id: } ], [ "#{id}" ], Array.new(11) { { id:, distance: "1" } }, [] ].each do |artworks|
      expect(described_class.from_params(params(artworks))).to be_nil
    end
    expect(described_class.from_params(ActionController::Parameters.new(reading: { artworks: "x" }))).to be_nil
    expect(described_class.from_params(ActionController::Parameters.new(reading: "x"))).to be_nil
  end

  it "reads nothing with art matching off (AC-1.1)" do
    expect(described_class.from_params(params([ { id:, distance: "1" } ]))).to be_nil
  end
end
