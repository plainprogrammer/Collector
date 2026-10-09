class FakeCatalogSource
  ALLOWED_HOSTS = %w[example.test].freeze

  def self.entry_extension_model = nil
  def self.identity_extension_model = nil

  attr_accessor :version, :sets, :entries, :languages_result, :fail_at, :reapply
  attr_reader :downloads, :refreshed

  def initialize(version: "v1", sets: [], entries: [], languages: [ "en" ], fail_at: nil, reapply: false)
    @version, @sets, @entries, @languages_result, @fail_at, @reapply = version, sets, entries, languages, fail_at, reapply
    @downloads = []
    @refreshed = []
  end

  # Spec 011 AC-2.4: the optional hooks a source may implement.
  def reapply? = reapply

  def after_refresh(run) = refreshed << [ run.status, run.source_version ]

  def languages
    raise languages_result if languages_result.is_a?(Exception)

    languages_result
  end

  def current_version(languages:) = version

  def download(version, dir:)
    downloads << version
    dir.join("#{version}.fake")
  end

  def each_set(&) = sets.each(&)

  def each_entry(_path, languages:)
    entries.each_with_index do |record, index|
      raise "source exploded" if index == fail_at

      yield record if record.is_a?(Catalog::Sources::Malformed) || languages.include?(record.language)
    end
  end
end

module CatalogRecordHelpers
  def identity_record(key = "bolt", name: "Lightning Bolt", extension: {})
    Catalog::Sources::IdentityRecord.new(external_key: key, name:, extension:)
  end

  def entry_record(key, identity: identity_record, set_code: "lea", language: "en", name: identity.name, kind: "card", number: "1")
    Catalog::Sources::EntryRecord.new(external_key: key, identity:, set_code:, set_name: set_code.upcase, number:,
      language:, name:, localized_name: nil, kind:, released_on: Date.new(1993, 8, 5),
      image_url: "https://example.test/#{key}.jpg", extension: {})
  end

  def set_record(code) = Catalog::Sources::SetRecord.new(code:, name: code.upcase, released_on: Date.new(1993, 8, 5), parent_code: nil)
end

RSpec.configure { |config| config.include CatalogRecordHelpers }
