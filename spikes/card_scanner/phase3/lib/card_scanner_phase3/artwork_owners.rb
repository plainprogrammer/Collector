require "zlib"
require_relative "../../../phase2/lib/card_scanner_phase2/bulk_artworks"

module CardScannerPhase3
  # For each front-face artwork among the entries the catalog imports (spec 008 AC-4.1's filter): the card names and the
  # printings that carry it (spec 010 AC-4.4, AC-4.5).
  module ArtworkOwners
    module_function

    def read(path)
      owners = {}
      Zlib::GzipReader.open(path.to_s) do |gz|
        gz.each_line do |line|
          next if line.strip.empty?

          card = JSON.parse(line)
          next unless CardScannerPhase2::BulkArtworks.imported?(card)

          front = Array(card["card_faces"]).first || card
          next unless (id = front["illustration_id"] || card["illustration_id"])

          owner = owners[id] ||= { "names" => [], "printings" => [] }
          owner["names"] |= [ card["name"] ]
          owner["printings"] << card["id"]
        end
      end
      owners
    end
  end
end
