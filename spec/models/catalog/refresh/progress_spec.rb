require "rails_helper"

RSpec.describe Catalog::Refresh::Progress, type: :model do
  subject(:progress) { described_class.new(run, counts, clock: -> { now[0] }) }

  let(:run) { Catalog::RefreshRun.start!("fake", trigger: "manual") }
  let(:counts) { Hash.new(0) }
  let(:now) { [ 0.0 ] }
  let(:writes) { [] }

  before do
    allow(run).to receive(:progress!).and_wrap_original do |original, **written|
      writes << written.slice(:stage, :done, :total).values + [ written[:counts][:seen] ]
      original.call(**written)
    end
    progress.stage("sync")
  end

  # Sees records one by one, each taking the given seconds, and counts them as the refresh does.
  def see(records, seconds_each:)
    records.times do
      now[0] += seconds_each
      counts[:seen] += 1
      progress.seen
    end
  end

  it "writes a stage at once, without a place in it", :aggregate_failures do
    expect(writes).to eq([ [ "sync", nil, nil, 0 ] ])
    expect(run.reload).to have_attributes(stage: "sync", stage_done: nil, stage_total: nil)
  end

  it "writes every 5,000 records seen (spec 015 AC-2.9)" do
    see(12_000, seconds_each: 1.0 / 4_096) # 5,000 records take about 1.22 seconds

    expect(writes.map(&:last)).to eq([ 0, 5_000, 10_000 ])
  end

  it "writes when 2 seconds pass with fewer records, well inside the 5 seconds asked (AC-2.9)" do
    see(160, seconds_each: 0.015625) # 2.5 seconds, 160 records; 2 seconds are up at the 128th

    expect(writes.map(&:last)).to eq([ 0, 128 ])
  end

  it "never writes more than once a second (AC-2.9)" do
    see(12_000, seconds_each: 1.0 / 8_192) # 5,000 records take about 0.61 seconds; a second is up at the 8,192nd

    expect(writes.map(&:last)).to eq([ 0, 8_192 ])
  end

  it "records where the source says it is, on the same schedule", :aggregate_failures do
    progress.at(10, 100)
    now[0] += 2
    progress.at(60, 100)

    expect(writes.last).to eq([ "sync", 60, 100, 0 ])
    expect(writes.size).to eq(2)
  end

  it "forgets the place when the stage changes" do
    now[0] += 2
    progress.at(60, 100)
    progress.stage("retire")

    expect(writes.last).to eq([ "retire", nil, nil, 0 ])
  end

  it "writes a report that comes before any stage, instead of failing", :aggregate_failures do
    early = described_class.new(run, counts, clock: -> { now[0] })

    expect { early.at(1, 2) }.not_to raise_error
    expect(run.reload).to have_attributes(stage: nil, stage_done: 1, stage_total: 2)
  end

  it "writes with the real clock by default" do
    expect { described_class.new(run, counts).stage("index") }.to change { run.reload.stage }.to("index")
  end
end
