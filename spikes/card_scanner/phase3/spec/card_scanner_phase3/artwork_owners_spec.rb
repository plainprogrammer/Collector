require_relative "../phase3_helper"
require "card_scanner_phase3/artwork_owners"
require "tmpdir"
require "zlib"

RSpec.describe CardScannerPhase3::ArtworkOwners do
  it "lists each front-face artwork's card names and printings among imported entries (AC-4.4, AC-4.5)", :aggregate_failures do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "bulk.jsonl.gz")
      cards = [
        { "id" => "p1", "name" => "Plains", "lang" => "en", "games" => [ "paper" ], "illustration_id" => "art-1" },
        { "id" => "p2", "name" => "Plains", "lang" => "en", "games" => [ "paper" ], "illustration_id" => "art-1" },
        { "id" => "p3", "name" => "Plains", "lang" => "ja", "games" => [ "paper" ], "illustration_id" => "art-1" },
        { "id" => "d1", "name" => "Front // Back", "lang" => "en", "games" => [ "paper" ], "card_faces" => [ { "illustration_id" => "art-2" }, { "illustration_id" => "art-3" } ] }
      ]
      Zlib::GzipWriter.open(path) { |gz| cards.each { gz.puts(it.to_json) } }
      owners = described_class.read(path)
      expect(owners["art-1"]).to eq("names" => [ "Plains" ], "printings" => %w[p1 p2])
      expect(owners["art-2"]).to eq("names" => [ "Front // Back" ], "printings" => %w[d1])
      expect(owners).not_to have_key("art-3")
    end
  end
end
