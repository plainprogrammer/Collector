require "rails_helper"

RSpec.describe Collector::Backup::Manifest, :backup do
  let(:fields) do
    { backup_format_version: 1, taken_at: "2026-10-21T14:21:00Z", schema_version: "20261020100002", snapshot_bytes: 4096,
      snapshot_sha256: "a" * 64, counts: { "accounts" => 1, "users" => 1, "lots" => 7 } }
  end

  let(:prices) { { "schema_version" => "20261113100001", "snapshot_bytes" => 2048, "snapshot_sha256" => "b" * 64, "counts" => { "current_prices" => 3, "price_changes" => 5 } } }

  it "writes exactly the six members of AC-1.4 and reads them back", :aggregate_failures do
    manifest = described_class.new(**fields)

    expect(JSON.parse(manifest.to_json).keys).to match_array(%w[backup_format_version taken_at schema_version snapshot_bytes snapshot_sha256 counts])
    expect(described_class.parse(manifest.to_json)).to eq(manifest)
  end

  it "refuses a version this release doesn't restore, before it looks at any other member (AC-3.4)", :aggregate_failures do
    text = JSON.generate("backup_format_version" => 99, "future" => "members")

    expect { described_class.parse(text) }.to raise_error(described_class::UnknownVersion) { |error| expect(error.version).to eq(99) }
  end

  it "refuses what isn't a manifest of a known version", :aggregate_failures do
    [ "not json", "[]", JSON.generate(fields.merge(extra: 1)), JSON.generate(fields.except(:counts)),
      JSON.generate(fields.merge(snapshot_sha256: "xyz")), JSON.generate(fields.merge(snapshot_bytes: "4096")),
      JSON.generate(fields.merge(counts: { "accounts" => 1 })) ].each do |text|
      expect { described_class.parse(text) }.to raise_error(described_class::Invalid)
    end
  end

  it "writes version 2 with the prices member and reads it back (spec 081 AC-4.2)", :aggregate_failures do
    manifest = described_class.new(**fields, backup_format_version: 2, prices:)

    expect(JSON.parse(manifest.to_json).keys).to match_array(%w[backup_format_version taken_at schema_version snapshot_bytes snapshot_sha256 counts prices])
    expect(described_class.parse(manifest.to_json)).to eq(manifest)
    expect(manifest.entries).to eq([ [ "primary.sqlite3", 4096, "a" * 64 ], [ "prices.sqlite3", 2048, "b" * 64 ] ])
  end

  it "keeps version 1 as it was: no prices member, one entry" do
    expect(described_class.new(**fields).entries).to eq([ [ "primary.sqlite3", 4096, "a" * 64 ] ])
  end

  it "refuses a version 2 manifest without prices, a version 1 with them, and malformed prices", :aggregate_failures do
    [ JSON.generate(fields.merge(backup_format_version: 2)), JSON.generate(fields.merge(prices:)),
      JSON.generate(fields.merge(backup_format_version: 2, prices: prices.merge("counts" => { "current_prices" => 1 }))),
      JSON.generate(fields.merge(backup_format_version: 2, prices: prices.merge("snapshot_sha256" => "x"))) ].each do |text|
      expect { described_class.parse(text) }.to raise_error(described_class::Invalid), text
    end
  end
end
