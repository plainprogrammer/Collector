module Collector
  module Backup
    # backup:create (spec 030 FR-1, decisions 1, 5, 7, 13): a verified, private, atomically named backup of the primary
    # and prices databases (spec 081 decision 7), taken while the app runs. The two snapshots are taken one after the other,
    # not at one moment. Everything it writes is in +directory+, under a .partial name created 0600, until the finished
    # archive is hard-linked to its final name, which it never replaces.
    class Create
      Result = Data.define(:path, :bytes, :schema_version, :counts, :prices_schema_version, :prices_counts, :seconds) do
        # The operator's report: five lines, the schema line and the counts line naming both databases (AC-4.7).
        #
        # @return [String]
        def report
          [ "Backup written: #{path}", "Size: #{Backup.size_phrase(bytes)}", "Schema version: #{schema_version}; prices #{prices_schema_version}",
            "Holds: #{Backup.counts_phrase(counts)}; #{Backup.prices_phrase(prices_counts)}", format("Took: %.1f s", seconds) ].join("\n")
        end
      end

      # The three temporary names, and the sidecars SQLite may leave beside one a killed run was using:
      # collector-backup-<time>.(tar.gz|sqlite3|prices.sqlite3).<16 hex>.partial[-journal|-wal|-shm] (contracts/archive.md).
      PARTIAL = /\Acollector-backup-\d{8}T\d{6}Z\.(?:tar\.gz|sqlite3|prices\.sqlite3)\.\h{16}\.partial(?:-journal|-wal|-shm)?\z/

      # @param directory [String, Pathname] an existing, writable directory
      # @param source [String, Pathname] the primary database file
      # @param prices_source [String, Pathname] the prices database file
      def initialize(directory:, source: Databases.configured.primary, prices_source: Databases.configured.prices, clock: Time, free_space: FreeSpace.method(:bytes),
        checkpoint: ->(_step) { })
        @directory = Pathname(directory.to_s)
        @source = Pathname(source)
        @prices_source = Pathname(prices_source)
        @clock = clock
        @free_space = free_space
        @checkpoint = checkpoint
      end

      # Takes, verifies and archives both databases.
      #
      # @return [Result]
      # @raise [Refusal] for each condition the operator can act on, with nothing left in the directory
      def call
        translating do
          started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          check_destination
          taken_at = Time.at(@clock.now.to_i).utc
          final = @directory.join("collector-backup-#{taken_at.strftime("%Y%m%dT%H%M%SZ")}.tar.gz")
          raise name_taken(final) if final.exist?

          sweep_stale_partials
          manifest = make(final, taken_at)
          Result.new(path: final, bytes: final.size, schema_version: manifest.schema_version, counts: manifest.counts,
            prices_schema_version: manifest.prices["schema_version"], prices_counts: manifest.prices["counts"],
            seconds: Process.clock_gettime(Process::CLOCK_MONOTONIC) - started)
        end
      end

      private
        def check_destination
          raise Refusal.new("#{@directory} doesn't exist or isn't a directory.", "Create it, or give another directory.") unless @directory.directory?
          unless @directory.writable? && @directory.executable?
            raise Refusal.new("#{@directory} isn't writable by the user Collector runs as (uid #{Process.uid}).",
              "Make it writable by that user (for example with chown 1000:1000), or give another directory.")
          end
          raise no_source unless @source.file?
          raise no_prices unless @prices_source.file?

          need = 2 * (@source.size + @prices_source.size)
          free = @free_space.call(@directory)
          return unless free && free < need

          raise Refusal.new("#{@directory} has #{Backup.size_phrase(free)} free; a backup needs about #{Backup.size_phrase(need)} (twice the two databases' sizes).",
            "Free some space, or give a directory on a larger disk.")
        end

        # A killed run leaves a .partial file; a younger one may belong to a run in progress (decision 7).
        def sweep_stale_partials
          cutoff = Time.now - STALE_PARTIAL_SECONDS
          @directory.children.each do |child|
            FileUtils.rm_f(child) if PARTIAL.match?(child.basename.to_s) && child.file? && child.mtime < cutoff
          end
        end

        def make(final, taken_at)
          token = SecureRandom.hex(8)
          snapshot_file = @directory.join("#{final.basename(".tar.gz")}.sqlite3.#{token}.partial")
          prices_file = @directory.join("#{final.basename(".tar.gz")}.prices.sqlite3.#{token}.partial")
          archive_file = @directory.join("#{final.basename}.#{token}.partial")
          published = false
          @stage = :primary
          Backup.create_private(snapshot_file).close
          @checkpoint.call(:snapshot_starting)
          Snapshot.take(source: @source, into: snapshot_file)
          @checkpoint.call(:snapshot_written)
          snapshot = Snapshot.new(snapshot_file)
          snapshot.rollback_journal! # before verify!: a WAL header would make verify!'s open leave -shm and -wal beside the file
          snapshot.verify!
          @stage = :prices
          Backup.create_private(prices_file).close
          @checkpoint.call(:prices_starting)
          Snapshot.take(source: @prices_source, into: prices_file)
          prices = Snapshot.new(prices_file)
          prices.rollback_journal!
          prices.verify!
          @checkpoint.call(:prices_written)
          manifest = Manifest.for(snapshot, taken_at:, prices:)
          Archive.write(archive_file, manifest:, snapshot: snapshot_file, prices: prices_file)
          read_back(archive_file)
          @checkpoint.call(:archive_written)
          Backup.publish(archive_file, final) { raise name_taken(final) }
          published = true
          Backup.fsync_directory(@directory)
          manifest
        ensure
          Backup.remove(snapshot_file) if snapshot_file
          Backup.remove(prices_file) if prices_file
          Backup.remove(archive_file) if archive_file && !published
        end

        # The archive is read back whole before it counts as a backup: one that can't be restored is never reported as made.
        # It is still under its .partial name, which Archive.read refuses for anyone else (plan-review C1).
        def read_back(archive_file)
          Archive.read(archive_file, allow_partial: true)
        rescue Refusal
          raise Refusal.new("The backup file just written doesn't read back, so no backup was made.", "Run it again; if it keeps failing, check the disk.")
        end

        def translating
          yield
        rescue Snapshot::Damaged
          raise Refusal.new("#{database_name} reports damage, so no backup was made.",
            "Restore the last good backup, and ask each collector to download their export (Export collection) while the instance still answers.")
        rescue Snapshot::OrphanRows => error
          raise Refusal.new("#{database_name} fails its foreign-key check (#{error.count} #{error.count == 1 ? "row" : "rows"}), so no backup was made.",
            "Each collector's export (Export collection) is still available; a backup of an instance in this state would be refused when restored.")
        rescue SQLite3::BusyException
          raise Refusal.new("The database stayed busy for more than #{BUSY_TIMEOUT_MS / 1000} seconds.", "Run it again in a quieter moment.")
        rescue SQLite3::FullException, Errno::ENOSPC
          raise Refusal.new("The disk filled up while the backup was written.", "Free some space and run it again.")
        rescue SQLite3::CantOpenException
          raise Refusal.new("The database couldn't be opened or the backup couldn't be written.",
            "Check that #{@source}, #{@prices_source} and #{@directory} are readable by the user Collector runs as.")
        end

        # Which database the stage being handled belongs to, for the two refusals that name it.
        def database_name = @stage == :prices ? "The prices database" : "The database"

        def name_taken(final)
          Refusal.new("A file named #{final.basename} already exists in #{@directory}; it was left as it is.", "Run it again in a second, or give another directory.")
        end

        def no_prices
          Refusal.new("There is no prices database at #{@prices_source}.", "Start Collector once on this release, which creates it, then run this again.")
        end

        def no_source
          Refusal.new("There is no primary database at #{@source}.", "Run this inside the running Collector container, with its storage volume mounted.")
        end
    end
  end
end
