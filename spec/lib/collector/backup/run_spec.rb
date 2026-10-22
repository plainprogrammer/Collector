require "rails_helper"

RSpec.describe Collector::Backup, ".run", :backup do
  it "prints a refusal as its two sentences and exits 1", :aggregate_failures do
    out, err, status = captured_streams { described_class.run { raise Collector::Backup::Refusal.new("It is wrong.", "Do this.") } }

    expect([ out, err, status ]).to eq([ "", "It is wrong.\nDo this.\n", 1 ])
  end

  it "prints a system error nothing else names as two plain lines without its class or its frames, and exits 1", :aggregate_failures do
    out, err, status = captured_streams { described_class.run { raise Errno::EACCES, "/rails/storage/production.sqlite3" } }

    expect([ out, status ]).to eq([ "", 1 ])
    expect(err.lines.size).to eq(2)
    expect(err.lines.first).to eq("The command stopped: Permission denied.\n")
    expect(err.lines.last).to start_with("It left nothing half-made; check that")
    expect(err).not_to match(/Errno|EACCES|Exception|Error|\.rb:\d+/)
  end

  it "does the same for a SQLite error", :aggregate_failures do
    _out, err, status = captured_streams { described_class.run { raise SQLite3::IOException, "disk I/O error" } }

    expect([ status, err.lines.first, err.lines.size ]).to eq([ 1, "The command stopped: Disk I/O error.\n", 2 ])
  end
end
