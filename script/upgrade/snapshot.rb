# A consolidated, read-only copy of a container's primary database (spec 031 decision 5, AC-2.4). A stopped container can
# leave a write-ahead log beside the main file, so the main file is never read alone: it is copied with any -wal and -shm
# into a scratch directory, opened there (SQLite replays the log) and written out whole with VACUUM INTO.
require "fileutils"
require "sqlite3"
require "tmpdir"

module Upgrade
  module Snapshot
    Missing = Class.new(StandardError)

    SUFFIXES = [ "", "-wal", "-shm" ].freeze

    def self.consolidate(source_dir, basename, target)
      main = File.join(source_dir, basename)
      raise Missing, "#{main} is missing: the volume holds no #{basename}" unless File.file?(main)

      Dir.mktmpdir("upgrade-copy") do |scratch|
        SUFFIXES.each do |suffix|
          source = File.join(source_dir, "#{basename}#{suffix}")
          FileUtils.cp(source, File.join(scratch, "#{basename}#{suffix}")) if File.file?(source)
        end
        database = SQLite3::Database.new(File.join(scratch, basename))
        begin
          database.execute("VACUUM INTO ?", [ target ])
        ensure
          database.close
        end
      end
      rollback_journal(target)
      target
    end

    def self.open(path) = SQLite3::Database.new(path, readonly: true)

    # The snapshot is a plain file: no -wal or -shm will appear beside it when it is opened (spec 030 research, section 3).
    def self.rollback_journal(path)
      database = SQLite3::Database.new(path)
      database.execute("PRAGMA journal_mode = DELETE")
    ensure
      database&.close
    end
    private_class_method :rollback_journal
  end
end
