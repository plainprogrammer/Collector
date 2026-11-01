require "rails_helper"
require "tmpdir"
require Rails.root.join("lib/collector/ci_shard").to_s

RSpec.describe Collector::CiShard do
  let(:spec_files) { Dir["spec/**/*_spec.rb"].sort }
  let(:scratch) { Dir.mktmpdir("ci_shard") }

  after { FileUtils.remove_entry(scratch) }

  def shards(total, log)
    (1..total).map { |index| described_class.new(index:, total:, log:).files }
  end

  def expect_every_file_once(log)
    [ 2, 3, 4 ].each do |total|
      files = shards(total, log).flatten
      expect(files.tally.select { |_, count| count > 1 }.keys).to be_empty, "files in two of #{total} shards"
      expect(files.sort).to eq(spec_files), "#{total} shards"
    end
  end

  def fixture_log
    File.join(scratch, "runtime_log.txt").tap do |path|
      lines = spec_files.drop(1).map { "#{it}:1.0" } + [ "spec/deleted/gone_spec.rb:30.0" ]
      File.write(path, lines.join("\n") + "\n")
    end
  end

  def missing_log = File.join(scratch, "absent.txt")

  describe "#files" do
    it "puts every spec file in exactly one shard with a run-time log (AC-1.5)", :aggregate_failures do
      expect_every_file_once(fixture_log)
    end

    it "puts every spec file in exactly one shard without a run-time log (AC-1.5)", :aggregate_failures do
      expect_every_file_once(missing_log)
    end

    it "puts every spec file in exactly one of four shards with the committed run-time log (decision 6)", :aggregate_failures do
      expect(File.file?(described_class::RUNTIME_LOG)).to be(true)
      files = (1..4).map { |index| described_class.new(index:, total: 4).files }.flatten

      expect(files.tally.select { |_, count| count > 1 }.keys).to be_empty
      expect(files.sort).to eq(spec_files)
    end
  end

  describe "#grouping" do
    it "groups by run time when the log exists and by file size when it doesn't (decision 6)", :aggregate_failures do
      expect(described_class.new(index: 1, total: 2, log: fixture_log).grouping).to eq(:runtime)
      expect(described_class.new(index: 1, total: 2, log: missing_log).grouping).to eq(:filesize)
    end
  end

  describe ".replay_command" do
    it "runs the files in order with the seed, CI set and the profile (AC-1.4, decision 8)" do
      expect(described_class.replay_command(files: %w[spec/a_spec.rb spec/b_spec.rb], seed: 7))
        .to eq("CI=true bin/rspec --seed 7 --profile 10 spec/a_spec.rb spec/b_spec.rb")
    end
  end
end
