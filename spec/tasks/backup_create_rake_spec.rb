require "rails_helper"
require "rake"

RSpec.describe "backup:create", :backup, :committed, type: :task do
  let(:directory) { scratch("out") }
  let!(:seed) { seed_instance }

  before { Rails.application.load_tasks unless Rake::Task.task_defined?("backup:create") }

  def run_task(*arguments)
    Rake::Task["backup:create"].reenable
    captured_streams { Rake::Task["backup:create"].invoke(*arguments) }
  end

  it "prints the file's path, size, schema version, counts and time, and exits 0 (AC-1.1)", :aggregate_failures do
    out, err, status = run_task(directory.to_s)

    expect(status).to eq(0)
    expect(err).to be_empty
    expect(out).to include("Backup written: #{directory}/collector-backup-", "Size: ", "Schema version: #{release_versions.max_by(&:to_i)}",
      "Holds: 1 account, 1 user and 3 lots", "Took: ")
  end

  it "prints no recognisable name, address or card, and logs none (AC-1.7)", :aggregate_failures do
    out = err = nil
    log = captured_log { out, err, = run_task(directory.to_s) }

    seed.values.each do |value|
      expect(out).not_to include(value)
      expect(err).not_to include(value)
      expect(log).not_to include(value)
    end
  end

  it "says what to do, in two lines and with status 1, when no directory is given", :aggregate_failures do
    out, err, status = run_task

    expect(status).to eq(1)
    expect(out).to be_empty
    expect(err.lines(chomp: true)).to eq([ "No directory was given.", %(Run: bin/rails "backup:create[/path/to/directory]".) ])
  end

  it "refuses an argument with a comma, which Rake reads as two" do
    _out, err, status = run_task("/tmp/a", "b")

    expect([ status, err.lines.first ]).to eq([ 1, "The directory argument contains a comma, which Rake reads as a second argument.\n" ])
  end

  it "prints a refusal as two sentences without an exception class or a backtrace, and exits 1", :aggregate_failures do
    _out, err, status = run_task(scratch_path("not-there").to_s)

    expect(status).to eq(1)
    expect(err.lines.size).to eq(2)
    expect(err).not_to match(/Refusal|Collector::|\.rb:\d+/)
  end
end
