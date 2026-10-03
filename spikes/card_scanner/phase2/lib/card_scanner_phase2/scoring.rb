require_relative "derived_corpus" # scripts load units with require_relative, so lib isn't always on $LOAD_PATH

module CardScannerPhase2
  # Scores a reading run with spec 007's rate definitions (Collector::ScannerFindings), with a baseline column
  # from the committed fixtures and, for the new corpus, the live column (AC-2.2, AC-2.3, AC-2.5).
  module Scoring
    FINDINGS = Collector::ScannerFindings
    RATES = {
      "Top 1, final ranking" => ->(r) { FINDINGS.in_top?(r, "final_candidates", 1) },
      "Top 3, final ranking" => ->(r) { FINDINGS.in_top?(r, "final_candidates", 3) },
      "Top 1, name only" => ->(r) { FINDINGS.in_top?(r, "name_candidates", 1) },
      "Top 3, name only" => ->(r) { FINDINGS.in_top?(r, "name_candidates", 3) }
    }.freeze
    EMPTY_CAPTURE = { "name_text" => "", "collector_text" => "", "ms" => 0, "user_agent" => "none (not found)", "captured_at" => nil }.freeze

    module_function

    # One record per photo of the half: the shipped rescore over the measurement captures (keyed back to the
    # original file name), plus an empty reading for every photo the detector didn't find.
    def records(run_dir, truths:, measured_captures:)
      detections = DerivedCorpus.detections(run_dir).to_h { [ it["file"], it ] }
      classes = run_dir.join("classes.json").then { it.exist? ? JSON.parse(it.read) : {} }
      derived_truth = JSON.parse(run_dir.join("corpus/ground_truth.json").read).fetch("photos").to_h { [ it["file"], it ] }
      read = FINDINGS.rescore(derived_truth, measured_captures).map { it.merge("file" => "#{File.basename(it["file"], ".*")}.jpeg") }
      missing = detections.values.reject { it["found"] }.map do |detection|
        truth = truths.fetch(detection["corpus"]).fetch(detection["file"])
        FINDINGS.rescore({ detection["file"] => truth }, [ EMPTY_CAPTURE.merge("file" => detection["file"]) ]).first
      end
      (read + missing).map do |record|
        detection = detections.fetch(record["file"])
        record.merge(detection.slice("corpus", "found", "msDetect", "msWarp", "run", "half", "recorded_at", "code_commit", "settings_commit", "tree_clean"))
          .merge("class" => classes.fetch(record["file"], detection["found"] ? "found" : "not_found"))
      end.sort_by { it["file"] }
    end

    # The same photos' text from a committed fixture, rescored against the spike's ground-truth copy.
    def fixture_records(fixture, truth, files)
      results = JSON.parse(FIXTURE_DIR.join(fixture).read).fetch("results").select { files.include?(it["file"]) }
      FINDINGS.rescore(truth, results)
    end

    def tables(sources)
      { "both" => markdown(sources), "phase0" => markdown(sources.transform_values { |rs| rs.select { it["corpus"] == "phase0" } }),
        "new" => markdown(sources.transform_values { |rs| rs.select { it["corpus"] == "new" } }) }
    end

    def markdown(sources)
      parts = RATES.map { |title, hit| FINDINGS.comparison(title, sources, &hit) }
      set_line = sources.transform_values { |rs| rs.select { FINDINGS::SET_LINE_ERAS.include?(it["era"]) } }
      parts << FINDINGS.comparison("Exact printing (M15–ONE, MOM+)", set_line) { FINDINGS.printing_identified?(it) }
      parts << "Lookup outcomes (M15–ONE, MOM+): " + set_line.map { |label, rs| "#{label} #{rs.map { it.dig("lookup", "status") }.tally.sort.to_h}" }.join("; ")
      detected = sources.select { |_, rs| rs.any? { it.key?("class") } }
      parts << "Detection: " + detected.map { |label, rs| "#{label} #{rs.map { it["class"] }.tally.sort.map { |k, n| "#{k} #{n}" }.join(", ")}" }.join("; ") if detected.any?
      parts.join("\n\n")
    end

    def misses(records) = records.reject { FINDINGS.in_top?(it, "final_candidates", 3) }

    def timings(records)
      found = records.select { it["found"] }
      { "detect" => summary(records.map { it["msDetect"] }.compact), "warp" => summary(found.map { it["msWarp"] }.compact), "ocr" => summary(found.map { it["ms"] }.compact) }
    end

    def summary(values) = values.empty? ? nil : { "n" => values.size, "median" => CardScannerPhase2.median(values).round(1), "max" => values.max.round(1) }
  end
end
