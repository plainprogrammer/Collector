module Collector
  module Backup
    # backup:restore (spec 030 FR-2, FR-3, FR-8, decisions 3, 6, 7, 10): places a verified snapshot as the primary database
    # of a fresh volume. Everything before the final rename is read-only on the volume except one temporary file and its
    # journal; the primary's path is never opened, because opening it would create the empty database that the next
    # db:prepare takes for a blank instance (research.md 2). Nothing is migrated here: the first boot's db:prepare does it.
    class Restore
      TEMPORARY = "collector-restore.partial".freeze
      MARGIN = 16 * 1024 * 1024 # room for the delete's journal and the rename, beyond the snapshot's own size

      Result = Data.define(:file, :volume, :manifest) do
        def report
          counts = manifest.counts
          lines = [ "Restored #{File.basename(file)} into #{volume}.",
            "Taken #{manifest.taken_at} at schema version #{manifest.schema_version}; it holds #{Backup.counts_phrase(counts)}. " \
              "Compare these with what you expect before you start Collector." ]
          lines << "The backup holds no users: the first person to reach the restored instance becomes its admin." if counts.fetch("users").zero?
          lines << "Everyone signs in again, and pending bulk-removal Undos and selections are gone; no collection is lost."
          lines << "Start Collector now. With art matching on, press Build art index on the admin catalog page to rebuild the scanner's art index."
          lines.join("\n")
        end
      end

      def initialize(file:, databases: Databases.configured, release_versions: Backup.release_schema_versions,
        free_space: FreeSpace.method(:bytes), checkpoint: ->(_step) { })
        @file = Pathname(file.to_s)
        @databases = databases
        @release_versions = release_versions
        @free_space = free_space
        @checkpoint = checkpoint
      end

      def call
        volume = @databases.directory
        raise Refusal.new("The storage directory #{volume} doesn't exist.", "Mount the volume where Collector expects it, then run this again.") unless volume.directory?

        refuse_unless_fresh
        raise Refusal.new("There is no file at #{@file}.", "Check the path as the container sees it; copy the backup in first.") unless @file.file?

        # docker cp makes root-owned files and the backup is 0600 (decision 4): a file or a volume the user can't use is the
        # slip to expect, so it is named here and not left to an Errno::EACCES (plan-review M3).
        raise unreadable unless @file.readable?
        raise unwritable(volume) unless volume.writable? && volume.executable?

        # The kind, completeness and version, then the room as soon as the manifest is read (FR-2 lists it before the
        # checksum, which the same pass computes), then the checksum: all decided before anything is written.
        read = Archive.read(@file, on_manifest: ->(manifest) { refuse_without_room(volume, manifest) })
        temporary = volume.join(TEMPORARY)
        Backup.remove(temporary) # a stopped run's leftover and its journal (FR-6)
        placed = false
        begin
          extract(temporary, read.manifest)
          prepare(temporary, read.manifest)
          @checkpoint.call(:snapshot_ready)
          Backup.publish(temporary, @databases.primary) { raise not_fresh }
          placed = true
          Backup.fsync_directory(volume)
          Result.new(file: @file, volume:, manifest: read.manifest)
        ensure
          Backup.remove(temporary) unless placed
        end
      rescue SQLite3::FullException, Errno::ENOSPC
        raise Refusal.new("The volume filled up while the backup was restored.", "Free some space or use a larger volume, then run this again. Nothing was changed.")
      end

      private
        def refuse_unless_fresh
          raise not_fresh if @databases.occupied.any?
        end

        def unreadable
          Refusal.new("#{@file} can't be read by the user Collector runs as (uid #{Process.uid}).",
            "Give it to that user (chown 1000:1000), as the README's restore steps do, then run this again. Nothing was changed.")
        end

        def unwritable(volume)
          Refusal.new("The volume at #{volume} isn't writable by the user Collector runs as (uid #{Process.uid}).",
            "Give the volume to that user (chown 1000:1000), then run this again. Nothing was changed.")
        end

        def not_fresh
          Refusal.new("The volume at #{@databases.directory} isn't empty: it holds #{@databases.occupied.map { it.basename.to_s }.join(", ")}.",
            "Restore onto a new, empty volume and start Collector on that. Nothing was changed.")
        end

        def refuse_without_room(volume, manifest)
          need = manifest.snapshot_bytes + MARGIN
          free = @free_space.call(volume)
          return unless free && free < need

          raise Refusal.new("The volume at #{volume} has #{Backup.size_phrase(free)} free; the snapshot needs #{Backup.size_phrase(need)}.",
            "Free some space or use a larger volume.")
        end

        # The second pass over the archive: the snapshot's bytes go to the temporary file, created private (decision 7).
        def extract(temporary, manifest)
          file = Backup.create_private(temporary)
          Archive.read(@file) { file.write(it) }
          file.flush
          file.fsync
          raise damaged_inside unless temporary.size == manifest.snapshot_bytes
        ensure
          file&.close
        end

        # FR-2's checks in order, then ending sessions, rollback-journal mode, and agreement with the manifest.
        def prepare(temporary, manifest)
          snapshot = Snapshot.new(temporary)
          snapshot.verify!
          check_schema(snapshot)
          snapshot.end_sessions!
          snapshot.rollback_journal!
          snapshot.verify! # the clearing leaves no foreign-key violation (AC-2.1)
          raise Refusal.new("The restored database doesn't match the backup's counts.", "Use another copy of the backup.") unless snapshot.counts == manifest.counts

          Backup.fsync_file(temporary)
        rescue Snapshot::Damaged, Snapshot::OrphanRows
          raise damaged_inside
        end

        def check_schema(snapshot)
          versions = snapshot.schema_versions
          raise Snapshot::Damaged, "no migrations" if versions.empty?
          return if (versions - @release_versions).empty?

          raise Refusal.new("#{@file.basename} was taken by a newer release of Collector (schema version #{versions.max_by(&:to_i)}; this release has #{@release_versions.max_by(&:to_i)}).",
            "Restore it onto that release or a newer one.")
        end

        def damaged_inside
          Refusal.new("The database inside #{@file.basename} is damaged.", "Use another copy of the backup.")
        end
    end
  end
end
