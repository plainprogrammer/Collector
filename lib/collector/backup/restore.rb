module Collector
  module Backup
    # backup:restore (spec 030 FR-2, FR-3, FR-8, decisions 3, 6, 7, 10; spec 081 decision 8): places a verified snapshot as
    # the primary database of a fresh volume, and a version 2 backup's prices snapshot as the prices database beside it, both
    # or neither. Everything before the placing is read-only on the volume except two temporary files (one per snapshot)
    # and their journals; neither database's path is opened, because opening the primary's would create the empty database
    # that the next db:prepare takes for a blank instance (research.md 2). Nothing is migrated here: the first boot's
    # db:prepare does it.
    #
    # The prices file is placed first and the primary second, so that a primary never stands without its prices. If the
    # primary can't be placed (its name was taken meanwhile, the disk filled), the prices file just placed is removed, so
    # the volume is as it was. A run killed between the two placings can't clean up and leaves the prices file alone: the
    # next run refuses the volume as not fresh and says to remove that file (spec 081 AC-5.9; #375 owns a start-up check).
    # @see file:release-and-deploy.md
    class Restore
      TEMPORARY = "collector-restore.partial".freeze
      TEMPORARY_PRICES = "collector-restore-prices.partial".freeze # the prices snapshot's temporary file, with the same suffixes
      RESTORE_SUFFIXES = [ "", "-journal" ].freeze # the temporary file is in rollback-journal mode: no -wal, no -shm (FR-6)
      MARGIN = 16 * 1024 * 1024 # room for the delete's journal and the rename, beyond the snapshot's own size

      Result = Data.define(:file, :volume, :manifest) do
        # The operator's report. A version 2 backup's second line gives both schema versions and both sets of counts; a
        # version 1 backup's says it holds no prices and that the first start creates an empty prices database.
        #
        # @return [String]
        def report
          counts = manifest.counts
          lines = [ "Restored #{File.basename(file)} into #{volume}.", "Taken #{manifest.taken_at} #{held_phrase} Compare these with what you expect before you start Collector." ]
          lines << "The backup holds no users: the first person to reach the restored instance becomes its admin." if counts.fetch("users").zero?
          lines << "Everyone signs in again, and pending bulk-removal Undos and selections are gone; no collection is lost."
          lines << "Start Collector now. With art matching on, press Build art index on the admin catalog page to rebuild the scanner's art index."
          lines.join("\n")
        end

        private
          def held_phrase
            counts = Backup.counts_phrase(manifest.counts)
            return "at schema version #{manifest.schema_version}; it holds #{counts}. The backup holds no prices; Collector's first start creates an empty prices database." unless manifest.prices

            "at schema version #{manifest.schema_version} (prices #{manifest.prices["schema_version"]}); it holds #{counts}; #{Backup.prices_phrase(manifest.prices["counts"])}."
          end
      end

      # @param file [String, Pathname] the backup file
      # @param databases [Databases] the volume's databases; one with a prices path is needed for a version 2 backup
      # @param release_versions [Array<String>] this release's primary migrations, read from its files
      # @param release_prices_versions [Array<String>] this release's prices migrations, read from its files
      def initialize(file:, databases: Databases.configured, release_versions: Backup.release_schema_versions,
        release_prices_versions: Backup.release_schema_versions(Rails.root, "db/prices_migrate"), free_space: FreeSpace.method(:bytes), checkpoint: ->(_step) { })
        @file = Pathname(file.to_s)
        @databases = databases
        @release_versions = release_versions
        @release_prices_versions = release_prices_versions
        @free_space = free_space
        @checkpoint = checkpoint
      end

      # Restores the backup: every check first, then the prices snapshot and the primary placed, both or neither (spec 030
      # FR-2; spec 081 decision 8). A version 1 backup places the primary only.
      #
      # @return [Result] the file, the volume and the backup's manifest, for the report
      # @raise [Refusal] when anything is wrong; the volume is then as it was
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
        manifest = read.manifest
        raise ArgumentError, "the backup holds prices but the configuration has no prices database" if manifest.prices && !@databases.prices

        temporaries = [ volume.join(TEMPORARY), (volume.join(TEMPORARY_PRICES) if manifest.prices) ]
        [ volume.join(TEMPORARY), volume.join(TEMPORARY_PRICES) ].each { Backup.remove(it, RESTORE_SUFFIXES) } # a stopped run's leftovers and their journals (FR-6)
        placed = prices_placed = false
        begin
          extract(temporaries, manifest)
          prepare(temporaries.first, manifest)
          prepare_prices(temporaries.last, manifest) if manifest.prices
          @checkpoint.call(:snapshot_ready)
          temporaries.compact.each { Backup.fsync_file(it) }
          if manifest.prices
            Backup.publish(temporaries.last, @databases.prices) { raise not_fresh }
            prices_placed = true
            @checkpoint.call(:prices_placed)
          end
          Backup.publish(temporaries.first, @databases.primary) do
            remove_placed_prices if prices_placed # so that the refusal lists only what was there before this run
            prices_placed = false
            raise not_fresh
          end
          placed = true
          Backup.fsync_directory(volume)
          Result.new(file: @file, volume:, manifest:)
        ensure
          unless placed
            temporaries.compact.each { Backup.remove(it, RESTORE_SUFFIXES) }
            remove_placed_prices if prices_placed
          end
        end
      rescue SQLite3::FullException, Errno::ENOSPC
        raise Refusal.new("The volume filled up while the backup was restored.", "Free some space or use a larger volume, then run this again. Nothing was changed.")
      end

      private
        # The prices file this run placed, and any sidecar: it is the run's own, because the volume was fresh and publish never
        # replaces a file.
        def remove_placed_prices
          Backup.remove(@databases.path(HELD.key(Archive::PRICES)))
        end

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

        # A volume that holds a prices file and no primary may be a killed restore's (spec 081 AC-5.9): the advice then says to
        # remove the file, and never to start Collector on it.
        def not_fresh
          names = @databases.occupied.map { it.basename.to_s }
          prices = names.select { it.start_with?(@databases.prices.basename.to_s) } if @databases.prices
          advice = if prices.present? && names.none? { it.start_with?(@databases.primary.basename.to_s) }
            "It may be the prices database of a restore that stopped: remove #{prices.first} and its -wal, -shm and -journal files, then restore again. " \
              "Never start Collector on this volume as it is (#375)."
          else
            "Restore onto a new, empty volume and start Collector on that. Nothing was changed."
          end
          Refusal.new("The volume at #{@databases.directory} isn't empty: it holds #{names.join(", ")}.", advice)
        end

        def refuse_without_room(volume, manifest)
          need = manifest.entries.sum { it[1] } + MARGIN
          free = @free_space.call(volume)
          return unless free && free < need

          raise Refusal.new("The volume at #{volume} has #{Backup.size_phrase(free)} free; the snapshot needs #{Backup.size_phrase(need)}.",
            "Free some space or use a larger volume.")
        end

        # The second pass over the archive: each snapshot's bytes go to its temporary file, created private (decision 7).
        # +temporaries+ is the primary's file, then the prices file for a version 2 backup.
        def extract(temporaries, manifest)
          ios = temporaries.compact.to_h { [ it, Backup.create_private(it) ] }
          primary_io, prices_io = ios.values
          Archive.read(@file) { |chunk, name| (name == Archive::PRICES ? prices_io : primary_io).write(chunk) }
          ios.each_value { |io| io.flush && io.fsync }
          sizes = temporaries.compact.map(&:size)
          raise damaged_inside unless sizes == manifest.entries.map { it[1] }
        ensure
          ios&.each_value(&:close)
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

        # The prices snapshot's checks: sound, no migration this release lacks, rollback-journal mode and the manifest's counts.
        # It holds no session, so nothing is ended in it.
        def prepare_prices(temporary, manifest)
          snapshot = Snapshot.new(temporary)
          snapshot.verify!
          check_schema(snapshot, @release_prices_versions, "prices schema version")
          snapshot.rollback_journal!
          raise Refusal.new("The restored database doesn't match the backup's counts.", "Use another copy of the backup.") unless snapshot.counts(Manifest::PRICES_COUNT_NAMES) == manifest.prices["counts"]

          Backup.fsync_file(temporary)
        rescue Snapshot::Damaged, Snapshot::OrphanRows
          raise damaged_inside
        end

        def check_schema(snapshot, release_versions = @release_versions, label = "schema version")
          versions = snapshot.schema_versions
          raise Snapshot::Damaged, "no migrations" if versions.empty?
          return if (versions - release_versions).empty?

          raise Refusal.new("#{@file.basename} was taken by a newer release of Collector (#{label} #{versions.max_by(&:to_i)}; this release has #{release_versions.max_by(&:to_i)}).",
            "Restore it onto that release or a newer one.")
        end

        def damaged_inside
          Refusal.new("The database inside #{@file.basename} is damaged.", "Use another copy of the backup.")
        end
    end
  end
end
