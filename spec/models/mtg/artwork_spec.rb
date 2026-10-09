require "rails_helper"

RSpec.describe MTG::Artwork, type: :model do
  it "is one 128-byte fingerprint per artwork, with its printing and settings digest (spec 011 AC-3.7)", :aggregate_failures do
    artwork = create(:mtg_artwork)
    expect(artwork.entry).to be_a(Catalog::Entry)
    expect(build(:mtg_artwork, illustration_id: artwork.illustration_id)).not_to be_valid
    expect(build(:mtg_artwork, fingerprint: "\x00".b * 127)).not_to be_valid
  end

  it "knows which fingerprints were made with the current settings" do
    current = create(:mtg_artwork)
    create(:mtg_artwork, settings_digest: "0123456789abcdef")
    expect(described_class.current).to eq([ current ])
  end
end
