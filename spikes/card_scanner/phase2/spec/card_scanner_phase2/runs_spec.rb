require_relative "../phase2_helper"
require "card_scanner_phase2/runs"
require "fileutils"
require "tmpdir"

RSpec.describe CardScannerPhase2::Runs do
  let(:git) { instance_double(CardScannerPhase2::Runs::Git, head: "a" * 40, clean?: true) }
  let(:dir) { Pathname(Dir.mktmpdir) }

  after { FileUtils.remove_entry(dir) }

  it "starts a development run and records its provenance" do
    run = described_class.start!("dev-hand", half: "development", root: dir, git:, settings_commit: "b" * 40, now: Time.utc(2026, 10, 3, 12))
    expect(JSON.parse(run.join("run.json").read)).to include("run" => "dev-hand", "half" => "development", "code_commit" => "a" * 40, "tree_clean" => true,
      "settings_commit" => "b" * 40, "started_at" => "2026-10-03T12:00:00Z")
  end

  it "refuses a held-out run without the settings commit" do
    expect { described_class.start!("held", half: "held_out", root: dir, git:, settings_commit: nil) }.to raise_error(described_class::Refused, /settings commit/)
  end

  it "refuses a held-out run when the code isn't at the settings commit" do
    expect { described_class.start!("held", half: "held_out", root: dir, git:, settings_commit: "b" * 40) }
      .to raise_error(described_class::Refused, /code is at/)
  end

  it "refuses a held-out run on a dirty tree" do
    dirty = instance_double(CardScannerPhase2::Runs::Git, head: "a" * 40, clean?: false)
    expect { described_class.start!("held", half: "held_out", root: dir, git: dirty, settings_commit: "a" * 40) }
      .to raise_error(described_class::Refused, /uncommitted/)
  end

  it "starts a held-out run at the settings commit on a clean tree" do
    run = described_class.start!("held", half: "held_out", root: dir, git:, settings_commit: "a" * 40)
    expect(JSON.parse(run.join("run.json").read)).to include("half" => "held_out", "settings_commit" => "a" * 40)
  end

  it "refuses to reuse a run directory" do
    described_class.start!("dev", half: "development", root: dir, git:, settings_commit: nil)
    expect { described_class.start!("dev", half: "development", root: dir, git:, settings_commit: nil) }.to raise_error(described_class::Refused, /exists/)
  end

  it "stamps a record with the run's provenance" do
    run = described_class.start!("dev", half: "development", root: dir, git:, settings_commit: nil, now: Time.utc(2026, 10, 3, 12))
    stamped = described_class.stamp(run, { "file" => "A.jpeg" }, now: Time.utc(2026, 10, 3, 12, 5))
    expect(stamped).to include("file" => "A.jpeg", "run" => "dev", "code_commit" => "a" * 40, "tree_clean" => true, "recorded_at" => "2026-10-03T12:05:00Z")
  end
end
