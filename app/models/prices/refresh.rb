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

    # Filled in by the next phases.
    def apply(_reader, _path); end
end
