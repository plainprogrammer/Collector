module Collector
  module Backup
    # One SQLite file that is the commands' own (a snapshot being written, or the restore's temporary file). Always opened
    # with SQLite3::Database and never Active Record: the Rails adapter sets journal_mode WAL on every connection, which
    # would convert the file and leave -wal and -shm beside it (decision 6, research.md 4). No open creates a missing file.
    class Snapshot
      Damaged = Class.new(StandardError) # the file can't be read as a sound Collector database

      class OrphanRows < StandardError
        attr_reader :count

        def initialize(count)
          @count = count
          super("#{count} rows fail the foreign-key check")
        end
      end

      attr_reader :path

      # One read transaction, so a WAL database's writers keep going (decision 1). +into+ must be absent or an empty file.
      def self.take(source:, into:)
        database = SQLite3::Database.new(source.to_s, readwrite: true)
        database.busy_timeout = BUSY_TIMEOUT_MS
        database.execute("VACUUM INTO ?", [ into.to_s ])
      rescue SQLite3::CorruptException, SQLite3::NotADatabaseException => error
        raise Damaged, error.message
      ensure
        database&.close
      end

      def initialize(path)
        @path = Pathname(path)
      end

      # SQLite's integrity check, then its foreign-key check (decision 7). Proves this file sound, not the file it was
      # copied from: VACUUM INTO rebuilds indexes (decision 7). foreign_keys is set explicitly because SQLite's default is
      # off (decision 6), though foreign_key_check reports violations either way.
      def verify!
        with(readonly: true) do |database|
          database.execute("PRAGMA foreign_keys = ON")
          problems = database.execute("PRAGMA integrity_check").flatten
          raise Damaged, problems.first(3).join("; ") unless problems == [ "ok" ]

          # One result per broken key, so a row with two broken keys counts once: the count is of rows.
          rows = database.execute("PRAGMA foreign_key_check").map { it.first(2) }.uniq
          raise OrphanRows.new(rows.size) if rows.any?
        end
      end

      # Counts only, never a name or an address (hosted-door rule 2, AC-1.7). Cross-tenant by nature: it counts the instance.
      def counts
        with(readonly: true) do |database|
          %w[accounts users lots].to_h { |table| [ table, database.get_first_value("SELECT COUNT(*) FROM #{table}") ] }
        end
      end

      def schema_versions
        with(readonly: true) { |database| database.execute("SELECT version FROM schema_migrations").flatten }
      end

      # Ends every session with foreign keys on, so the database cascades to bulk_removals, bulk_selections and, through
      # them, bulk_selection_marks (decision 3, FR-3). journal_mode is set first so the delete can't make a WAL file.
      def end_sessions!
        with do |database|
          database.execute("PRAGMA journal_mode = DELETE")
          database.execute("PRAGMA foreign_keys = ON")
          database.execute("DELETE FROM sessions")
        end
      end

      def rollback_journal!
        with { |database| database.execute("PRAGMA journal_mode = DELETE") }
        [ "-wal", "-shm", "-journal" ].each { FileUtils.rm_f("#{path}#{it}") }
        raise Damaged, "the file is not in rollback-journal mode" unless rollback_journal?
      end

      # Header bytes 18 and 19 are 1 for rollback-journal mode and 2 for WAL.
      def rollback_journal? = File.binread(path, 2, 18).bytes == [ 1, 1 ]

      private
        def with(readonly: false)
          database = SQLite3::Database.new(path.to_s, readonly ? { readonly: true } : { readwrite: true })
          database.busy_timeout = BUSY_TIMEOUT_MS
          yield database
        rescue SQLite3::CorruptException, SQLite3::NotADatabaseException, SQLite3::SQLException => error
          raise Damaged, error.message
        ensure
          database&.close
        end
    end
  end
end
