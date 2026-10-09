# Pure mapping from Scryfall card and set objects to catalog source records.
module MTG::Scryfall::Mapper
  KINDS = { "token" => "token", "double_faced_token" => "token", "emblem" => "emblem", "art_series" => "art_card",
            "planar" => "other", "scheme" => "other", "vanguard" => "other" }.freeze
  FLAG_TAGS = %w[full_art textless oversized promo variation].freeze
  EXTERNAL_IDS = %w[tcgplayer_id tcgplayer_etched_id cardmarket_id mtgo_id mtgo_foil_id arena_id multiverse_ids].freeze
  FACE_FIELDS = %w[name printed_name mana_cost type_line oracle_text power toughness loyalty defense artist].freeze

  module_function

  def paper?(card) = !card["digital"] && Array(card["games"]).include?("paper")

  def set_record(set)
    Catalog::Sources::SetRecord.new(code: set.fetch("code"), name: set.fetch("name"),
      released_on: date(set["released_at"]), parent_code: set["parent_set_code"])
  end

  def entry_record(card)
    faces = faces(card)
    Catalog::Sources::EntryRecord.new(
      external_key: card.fetch("id"),
      identity: identity_record(card, faces),
      set_code: card.fetch("set"),
      set_name: card.fetch("set_name"),
      number: card.fetch("collector_number"),
      language: card.fetch("lang"),
      name: card.fetch("name"),
      localized_name: card["printed_name"] || faces.filter_map { |face| face["printed_name"] }.join(" // ").presence,
      kind: KINDS.fetch(card.fetch("layout"), "card"),
      released_on: date(card["released_at"]),
      image_url: faces.first.dig("image_uris", "normal"),
      extension: {
        rarity: card.fetch("rarity"), finishes: card.fetch("finishes").sort, layout: card.fetch("layout"),
        frame: card["frame"], border_color: card["border_color"], security_stamp: card["security_stamp"],
        variant_tags: variant_tags(card), legalities: card.fetch("legalities", {}),
        external_ids: card.slice(*EXTERNAL_IDS), faces:, scryfall_uri: card.fetch("scryfall_uri"),
        illustration_id: illustration_id(card)
      }
    )
  end

  def identity_record(card, faces)
    Catalog::Sources::IdentityRecord.new(
      external_key: card["oracle_id"] || card.fetch("card_faces").first.fetch("oracle_id"),
      name: card.fetch("name"),
      extension: {
        mana_cost: joined(card, faces, "mana_cost"), type_line: joined(card, faces, "type_line"),
        oracle_text: joined(card, faces, "oracle_text"),
        colors: Array(card["colors"] || card["card_faces"]&.flat_map { |face| Array(face["colors"]) }).uniq.sort,
        color_identity: card.fetch("color_identity").sort, keywords: card.fetch("keywords").sort
      }
    )
  end

  def faces(card)
    (card["card_faces"].presence || [ card ]).map do |face|
      face.slice(*FACE_FIELDS).merge("image_uris" => (face["image_uris"] || card["image_uris"] || {}).slice("small", "normal", "large"))
    end
  end

  # The front face's artwork (spec 011 AC-2.1): a multi-face printing's first face, else the card's own.
  def illustration_id(card) = Array(card["card_faces"]).first&.dig("illustration_id") || card["illustration_id"]

  def joined(card, faces, field) = card[field] || faces.filter_map { |face| face[field].presence }.join(" // ").presence

  def variant_tags(card)
    (Array(card["promo_types"]) + Array(card["frame_effects"]) + FLAG_TAGS.select { |flag| card[flag] }).uniq.sort
  end

  def date(value) = value && Date.iso8601(value)
end
