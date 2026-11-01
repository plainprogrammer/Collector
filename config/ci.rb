# Run using bin/ci. Groups (spec 035 decision 4): bin/ci, bin/ci checks, bin/ci rspec, bin/ci rspec N/M.
require_relative "../lib/collector/ci_groups"
require_relative "../lib/collector/ci_shard"

begin
  selection = Collector::CiGroups.parse(ARGV)
rescue Collector::CiGroups::Unknown => error
  abort error.message
end

# Every RSpec run prints the 10 slowest examples (decision 8). Only a shard fixes the seed, so its replay is exact.
rspec = "bin/rspec --profile 10"

if selection.index
  seed = Integer(ENV.fetch("SEED") { rand(1..65_535) })
  shard = Collector::CiShard.new(index: selection.index, total: selection.total)
  files = shard.files
  puts "Shard #{selection.index}/#{selection.total}: #{files.size} files, grouped by #{shard.grouping}, seed #{seed}"
  puts "Balance may be worse: no run-time log at #{Collector::CiShard::RUNTIME_LOG}" if shard.grouping == :filesize
  puts "Replay: #{Collector::CiShard.replay_command(files:, seed:)}"
  rspec = "bin/rspec --seed #{seed} --profile 10 #{files.shelljoin}"
end

CI.run do
  step "Setup", "bin/setup --skip-server"

  unless selection.group == :rspec
    step "Upgrade: released migrations unchanged", "ruby script/upgrade/guard.rb"
    step "Style: Ruby", "bin/rubocop"
    step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
    step "Security: Gem audit", "bin/bundler-audit"
    step "Security: Importmap vulnerability audit", "bin/importmap audit"
  end

  step "Tests: RSpec", rspec unless selection.group == :checks

  # Optional: set a green GitHub commit status to unblock PR merge.
  # Requires the `gh` CLI and `gh extension install basecamp/gh-signoff`.
  # if success?
  #   step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  # else
  #   failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  # end
end
