require "rails_helper"

RSpec.describe Collector::Backup::Archive, :backup do
  let(:payload) { Random.bytes(3 * 1024 * 1024 + 17) } # not a multiple of 512, several chunks, and nothing SQLite
  let(:snapshot) { scratch_path("primary.sqlite3").tap { it.binwrite(payload) } }
  let(:fields) do
    { backup_format_version: 1, taken_at: "2026-10-21T14:21:00Z", schema_version: "20261020100002", snapshot_bytes: payload.bytesize,
      snapshot_sha256: Digest::SHA256.hexdigest(payload), counts: { "accounts" => 1, "users" => 1, "lots" => 2 } }
  end
  let(:manifest) { Collector::Backup::Manifest.new(**fields) }
  let(:archive) { scratch("archives").join("collector-backup-20261021T142100Z.tar.gz").tap { described_class.write(it, manifest:, snapshot:) } }

  describe ".write" do
    it "makes a private gzip'd tar of manifest.json then primary.sqlite3 and nothing else that the system tar reads (AC-1.4)", :aggregate_failures do
      listing, status = Open3.capture2("tar", "-tzf", archive.to_s)
      expect(status).to be_success
      expect(listing.lines(chomp: true)).to eq(%w[manifest.json primary.sqlite3])
      expect(archive.stat.mode & 0o777).to eq(0o600)

      Open3.capture2("tar", "-xzf", archive.to_s, "-C", scratch("unpacked").to_s)
      expect(scratch("unpacked").join("primary.sqlite3").binread).to eq(payload)
      expect(Collector::Backup::Manifest.parse(scratch("unpacked").join("manifest.json").read)).to eq(manifest)
    end

    it "never replaces a file that is there" do
      archive
      expect { described_class.write(archive, manifest:, snapshot:) }.to raise_error(Errno::EEXIST)
    end
  end

  describe ".read" do
    it "reads the whole archive once, yielding the snapshot's bytes, and reports what it saw", :aggregate_failures do
      chunks = []
      result = described_class.read(archive) { chunks << it }

      expect(chunks.join.b).to eq(payload.b)
      expect(result).to have_attributes(manifest:, sha256: fields[:snapshot_sha256], bytes: payload.bytesize)
    end

    it "writes nothing", :aggregate_failures do
      before = archive.dirname.children.map { [ it.basename.to_s, it.size ] }
      described_class.read(archive)
      expect(archive.dirname.children.map { [ it.basename.to_s, it.size ] }).to eq(before)
    end

    it "calls a file cut short incomplete (AC-3.1)", :aggregate_failures do
      cut = scratch("cut").join(archive.basename).tap { it.binwrite(archive.binread[0...-100]) }
      refusal = refusal_of { described_class.read(cut) }

      expect(refusal.problem).to eq("#{cut.basename} is incomplete; it was cut short or is still being written.")
      expect(refusal.advice).to eq("Take the backup again, or copy it again.")
    end

    it "calls a file whose gzip checksum fails incomplete (AC-3.1)" do
      damaged = archive.binread
      damaged.setbyte(-8, damaged.getbyte(-8) ^ 0xFF) # the gzip footer's CRC
      broken = scratch("crc").join(archive.basename).tap { it.binwrite(damaged) }

      expect(refusal_of { described_class.read(broken) }.problem).to include("is incomplete")
    end

    it "calls an intact file named *.partial incomplete, because the run that made it didn't finish (AC-3.1)" do
      partial = scratch("partial").join("#{archive.basename}.0123456789abcdef.partial").tap { it.binwrite(archive.binread) }

      expect(refusal_of { described_class.read(partial) }.problem).to include("is incomplete")
    end

    it "reads an intact *.partial file when it is told the file is its own (Create's read-back, plan-review C1)", :aggregate_failures do
      partial = scratch("partial").join("#{archive.basename}.0123456789abcdef.partial").tap { it.binwrite(archive.binread) }
      chunks = []
      result = described_class.read(partial, allow_partial: true) { chunks << it }

      expect(chunks.join.b).to eq(payload.b)
      expect(result.sha256).to eq(fields[:snapshot_sha256])
    end

    it "still calls a cut-short *.partial file incomplete when it is told the file is its own" do
      partial = scratch("partial").join("#{archive.basename}.0123456789abcdef.partial").tap { it.binwrite(archive.binread[0...-100]) }

      expect(refusal_of { described_class.read(partial, allow_partial: true) }.problem).to include("is incomplete")
    end

    it "hands the manifest to on_manifest before it reads the snapshot or checks the checksum (FR-2: the room before the checksum)", :aggregate_failures do
      altered = scratch("altered").join("collector-backup-20261021T142100Z.tar.gz").tap do
        described_class.write(it, manifest:, snapshot: scratch_path("changed.sqlite3").tap { |file| file.binwrite(payload.dup.tap { |bytes| bytes.setbyte(1000, bytes.getbyte(1000) ^ 1) }) })
      end
      seen = nil
      chunks = []
      no_room = lambda do |read|
        seen = read
        raise Collector::Backup::Refusal.new("No room.", "Make some.")
      end
      refusal = refusal_of { described_class.read(altered, on_manifest: no_room) { chunks << it } }

      expect(refusal.problem).to eq("No room.") # not the checksum refusal the same file gets without the callback
      expect(seen).to eq(manifest)
      expect(chunks).to be_empty
    end

    it "does not call on_manifest for a file that isn't a backup or names an unknown version", :aggregate_failures do
      future = raw_archive([ "manifest.json", JSON.generate("backup_format_version" => 2) ], [ "primary.sqlite3", "x" ], name: "v2.tar.gz")
      text = scratch_path("note.txt").tap { it.write("hello") }
      calls = []
      [ future, text ].each { |file| refusal_of { described_class.read(file, on_manifest: ->(read) { calls << read }) } }

      expect(calls).to be_empty
    end

    it "calls a changed snapshot a checksum failure, not an incomplete file (AC-3.2)", :aggregate_failures do
      changed = scratch_path("changed.sqlite3").tap { it.binwrite(payload.dup.tap { |bytes| bytes.setbyte(1000, bytes.getbyte(1000) ^ 1) }) }
      altered = scratch("altered").join("collector-backup-20261021T142100Z.tar.gz").tap { described_class.write(it, manifest:, snapshot: changed) }
      refusal = refusal_of { described_class.read(altered) }

      expect(refusal.problem).to eq("#{altered.basename} doesn't match its checksum; it was changed or damaged after it was made.")
      expect(refusal.advice).to eq("Use another copy of the backup.")
    end

    it "refuses what isn't a backup, saying so and never 'incomplete' (AC-3.3)", :aggregate_failures do
      other = Collector::Backup::Manifest.new(**fields).to_json
      files = {
        "a text file" => scratch_path("note.txt").tap { it.write("hello") },
        "an empty file" => scratch_path("empty").tap { it.write("") },
        "a gzip file of something else" => scratch_path("other.gz").tap { it.binwrite(Zlib.gzip("hello, this is not a tar")) },
        "a tar.gz whose first entry isn't manifest.json" => raw_archive([ "other.txt", "x" ], [ "manifest.json", other ], name: "first.tar.gz"),
        "a tar.gz with a manifest that doesn't parse" => raw_archive([ "manifest.json", "not json" ], [ "primary.sqlite3", "x" ], name: "garbled.tar.gz"),
        "a tar.gz whose second entry isn't primary.sqlite3" => raw_archive([ "manifest.json", other ], [ "other.bin", "x" ], name: "second.tar.gz")
      }

      files.each do |label, path|
        refusal = refusal_of { described_class.read(path) }
        expect(refusal&.problem).to eq("#{path.basename} isn't a Collector backup."), label
        expect(refusal.advice).to eq("Give a collector-backup-….tar.gz file made by backup:create."), label
      end
    end

    it "tells a Collector export file where it belongs (AC-3.3)", :aggregate_failures do
      export = scratch_path("collector-export-2026-10-21.json").tap { it.write(JSON.generate("format" => "collector-export", "format_version" => 1, "lots" => [])) }
      refusal = refusal_of { described_class.read(export) }

      expect(refusal.problem).to eq("#{export.basename} is a Collector export file, not a backup.")
      expect(refusal.advice).to include("Import collection")
    end

    it "refuses a backup format version this release doesn't restore, naming the ones it does (AC-3.4)", :aggregate_failures do
      future = raw_archive([ "manifest.json", JSON.generate("backup_format_version" => 2, "newer" => true) ], [ "primary.sqlite3", "x" ], name: "v2.tar.gz")
      refusal = refusal_of { described_class.read(future) }

      expect(refusal.problem).to eq("#{future.basename} uses backup format version 2; this release restores version 1.")
      expect(refusal.advice).to eq("Restore it with a release that knows that version.")
    end

    it "calls a cut-short file of an unknown version incomplete first (FR-2's order)" do
      future = raw_archive([ "manifest.json", JSON.generate("backup_format_version" => 2) ], [ "primary.sqlite3", Random.bytes(100_000) ], name: "v2.tar.gz")
      cut = scratch("cut").join("v2.tar.gz").tap { it.binwrite(future.binread[0...-200]) }

      expect(refusal_of { described_class.read(cut) }.problem).to include("is incomplete")
    end
  end
end
