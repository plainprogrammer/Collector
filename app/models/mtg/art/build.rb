# Builds the art index (spec 011 Story 3; ADR 0006). One fingerprint per artwork among the catalog's English card
# printings that aren't retired, from Scryfall's small image of the artwork's oldest printing that has one (AC-3.3),
# fetched once into the art cache (AC-3.4, AC-3.5). Incremental: only artworks without a fingerprint at the current
# settings are fingerprinted (AC-3.7). Resumable: the cache and the table survive an interruption (AC-3.8). A failed
# image is recorded and tried again next time (AC-3.6). Recorded as an MTG::ArtBuild with a heartbeat per batch, and the
# index file is written last (AC-3.9).
class MTG::Art::Build
  BATCH = 50
  FAILURES_SHOWN = 20
  IMAGE_HOSTS = %w[cards.scryfall.io].freeze
  COLLECTIBLE_TYPE = "mtg"
  # Oldest first: release date (undated last), then set code, then collector number as the catalog orders them.
  OLDEST_FIRST = Arel.sql("catalog_entries.released_on IS NULL, catalog_entries.released_on, catalog_sets.code, " \
                          "catalog_entries.number, catalog_entries.id")
  SMALL_IMAGE = Arel.sql("json_extract(mtg_printings.faces, '$[0].image_uris.small')")

  Representative = Data.define(:id, :catalog_entry_id, :url)

  def initialize(job_id:, client: MTG::Scryfall::Client.new, decoder: MTG::Art::Decoder)
    @job_id = job_id
    @client = client
    @decoder = decoder
    @counts = Hash.new(0)
    @failures = []
  end

  def call
    return unless MTG::Art.enabled?

    version = Catalog::RefreshRun.for_type(COLLECTIBLE_TYPE).last_applied&.source_version
    return unless version

    @run = MTG::ArtBuild.start!(job_id: @job_id, catalog_version: version, settings_digest: MTG::Art::Settings.digest)
    return @run unless @run.running?

    @decoder.command # fails the build at once when ImageMagick is missing (ADR 0011)
    artworks = representatives
    done = MTG::Artwork.current.pluck(:illustration_id).to_set
    todo = artworks.reject { done.include?(it.id) }
    @counts.merge!(total: artworks.size, fingerprinted: artworks.size - todo.size)
    @run.beat!(**@counts)
    todo.each_slice(BATCH) do |batch|
      store(batch.filter_map { fingerprint(it) })
      @run.beat!(**@counts)
    end
    @run.update!(index_file: write_index(version, artworks).basename.to_s)
    @run.finish!(:finished, message: failure_note, **@counts)
    @run
  rescue StandardError => error
    @run.finish!(:failed, message: "#{error.class}: #{error.message}", **@counts) if @run&.running?
    raise
  end

  private
    def representatives
      chosen = {}
      seen = ::Set.new
      printings.pluck(Arel.sql("mtg_printings.illustration_id"), "catalog_entries.id", SMALL_IMAGE).each do |id, entry_id, url|
        seen << id
        chosen[id] ||= Representative.new(id:, catalog_entry_id: entry_id, url:) if url.present?
      end
      @counts[:without_image] = seen.size - chosen.size
      chosen.values
    end

    def printings
      Catalog::Entry.searchable.where(collectible_type: COLLECTIBLE_TYPE, language: "en").joins(:set)
        .joins("INNER JOIN mtg_printings ON mtg_printings.catalog_entry_id = catalog_entries.id")
        .where.not(mtg_printings: { illustration_id: nil }).order(OLDEST_FIRST)
    end

    def fingerprint(artwork)
      path = cached(artwork)
      return unless path

      { illustration_id: artwork.id, catalog_entry_id: artwork.catalog_entry_id,
        fingerprint: MTG::Art::Fingerprint.of(@decoder.decode(path)), settings_digest: MTG::Art::Settings.digest }
    rescue MTG::Art::Decoder::Error => error
      path&.delete # an undecodable download is fetched again next time
      failed(artwork, error)
    end

    def cached(artwork)
      path = MTG::Art.cache_dir.join("#{artwork.id}.jpg")
      path.file? && path.size.positive? ? path : fetch(artwork, path)
    end

    def fetch(artwork, path)
      uri = URI(artwork.url)
      raise Catalog::Sources::Error, "#{artwork.url} isn't a Scryfall image" unless uri.scheme == "https" && IMAGE_HOSTS.include?(uri.host)

      bytes = @client.fetch_image(artwork.url)
      path.dirname.mkpath
      partial = Pathname("#{path}.part")
      partial.binwrite(bytes)
      partial.rename(path)
      @counts[:fetched] += 1
      path
    rescue Catalog::Sources::Error, URI::InvalidURIError => error
      failed(artwork, error)
    end

    def failed(artwork, error)
      @counts[:failed] += 1
      @failures << artwork.id if @failures.size < FAILURES_SHOWN
      Rails.logger.warn("mtg.art_build image #{artwork.id} failed: #{error.class}: #{error.message}")
      nil
    end

    def store(rows)
      return if rows.empty?

      MTG::Artwork.upsert_all(rows, unique_by: :illustration_id)
      @counts[:fingerprinted] += rows.size
    end

    def write_index(version, artworks)
      ids = artworks.to_set(&:id)
      records = MTG::Artwork.current.pluck(:illustration_id, :fingerprint).select { |id, _| ids.include?(id) }
      @counts[:indexed] = records.size
      MTG::Art::Index.write!(version, records)
    end

    def failure_note
      return if @failures.empty?

      "failed images: #{@failures.join(", ")}#{" and #{@counts[:failed] - @failures.size} more" if @counts[:failed] > @failures.size}"
    end
end
