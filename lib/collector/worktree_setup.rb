require "fileutils"
require "open3"

module Collector
  # Worktree-aware parts of bin/setup (spec 003): detect the checkout kind, copy
  # the gitignored files listed in .worktreeinclude from the main checkout, enable
  # the versioned git hooks, and serialize concurrent setups. Stdlib only.
  class WorktreeSetup
    INCLUDE_LIST = ".worktreeinclude"
    # Missing from the main checkout without a warning: Rails regenerates it.
    REGENERATED_IF_MISSING = %w[tmp/local_secret.txt].freeze
    NOT_GIT = "Not a git checkout; skipping file copy and worktree hooks.".freeze

    attr_reader :root

    def initialize(root:, env: ENV, git: "git")
      @root = root
      @env = env
      @git = git
    end

    def checkout_kind
      @checkout_kind ||= begin
        git_dir, common_dir = git_output("rev-parse", "--path-format=absolute", "--git-dir", "--git-common-dir")&.lines(chomp: true)
        if common_dir.nil? then :none
        elsif git_dir == common_dir then :main
        else :linked
        end
      end
    end

    def main_checkout
      return root if checkout_kind == :main
      return unless checkout_kind == :linked

      # The first porcelain entry is the main worktree; a bare repository has no files to copy.
      first = git_output("worktree", "list", "--porcelain").to_s.split("\n\n").first.to_s.lines(chomp: true)
      return if first.include?("bare")

      first.find { |line| line.start_with?("worktree ") }&.delete_prefix("worktree ")
    end

    def included_paths
      list = File.join(root, INCLUDE_LIST)
      return [] unless File.file?(list)

      File.readlines(list, chomp: true).map(&:strip).reject { |line| line.empty? || line.start_with?("#") }
    end

    def copy_included_files
      return [ NOT_GIT ] if checkout_kind == :none

      messages = []
      source = main_checkout
      if checkout_kind == :linked
        messages << orca_root_notice(source)
        messages << "!! main checkout not found (bare repository?); skipping file copy." if source.nil?
      end

      included_paths.each do |path|
        destination = File.join(root, path)
        next if File.exist?(destination)

        origin = source && File.join(source, path)
        if checkout_kind == :linked && origin && File.file?(origin)
          copy_secret(origin, destination)
          messages << "Copied #{path} from #{source}"
        elsif !REGENERATED_IF_MISSING.include?(path)
          messages << missing_warning(path)
        end
      end
      messages.compact
    end

    private

    def git_output(*args)
      out, status = Open3.capture2(git_env, @git, *args, chdir: root, err: File::NULL)
      out if status.success?
    rescue SystemCallError
      nil
    end

    # git reads its GIT_* variables from the injected env only (an enclosing
    # hook's GIT_DIR must not redirect it); with the default ENV this is a no-op.
    def git_env
      ENV.keys.grep(/\AGIT_/).to_h { |key| [ key, nil ] }
        .merge(@env.to_h.select { |key, _| key.start_with?("GIT_") })
    end

    def copy_secret(origin, destination)
      FileUtils.mkdir_p(File.dirname(destination))
      partial = "#{destination}.#{Process.pid}.partial"
      File.open(partial, File::WRONLY | File::CREAT | File::EXCL, 0o600) { |f| f.write(File.binread(origin)) }
      File.chmod(0o600, partial)
      File.rename(partial, destination)
    ensure
      FileUtils.rm_f(partial) if partial
    end

    def missing_warning(path)
      hint = path == "config/master.key" ? " or set RAILS_MASTER_KEY" : ""
      "!! #{path} is missing. Credentials are unavailable until you copy it into #{root}/#{path}#{hint}."
    end

    def orca_root_notice(source)
      orca_root = @env["ORCA_ROOT_PATH"]
      return if orca_root.nil? || orca_root.empty? || source.nil?
      return if canonical(orca_root) == canonical(source)

      "Note: ORCA_ROOT_PATH (#{orca_root}) differs from git's main checkout (#{source}); using git's."
    end

    def canonical(path)
      File.realpath(path)
    rescue SystemCallError
      File.expand_path(path)
    end
  end
end
