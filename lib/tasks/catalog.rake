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
    runs = Catalog::RefreshRun.for_type(collectible_type).recent.limit(10)
    puts "No #{collectible_type} refresh runs yet." if runs.none?
    runs.each { |run| puts run.status_line }
  end
end
