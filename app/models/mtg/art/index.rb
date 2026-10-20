require "zlib"

# The art index file (spec 011 AC-3.9; ADR 0006, ADR 0007), which the scanner page downloads and searches. Compressed;
# a 28-byte header (CART, format version, three zero bytes, the 16-character settings digest, the record count as uint32
# big-endian) and then one 144-byte record per artwork (16-byte artwork id, 128-byte fingerprint), sorted by artwork id.
# Named by catalog version, settings digest and record count, so a name never changes content (it's served immutable);
# written under a temporary name and renamed; the two newest are kept, and the newest is the one pages use.
class MTG::Art::Index
  MAGIC = "CART".b
  FORMAT_VERSION = 1
  HEADER = 28
  RECORD = 144
  KEEP = 2
  NAME = /\Aart-index-[a-z0-9-]+-[0-9a-f]{16}-\d+\.bin\.gz\z/

  def self.dir = MTG::Art.root.join("index")

  def self.name_for(catalog_version, count) = "art-index-#{catalog_version}-#{MTG::Art::Settings.digest}-#{count}.bin.gz"

  def self.files
    dir.glob("art-index-*.bin.gz").select { NAME.match?(it.basename.to_s) }.sort_by { [ it.mtime, it.basename.to_s ] }.reverse
  end

  def self.current = files.first

  def self.built_for?(catalog_version) = files.any? { it.basename.to_s.start_with?("art-index-#{catalog_version}-#{MTG::Art::Settings.digest}-") }

  # Only the current or previous index, by its exact name; anything else is nil (AC-4.2).
  def self.path_for(name) = NAME.match?(name.to_s) ? files.first(KEEP).find { it.basename.to_s == name } : nil

  def self.write!(catalog_version, records)
    sorted = records.sort_by(&:first)
    path = dir.join(name_for(catalog_version, sorted.size))
    return path if path.file?

    dir.mkpath
    partial = Pathname("#{path}.part")
    Zlib::GzipWriter.open(partial.to_s, Zlib::BEST_COMPRESSION) do |gzip|
      gzip.write(header(sorted.size))
      sorted.each { |id, fingerprint| gzip.write([ id.delete("-") ].pack("H32") + fingerprint.b) }
    end
    partial.rename(path)
    files.drop(KEEP).each(&:delete)
    path
  end

  def self.header(count) = MAGIC + [ FORMAT_VERSION, 0, 0, 0 ].pack("C4") + MTG::Art::Settings.digest.b + [ count ].pack("N")

  # The header and records of an index file, for specs and the findings.
  def self.read(path)
    data = Zlib.gunzip(Pathname(path).binread)
    count = data.byteslice(24, 4).unpack1("N")
    records = Array.new(count) do |i|
      record = data.byteslice(HEADER + i * RECORD, RECORD)
      hex = record.byteslice(0, 16).unpack1("H32")
      [ "#{hex[0, 8]}-#{hex[8, 4]}-#{hex[12, 4]}-#{hex[16, 4]}-#{hex[20, 12]}", record.byteslice(16, 128) ]
    end
    { magic: data.byteslice(0, 4), version: data.getbyte(4), digest: data.byteslice(8, 16), count:, records: }
  end
end
