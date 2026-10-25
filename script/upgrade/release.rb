# Release resolution for the upgrade proof (spec 031 decision 2): the release tags of a checkout, the tag being built, and
# the previous release. Standard library only, so bin/ci's guard runs it before any gem is needed.
require "open3"

module Upgrade
  class Release
    Error = Class.new(StandardError)
    TagsNotFetched = Class.new(Error)

    TAG = /\Av(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?\z/

    # A release tag with semver precedence: by number, a pre-release before its release, pre-release identifiers
    # compared one by one (numbers before words, a shorter list before a longer one that starts with it).
    Version = Struct.new(:tag, :core, :pre) do
      include Comparable

      def self.parse(tag)
        match = TAG.match(tag.to_s)
        match && new(tag, match.captures.first(3).map(&:to_i), match[4]&.split("."))
      end

      def stable? = pre.nil?
      def number = tag.delete_prefix("v")
      def to_s = tag

      def <=>(other)
        return core <=> other.core unless core == other.core
        return 0 if pre.nil? && other.pre.nil?
        return 1 if pre.nil?
        return -1 if other.pre.nil?

        compare_identifiers(pre, other.pre)
      end

      private
        def compare_identifiers(left, right)
          left.zip(right).each do |one, other|
            return 1 if other.nil?

            order = identifier_order(one, other)
            return order unless order.zero?
          end
          left.size <=> right.size
        end

        def identifier_order(one, other)
          numeric = one.match?(/\A\d+\z/)
          other_numeric = other.match?(/\A\d+\z/)
          return one.to_i <=> other.to_i if numeric && other_numeric
          return -1 if numeric
          return 1 if other_numeric

          one <=> other
        end
    end

    def initialize(dir = Dir.pwd, env: ENV)
      @dir = dir
      @env = env
    end

    def tags = git("tag", "--list").lines(chomp: true)

    def versions = tags.filter_map { Version.parse(it) }

    # The tag being built: the pushed tag; in GitHub Actions otherwise none (also when HEAD happens to be tagged, so the
    # ci and image jobs agree for one run); elsewhere the tag of highest precedence at HEAD, else none.
    def building
      if @env["GITHUB_REF_TYPE"] == "tag"
        name = @env["GITHUB_REF_NAME"].to_s
        Version.parse(name) || raise(Error, "#{name.inspect} is not a release tag (vX.Y.Z or vX.Y.Z-suffix)")
      elsif @env["GITHUB_ACTIONS"].to_s.empty?
        git("tag", "--points-at", "HEAD").lines(chomp: true).filter_map { Version.parse(it) }.max
      end
    end

    # The newest stable tag, strictly older than the tag being built when one is. Nil when there is none: tags present
    # and none stable, or no tags and no remote. A remote with no tag at all is a checkout that did not fetch them; a
    # remote with only tags that are no release passes as "no previous release".
    def previous
      all = versions
      if tags.empty? && remote?
        raise TagsNotFetched, "this checkout has a remote but no tags, so the previous release can't be found; fetch them " \
          "from the repository that publishes releases (git fetch <upstream> --tags, or fetch-depth: 0 in actions/checkout)"
      end

      ceiling = building
      stable = all.select(&:stable?)
      stable = stable.select { it < ceiling } if ceiling
      stable.max
    end

    def migration_files(ref) = git("ls-tree", "-r", "--name-only", ref, "--", "db/migrate").lines(chomp: true).sort

    def migration_versions(ref) = migration_files(ref).filter_map { File.basename(it)[/\A\d+/] }

    def show(ref, path) = git("show", "#{ref}:#{path}", binmode: true)

    def ancestor?(ref) = Open3.capture3("git", "merge-base", "--is-ancestor", ref, "HEAD", chdir: @dir).last.success?

    def head = git("rev-parse", "HEAD").strip

    def remote? = !git("remote").strip.empty?

    private
      def git(*args, binmode: false)
        out, err, status = Open3.capture3("git", *args, chdir: @dir, binmode:)
        raise Error, "git #{args.join(" ")} failed: #{err.strip}" unless status.success?

        out
      end
  end
end
