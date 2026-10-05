# A measured run of the card scanner (spec 007 Story 5): the manifest of known cards (spec 005's format,
# file,set,number,foil[,era]) and what each live capture read, stored in a directory outside the
# repository. The first capture of a row is the measured one; later ones are retakes (AC-5.4).
# Layout: <dir>/<file>/capture-NNN.json, capture-NNN-{name,collector}.png (and capture-NNN-frame.png, spec 010), skipped.json;
# <dir>/replays/<label>.json.
class Scanner::MeasurementRun
  Row = Data.define(:file, :set, :number)
  class ManifestError < StandardError; end
  class InvalidCapture < StandardError; end

  FILE_NAME = /\A[\w-][\w.-]*\z/
  STRIPS = %w[name collector].freeze
  MAX_STRIP_BYTES = 5.megabytes
  MAX_FRAME_BYTES = 32.megabytes
  GUIDE_KEYS = %w[x y width height].freeze
  PNG_SIGNATURE = "\x89PNG\r\n\x1A\n".b
  # Spec 009 adds the reading key, the outline ("live", "found" or "not_found") and the detector's timings (AC-9.2, AC-9.3).
  EXTRA_FIELDS = %w[reading_key outline detect_ms warp_ms].freeze
  EVENT_KINDS = %w[add undo details].freeze

  def self.enabled? = Rails.configuration.x.scanner_measurement.present?

  # Spec 010: live captures also keep their full frame when the measurement config's keep_frames is set (development only).
  def self.keep_frames? = Rails.configuration.x.scanner_measurement.to_h[:keep_frames].present?

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
  def record!(row, name_text:, collector_text:, ms:, user_agent:, name_strip:, collector_strip:, extra: {}, frame: nil, guide: nil)
    if [ name_text, collector_text ].any? { it.length > MTG::Reading::MAX_TEXT_LENGTH }
      raise InvalidCapture, "That capture's text was too long to store."
    end

    images = { "name" => png!(name_strip), "collector" => png!(collector_strip) }
    frame_data = frame && png!(frame, limit: MAX_FRAME_BYTES, what: "frame")
    raise InvalidCapture, "The frame was too short to be a PNG, so nothing was stored." if frame_data && frame_data.bytesize < 24
    raise InvalidCapture, "The frame's guide rect was missing, so nothing was stored." if frame_data && !whole_guide?(guide)

    number = captures(row).size + 1
    kind = number == 1 ? :measured : :retake
    stem = format("capture-%03d", number)
    row_dir(row).mkpath
    images.each { |strip, data| row_dir(row).join("#{stem}-#{strip}.png").binwrite(data) }
    row_dir(row).join("#{stem}-frame.png").binwrite(frame_data) if frame_data
    row_dir(row).join("#{stem}.json").write(JSON.pretty_generate({ "file" => row.file, "kind" => kind.to_s, "name_text" => name_text,
      "collector_text" => collector_text, "ms" => ms, "user_agent" => user_agent, "captured_at" => Time.current.utc.iso8601 }
      .merge(extra.to_h.stringify_keys.slice(*EXTRA_FIELDS).compact_blank).merge(frame_fields(frame_data, guide))))
    kind
  end

  def skip!(row)
    row_dir(row).mkpath
    row_dir(row).join("skipped.json").write(JSON.generate("file" => row.file, "skipped_at" => Time.current.utc.iso8601))
  end

  # The row whose capture carried this reading key (spec 009 AC-9.2), or nil.
  def row_for_key(key) = key.present? ? rows.find { |row| captures(row).any? { it["reading_key"] == key } } : nil

  # One line per event, with the server's time, so the findings can time each card (AC-9.1, AC-9.2).
  def record_event!(row, kind:, rank:, reading_key:)
    row_dir(row).mkpath
    row_dir(row).join("events.jsonl").open("a") do |file|
      file.puts(JSON.generate("kind" => kind, "rank" => rank, "reading_key" => reading_key, "at" => Time.current.utc.iso8601(3)))
    end
  end

  def events(row)
    path = row_dir(row).join("events.jsonl")
    path.file? ? path.readlines.map { JSON.parse(it) } : []
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

    def png!(upload, limit: MAX_STRIP_BYTES, what: "strip")
      data = upload.respond_to?(:read) ? upload.read(limit + 1) : nil
      return data if data && data.bytesize <= limit && data.b.start_with?(PNG_SIGNATURE)

      raise InvalidCapture, "A #{what} wasn't a PNG of at most #{limit / 1.megabyte} MB, so nothing was stored."
    end

    def whole_guide?(guide) = guide.is_a?(Hash) && GUIDE_KEYS.all? { guide[it].is_a?(Numeric) }

    # The guide rect as the page used it, and the frame's size from its PNG header (width and height at bytes 16–23).
    def frame_fields(data, guide)
      return {} unless data

      width, height = data.byteslice(16, 8).unpack("NN")
      { "guide" => guide.slice(*GUIDE_KEYS).transform_values(&:to_f), "frame_width" => width, "frame_height" => height }
    end
end
