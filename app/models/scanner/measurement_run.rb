# A measured run of the card scanner (spec 007 Story 5): the manifest of known cards (spec 005's format,
# file,set,number,foil[,era]) and what each live capture read, stored in a directory outside the
# repository. The first capture of a row is the measured one; later ones are retakes (AC-5.4).
# Layout: <dir>/<file>/capture-NNN.json, capture-NNN-{name,collector}.png, skipped.json;
# <dir>/replays/<label>.json.
class Scanner::MeasurementRun
  Row = Data.define(:file, :set, :number)
  class ManifestError < StandardError; end
  class InvalidCapture < StandardError; end

  FILE_NAME = /\A[\w-][\w.-]*\z/
  STRIPS = %w[name collector].freeze
  MAX_STRIP_BYTES = 5.megabytes
  PNG_SIGNATURE = "\x89PNG\r\n\x1A\n".b

  def self.enabled? = Rails.configuration.x.scanner_measurement.present?

  def self.current
    config = Rails.configuration.x.scanner_measurement
    new(manifest: config.fetch(:manifest), dir: config.fetch(:dir)) if config.present?
  end

  attr_reader :dir

  def initialize(manifest:, dir:)
    @manifest = Pathname(manifest).expand_path
    @dir = Pathname(dir).expand_path
  end

  # The manifest has no quoted or comma-bearing values, so a split is enough.
  def rows
    @rows ||= begin
      raise ManifestError, "No manifest at #{@manifest}." unless @manifest.file?

      header, *lines = @manifest.readlines(chomp: true).map(&:strip).reject(&:empty?)
      keys = header.to_s.split(",").map(&:strip)
      raise ManifestError, "#{@manifest.basename} needs file, set and number columns." unless (%w[file set number] - keys).empty?

      lines.map do |line|
        values = keys.zip(line.split(",", -1).map(&:strip)).to_h
        raise ManifestError, "Bad file name in #{@manifest.basename}: #{values["file"].inspect}." unless values["file"].to_s.match?(FILE_NAME)

        Row.new(file: values["file"], set: values["set"], number: values["number"])
      end
    end
  end

  def row(file) = rows.find { it.file == file }

  def status(row)
    if captures(row).any? then :captured
    elsif row_dir(row).join("skipped.json").file? then :skipped
    else :pending
    end
  end

  def next_row = rows.find { status(it) == :pending }

  def counts = rows.group_by { status(it) }.transform_values(&:size)

  def retakes = rows.sum { [ captures(it).size - 1, 0 ].max }

  def captures(row) = row_dir(row).glob("capture-*.json").sort.map { JSON.parse(it.read) }

  def measured_rows = rows.select { captures(it).any? }

  def measured_captures = measured_rows.map { captures(it).first }

  # Stores one capture and returns :measured for a row's first, :retake after. The JSON is written last, so a
  # capture interrupted halfway doesn't count.
  def record!(row, name_text:, collector_text:, ms:, user_agent:, name_strip:, collector_strip:)
    if [ name_text, collector_text ].any? { it.length > MTG::Reading::MAX_TEXT_LENGTH }
      raise InvalidCapture, "That capture's text was too long to store."
    end

    images = { "name" => png!(name_strip), "collector" => png!(collector_strip) }
    number = captures(row).size + 1
    kind = number == 1 ? :measured : :retake
    stem = format("capture-%03d", number)
    row_dir(row).mkpath
    images.each { |strip, data| row_dir(row).join("#{stem}-#{strip}.png").binwrite(data) }
    row_dir(row).join("#{stem}.json").write(JSON.pretty_generate("file" => row.file, "kind" => kind.to_s, "name_text" => name_text,
      "collector_text" => collector_text, "ms" => ms, "user_agent" => user_agent, "captured_at" => Time.current.utc.iso8601))
    kind
  end

  def skip!(row)
    row_dir(row).mkpath
    row_dir(row).join("skipped.json").write(JSON.generate("file" => row.file, "skipped_at" => Time.current.utc.iso8601))
  end

  # The measured capture's strip image, for the desktop replay (AC-5.6).
  def strip_path(row, strip) = STRIPS.include?(strip) ? row_dir(row).join("capture-001-#{strip}.png") : nil

  # The manifest's own photo of a row (it sits beside the manifest, as in Phase 0's corpus), for the photo replay.
  def photo_path(row)
    path = @manifest.dirname.join(row.file)
    path if path.file?
  end

  def record_replay!(label, results)
    @dir.join("replays").mkpath
    @dir.join("replays/#{label}.json").write(JSON.pretty_generate("label" => label, "replayed_at" => Time.current.utc.iso8601,
      "results" => results.map { it.slice("file", "name_text", "collector_text") }))
  end

  def replays = @dir.join("replays").glob("*.json").sort.to_h { |path| [ path.basename(".json").to_s, JSON.parse(path.read).fetch("results") ] }

  def expected_name(row)
    entry = Catalog::Entry.where(collectible_type: "mtg").printed_as(set_code: row.set, number: row.number, language: "en").first
    label = "#{row.set.upcase} · #{row.number}"
    entry ? "#{entry.name} (#{label})" : "#{label} (not in the catalog)"
  end

  private
    def row_dir(row) = @dir.join(row.file)

    def png!(upload)
      data = upload.respond_to?(:read) ? upload.read(MAX_STRIP_BYTES + 1) : nil
      return data if data && data.bytesize <= MAX_STRIP_BYTES && data.b.start_with?(PNG_SIGNATURE)

      raise InvalidCapture, "A strip wasn't a PNG of at most 5 MB, so nothing was stored."
    end
end
