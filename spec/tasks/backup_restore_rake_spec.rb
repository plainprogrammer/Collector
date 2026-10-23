require "rails_helper"
require "rake"

RSpec.describe "backup:restore", :backup, :committed, type: :task do
  let(:volume) { scratch("volume") }
  let!(:seed) { seed_instance }
  # The real database, taken before the stub below points Databases.configured at the scratch volume.
  let!(:live) { instance_database }

  before do
    Rails.application.load_tasks unless Rake::Task.task_defined?("backup:restore")
    allow(Collector::Backup::Databases).to receive(:configured).and_return(databases_for(volume))
  end

  def run_task(*arguments)
    Rake::Task["backup:restore"].reenable
    captured_streams { Rake::Task["backup:restore"].invoke(*arguments) }
  end

  it "restores onto the configured volume, prints the facts and exits 0 (AC-2.1)", :aggregate_failures do
    path = create_backup(source: live)
    out, err, status = run_task(path.to_s)

    expect([ status, err ]).to eq([ 0, "" ])
    expect(out).to include("Restored #{path.basename} into #{volume}.", "it holds 1 account, 1 user and 3 lots.", "Start Collector now")
    expect(volume.join("production.sqlite3")).to exist
  end

  it "prints no recognisable name, address or card, and logs none (AC-1.7)", :aggregate_failures do
    path = create_backup(source: live)
    out = err = nil
    log = captured_log { out, err, = run_task(path.to_s) }

    seed.values.each do |value|
      expect(out).not_to include(value)
      expect(err).not_to include(value)
      expect(log).not_to include(value)
    end
  end

  it "prints each refusal as two lines, exits 1 and prints nothing else (AC-3.8)", :aggregate_failures do
    path = create_backup(source: live)
    volume.join("production.sqlite3").write("in the way")
    out, err, status = run_task(path.to_s)

    expect([ out, status ]).to eq([ "", 1 ])
    expect(err.lines(chomp: true).first).to eq("The volume at #{volume} isn't empty: it holds production.sqlite3.")
    expect(err.lines.size).to eq(2)
    volume.join("production.sqlite3").delete

    text = scratch_path("note.txt").tap { it.write("hello") }
    out, err, status = run_task(text.to_s)
    expect([ out, status, err.lines.size ]).to eq([ "", 1, 2 ])
    expect(err).not_to match(/Refusal|Collector::|\.rb:\d+/)
  end

  it "says what to do when no file is given, and refuses an argument with a comma", :aggregate_failures do
    _out, err, status = run_task
    expect([ status, err.lines(chomp: true) ]).to eq([ 1, [ "No file was given.", %(Run: bin/rails "backup:restore[/path/to/collector-backup.tar.gz]".) ] ])
    expect(run_task("/a", "b")[2]).to eq(1)
  end
end
