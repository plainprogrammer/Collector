# One run of the daily price refresh for one price source (spec 089): asks the collectible's catalog source for the bulk
# file it already downloads, judges each quote against the current price and writes only what changed, and records the
# run (`PriceRefreshRun`). It makes no request outside that catalog source, never joins the prices database with the
# primary, and holds no network call or primary read inside a transaction on the prices database.
#
# Side effects: rows of `current_prices`, `price_changes`, `price_sources`, `price_series` and `price_refresh_runs`;
# the catalog source's download directory. It needs no `Current.account` (prices are global). Safe to run twice on one
# file: the second run is skipped as already applied, and a rerun of a failed run changes nothing it already wrote.
#
# @see file:prices.md
class Prices::Refresh
  # Printings per write transaction, and printings (their current prices) per removal slice and transaction: a few
  # thousand rows each, so the database is held briefly (spec 089 decision 7).
  BATCH_SIZE = 1_000

  # The largest share of the source's candidate current prices a run may remove in one day (spec 089 decision 4, ruled
  # by the maintainer on 2026-11-13). A GUESS until #366's run records measure the real daily share of prices that
  # disappear: a file that loses a tenth of the market in a day is far more likely truncated or damaged than a market
  # event. A real drop above it is refused, every day, until this constant moves.
  MAX_REMOVED_SHARE = Rational(1, 10)

  # The file can't be trusted to say prices are gone (decision 4, items 2 and 5); the run fails and nothing is removed.
  class GuardError < StandardError; end

  # @param source_key [String] a key of `Prices.sources`
  # @param job_id [String, nil] the Active Job id, so a re-run after a restart closes its own left-behind run
  def initialize(source_key, job_id: nil)
    @source_key = source_key
    @job_id = job_id
    @counts = Hash.new(0)
  end

  # Runs the refresh. The source is looked up and synced before any run exists (a run's source row is required), so an
  # unregistered key or a source that fails verification raises with no run recorded; every later failure ends the run
  # `failed` with its error and re-raises it for the job's retry rules.
  #
  # @return [PriceRefreshRun] finished, skipped or (when another run works) skipped as already running
  # @raise [ArgumentError, Prices::Sources::ConfigurationError] before a run exists
  # @raise [GuardError, Prices::Sources::IntegrityError, Zlib::Error, Catalog::Sources::Error, StandardError] after the run is recorded failed
  def call
    @source_class = Prices.source_class(@source_key)
    @source = PriceSource.sync!(@source_class)
    @series = PriceSeries.ensure!(@source_class.series)
    @run = PriceRefreshRun.start!(@source, job_id: @job_id)
    return @run unless @run.running?

    perform
    @run
  rescue StandardError => error
    @run.fail!(error, @counts) if @run&.running?
    raise
  end

  private
    def collectible_type = @source_class.collectible_type

    def perform
      return @run.skip!("the catalog has no printing of the type #{collectible_type} yet") unless Catalog::Entry.exists?(collectible_type:)

      catalog = Catalog.source_for(collectible_type)
      @languages = catalog.languages
      version = catalog.current_version(languages: @languages)
      @run.record_file!(version:, languages: @languages.join(","))
      applied = PriceRefreshRun.applied(@source, version, @run.languages).first
      return @run.skip!("#{version} already applied", run_on: applied.run_on) if applied

      catalog.progress = @run.method(:heartbeat) if catalog.respond_to?(:progress=)
      path = catalog.download(version, dir: Rails.configuration.x.catalog_download_dir.join(collectible_type))
      reader = @source_class.new
      @run_on = reader.reported_on(path)
      @run.update!(run_on: @run_on)
      latest = PriceRefreshRun.latest_run_on(@source)
      return @run.skip!("a later file (#{latest}) was already read; this one is dated #{@run_on}") if latest && @run_on < latest

      apply(reader, path)
      @run.finish!(@counts)
    end

    # Reads the file once, flushing a batch of printings at a time (decision 6), then handles absences (decision 4).
    def apply(reader, path)
      @seen = Set.new # [entry id, series id] judged this run: a duplicate quote is ignored, an unseen candidate is absent
      @unknown = Set.new
      @held_entries = Set.new
      @held_series = Set.new
      @untrusted = false
      @quotes_yielded = 0
      @pending = {}
      @pending_malformed = []

      reader.each_quote(path, languages: @languages) do |record|
        case record
        when Prices::Sources::Quote then queue_quote(record)
        when Prices::Sources::Malformed then queue_malformed(record)
        end
      end
      flush
      remove_absent
    end

    def queue_quote(quote)
      @quotes_yielded += 1
      flush if !@pending.key?(quote.external_key) && pending_size >= BATCH_SIZE # earlier batches stand when the next raises
      @series.fetch(quote.series) do
        raise Prices::Sources::ConfigurationError, "#{@source_class} yielded a quote of #{quote.series.inspect}, which it did not declare"
      end
      (@pending[quote.external_key] ||= []) << quote
    end

    def queue_malformed(record)
      @counts[:malformed] += 1
      Rails.logger.warn("prices.refresh skipped malformed #{record.external_key.inspect}: #{record.error}")
      flush if pending_size >= BATCH_SIZE
      @pending_malformed << record
    end

    # Printings and unreadable records waiting for the next flush. Both count toward BATCH_SIZE: a file of mostly
    # unreadable lines would otherwise pile up in memory and in one huge `IN` lookup of keys.
    def pending_size = @pending.size + @pending_malformed.size

    # Judges and writes the pending printings. The primary is read here, outside any transaction; the prices database
    # is read and written in one short transaction; the counts are tallied after it commits.
    def flush
      return if @pending.empty? && @pending_malformed.empty?

      keys = (@pending.keys + @pending_malformed.filter_map(&:external_key)).uniq
      ids = Catalog::Entry.where(collectible_type:, external_key: keys).pluck(:external_key, :id).to_h
      hold_malformed(ids)
      judged = []
      @pending.each do |key, quotes|
        id = ids[key]
        next @unknown << key unless id

        quotes.each do |quote|
          series_id = @series.fetch(quote.series).id
          judged << [ id, series_id, quote.cents ] if @seen.add?([ id, series_id ])
        end
      end
      write_judged(judged)
      @pending = {}
      @pending_malformed = []
      @counts[:unknown_printings] = @unknown.size
      @run.progress!(@counts)
    end

    # What a Malformed holds back from removal (decision 4, items 3 and 4): no key, the whole run; a key and no series (or
    # a series the source didn't declare), every series of the printing; a key and a series, that series.
    def hold_malformed(ids)
      @pending_malformed.each do |record|
        entry_id = ids[record.external_key]
        if record.external_key.nil? then @untrusted = true
        elsif entry_id.nil? then next
        elsif record.series.nil? || @series[record.series].nil? then @held_entries << entry_id
        else @held_series << [ entry_id, @series[record.series].id ]
        end
      end
    end

    def write_judged(judged)
      return if judged.empty?

      tally = Hash.new(0)
      PricesRecord.transaction do
        existing = CurrentPrice.where(price_source_id: @source.id, catalog_entry_id: judged.map(&:first).uniq)
          .pluck(:catalog_entry_id, :price_series_id, :cents).to_h { |entry_id, series_id, cents| [ [ entry_id, series_id ], cents ] }
        currents = []
        changes = []
        judged.each do |entry_id, series_id, cents|
          had = existing[[ entry_id, series_id ]]
          next tally[:unchanged] += 1 if had == cents

          tally[had ? :repriced : :added] += 1
          keys = { catalog_entry_id: entry_id, price_source_id: @source.id, price_series_id: series_id }
          currents << keys.merge(cents:, reported_on: @run_on, changed_on: @run_on)
          changes << keys.merge(recorded_on: @run_on, cents:)
        end
        CurrentPrice.upsert_all(currents, unique_by: CurrentPrice.primary_key) if currents.any?
        PriceChange.upsert_all(changes, unique_by: PriceChange.primary_key) if changes.any?
      end
      tally.each { |name, count| @counts[name] += count }
      @counts[:quotes_seen] += judged.size
    end

    # Absence is trusted only as far as the file is (spec 089 decision 4). The file has been read to the end here (a
    # reader's error would have left `#apply` already). Two walks over the source's candidate current prices by printing
    # id: the first counts the candidates and the absences, so the ceiling is judged on the whole; the second removes.
    def remove_absent
      raise GuardError, "the file yielded no valid quotes (#{@counts[:malformed]} malformed), so nothing was written or removed" if @quotes_yielded.zero?

      candidates = absent_clear = absent_held = 0
      each_candidate_slice do |rows|
        rows.each do |entry_id, series_id|
          candidates += 1
          next if @seen.include?([ entry_id, series_id ])

          held?(entry_id, series_id) ? absent_held += 1 : absent_clear += 1
        end
      end
      @counts[:removals_withheld] = absent_held
      return if absent_clear.zero?

      if absent_clear > candidates * MAX_REMOVED_SHARE
        @counts[:removals_withheld] += absent_clear
        raise GuardError, "#{absent_clear} of #{candidates} current prices are missing from the file, more than the #{(MAX_REMOVED_SHARE * 100).to_i} percent " \
                          "a day may lose, so nothing was removed. A file that loses that much in a day is usually truncated or damaged; a real, " \
                          "lasting drop is refused until Prices::Refresh::MAX_REMOVED_SHARE is raised."
      end

      each_candidate_slice { |rows| remove(rows.reject { |entry_id, series_id| @seen.include?([ entry_id, series_id ]) || held?(entry_id, series_id) }) }
    end

    def held?(entry_id, series_id) = @untrusted || @held_entries.include?(entry_id) || @held_series.include?([ entry_id, series_id ])

    # Yields the source's candidate current prices as [entry id, series id], a slice of BATCH_SIZE printings at a time,
    # by keyset on the printing id. A candidate's printing is a catalog entry of this type in a language of the run,
    # retired or not; one the primary lacks, or in a language not read, isn't asked about and is left out. The primary is
    # read outside any transaction, and each slice touches the run as progress.
    def each_candidate_slice
      last = 0
      loop do
        ids = CurrentPrice.where(price_source_id: @source.id).where("catalog_entry_id > ?", last).distinct.order(:catalog_entry_id).limit(BATCH_SIZE).pluck(:catalog_entry_id)
        break if ids.empty?

        last = ids.last
        languages = Catalog::Entry.where(collectible_type:, id: ids).pluck(:id, :language).to_h
        rows = CurrentPrice.where(price_source_id: @source.id, catalog_entry_id: ids).pluck(:catalog_entry_id, :price_series_id)
        yield rows.select { |entry_id, _series_id| @languages.include?(languages[entry_id]) }
        @run.progress!(@counts)
      end
    end

    # Deletes the current prices and records their blank history rows in ONE transaction: a price deleted without its row
    # would no longer be a candidate, and the removal would be lost for good. `delete_all` is bulk maintenance of
    # global rows by key; no callbacks or validations apply.
    def remove(rows)
      return if rows.empty?

      PricesRecord.transaction do
        rows.group_by(&:first).each do |entry_id, pairs|
          CurrentPrice.where(price_source_id: @source.id, catalog_entry_id: entry_id, price_series_id: pairs.map(&:last)).delete_all
        end
        PriceChange.upsert_all(rows.map { |entry_id, series_id| { catalog_entry_id: entry_id, price_source_id: @source.id, price_series_id: series_id, recorded_on: @run_on, cents: nil } },
          unique_by: PriceChange.primary_key)
      end
      @counts[:removed] += rows.size
    end
end
