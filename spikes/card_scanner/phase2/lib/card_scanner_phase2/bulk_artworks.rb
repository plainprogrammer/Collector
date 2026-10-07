require "zlib"

module CardScannerPhase2
  # Reads the Scryfall bulk file the catalog was built from and lists one front-face artwork per distinct
  # illustration id among the entries the catalog imports (AC-4.1): lang en, not digital, paper, the same
  # filter as MTG::Scryfall::Mapper.paper?. The first printing in file order stands for each artwork.
  module BulkArtworks
    module_function

    # Spec 010 names its bulk file with CARD_SCANNER_BULK_FILE, so a later catalog refresh can't change the input.
    def latest_bulk_file(dir = REPO.join("storage/catalog/mtg"))
      return Pathname(File.expand_path(ENV["CARD_SCANNER_BULK_FILE"])) if ENV["CARD_SCANNER_BULK_FILE"]

      dir.glob("default-cards-*.jsonl.gz").max_by(&:mtime) or raise "no bulk file under #{dir}"
    end

    def imported?(card) = card["lang"] == "en" && !card["digital"] && Array(card["games"]).include?("paper")

    def read(path)
      artworks, entries, names = {}, {}, Hash.new(0)
      counts = Hash.new(0)
      Zlib::GzipReader.open(path.to_s) do |gz|
        gz.each_line do |line|
          next if line.strip.empty?
          card = JSON.parse(line)
          next unless imported?(card)

          counts["entries"] += 1
          names[card["name"]] += 1
          front = Array(card["card_faces"]).first || card
          illustration = front["illustration_id"] || card["illustration_id"]
          entries[card["id"]] = illustration
          counts[illustration ? "with_artwork" : "without_artwork"] += 1
          next unless illustration

          uris = front["image_uris"] || card["image_uris"] || {}
          artworks[illustration] ||= { "printing" => card["id"], "name" => card["name"], "small" => uris["small"], "normal" => uris["normal"], "entries" => 0 }
          artworks[illustration]["entries"] += 1
        end
      end
      counts["artworks"] = artworks.size
      { "bulk_version" => File.basename(path.to_s, ".jsonl.gz"), "counts" => counts.sort.to_h, "artworks" => artworks, "entries" => entries, "names" => names }
    end

    def write!(result, dir = WORK_DIR)
      dir.mkpath
      dir.join("artworks.json").write(JSON.generate(result.slice("bulk_version", "counts", "artworks")))
      dir.join("entries.json").write(JSON.generate(result["entries"]))
      dir.join("names.json").write(JSON.generate(result["names"]))
    end

    def load(dir = WORK_DIR) = JSON.parse(dir.join("artworks.json").read).merge("entries" => JSON.parse(dir.join("entries.json").read), "names" => JSON.parse(dir.join("names.json").read))
  end
end
