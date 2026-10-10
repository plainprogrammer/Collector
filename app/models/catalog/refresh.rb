# Applies a catalog source's current data: writes only changed rows in short
# batches, retires entries the source no longer lists (only after a complete
# pass), restores ones that come back, and records a Catalog::RefreshRun. While it works it records the run's stage
# and progress (spec 015 FR-1): download, sync, retire, index.
class Catalog::Refresh
  BATCH_SIZE = 1_000

  def initialize(collectible_type, trigger:, source: Catalog.source_for(collectible_type), job_id: nil,
    clock: Progress::CLOCK)
    @collectible_type = collectible_type
    @trigger = trigger
    @source = source
    @job_id = job_id
    @clock = clock
    @counts = Hash.new(0)
  end

  def call
    @run = Catalog::RefreshRun.start!(@collectible_type, trigger: @trigger, job_id: @job_id)
    return @run unless @run.running?

    track_progress
    @progress.stage("download")
    languages = @source.languages
    version = @source.current_version(languages:)
    @run.update!(source_version: version, languages: languages.join(","))
    return skip(version) if already_applied?(version) && !reapply?

    path = @source.download(version, dir: Rails.configuration.x.catalog_download_dir.join(@collectible_type))
    @progress.stage("sync")
    sync_sets
    sync_entries(path, languages)
    @progress.stage("retire")
    retire_unseen
    @progress.stage("index")
    name_index.rebuild
    @run.finish!(:applied, counts: @counts)
    after_refresh
    @run
  rescue StandardError => error
    @run.finish!(:failed, message: "#{error.class}: #{error.message}", counts: @counts) if @run&.running?
    raise
  end

  private
    # Optional source hook (app/models/catalog/sources.rb): a source that can say how far through a download or a file
    # it is takes a callable and calls it with (done, total). One that can't is still tracked by stage and counts.
    def track_progress
      @progress = Progress.new(@run, @counts, clock: @clock)
      @source.progress = @progress.method(:at) if @source.respond_to?(:progress=)
    end

    def already_applied?(version)
      @trigger == "scheduled" &&
        Catalog::RefreshRun.applied?(@collectible_type, source_version: version, languages: @run.languages)
    end

    def skip(version)
      rebuilt = name_index.rebuild unless name_index.populated?
      note = "; name index rebuilt with #{rebuilt} #{"name".pluralize(rebuilt)}" if rebuilt
      @run.finish!(:skipped, message: "#{version} already applied#{note}")
      after_refresh
      @run
    end

    # Optional source hooks (app/models/catalog/sources.rb): a reason to apply an already-applied version again, and a
    # step after an applied or already-applied run. The core never knows what a source does with them (spec 011 AC-2.4).
    def reapply? = @source.respond_to?(:reapply?) && @source.reapply?

    def after_refresh = @source.respond_to?(:after_refresh) && @source.after_refresh(@run)

    def name_index = @name_index ||= Catalog::NameIndex.new(@collectible_type, source_class: @source.class)

    def sync_sets
      @sets = Catalog::Set.where(collectible_type: @collectible_type).pluck(:code, :id, :content_digest)
        .to_h { |code, id, digest| [ code, [ id, digest ] ] }
      changed = []
      @source.each_set { |record| changed << record unless @sets.dig(record.code, 1) == record.digest }
      write_sets(changed)
    end

    def sync_entries(path, languages)
      @identities = Catalog::Identity.where(collectible_type: @collectible_type).pluck(:external_key, :id, :content_digest)
        .to_h { |key, id, digest| [ key, [ id, digest ] ] }
      @entries = Catalog::Entry.where(collectible_type: @collectible_type).pluck(:external_key, :id, :content_digest, :retired_at)
        .to_h { |key, id, digest, retired_at| [ key, [ id, digest, retired_at ] ] }
      @seen = ::Set.new
      @identities_checked = ::Set.new
      @pending_entries = []
      @pending_identities = []

      @source.each_entry(path, languages:) do |record|
        sync_entry(record)
        @progress.seen # outside the batch's transaction, which flush has closed by now
      end
      flush
      # An unreadable file must not look like "everything was removed upstream".
      raise Catalog::Sources::Error, "no valid records (#{@counts[:malformed]} malformed)" if @counts[:seen].zero?
    end

    def sync_entry(record)
      return record_malformed(record) if record.is_a?(Catalog::Sources::Malformed)
      return if @seen.include?(record.external_key) # duplicate line in the source

      @counts[:seen] += 1
      @seen << record.external_key
      queue_identity(record.identity)
      queue_entry(record)
      flush if @pending_entries.size >= BATCH_SIZE || @pending_identities.size >= BATCH_SIZE
    end

    def queue_identity(identity)
      return unless @identities_checked.add?(identity.external_key)

      @pending_identities << identity unless @identities.dig(identity.external_key, 1) == identity.digest
    end

    def queue_entry(record)
      _id, digest, retired_at = @entries[record.external_key]
      @pending_entries << record unless digest == record.digest && retired_at.nil?
    end

    def flush
      return if @pending_entries.empty? && @pending_identities.empty?

      Catalog::Entry.transaction do
        write_sets(@pending_entries.reject { |record| @sets.key?(record.set_code) }.uniq(&:set_code).map do |record|
          Catalog::Sources::SetRecord.new(code: record.set_code, name: record.set_name, released_on: nil, parent_code: nil)
        end)
        write_identities(@pending_identities)
        write_entries(@pending_entries)
      end
      @pending_entries.each { |record| tally(record) }
      @pending_entries = []
      @pending_identities = []
    end

    def write_sets(records)
      return if records.empty?

      rows = records.map { |record| record.to_h.merge(collectible_type: @collectible_type, content_digest: record.digest) }
      Catalog::Set.upsert_all(rows, unique_by: %i[collectible_type code], returning: %i[code id])
        .each { |row| @sets[row["code"]] = [ row["id"], nil ] }
    end

    def write_identities(records)
      return if records.empty?

      rows = records.map do |record|
        { collectible_type: @collectible_type, external_key: record.external_key, name: record.name, content_digest: record.digest }
      end
      ids = upsert_returning_ids(Catalog::Identity, rows)
      records.each { |record| @identities[record.external_key] = [ ids.fetch(record.external_key), record.digest ] }
      write_extensions(@source.class.identity_extension_model, :catalog_identity_id, records, ids)
    end

    def write_entries(records)
      return if records.empty?

      ids = upsert_returning_ids(Catalog::Entry, records.map { |record| entry_row(record) })
      write_extensions(@source.class.entry_extension_model, :catalog_entry_id, records, ids)
    end

    def entry_row(record)
      { collectible_type: @collectible_type, external_key: record.external_key,
        catalog_set_id: @sets.fetch(record.set_code).first,
        catalog_identity_id: @identities.fetch(record.identity.external_key).first,
        number: record.number, language: record.language, name: record.name, localized_name: record.localized_name,
        kind: record.kind, released_on: record.released_on, image_url: record.image_url,
        content_digest: record.digest, retired_at: nil }
    end

    def upsert_returning_ids(model, rows)
      model.upsert_all(rows, unique_by: %i[collectible_type external_key], returning: %i[external_key id])
        .to_h { |row| [ row["external_key"], row["id"] ] }
    end

    def write_extensions(model, foreign_key, records, ids)
      return if model.nil?

      rows = records.map { |record| record.extension.merge(foreign_key => ids.fetch(record.external_key)) }
      model.upsert_all(rows, unique_by: foreign_key)
    end

    def tally(record)
      _id, digest, retired_at = @entries[record.external_key]
      if digest.nil? then @counts[:inserted] += 1
      elsif retired_at then @counts[:restored] += 1
      else @counts[:updated] += 1
      end
    end

    # A known entry whose record is malformed this run is kept as it was, not retired.
    def record_malformed(record)
      @counts[:malformed] += 1
      @seen << record.external_key if record.external_key
      Rails.logger.warn("catalog.refresh skipped malformed #{@collectible_type} record #{record.external_key.inspect}: #{record.error}")
    end

    def retire_unseen
      ids = @entries.filter_map { |key, (id, _digest, retired_at)| id if retired_at.nil? && !@seen.include?(key) }
      now = Time.current
      ids.each_slice(BATCH_SIZE) do |slice|
        # Bulk maintenance of global catalog rows: no callbacks or validations apply.
        Catalog::Entry.where(id: slice).update_all(retired_at: now, updated_at: now)
      end
      @counts[:retired] = ids.size
    end
end
