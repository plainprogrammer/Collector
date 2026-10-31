require "open3"
require "shellwords"

# What the pre-push hook runs (spec 035 decision 3): bin/ci checks for a documentation-only branch pushed with a
# plain push form, the full bin/ci otherwise. Anything it can't determine runs the full bin/ci (FR-4). Development
# tooling, required by path from .claude/hooks/pre_push_ci.rb; not autoloaded and not in the image.
module Collector
  module PushScope
    CODE_DIRS = %w[app/ bin/ config/ db/ lib/ script/ spec/ vendor/].freeze
    EXCLUDED_DIRS = %w[docs/export-format/ .claude/hooks/].freeze
    EXCLUDED_FILES = %w[.claude/settings.json .claude/settings.local.json].freeze

    # Variables an enclosing git hook may set; they would point git at another repository.
    GIT_ENV = { "GIT_DIR" => nil, "GIT_WORK_TREE" => nil, "GIT_INDEX_FILE" => nil, "GIT_COMMON_DIR" => nil }.freeze
    PUSH = /(^|[;&|\s])git(\s+-C\s+\S+)?\s+push/
    LEADING_CD = /\A\s*cd\s+(?:"([^"]*)"|'([^']*)'|([^\s;&|"']+))/
    GIT_C = /git\s+-C\s+(?:"([^"]*)"|'([^']*)'|([^\s"']+))\s+push/
    UPSTREAM = %w[-u --set-upstream].freeze

    # The changed paths can't be determined: the hook runs the full bin/ci.
    class Unknown < StandardError; end

    Parsed = Data.define(:accepted, :cd, :git_c, :reason)

    def self.documentation?(path)
      return false if path.start_with?(*EXCLUDED_DIRS) || EXCLUDED_FILES.include?(path)

      path.start_with?("docs/") || (path.end_with?(".md") && !path.start_with?(*CODE_DIRS))
    end

    def self.documentation_only?(paths) = paths.any? && paths.all? { documentation?(it) }

    def self.push?(command) = PUSH.match?(command)

    # Whether a command is one of decision 3's push forms. cd and git_c are filled for every command, so a refused
    # push still runs the full bin/ci in the checkout it names.
    def self.parse(command, current_branch:)
      cd = command[LEADING_CD, 1] || command[LEADING_CD, 2] || command[LEADING_CD, 3]
      git_c = command[GIT_C, 1] || command[GIT_C, 2] || command[GIT_C, 3]
      reason = refusal(command, current_branch)
      Parsed.new(accepted: reason.nil?, cd:, git_c:, reason: reason || "accepted push form")
    end

    def self.refusal(command, current_branch)
      return "`||` in the command" if command.include?("||")
      return "`;` in the command" if command.include?(";")
      return "more than one git push in the command" if command.scan(PUSH).size > 1
      return "a background `&` in the command" if command.gsub(/&&|>&\d/, "").include?("&")

      rest = command.strip.sub(/\s*\|\s*(?:tail|head)\s+-\d+\z/, "").sub(/\s*2>&1\z/, "")
      return "a pipe other than `| tail -N` or `| head -N`" if rest.include?("|")

      rest = rest.sub(/\A\s*cd\s+(?:"[^"]*"|'[^']*'|[^\s;&|"']+)\s*&&\s*/, "")
      return "a push chained after something other than `cd <dir> &&`" if rest.include?("&&")

      words = Shellwords.split(rest)
      return "not a plain `git push` command" unless words.shift == "git"

      words.shift(2) if words.first == "-C"
      return "not a plain `git push` command" unless words.shift == "push"

      push_arguments_refusal(words, current_branch)
    rescue ArgumentError => error
      "the command can't be split into words (#{error.message})"
    end
    private_class_method :refusal

    def self.push_arguments_refusal(words, current_branch)
      upstream = words.first if UPSTREAM.include?(words.first)
      words = words.drop(1) if upstream
      option = words.find { it.start_with?("-") }
      return "option #{option} pushes more than the current branch" if option
      return "#{upstream} without a remote and the current branch" if upstream && words.size != 2
      return nil if words.size <= 1
      return "several refspecs (#{words.drop(1).join(' ')})" if words.size > 2

      ref = words.last
      return "refspec #{ref} names a destination" if ref.include?(":")
      return nil if ref == "HEAD" || ref == current_branch

      "ref #{ref} is not the current branch"
    end
    private_class_method :push_arguments_refusal

    def self.git!(directory, *args)
      out, err, status = Open3.capture3(GIT_ENV, "git", *args, chdir: directory)
      raise Unknown, "git #{args.join(' ')} failed: #{err.strip}" unless status.success?

      out.force_encoding(Encoding::UTF_8)
    rescue SystemCallError => error
      raise Unknown, "git #{args.join(' ')} failed: #{error.message}"
    end

    def self.current_branch(directory)
      out, _err, status = Open3.capture3(GIT_ENV, "git", "symbolic-ref", "-q", "--short", "HEAD", chdir: directory)
      status.success? ? out.strip : nil
    end

    # Every path the branch changes since it left origin/main, both names of a rename (decision 3).
    def self.changed_paths(directory)
      git!(directory, "rev-parse", "--is-inside-work-tree")
      raise Unknown, "HEAD is detached" if current_branch(directory).nil?

      begin
        git!(directory, "rev-parse", "--verify", "--quiet", "refs/remotes/origin/main^{commit}")
      rescue Unknown
        raise Unknown, "there is no origin/main"
      end
      base = begin
        git!(directory, "merge-base", "HEAD", "origin/main").strip
      rescue Unknown => error
        raise Unknown, "there is no merge base with origin/main (#{error.message})"
      end
      git!(directory, "diff", "-z", "--no-renames", "--name-only", base, "HEAD").split("\0")
    end

    # [bin/ci arguments, why]: ["checks"] only for an accepted push form and a documentation-only branch.
    def self.decide(command, directory:, current_branch:, classifier: PushScope)
      parsed = parse(command, current_branch:)
      return [ [], "push form not eligible for the fast path: #{parsed.reason}" ] unless parsed.accepted

      paths = begin
        changed_paths(directory)
      rescue Unknown => error
        return [ [], "changed paths unknown: #{error.message}" ]
      end
      count = paths.uniq.size
      files = "#{count} #{count == 1 ? 'file' : 'files'}"
      if classifier.documentation_only?(paths)
        [ [ "checks" ], "documentation-only branch (#{files}): skipping RSpec" ]
      else
        [ [], "branch is not documentation-only (#{files} changed)" ]
      end
    rescue StandardError => error
      [ [], "error while classifying the branch (#{error.class}: #{error.message})" ]
    end
  end
end
