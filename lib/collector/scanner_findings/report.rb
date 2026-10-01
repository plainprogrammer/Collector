# The Markdown for spec 007's findings (AC-6.2–AC-6.5): each rate for Phase 0, Phase 0's text through Phase 1's
# matcher, and the live run; then the live run's misses, timings, coverage and replay differences.
class Collector::ScannerFindings::Report
  FIXTURES = Rails.root.join("spec/fixtures/card_scanner")

  def initialize(run:, ground_truth: FIXTURES.join("ground_truth.json"), output: FIXTURES)
    @run = run
    @truth = JSON.parse(Pathname(ground_truth).expand_path.read).fetch("photos").to_h { [ it["file"], it ] }
    @output = Pathname(output)
  end

  def to_markdown = [ rates, misses, timings, coverage, replays ].join("\n\n")

  # The live run as text-only fixtures beside Phase 0's, keyed by manifest file (AC-6.6).
  def write_fixtures!
    @output.join("phase1_ocr_results.json").write(JSON.pretty_generate("format_version" => 2, "run" => "live",
      "results" => live.map { it.slice("file", "name_text", "collector_text", "ms", "user_agent", "captured_at", "parsed", "lookup") }))
    @output.join("phase1_name_matches.json").write(JSON.pretty_generate("format_version" => 2, "run" => "live",
      "matches" => live.map { it.slice("file", "lookup_ms", "name_candidates", "final_candidates").merge("query" => it["name_text"]) }))
  end

  private
    def findings = Collector::ScannerFindings

    def fixture(name) = JSON.parse(FIXTURES.join(name).read)

    def live = @live ||= findings.rescore(@truth, @run.measured_captures)

    def sources
      @sources ||= { "Phase 0" => findings.phase0(@truth, fixture("ocr_results.json"), fixture("name_matches.json")),
                     "Phase 0 text, Phase 1 matcher" => findings.rescore(@truth, fixture("ocr_results.json").fetch("results")),
                     "Phase 1 live" => live }
    end

    def rates
      set_line = sources.transform_values { |records| records.select { findings::SET_LINE_ERAS.include?(it["era"]) } }
      ranked = sources.except("Phase 0") # Phase 0 had no final ranking
      [ findings.comparison("Name read (front face)", sources) { findings.name_read?(it) },
        findings.comparison("Name read (catalog name)", sources) { findings.name_read?(it, against: "name") },
        findings.comparison("Top 1, name only", sources) { findings.in_top?(it, "name_candidates", 1) },
        findings.comparison("Top 3, name only", sources) { findings.in_top?(it, "name_candidates", 3) },
        findings.comparison("Top 1, final ranking", ranked) { findings.in_top?(it, "final_candidates", 1) },
        findings.comparison("Top 3, final ranking", ranked) { findings.in_top?(it, "final_candidates", 3) },
        findings.comparison("Exact printing (M15–ONE, MOM+)", set_line) { findings.printing_identified?(it) },
        "Lookup outcomes (M15–ONE, MOM+): " + set_line.map { |label, records| "#{label} #{records.map { it.dig("lookup", "status") }.tally}" }.join("; ")
      ].join("\n\n")
    end

    def misses
      rows = live.reject { findings.in_top?(it, "final_candidates", 3) }.map do |record|
        "| #{record["file"]} | #{cell(record["name"])} | #{cell(record["name_text"])} | #{cell(record["collector_text"])} | #{cell(record["final_candidates"].join("; "))} | |"
      end
      [ "Not in the top 3 (live run, final ranking): #{rows.size} of #{live.size}", "",
        "| File | Expected | Name strip | Collector strip | Top 3 | Likely cause |", "|---|---|---|---|---|---|", *rows ].join("\n")
    end

    def timings
      ms = live.filter_map { it["ms"] }
      lookups = live.map { it["lookup_ms"] }
      "Recognition on the device: median #{findings.percentile(ms, 50)} ms, slowest #{ms.max} ms (n=#{ms.size}). " \
        "Candidate lookup on this machine: median #{findings.percentile(lookups, 50)} ms, p95 #{findings.percentile(lookups, 95)} ms (n=#{lookups.size}). " \
        "Devices: #{live.map { it["user_agent"] }.tally.map { |agent, count| "#{agent} (#{count})" }.join("; ")}."
    end

    def coverage
      files = ->(status) { @run.rows.select { @run.status(it) == status }.map(&:file).join(", ").presence || "none" }
      "Captured #{live.size} of #{@run.rows.size}; skipped: #{files.call(:skipped)}; not captured: #{files.call(:pending)}; retakes: #{@run.retakes}."
    end

    def replays
      device = @run.measured_captures.to_h { [ it["file"], it ] }
      sections = @run.replays.map do |label, results|
        diffs = results.flat_map do |result|
          %w[name_text collector_text].filter_map do |field|
            on_device = device.dig(result["file"], field)
            "- #{result["file"]} #{field}: #{on_device.inspect} on the device, #{result[field].inspect} replayed" if on_device != result[field]
          end
        end
        [ "Replay #{label}: #{diffs.map { it.split[1] }.uniq.size} of #{results.size} captures differ from the device's text", *diffs ].join("\n")
      end
      sections.join("\n\n").presence || "No replays yet."
    end

    def cell(text) = text.to_s.gsub("|", "\\|").tr("\n", " ")
end
