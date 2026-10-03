require_relative "../phase2_helper"
require "card_scanner_phase2/bulk_artworks"
require "tmpdir"
require "zlib"

RSpec.describe CardScannerPhase2::BulkArtworks do
  def card(id:, name:, lang: "en", digital: false, games: %w[paper], layout: "normal", illustration: nil, faces: nil, set: "aaa", number: "1")
    record = { "id" => id, "name" => name, "lang" => lang, "digital" => digital, "games" => games, "layout" => layout, "set" => set, "collector_number" => number }
    record["illustration_id"] = illustration if illustration
    record["image_uris"] = { "small" => "https://cards.scryfall.io/small/front/#{id}.jpg", "normal" => "https://cards.scryfall.io/normal/front/#{id}.jpg" } unless faces
    record["card_faces"] = faces if faces
    record
  end

  let(:lines) do
    [ card(id: "p1", name: "Bolt", illustration: "art-1"),
      card(id: "p2", name: "Bolt", illustration: "art-1", set: "bbb"),
      card(id: "p3", name: "Bolt", illustration: "art-2"),
      card(id: "p4", name: "Bolt", illustration: "art-1", lang: "ja"),
      card(id: "p5", name: "Arena Bolt", illustration: "art-3", digital: true),
      card(id: "p6", name: "Online Bolt", illustration: "art-4", games: %w[mtgo]),
      card(id: "p7", name: "Front // Back", layout: "transform",
        faces: [ { "name" => "Front", "illustration_id" => "art-5", "image_uris" => { "small" => "https://cards.scryfall.io/small/front/p7.jpg", "normal" => "n" } },
                 { "name" => "Back", "illustration_id" => "art-6", "image_uris" => { "small" => "https://cards.scryfall.io/small/back/p7.jpg", "normal" => "n" } } ]),
      card(id: "p8", name: "No Art") ]
  end

  it "keeps the entries the catalog imports and one front-face artwork per illustration id", :aggregate_failures do
    Dir.mktmpdir do |dir|
      path = Pathname(dir).join("default-cards-20261003000000.jsonl.gz")
      Zlib::GzipWriter.open(path.to_s) { |gz| lines.each { gz.puts(it.to_json) } }
      result = described_class.read(path)
      expect(result["bulk_version"]).to eq("default-cards-20261003000000")
      expect(result["counts"]).to eq("entries" => 5, "with_artwork" => 4, "without_artwork" => 1, "artworks" => 3)
      expect(result["artworks"].keys).to contain_exactly("art-1", "art-2", "art-5")
      expect(result["artworks"]["art-1"]).to eq("printing" => "p1", "name" => "Bolt", "small" => "https://cards.scryfall.io/small/front/p1.jpg",
        "normal" => "https://cards.scryfall.io/normal/front/p1.jpg", "entries" => 2)
      expect(result["entries"]).to eq("p1" => "art-1", "p2" => "art-1", "p3" => "art-2", "p7" => "art-5", "p8" => nil)
      expect(result["names"]).to eq("Bolt" => 3, "Front // Back" => 1, "No Art" => 1)
    end
  end
end
