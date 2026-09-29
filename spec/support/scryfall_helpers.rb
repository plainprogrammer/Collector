module ScryfallHelpers
  def scryfall_card(overrides = {})
    id = overrides.fetch("id") { SecureRandom.uuid }
    {
      "object" => "card", "id" => id, "oracle_id" => "oracle-bolt", "name" => "Lightning Bolt", "lang" => "en",
      "released_at" => "2009-07-17", "scryfall_uri" => "https://scryfall.com/card/m10/146/lightning-bolt",
      "layout" => "normal", "image_uris" => { "normal" => "https://cards.scryfall.io/normal/front/a/b/#{id}.jpg",
                                              "large" => "https://cards.scryfall.io/large/front/a/b/#{id}.jpg" },
      "mana_cost" => "{R}", "type_line" => "Instant", "oracle_text" => "Lightning Bolt deals 3 damage to any target.",
      "colors" => [ "R" ], "color_identity" => [ "R" ], "keywords" => [], "legalities" => { "modern" => "legal" },
      "games" => [ "paper", "mtgo" ], "digital" => false, "finishes" => [ "nonfoil", "foil" ], "rarity" => "common",
      "set" => "m10", "set_name" => "Magic 2010", "collector_number" => "146", "artist" => "Christopher Moeller",
      "frame" => "2003", "border_color" => "black", "tcgplayer_id" => 33_517, "prices" => { "usd" => "1.00" }
    }.merge(overrides)
  end

  def scryfall_set(overrides = {})
    { "object" => "set", "code" => "m10", "name" => "Magic 2010", "released_at" => "2009-07-17",
      "set_type" => "core", "digital" => false }.merge(overrides)
  end

  def gzip_jsonl(lines)
    io = StringIO.new
    gz = Zlib::GzipWriter.new(io)
    lines.each { |line| gz.puts(line.is_a?(String) ? line : JSON.generate(line)) }
    gz.close
    io.string
  end

  def stub_scryfall(cards:, sets: [ scryfall_set ], type: "default_cards", stamp: "20260929090555", size: nil)
    body = gzip_jsonl(cards)
    url = "https://data.scryfall.io/#{type.dasherize}/#{type.dasherize}-#{stamp}.jsonl.gz"
    bulk = { "object" => "list", "has_more" => false,
             "data" => [ { "type" => type, "jsonl_download_uri" => url, "compressed_size" => size || body.bytesize } ] }

    stub_request(:get, "https://api.scryfall.com/bulk-data").to_return(json_response(bulk))
    stub_request(:get, "https://api.scryfall.com/sets")
      .to_return(json_response("object" => "list", "has_more" => false, "data" => sets))
    stub_request(:get, url).to_return(body:, headers: { "Content-Type" => "application/gzip" })
  end

  def json_response(payload) = { body: JSON.generate(payload), headers: { "Content-Type" => "application/json" } }
end

RSpec.configure { |config| config.include ScryfallHelpers }
