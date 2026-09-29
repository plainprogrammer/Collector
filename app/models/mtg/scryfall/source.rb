# Catalog source for Magic: The Gathering backed by Scryfall bulk data
# (implements the contract documented in app/models/catalog/sources.rb).
class MTG::Scryfall::Source
  ALLOWED_HOSTS = %w[scryfall.com cards.scryfall.io svgs.scryfall.io].freeze
  LANGUAGES = %w[en es fr de it pt ja ko ru zhs zht he la grc ar sa ph qya].freeze
  LANGUAGES_ENV = "COLLECTOR_MTG_LANGUAGES"
  KEEP_DOWNLOADS = 2

  def self.entry_extension_model = MTG::Printing
  def self.identity_extension_model = MTG::Card

  def initialize(client: MTG::Scryfall::Client.new, env: ENV)
    @client = client
    @env = env
    @bulk_files = {}
  end

  def languages
    requested = @env.fetch(LANGUAGES_ENV, "").split(",").map { |code| code.strip.downcase }.compact_blank
    invalid = requested - LANGUAGES
    if invalid.any?
      raise Catalog::Sources::ConfigurationError,
        "#{LANGUAGES_ENV} has unsupported language code(s): #{invalid.join(", ")} (supported: #{LANGUAGES.join(", ")})"
    end
    (requested | [ "en" ]).sort
  end

  # English only needs Scryfall's much smaller default_cards file.
  def current_version(languages:)
    type = languages == [ "en" ] ? "default_cards" : "all_cards"
    file = @client.get_json("/bulk-data").fetch("data").find { |entry| entry["type"] == type }
    raise Catalog::Sources::TransientError, "Scryfall bulk-data lists no #{type} file" unless file

    File.basename(file.fetch("jsonl_download_uri"), ".jsonl.gz").tap { |version| @bulk_files[version] = file }
  end

  def download(version, dir:)
    file = @bulk_files.fetch(version)
    expected = Integer(file.fetch("compressed_size"))
    path = dir.join("#{version}.jsonl.gz")
    dir.mkpath
    fetch(file.fetch("jsonl_download_uri"), path, expected) unless path.exist? && path.size == expected
    prune(dir)
    path
  end

  def each_set
    url = "/sets"
    while url
      page = @client.get_json(url)
      page.fetch("data").each { |set| yield MTG::Scryfall::Mapper.set_record(set) }
      url = page["has_more"] ? page.fetch("next_page") : nil
    end
  end

  def each_entry(path, languages:)
    allowed = languages.to_set
    Zlib::GzipReader.open(path) do |gzip|
      gzip.each_line do |line|
        record = entry_or_malformed(line, allowed)
        yield record if record
      end
    end
  end

  private
    def fetch(url, path, expected)
      partial = Pathname("#{path}.part")
      File.open(partial, "wb") { |io| @client.download(url, to: io) }
      return partial.rename(path) if partial.size == expected

      actual = partial.size
      partial.delete
      raise Catalog::Sources::IntegrityError, "#{path.basename}: downloaded #{actual} bytes, Scryfall published #{expected}"
    end

    def prune(dir)
      dir.glob("*.jsonl.gz").sort_by(&:mtime).reverse.drop(KEEP_DOWNLOADS).each(&:delete)
    end

    def entry_or_malformed(line, allowed)
      return if line.strip.empty?

      card = JSON.parse(line)
      return unless allowed.include?(card["lang"]) && MTG::Scryfall::Mapper.paper?(card)

      MTG::Scryfall::Mapper.entry_record(card)
    rescue JSON::ParserError, KeyError, ArgumentError, TypeError, NoMethodError => error
      Catalog::Sources::Malformed.new(external_key: card.is_a?(Hash) ? card["id"] : nil, error: "#{error.class}: #{error.message}")
    end
end
