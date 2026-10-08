namespace :scanner do
  desc 'Build ground truth for a tuning manifest the committed fixture doesn\'t cover: bin/rails "scanner:ground_truth[path/to/manifest.csv]"'
  task :ground_truth, [ :manifest ] => :environment do |_task, args|
    manifest = Pathname(args.fetch(:manifest)).expand_path
    truth = Collector::ScannerFindings.ground_truth(manifest.read)
    manifest.dirname.join("ground_truth.json").write(JSON.pretty_generate(truth))
    puts "#{truth["photos"].size} rows resolved, #{truth["errors"].size} errors -> #{manifest.dirname.join("ground_truth.json")}"
    truth["errors"].each { puts "  #{it}" }
  end

  desc "Score the measurement run against Phase 0 (spec 007 Story 6). FIXTURES=1 writes the text fixtures; GROUND_TRUTH=path " \
       "for a tuning run; RUN_LABEL names the run's column, FIXTURES_PREFIX its fixture files"
  task findings: :environment do
    run = Scanner::MeasurementRun.current
    abort "Measurement mode is off; run this in development." unless run
    report = Collector::ScannerFindings::Report.new(run:, **{ ground_truth: ENV["GROUND_TRUTH"], label: ENV["RUN_LABEL"].presence,
      prefix: ENV["FIXTURES_PREFIX"].presence }.compact, format_version: ENV.fetch("FORMAT_VERSION", "2").to_i)
    puts report.to_markdown
    report.write_fixtures! if ENV["FIXTURES"] == "1"
  end

  desc "Spec 009 AC-5.4: commit the ranking baseline (once, under spec 007's ranking, before spec 009 changes it)"
  task ranking_baseline: :environment do
    Collector::ScannerFindings::Ranking.new.write_baseline!
    puts "Wrote #{Collector::ScannerFindings::Ranking::FIXTURES.join(Collector::ScannerFindings::Ranking::BASELINE)}"
  end

  desc "Spec 009 AC-5.4, AC-6.1: every earlier run's stored text under the shipped ranking, against the baseline"
  task ranking: :environment do
    ranking = Collector::ScannerFindings::Ranking.new
    now = ranking.rankings
    puts ranking.comparison(now)
    abort "A right first place or a name-only top 3 place was lost." if ranking.losses(now).any? || ranking.name_losses(now).any?
  end

  desc "Spec 009 AC-5.1: right-first readings, lost first places and the misread cases per strong-name threshold"
  task strong_sweep: :environment do
    rows = Collector::ScannerFindings::Ranking.new.sweep((80..100).map { it / 100.0 })
    puts "| Threshold | Right first | First places lost | Misreads right first |", "|---|---|---|---|"
    rows.each { puts "| #{it[:threshold]} | #{it[:right_first]} | #{it[:losses]} | #{it[:misreads_fixed] ? "yes" : "no"} |" }
    eligible = rows.select { it[:losses].zero? && it[:misreads_fixed] }
    abort "No threshold fixes the three misreads without losing a right first place: ask the maintainer (AC-5.4)." if eligible.empty?

    best = eligible.max_by { [ it[:right_first], it[:threshold] ] }
    puts "Choose #{best[:threshold]}: the most right-first readings with no loss, ties to the higher threshold."
  end

  desc "Spec 009: derived folders for the spike's halves (symlinked photos, one manifest and ground truth each) under ~/card-scanner-corpus/derived"
  task derive_halves: :environment do
    corpus = Pathname(File.expand_path(ENV.fetch("CARD_SCANNER_CORPUS", "~/card-scanner-corpus")))
    fixtures = Rails.root.join("spec/fixtures/card_scanner")
    halves = JSON.parse(fixtures.join("phase2_split.json").read).fetch("halves")
    sources = { "phase0" => [ corpus, fixtures.join("ground_truth.json") ], "new" => [ corpus.join("phase1-live"), fixtures.join("phase1_live_ground_truth.json") ] }
    %w[development held_out].each do |half|
      out = corpus.join("derived", half).tap(&:mkpath)
      rows, truth = [], []
      sources.each do |key, (folder, truth_file)|
        files = halves.fetch(key).fetch(half)
        manifest = folder.join("manifest.csv").readlines(chomp: true)
        header = manifest.first.split(",")
        manifest.drop(1).map { header.zip(it.split(",", -1)).to_h }.select { files.include?(it["file"]) }.each do |row|
          link = out.join(row["file"])
          link.make_symlink(folder.join(row["file"])) unless link.symlink? || link.exist?
          rows << [ row["file"], row["set"], row["number"], row["foil"], row["era"].to_s ].join(",")
        end
        truth.concat(JSON.parse(truth_file.read).fetch("photos").select { files.include?(it["file"]) })
      end
      out.join("manifest.csv").write(([ "file,set,number,foil,era" ] + rows).join("\n") + "\n")
      out.join("ground_truth.json").write(JSON.pretty_generate("photos" => truth, "errors" => []))
      puts "#{half}: #{rows.size} photos, #{truth.size} truth records -> #{out}"
    end
  end

  desc "Spec 009 AC-6.4, AC-6.6: rates of the configured measurement run against GROUND_TRUTH; COMPARE_DIR names a run to diff names with"
  task detected_score: :environment do
    run = Scanner::MeasurementRun.current
    abort "Measurement mode is off; run this in development." unless run
    truth = JSON.parse(Pathname(ENV.fetch("GROUND_TRUTH")).expand_path.read).fetch("photos").to_h { [ it["file"], it ] }
    records = Collector::ScannerFindings.rescore(truth, run.measured_captures)
    puts Collector::ScannerFindings.headline(records)
    if (other = ENV["COMPARE_DIR"].presence)
      manifest = Rails.configuration.x.scanner_measurement.fetch(:manifest)
      before = Collector::ScannerFindings.rescore(truth, Scanner::MeasurementRun.new(manifest:, dir: other).measured_captures)
      gained, lost = Collector::ScannerFindings.name_read_changes(before, records)
      puts "Names now read in full: #{gained.join(", ").presence || "none"}. No longer read: #{lost.join(", ").presence || "none"}."
    end
  end

  desc "Spec 009 AC-6.2, AC-6.3: rates of a desktop replay of the configured run against GROUND_TRUTH"
  task :replay_score, [ :label ] => :environment do |_task, args|
    run = Scanner::MeasurementRun.current
    abort "Measurement mode is off; run this in development." unless run
    truth = JSON.parse(Pathname(ENV.fetch("GROUND_TRUTH")).expand_path.read).fetch("photos").to_h { [ it["file"], it ] }
    records = Collector::ScannerFindings.rescore(truth, run.replays.fetch(args.fetch(:label)))
    puts Collector::ScannerFindings.headline(records)
    puts "IMG_6785 name read: #{records.find { it["file"] == "IMG_6785.jpeg" }&.then { Collector::ScannerFindings.name_read?(it) }.inspect}"
  end

  desc "Spec 009 AC-6.5: the set-line separator read on the new corpus's live captures, by real finish, and what the shipped markers mark"
  task foil_markers: :environment do
    fixtures = Rails.root.join("spec/fixtures/card_scanner")
    truth = JSON.parse(fixtures.join("phase1_live_ground_truth.json").read).fetch("photos").to_h { [ it["file"], it ] }
    results = JSON.parse(fixtures.join("phase1_live_ocr_results.json").read).fetch("results")
    Collector::ScannerFindings.foil_markers(results, truth).sort.each { |(finish, marker), count| puts "#{finish}\t#{marker.inspect}\t#{count}" }
    known = Catalog::Set.where(collectible_type: "mtg").pluck(:code)
    marked = results.filter_map { (record = truth[it["file"]]) && [ record["foil"], MTG::CollectorLine.parse(it["collector_text"], known_set_codes: known).foil ] }
    puts "Marked as foil: foils #{marked.count { |foil, hint| foil && hint }}/#{marked.count(&:first)}, " \
      "non-foils #{marked.count { |foil, hint| !foil && hint }}/#{marked.count { !it.first }} (markers #{MTG::CollectorLine::FOIL_MARKERS.inspect})"
  end

  desc 'Spec 009 AC-9.1: abort if the live sitting reuses a card from an earlier corpus: bin/rails "scanner:overlap[path/to/manifest.csv]"'
  task :overlap, [ :manifest ] => :environment do |_task, args|
    fresh = Collector::ScannerFindings.ground_truth(Pathname(args.fetch(:manifest)).expand_path.read)
    abort "Ground truth errors: #{fresh["errors"].inspect}" if fresh["errors"].any?
    fixtures = Rails.root.join("spec/fixtures/card_scanner")
    earlier = { "Phase 0" => "ground_truth.json", "the tuning cards" => "phase1_tuning_ground_truth.json", "the new corpus" => "phase1_live_ground_truth.json" }
      .transform_values { JSON.parse(fixtures.join(it).read).fetch("photos") }
    clashes = Collector::ScannerFindings.overlaps(fresh["photos"], earlier)
    abort(([ "These cards were used before:" ] + clashes).join("\n")) if clashes.any?
    puts "#{fresh["photos"].size} cards, none used by an earlier corpus."
  end

  desc "Spec 009 AC-9.1: score the live sitting (before Done): SCANNER_EMAIL=… GROUND_TRUTH=… bin/rails scanner:sitting_findings"
  task sitting_findings: :environment do
    run = Scanner::MeasurementRun.current
    abort "Measurement mode is off; run this in development." unless run
    account = User.find_by!(email_address: ENV.fetch("SCANNER_EMAIL")).account
    puts Collector::ScannerFindings::SittingReport.new(run:, account:, ground_truth: ENV.fetch("GROUND_TRUTH")).to_markdown
  end

  desc "Spec 011 AC-9.2–AC-9.6: score the art sitting (before Done), write its fixture: SCANNER_EMAIL=… GROUND_TRUTH=… bin/rails scanner:art_sitting_findings"
  task art_sitting_findings: :environment do
    run = Scanner::MeasurementRun.current
    abort "Measurement mode is off; run this in development." unless run
    account = User.find_by!(email_address: ENV.fetch("SCANNER_EMAIL")).account
    report = Collector::ScannerFindings::ArtSittingReport.new(run:, account:, ground_truth: ENV.fetch("GROUND_TRUTH"))
    Rails.root.join("spec/fixtures/card_scanner/phase3_shipped_sitting.json").write(JSON.pretty_generate(report.fixture) + "\n")
    puts report.to_markdown
  end
end
