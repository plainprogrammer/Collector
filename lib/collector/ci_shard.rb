require "shellwords"

# One of M groups of spec files, formed by parallel_tests from the committed run-time log, or by file size without
# one (spec 035 decision 6). The same files on every machine, whatever its core count. Development tooling, required
# by path; not autoloaded and not in the image.
module Collector
  class CiShard
    RUNTIME_LOG = "spec/support/runtime_log.txt"

    attr_reader :index, :total

    def initialize(index:, total:, log: RUNTIME_LOG)
      @index, @total, @log = index, total, log
    end

    def grouping = File.file?(@log) ? :runtime : :filesize

    def files
      require "parallel_tests"
      require "parallel_tests/rspec/runner"
      options = grouping == :runtime ? { group_by: :runtime, runtime_log: @log, allowed_missing_percent: 100 } : { group_by: :filesize }
      ParallelTests::RSpec::Runner.tests_in_groups([ "spec" ], total, options).fetch(index - 1)
    end

    def self.replay_command(files:, seed:) = "CI=true bin/rspec --seed #{seed} --profile 10 #{files.shelljoin}"
  end
end
