# The contract between the catalog and an external data source. A source
# class (e.g. MTG::Scryfall::Source) is registered per collectible type in
# config/initializers/catalog.rb and provides:
#
#   ALLOWED_HOSTS                       hosts whose https URLs views may render
#   .entry_extension_model              model keyed by catalog_entry_id, or nil
#   .identity_extension_model           model keyed by catalog_identity_id, or nil
#   .alternate_names(entries)           optional: [[identity id, name], …] the name index adds to identity names
#   #languages                          sorted language codes to ingest (raises ConfigurationError)
#   #current_version(languages:)        opaque String naming the current source data
#   #download(version, dir:)            Pathname of the verified local copy (IntegrityError, TransientError)
#   #each_set { |SetRecord| }
#   #each_entry(path, languages:) { |EntryRecord or Malformed| }   streamed, filtered to languages
#   #reapply?                           optional: true to apply a version again although it was applied (asked before a skip)
#   #after_refresh(run)                 optional: called after an applied run, or one skipped as already applied
#   #progress=(callable)                optional: the refresh sets it; the source calls it with (done, total) while it
#                                       downloads (bytes received, expected size) and while each_entry reads (bytes of the
#                                       file read, its size), so the run can show a percentage (spec 015 FR-2)
#   .title                              optional: what the admin catalog page calls this catalog ("Magic: The Gathering")
#   .operations(collectible_type)       optional: extra Catalog::Operation objects for the admin catalog page
#   .content_notice                     optional: the Catalog::ContentNotice::Line objects every page's footer shows for
#                                       this type, in order: what the content's owner asks to be said, and who provides
#                                       the data. Plain text, with the phrases that link out and their https addresses.
#                                       It is the same for every request and reads nothing (spec 018 FR-1)
module Catalog::Sources
  SetRecord = Data.define(:code, :name, :released_on, :parent_code) do
    def digest = Catalog::Sources.digest(to_h)
  end

  IdentityRecord = Data.define(:external_key, :name, :extension) do
    def digest = Catalog::Sources.digest(to_h)
  end

  EntryRecord = Data.define(:external_key, :identity, :set_code, :set_name, :number, :language, :name,
    :localized_name, :kind, :released_on, :image_url, :extension) do
    def digest = Catalog::Sources.digest(to_h.except(:identity).merge(identity_key: identity.external_key))
  end

  Malformed = Data.define(:external_key, :error)

  class Error < StandardError; end
  class TransientError < Error; end
  # The source is turning requests away for now: it kept answering "too many requests", or asked for a longer wait
  # than its client sits out. Transient, but what was being fetched hasn't failed, so a caller working through many
  # requests stops instead of going on to the next. #retry_after is the wait the source last asked for, in seconds,
  # or nil when it never said; a job comes back no sooner than that (Catalog::RateLimitRetry).
  class RateLimitedError < TransientError
    attr_reader :retry_after

    def initialize(message = nil, retry_after: nil)
      super(message)
      @retry_after = retry_after
    end
  end
  class IntegrityError < Error; end
  class ConfigurationError < Error; end

  def self.digest(attributes) = Digest::SHA256.hexdigest(ActiveSupport::JSON.encode(attributes))
end
