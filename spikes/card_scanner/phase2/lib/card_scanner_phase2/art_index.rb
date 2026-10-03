require "time"
require_relative "fingerprint" # scripts load units with require_relative, so lib isn't always on $LOAD_PATH

module CardScannerPhase2
  # The index as a flat binary file (16-byte uuid + 128-byte hash per artwork), which the browser downloads
  # and searches, plus the pure-Ruby server-side search for AC-3.7.
  class ArtIndex
    RECORD = 144
    attr_reader :ids, :hashes, :meta

    def self.write!(dir, ids, hashes, meta:)
      dir.mkpath
      dir.join("art_index.bin").binwrite(ids.zip(hashes).map { |id, hash| [ id.delete("-") ].pack("H32") + hash }.join)
      dir.join("art_index_meta.json").write(JSON.pretty_generate(meta.merge("count" => ids.size, "built_at" => Time.now.utc.iso8601, "record_bytes" => RECORD)))
    end

    def self.read(dir)
      data = dir.join("art_index.bin").binread
      ids, hashes = [], []
      (data.bytesize / RECORD).times do |i|
        record = data.byteslice(i * RECORD, RECORD)
        ids << record.byteslice(0, 16).unpack1("H32").then { "#{it[0, 8]}-#{it[8, 4]}-#{it[12, 4]}-#{it[16, 4]}-#{it[20, 12]}" }
        hashes << record.byteslice(16, 128)
      end
      new(ids, hashes, JSON.parse(dir.join("art_index_meta.json").read))
    end

    def initialize(ids, hashes, meta)
      @ids, @hashes, @meta = ids, hashes, meta
      @words = hashes.map { it.unpack("n*") }
    end

    def size = ids.size

    # queries: the six offset hashes of one photo. Each artwork's distance is the smallest over them.
    def search(queries, limit: 10)
      query_words = queries.map { it.unpack("n*") }
      distances = @words.map do |words|
        query_words.map { |q| words.each_index.sum { Fingerprint::POPCOUNT[words[it] ^ q[it]] } }.min
      end
      distances.each_index.sort_by { [ distances[it], it ] }.first(limit).map { { "id" => ids[it], "distance" => distances[it] } }
    end
  end
end
