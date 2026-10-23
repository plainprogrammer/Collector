require "digest"
require "fileutils"
require "json"
require "pathname"
require "securerandom"
require "sqlite3"
require "zlib"
require "rubygems/package"

require_relative "backup/refusal"
require_relative "backup/databases"
require_relative "backup/free_space"
require_relative "backup/manifest"
require_relative "backup/archive"
require_relative "backup/snapshot"
require_relative "backup/create"
require_relative "backup/restore"

module Collector
  # Back up and restore an instance (spec 030, ADR 0024, docs/backup-restore.md). The operator's two commands,
  # lib/tasks/backup.rake, run before the application is initialized and don't depend on Rake's :environment: no
  # initializers, no Solid* connection, no secret_key_base (research.md 1 and 2), and no Active Record connection that
  # could create the primary's file (FR-8). So this library needs only the standard library, the sqlite3 gem and, for the
  # database paths, Rails.root and config/database.yml; it is required by path and isn't autoloaded (config/application.rb).
  module Backup
    FORMAT_VERSIONS = [ 1 ].freeze # the backup format versions this release restores (decision 5, AC-3.4)
    FORMAT_VERSION = FORMAT_VERSIONS.last # the one backup:create writes
    BUSY_TIMEOUT_MS = 5_000 # the database's own busy timeout (config/database.yml), for the commands' direct connections
    STALE_PARTIAL_SECONDS = 24 * 60 * 60 # a .partial file older than this is a dead run's (decision 7, AC-1.6)
    TEMPORARY_MODE = 0o600

    # The one argument of a task, or the refusal that says how to give it (a comma makes Rake read a second argument).
    def self.argument(args, name, usage)
      value = args[name].to_s
      raise Refusal.new("No #{name} was given.", "Run: #{usage}.") if value.empty?
      raise Refusal.new("The #{name} argument contains a comma, which Rake reads as a second argument.", "Use a path without a comma.") if args.extras.any?

      value
    end

    # A task's body: a refusal prints its two sentences on stderr and exits 1, the only failure status (AC-3.8, FR-4). A
    # system or SQLite error that no command named (an unreadable file or an unwritable volume the commands didn't check,
    # a failing disk) ends the same way: what stopped it, and that it left nothing half-made (each command removes its own
    # temporary files and places nothing until every check has passed; an error after the database was placed, such as
    # the directory fsync, must not claim "nothing was changed"), never the exception class or its frames.
    def self.run
      yield
    rescue Refusal => refusal
      warn refusal.problem, refusal.advice
      exit 1
    rescue SystemCallError, SQLite3::Exception => error
      warn "The command stopped: #{stopped_text(error)}.",
        "It left nothing half-made; check that the directories and files involved are readable and writable by the user Collector runs as (uid #{Process.uid}) and have room, then run it again."
      exit 1
    end

    # An error's own words without Ruby's "@ rb_sysopen - /path" tail, capitalised: "Permission denied".
    def self.stopped_text(error)
      error.message.split(/ [@-] /).first.to_s.strip.sub(/\A./, &:upcase)
    end

    def self.size_phrase(bytes)
      units = %w[bytes KB MB GB TB]
      value = bytes.to_f
      index = 0
      while value >= 1024 && index < units.size - 1
        value /= 1024
        index += 1
      end
      index.zero? ? "#{bytes} #{bytes == 1 ? "byte" : "bytes"}" : format("%.1f %s", value, units[index])
    end

    def self.counts_phrase(counts)
      parts = %w[accounts users lots].map { |name| "#{counts.fetch(name)} #{counts.fetch(name) == 1 ? name.chomp("s") : name}" }
      "#{parts[0..-2].join(", ")} and #{parts.last}"
    end

    # The release's migrations as the framework finds them: the digits that start each file's name. Read from the files,
    # never through a connection (FR-8); primary's migrations_paths is the default, db/migrate.
    def self.release_schema_versions(root = Rails.root)
      Dir[root.join("db/migrate/**/[0-9]*_*.rb").to_s].filter_map { File.basename(it)[/\A(\d+)_/, 1] }.sort_by(&:to_i)
    end

    # A new, empty file readable by its owner only from the moment it exists (decision 7). Returns it open for writing.
    def self.create_private(path)
      # binmode: File::BINARY alone leaves the IO's encodings alone, and Rails' default_internal would then transcode bytes.
      File.open(path, File::WRONLY | File::CREAT | File::EXCL | File::BINARY, TEMPORARY_MODE).tap(&:binmode)
    end

    # Removes one of the commands' own temporary files and the sidecars named by +suffixes+ beside it (FR-6): the create's
    # files may have all of SQLite's, the restore's has only a rollback journal.
    def self.remove(path, suffixes = [ "", "-journal", "-wal", "-shm" ])
      suffixes.each { |suffix| FileUtils.rm_f("#{path}#{suffix}") }
    end

    def self.fsync_file(path)
      File.open(path, "r") { it.fsync }
    end

    # Where the platform or the share allows it (decision 7); a failure here never fails the run.
    def self.fsync_directory(path)
      File.open(path, "r") { it.fsync }
    rescue Errno::EINVAL, Errno::ENOTSUP, Errno::EISDIR, Errno::EACCES, Errno::EPERM
      nil
    end

    # Puts +from+ at +to+ and never replaces a file that is already there: a hard link fails on a clash where a rename
    # would overwrite. Some shares can't link; there the existence check and the rename are all there is. The block runs
    # when +to+ is taken.
    def self.publish(from, to, &on_clash)
      File.link(from, to)
      File.unlink(from)
    rescue Errno::EEXIST
      on_clash.call
    rescue Errno::EPERM, Errno::ENOTSUP, Errno::EOPNOTSUPP, Errno::EMLINK, Errno::EXDEV
      return on_clash.call if File.exist?(to)

      File.rename(from, to)
    end
  end
end
