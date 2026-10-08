require "rails_helper"

RSpec::Matchers.define_negated_matcher :not_change, :change

RSpec.describe MTG::Art::Build, :art_matching, type: :model do
  let(:naps) { [] }
  let(:client) { MTG::Scryfall::Client.new(sleeper: ->(seconds) { naps << seconds }, clock: -> { 0.0 }) }
  let(:art_a) { "aaaaaaaa-0000-4000-8000-000000000001" }
  let(:art_b) { "bbbbbbbb-0000-4000-8000-000000000002" }

  before { create(:catalog_refresh_run, collectible_type: "mtg", source_version: "default-cards-1") }

  def small(name) = "https://cards.scryfall.io/small/front/a/b/#{name}.jpg"

  # A printing of an artwork; small: false leaves its face without a small image.
  def printing(art, released_on:, name: "Lightning Bolt", small: true, set_code: nil, number: "1", **entry)
    set = create(:catalog_set, released_on:, **(set_code ? { code: set_code } : {}))
    image_uris = small ? { "small" => small("#{art}-#{released_on.year}-#{number}") } : {}
    printing = create(:mtg_printing, illustration_id: art, faces: [ { "name" => name, "image_uris" => image_uris } ],
      entry: create(:catalog_entry, set:, number:, released_on:, **entry))
    printing.entry
  end

  def serve(*names, png: noisy_png) = names.map { stub_request(:get, small(it)).to_return(body: png) }

  def run_build(job_id: "job-1") = described_class.new(job_id:, client:).call

  it "fingerprints each artwork from its oldest printing with a small image, passing over those without (AC-3.3)", :aggregate_failures do
    printing(art_a, released_on: Date.new(1999, 1, 1), small: false)
    chosen = printing(art_a, released_on: Date.new(2005, 1, 1))
    printing(art_a, released_on: Date.new(2020, 1, 1))
    serve("#{art_a}-2005-1")

    run = run_build

    expect(run).to have_attributes(status: "finished", total_count: 1, without_image_count: 0, fetched_count: 1, indexed_count: 1)
    expect(MTG::Artwork.sole).to have_attributes(illustration_id: art_a, catalog_entry_id: chosen.id, settings_digest: MTG::Art::Settings.digest)
    expect(MTG::Artwork.sole.fingerprint.bytesize).to eq(128)
  end

  it "counts artworks with no small image on any printing, and ignores tokens, art cards, other languages and retired printings", :aggregate_failures do
    printing(art_a, released_on: Date.new(2005, 1, 1), small: false)
    printing(art_b, released_on: Date.new(2005, 1, 1), kind: "art_card")
    printing(art_b, released_on: Date.new(2006, 1, 1), language: "ja")
    printing(art_b, released_on: Date.new(2007, 1, 1), retired_at: 1.day.ago)

    expect(run_build).to have_attributes(status: "finished", total_count: 0, without_image_count: 1, indexed_count: 0)
  end

  it "fetches only from Scryfall's image host and caches each image under its artwork id (AC-3.4)", :aggregate_failures do
    printing(art_a, released_on: Date.new(2005, 1, 1))
    serve("#{art_a}-2005-1")
    run_build

    expect(MTG::Art.cache_dir.join("#{art_a}.jpg")).to exist
    expect(MTG::Art.cache_dir.glob("*.part")).to be_empty
  end

  it "records an image on another host as failed without requesting it" do
    entry = printing(art_a, released_on: Date.new(2005, 1, 1))
    MTG::Printing.find_by!(catalog_entry_id: entry.id).update!(faces: [ { "image_uris" => { "small" => "https://evil.test/x.jpg" } } ])

    expect(run_build).to have_attributes(status: "finished", failed_count: 1, indexed_count: 0)
  end

  it "never fetches a cached image again (AC-3.5)" do
    printing(art_a, released_on: Date.new(2005, 1, 1))
    stub = serve("#{art_a}-2005-1").first
    run_build
    MTG::Artwork.delete_all # force a second fingerprint from the cache

    run_build(job_id: "job-2")

    expect(stub).to have_been_requested.once
  end

  it "records a failed image, goes on, and tries it again on the next build (AC-3.6)", :aggregate_failures do
    printing(art_a, released_on: Date.new(2005, 1, 1))
    printing(art_b, released_on: Date.new(2005, 1, 1), name: "Shock", number: "2")
    serve("#{art_a}-2005-1")
    missing = stub_request(:get, small("#{art_b}-2005-2")).to_return(status: 404)

    expect(run_build).to have_attributes(status: "finished", failed_count: 1, indexed_count: 1, message: include(art_b))
    expect(run_build(job_id: "job-2")).to have_attributes(failed_count: 1)
    expect(missing).to have_been_requested.twice
  end

  it "records an image it can't decode as failed and drops it from the cache, so it's fetched again", :aggregate_failures do
    printing(art_a, released_on: Date.new(2005, 1, 1))
    serve("#{art_a}-2005-1", png: "not an image")

    expect(run_build).to have_attributes(failed_count: 1, indexed_count: 0)
    expect(MTG::Art.cache_dir.join("#{art_a}.jpg")).not_to exist
  end

  it "fingerprints only artworks without a current fingerprint (AC-3.7)", :aggregate_failures do
    entry = printing(art_a, released_on: Date.new(2005, 1, 1))
    create(:mtg_artwork, illustration_id: art_a, entry:)
    stub = serve("#{art_a}-2005-1").first

    expect(run_build).to have_attributes(status: "finished", fetched_count: 0, fingerprinted_count: 1, indexed_count: 1)
    expect(stub).not_to have_been_requested
  end

  it "carries on after an interruption with the same result as an uninterrupted build (AC-3.8)", :aggregate_failures do
    printing(art_a, released_on: Date.new(2005, 1, 1))
    printing(art_b, released_on: Date.new(2005, 1, 1), name: "Shock", number: "2")
    stubs = serve("#{art_a}-2005-1", "#{art_b}-2005-2")
    full_disk = Module.new do # an error outside a single image, after the images were fetched and cached
      def self.command = MTG::Art::Decoder.command
      def self.decode(_path) = raise(Errno::ENOSPC)
    end

    expect { described_class.new(job_id: "job-1", client:, decoder: full_disk).call }.to raise_error(Errno::ENOSPC)
    expect(MTG::ArtBuild.sole).to have_attributes(status: "failed", message: include("ENOSPC"))

    # The first image was fetched and cached before the failure; only the second is fetched now.
    expect(run_build(job_id: "job-1")).to have_attributes(status: "finished", fetched_count: 1, indexed_count: 2)
    expect(stubs).to all(have_been_requested.once)
  end

  it "writes the index last, and a second complete build records only its run (AC-3.8, AC-3.9)", :aggregate_failures do
    printing(art_a, released_on: Date.new(2005, 1, 1))
    serve("#{art_a}-2005-1")
    path = MTG::Art::Index.dir.join(MTG::Art::Index.name_for("default-cards-1", 1))

    expect(run_build).to have_attributes(index_file: path.basename.to_s)
    written = path.mtime
    expect { run_build(job_id: "job-2") }.to change(MTG::ArtBuild, :count).by(1).and(not_change(MTG::Artwork, :count))
    expect(path.mtime).to eq(written)
    expect(MTG::Art::Index.read(path)[:records].map(&:first)).to eq([ art_a ])
  end

  it "fails at once, recorded, when ImageMagick is missing (ADR 0011)", :aggregate_failures do
    decoder = class_double(MTG::Art::Decoder, command: nil)
    allow(decoder).to receive(:command).and_raise(MTG::Art::Decoder::Error, "ImageMagick isn't installed")

    expect { described_class.new(job_id: "job-1", client:, decoder:).call }.to raise_error(MTG::Art::Decoder::Error)
    expect(MTG::ArtBuild.sole).to have_attributes(status: "failed", message: include("ImageMagick isn't installed"))
  end

  it "does nothing with art matching off, or before any refresh has applied", :aggregate_failures do
    Rails.configuration.x.mtg_art_matching = false
    expect(run_build).to be_nil
    Rails.configuration.x.mtg_art_matching = true
    Catalog::RefreshRun.delete_all
    expect(run_build).to be_nil
    expect(MTG::ArtBuild.count).to eq(0)
  end
end
