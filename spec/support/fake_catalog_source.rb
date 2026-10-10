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

# A source with the optional progress hook (spec 015 FR-2): it says how far through the download and the file it is.
class ReportingCatalogSource < FakeCatalogSource
  attr_writer :progress

  def download(version, dir:)
    @progress&.call(50, 100)
    @progress&.call(100, 100)
    super
  end

  def each_entry(path, languages:)
    index = 0
    super do |record|
      @progress&.call(index += 1, entries.size)
      yield record
    end
  end
end

# A test-only catalog type with a name of its own and one extra operation (spec 015 AC-5.3): registered for one
# example with `:other_catalog`, as the type "other".
class OtherCatalogSource < FakeCatalogSource
  def self.title = "Pocket Monsters"
  def self.operations(collectible_type) = [ OtherCatalogOperation.new(collectible_type) ]
end

class OtherCatalogOperation < Catalog::Operation
  def key = "price_sync"
  def title = "Price sync"
  def start_label = "Sync prices"
  def queued_notice = "Price sync queued."
  def in_flight_notice = "A price sync is already queued or running."
  def job_class = OtherCatalogJob
  def job_arguments = [ collectible_type ]
  def queue_argument = collectible_type
  def summary = "Never synced."
  def record_running? = false
  def meter = Meter.new(label: "Prices", done: 1, total: 4, text: "1 of 4 prices")
end

class OtherCatalogJob < ApplicationJob
  def perform(_collectible_type) = nil
end

RSpec.configure do |config|
  config.around(:each, :other_catalog) do |example|
    Catalog.sources["other"] = "OtherCatalogSource"
    example.run
  ensure
    Catalog.sources.delete("other")
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
