namespace :catalog do
  desc 'Queue a background catalog refresh (default mtg): bin/rails "catalog:refresh[mtg]"'
  task :refresh, [ :collectible_type ] => :environment do |_task, args|
    collectible_type = args[:collectible_type] || "mtg"
    Catalog.source_class(collectible_type)
    Catalog::RefreshJob.perform_later(collectible_type, "manual")
    puts %(Queued #{collectible_type} catalog refresh. Check progress with: bin/rails "catalog:status[#{collectible_type}]")
  end

  desc 'Show the 10 most recent catalog refresh runs (default mtg): bin/rails "catalog:status[mtg]"'
  task :status, [ :collectible_type ] => :environment do |_task, args|
    collectible_type = args[:collectible_type] || "mtg"
    source = Catalog.source_class(collectible_type)
    runs = Catalog::RefreshRun.for_type(collectible_type).recent.limit(10)
    puts "No #{collectible_type} refresh runs yet." if runs.none?
    # A run reads as the admin catalog page words it: a stalled one interrupted, or still running when its job is
    # (spec 015 AC-3.5); one whose job the queue has failed interrupted.
    operation = Catalog::RefreshOperation.new(collectible_type)
    runs.each { |run| puts operation.status_line(run) }
    source.status_lines.each { |line| puts line } if source.respond_to?(:status_lines)
  end
end
