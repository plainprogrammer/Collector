require "rails_helper"

# The smoke scripts run under `set -o pipefail`. A pipe into a reader that stops early (`grep -q`, `grep -m`, `head`)
# makes the writer's next write fail once the reader has gone (curl exits 23), and pipefail then reports the whole
# pipeline as failed although the reader found what it looked for. With GNU grep, as on the CI runners, a page of
# 13,516 bytes delivered in two writes failed 100 of 100 times at a 13,000-byte split (#217: `bin/backup-smoke`'s
# "the lot isn't on the collection page" on arm64). The scripts capture a command's output first and test it after
# (`bin/image-smoke`, "no pipe can end early under pipefail"); this guard keeps all three that way.
RSpec.describe "The smoke scripts' pipes (#217)", type: :config do
  let(:scripts) { %w[bin/backup-smoke bin/image-smoke bin/upgrade-smoke] }
  let(:advice) do
    "Capture the command's output first (out=\"$(command)\"), then test it (grep -q ... <<<\"$out\"); " \
      "a pipe into an early-exiting reader fails under pipefail when the writer still has output (#217)"
  end

  # The lines of a script's text that pipe into an early-exiting reader: head, or grep asked to quit, list files or stop
  # after a count. `||` is not a pipe, and a comment is not a command.
  def early_exit_pipes(text)
    reader = /(?<!\|)\|(?!\|)\s*(?:head\b|grep\b[^|\n]*?\s(?:-[a-zA-Z]*[qlm][a-zA-Z0-9]*|--quiet|--silent|--max-count|--files-with-matches)(?:[\s=]|\z))/
    text.each_line.with_index(1).filter_map do |line, number|
      code = line.sub(/(\A|\s)#.*/, "")
      "line #{number}: #{line.strip}" if code.match?(reader)
    end
  end

  it "never pipes into a reader that exits early, in any of the three scripts", :aggregate_failures do
    scripts.each do |script|
      found = early_exit_pipes(Rails.root.join(script).read)
      expect(found).to be_empty, "#{script} has #{found.join('; ')}. #{advice}"
    end
  end

  describe "the guard's own matcher (a negative control)" do
    it "finds a pipe into grep -q, grep -qx, grep -m, grep -l or head", :aggregate_failures do
      [ 'curl -s "$url" | grep -q "Smoke Dragon" || fail x', 'a | grep -qx b', 'a | grep -E -m 1 b', 'a | grep -l b',
        'a | grep --quiet b', 'port="$(docker port x 8080 | head -n 1)"', 'a | sed s/x/y/ | head -n 1' ].each do |line|
        expect(early_exit_pipes(line)).not_to be_empty, line
      end
    end

    it "lets reads that consume everything, here-strings, `||` and comments through", :aggregate_failures do
      [ 'a | tail -n 1', 'a | grep -c b', 'a | grep -E "x|y"', 'grep -q b <<<"$out"', 'a || grep -q b', 'a || head -n 1',
        '# a | grep -q b', 'a # | head -n 1', 'a | sed -n "s/x/y/p"', 'a | grep -v b' ].each do |line|
        expect(early_exit_pipes(line)).to be_empty, line
      end
    end
  end
end
