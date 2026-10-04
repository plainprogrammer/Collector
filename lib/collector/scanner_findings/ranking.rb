# Spec 009 AC-5.4: the stored text of every earlier run, ranked by the shipped matcher against committed ground truth.
# The baseline is taken once under spec 007's ranking, before spec 009 changes it, and committed. Later rankings are
# compared with it: every reading whose first candidate changed, every right first place lost (there must be none)
# and every right card that left the name-only top 3 (AC-6.1). Runs against the development catalog.
class Collector::ScannerFindings::Ranking
  FIXTURES = Rails.root.join("spec/fixtures/card_scanner")
  BASELINE = "spec009_ranking_baseline.json"
  RUNS = {
    "Phase 0" => %w[ocr_results.json ground_truth.json],
    "Phase 1 photo replay" => %w[phase1_photos_ocr_results.json ground_truth.json],
    "Tuning round 4" => %w[phase1_tuning4_ocr_results.json phase1_tuning_ground_truth.json],
    "New corpus live" => %w[phase1_live_ocr_results.json phase1_live_ground_truth.json],
    "New corpus photos" => %w[phase1_live_photos_ocr_results.json phase1_live_ground_truth.json]
  }.freeze
  # Spec 007 research.md §5's misread collector numbers, checked on the live run only (spec 009 AC-5.4).
  MISREADS = { "New corpus live" => %w[IMG_6765.jpeg IMG_6769.jpeg IMG_6792.jpeg] }.freeze

  def initialize(fixtures: FIXTURES, runs: RUNS, misreads: MISREADS)
    @fixtures = Pathname(fixtures)
    @runs = runs
    @misreads = misreads
    @readings = {}
  end

  # { run => [ { "file", "expected", "final", "name" } ] }: each reading's expected card, its final top 3 and its
  # name-only top 3. strong_name_score ranks with another strong-name threshold, for the sweep (AC-5.1).
  def rankings(strong_name_score: nil)
    @runs.to_h do |run, (results, truth)|
      expected = json(truth).fetch("photos").to_h { [ it["file"], it["name"] ] }
      rows = json(results).fetch("results").filter_map do |result|
        next unless expected.key?(result["file"])

        reading = reading(run, result)
        final = strong_name_score ? reading.ranked(strong_name_score) : reading.candidates
        { "file" => result["file"], "expected" => expected[result["file"]], "final" => final.first(3).map { it.entry.name },
          "name" => Collector::ScannerFindings.identity_names(reading.name_candidates.map(&:identity_id)) }
      end
      [ run, rows ]
    end
  end

  def write_baseline!
    @fixtures.join(BASELINE).write(JSON.pretty_generate("format_version" => 1, "spec" => "009", "ranking" => "spec 007",
      "catalog" => catalog_version, "runs" => rankings))
  end

  def baseline = json(BASELINE).fetch("runs")

  # [run, file] for each reading the baseline had right first and now doesn't (AC-5.4: none allowed).
  def losses(now, against: baseline) = lost(now, against) { right_first?(it) }

  # [run, file] for each reading whose right card left the name-only top 3 (AC-6.1: none allowed).
  def name_losses(now, against: baseline) = lost(now, against) { it.present? && it["name"].first(3).include?(it["expected"]) }

  def misreads_fixed?(now)
    @misreads.all? { |run, files| files.all? { |file| right_first?(now.fetch(run).find { it["file"] == file }) } }
  end

  # Markdown for research.md: per run, right first and in the top 3 under each ranking; every changed first candidate.
  def comparison(now = rankings, against: baseline)
    totals = @runs.keys.map do |run|
      before, after = against.fetch(run), now.fetch(run)
      "| #{run} | #{rate(before) { right_first?(it) }} | #{rate(after) { right_first?(it) }} | " \
        "#{rate(before) { in_top3?(it) }} | #{rate(after) { in_top3?(it) }} |"
    end
    changed = @runs.keys.flat_map do |run|
      later = now.fetch(run).to_h { [ it["file"], it ] }
      against.fetch(run).filter_map do |row|
        after = later[row["file"]]
        next if after.nil? || after["final"].first == row["final"].first

        "| #{run} | #{row["file"]} | #{row["expected"]} | #{row["final"].join("; ")} | #{after["final"].join("; ")} |"
      end
    end
    [ "| Run | Right first, spec 007 | Right first, spec 009 | Top 3, spec 007 | Top 3, spec 009 |", "|---|---|---|---|---|", *totals, "",
      "First candidate changed: #{changed.size}", "", "| Run | File | Expected | Spec 007 top 3 | Spec 009 top 3 |", "|---|---|---|---|---|",
      *changed, "", "Right first places lost: #{listed(losses(now, against:))}. Right cards that left the name-only top 3: " \
      "#{listed(name_losses(now, against:))}. Misread cases right first: #{misreads_fixed?(now) ? "yes" : "no"}." ].join("\n")
  end

  # One row per threshold (AC-5.1): right first over every run, first places lost, and whether the misreads are fixed.
  def sweep(thresholds, against: baseline)
    thresholds.map do |threshold|
      now = rankings(strong_name_score: threshold)
      { threshold:, right_first: now.values.flatten.count { right_first?(it) }, losses: losses(now, against:).size,
        misreads_fixed: misreads_fixed?(now) }
    end
  end

  private
    def reading(run, result)
      @readings[[ run, result["file"] ]] ||=
        MTG::Reading.new(name_text: result["name_text"].to_s, collector_text: result["collector_text"].to_s).resolve
    end

    def lost(now, against)
      against.flat_map do |run, rows|
        later = now.fetch(run, []).to_h { [ it["file"], it ] }
        rows.select { yield(it) && !yield(later[it["file"]]) }.map { [ run, it["file"] ] }
      end
    end

    def right_first?(row) = row.present? && row["final"].first == row["expected"]
    def in_top3?(row) = row["final"].first(3).include?(row["expected"])
    def rate(rows, &) = "#{rows.count(&)}/#{rows.size}"
    def listed(pairs) = pairs.empty? ? "none" : pairs.map { it.join(" ") }.join(", ")
    def json(name) = JSON.parse(@fixtures.join(name).read)
    def catalog_version = Catalog::RefreshRun.where(collectible_type: "mtg", status: "applied").order(:finished_at).last&.source_version
end
