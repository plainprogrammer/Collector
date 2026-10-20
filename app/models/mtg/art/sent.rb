# The art part of a reading request (spec 011 AC-6.1): up to 10 artwork ids (lowercase UUIDs, as Scryfall writes
# illustration_id) with whole-number distances from 0 to 1,024. Read leniently, apart from the text's strict parameters:
# anything malformed drops the whole art part and the text ranks alone; the request never fails for it. nil means no art.
module MTG::Art::Sent
  ID = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/
  DISTANCE = /\A\d{1,4}\z/
  MAX = 10

  Artwork = Data.define(:id, :distance)

  def self.from_params(params)
    return unless MTG::Art.enabled?

    reading = params[:reading]
    parse(reading[:artworks]) if reading.respond_to?(:key?)
  end

  def self.parse(raw)
    return unless raw.is_a?(Array) && raw.size.between?(1, MAX)

    artworks = raw.map do |item|
      return unless item.respond_to?(:key?)

      id, distance = item[:id].to_s, item[:distance].to_s
      return unless ID.match?(id) && DISTANCE.match?(distance) && distance.to_i <= 1_024

      Artwork.new(id:, distance: distance.to_i)
    end
    artworks
  end
end
