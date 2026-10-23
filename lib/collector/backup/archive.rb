module Collector
  module Backup
    # The backup file: a gzip'd ustar tar of manifest.json then primary.sqlite3 (decision 5, contracts/archive.md).
    # Written with Gem::Package::TarWriter, as bin/fetch-ocr-engine's library reads a tarball with TarReader. The reader is
    # this module's own, because what counts as "not a backup" and what as "incomplete" (FR-2, AC-3.1, AC-3.3) must be
    # exact, and is tested (research.md 6). Compression is the fastest level: the bar of decision 13 is for a NAS's CPU.
    module Archive
      MANIFEST = "manifest.json".freeze
      SNAPSHOT = "primary.sqlite3".freeze
      GZIP_MAGIC = "\x1F\x8B".b.freeze
      GZIP_HEADER_BYTES = 10 # the fixed part of a gzip header; a file shorter than this was cut inside it
      BLOCK = 512
      CHUNK = 1024 * 1024
      MANIFEST_LIMIT = 64 * 1024

      Result = Data.define(:manifest, :sha256, :bytes)

      def self.write(path, manifest:, snapshot:)
        snapshot = Pathname(snapshot)
        file = Backup.create_private(path)
        gzip = Zlib::GzipWriter.new(file, Zlib::BEST_SPEED)
        tar = Gem::Package::TarWriter.new(gzip)
        text = manifest.to_json
        tar.add_file_simple(MANIFEST, 0o600, text.bytesize) { it.write(text) }
        tar.add_file_simple(SNAPSHOT, 0o600, snapshot.size) { |entry| File.open(snapshot, "rb") { |source| IO.copy_stream(source, entry) } }
        tar.close
        gzip.finish
        file.flush
        file.fsync
      ensure
        file&.close
      end

      # Reads the whole archive once and writes nothing, so a refusal is decided before the volume is touched (FR-2). The
      # block, when given, gets each chunk of the snapshot (Restore's second pass writes them to its temporary file).
      # +allow_partial+ lets Create read back the archive it wrote under its own .partial name; for anyone else a .partial
      # name means the run that made the file didn't finish. +on_manifest+ is called with the manifest of a known version
      # as soon as it is parsed, before the snapshot is read (Restore checks the room there, as FR-2 orders).
      def self.read(path, allow_partial: false, on_manifest: nil, &sink)
        name = File.basename(path.to_s)
        File.open(path, "rb") do |file|
          raise not_a_backup(file, name) unless file.read(2) == GZIP_MAGIC

          file.rewind
          gzip = begin
            Zlib::GzipReader.new(file)
          rescue Zlib::Error
            # It starts like gzip: a file that ends inside the 10-byte header claims to be one and stops (contracts/archive.md).
            raise(file.size < GZIP_HEADER_BYTES ? incomplete(name) : not_a_backup(file, name))
          end
          read_entries(gzip, name, allow_partial:, on_manifest:, &sink)
        end
      rescue Zlib::Error
        raise incomplete(name)
      end

      def self.read_entries(gzip, name, allow_partial:, on_manifest:, &sink)
        manifest_size = entry_size(gzip, MANIFEST, name)
        raise incomplete(name) if !allow_partial && File.extname(name) == ".partial" # it starts as a backup; the run that made it didn't finish
        raise not_a_backup(nil, name) if manifest_size > MANIFEST_LIMIT

        manifest_text = read_exactly(gzip, manifest_size, name)
        skip_padding(gzip, manifest_size, name)
        manifest, unknown = parse_manifest(manifest_text, name)
        on_manifest&.call(manifest) if manifest
        snapshot_size = entry_size(gzip, SNAPSHOT, name)
        digest = Digest::SHA256.new
        remaining = snapshot_size
        while remaining.positive?
          chunk = gzip.read([ CHUNK, remaining ].min) or raise incomplete(name)
          digest << chunk
          sink&.call(chunk)
          remaining -= chunk.bytesize
        end
        skip_padding(gzip, snapshot_size, name)
        gzip.read # the end blocks
        gzip.read(1) # zlib checks the stream's CRC and length on the first read past the end, not on the read that reaches it
        raise unknown_version(unknown, name) if unknown
        raise changed(name) unless digest.hexdigest == manifest.snapshot_sha256 && snapshot_size == manifest.snapshot_bytes

        Result.new(manifest:, sha256: digest.hexdigest, bytes: snapshot_size)
      end

      def self.parse_manifest(text, name)
        [ Manifest.parse(text), nil ]
      rescue Manifest::UnknownVersion => unknown
        [ nil, unknown ]
      rescue Manifest::Invalid
        raise not_a_backup(nil, name)
      end

      # The size of the next entry, which must be the regular file +expected+ in a ustar block with a good checksum.
      def self.entry_size(gzip, expected, name)
        block = gzip.read(BLOCK)
        valid = block && block.bytesize == BLOCK && block.byteslice(257, 5) == "ustar" && checksum_ok?(block) &&
          block.byteslice(0, 100).unpack1("Z*") == expected && [ "0", "\0" ].include?(block.byteslice(156, 1))
        raise not_a_backup(nil, name) unless valid

        block.byteslice(124, 12).unpack1("Z*").strip.to_i(8)
      end

      def self.checksum_ok?(block)
        stored = block.byteslice(148, 8).unpack1("Z*").strip.to_i(8)
        stored == block.bytes.sum - block.byteslice(148, 8).bytes.sum + (" ".ord * 8)
      end

      def self.read_exactly(gzip, size, name)
        data = gzip.read(size)
        raise incomplete(name) unless data && data.bytesize == size

        data
      end

      def self.skip_padding(gzip, size, name)
        padding = (BLOCK - size % BLOCK) % BLOCK
        read_exactly(gzip, padding, name) if padding.positive?
      end

      # An export file is the likeliest wrong file (a collector's, not the instance's), so it gets its own sentence.
      def self.not_a_backup(file, name)
        head = file ? file.tap(&:rewind).read(4096).to_s.b : "".b
        if head.lstrip.start_with?("{") && head.include?('"format_version"')
          Refusal.new("#{name} is a Collector export file, not a backup.", "Import it in the app with Import collection (More, then Import collection).")
        else
          Refusal.new("#{name} isn't a Collector backup.", "Give a collector-backup-….tar.gz file made by backup:create.")
        end
      end

      def self.incomplete(name) = Refusal.new("#{name} is incomplete; it was cut short or is still being written.", "Take the backup again, or copy it again.")

      def self.changed(name) = Refusal.new("#{name} doesn't match its checksum; it was changed or damaged after it was made.", "Use another copy of the backup.")

      def self.unknown_version(unknown, name)
        known = FORMAT_VERSIONS.join(", ")
        Refusal.new("#{name} uses backup format version #{unknown.version}; this release restores #{FORMAT_VERSIONS.one? ? "version" : "versions"} #{known}.",
          "Restore it with a release that knows that version.")
      end

      private_class_method :read_entries, :parse_manifest, :entry_size, :checksum_ok?, :read_exactly, :skip_padding, :not_a_backup, :incomplete, :changed, :unknown_version
    end
  end
end
