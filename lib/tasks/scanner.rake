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
      prefix: ENV["FIXTURES_PREFIX"].presence }.compact)
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
end
