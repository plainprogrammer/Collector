module CardScannerPhase2
  # Halves each corpus before any tuning (AC-1.1): foil and non-foil rows alternate separately in manifest
  # order, each group starting with development. One card, Leyline Immersion mat 71, is in both corpora,
  # so its new-corpus photo is forced into development to keep every printing on one side.
  module Split
    FORCE_DEVELOPMENT = { "new" => %w[IMG_6763.jpeg] }.freeze
    SPLIT_PATH = FIXTURE_DIR.join("phase2_split.json")

    module_function

    def manifests
      CORPORA.to_h { |key, corpus| [ key, CardScannerPhase2.corpus_dir.join(corpus[:manifest]).read ] }
    end

    def rows(manifest_text)
      header, *lines = manifest_text.lines.map(&:strip).reject(&:empty?)
      keys = header.split(",", -1).map(&:strip)
      lines.map { |line| keys.zip(line.split(",", -1).map(&:strip)).to_h }
    end

    def halves(texts = manifests, force_development: FORCE_DEVELOPMENT)
      texts.to_h do |key, text|
        development, held_out = [], []
        rows(text).group_by { it["foil"].casecmp?("yes") }.sort_by { |foil, _| foil ? 1 : 0 }.each do |_, group|
          group.each_with_index { |row, index| (index.even? ? development : held_out) << row["file"] }
        end
        forced = Array(force_development[key])
        [ key, { "development" => development + (held_out & forced), "held_out" => held_out - forced } ]
      end
    end

    def write!(path = SPLIT_PATH)
      path.write(JSON.pretty_generate("format_version" => 1, "rule" => "foil and non-foil rows alternate separately in manifest order, " \
        "each group starting with development; IMG_6763.jpeg (mat 71, also in Phase 0) forced to development", "halves" => halves))
    end

    def read(path = SPLIT_PATH) = JSON.parse(path.read).fetch("halves")

    def half_of(corpus, file, split = read)
      split.fetch(corpus).find { |_, files| files.include?(file) }&.first or raise ArgumentError, "#{file} isn't in the #{corpus} split"
    end
  end
end
