require "time"

module CardScannerPhase2
  # Starts a run directory with its provenance, and refuses held-out runs before the freeze (AC-1.2, AC-1.5).
  module Runs
    class Refused < StandardError; end

    # Thin git reader, replaceable in specs.
    class Git
      def initialize(repo = REPO) = @repo = repo.to_s
      def head = IO.popen([ "git", "-C", @repo, "rev-parse", "HEAD" ], &:read).strip
      def clean? = IO.popen([ "git", "-C", @repo, "status", "--porcelain" ], &:read).strip.empty?
    end

    module_function

    def start!(name, half:, root: CardScannerPhase2.runs_dir, git: Git.new, settings_commit: ENV["SETTINGS_COMMIT"], now: Time.now.utc)
      raise ArgumentError, "half must be development or held_out" unless %w[development held_out].include?(half)

      guard!(half, git, settings_commit)
      dir = root.join(name)
      raise Refused, "#{dir} exists; held-out runs happen once, so pick a new name" if dir.exist?

      dir.mkpath
      dir.join("run.json").write(JSON.pretty_generate(provenance(name, half, git, settings_commit, now)))
      dir
    end

    def guard!(half, git, settings_commit)
      return if half == "development"
      raise Refused, "a held-out run needs the settings commit (SETTINGS_COMMIT)" if settings_commit.to_s.empty?
      raise Refused, "the code is at #{git.head}, not the settings commit #{settings_commit}" unless git.head == settings_commit
      raise Refused, "the working tree has uncommitted changes; held-out runs need a clean tree" unless git.clean?
    end

    def provenance(name, half, git, settings_commit, now)
      { "run" => name, "half" => half, "code_commit" => git.head, "tree_clean" => git.clean?, "settings_commit" => settings_commit,
        "started_at" => now.iso8601 }
    end

    def read(dir) = JSON.parse(dir.join("run.json").read)

    def stamp(dir, record, now: Time.now.utc)
      run = read(dir)
      record.merge("run" => run["run"], "half" => run["half"], "code_commit" => run["code_commit"], "tree_clean" => run["tree_clean"],
        "settings_commit" => run["settings_commit"], "recorded_at" => now.iso8601)
    end
  end
end
