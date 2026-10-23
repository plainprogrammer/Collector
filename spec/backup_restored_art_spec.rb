require "rails_helper"

RSpec.describe "art matching after a restore", :art_matching, :backup, :committed, type: :model do
  let(:art) { "aaaaaaaa-0000-4000-8000-000000000001" }
  let(:image) { "https://cards.scryfall.io/small/front/a/b/#{art}.jpg" }
  let(:client) { MTG::Scryfall::Client.new(sleeper: ->(_seconds) { }, clock: -> { 0.0 }) }
  let(:volume) { scratch("volume") }

  before do
    create(:catalog_refresh_run, collectible_type: "mtg", source_version: "default-cards-1")
    create(:mtg_printing, illustration_id: art, faces: [ { "name" => "Lightning Bolt", "image_uris" => { "small" => image } } ],
      entry: create(:catalog_entry, released_on: Date.new(2005, 1, 1)))
    stub_request(:get, image).to_return(body: noisy_png)
  end

  it "offers text recognition only until Build art index is pressed, which then needs no request (AC-2.8)", :aggregate_failures do
    MTG::Art::Build.new(job_id: "before", client:).call # fingerprints the artwork and writes the index
    expect(MTG::Art.page_config).to be_present
    path = create_backup
    FileUtils.rm_rf(MTG::Art.root) # the volume it is restored onto has no index file and no image
    restore_backup(path, volume:)

    with_restored_instance(volume.join("production.sqlite3")) do
      expect(MTG::Art.page_config).to be_nil
      WebMock.reset! # no stub is left: a request would raise, and would be counted
      run = MTG::Art::Build.new(job_id: "after", client:).call

      expect(run).to have_attributes(status: "finished", fetched_count: 0, indexed_count: 1)
      expect(a_request(:any, /.*/)).not_to have_been_made
      expect(MTG::Art.page_config).to include(name: a_string_starting_with("art-index-"))
    end
  end
end
