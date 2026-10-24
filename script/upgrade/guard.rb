# The engine-free half of the upgrade proof (spec 031 decision 1, Story 8): a released migration is never edited,
# deleted or renamed. Compares every file in db/migrate/ at the previous release's tag with the working tree. Standard
# library only. Run as `ruby script/upgrade/guard.rb` from the repository root (the bin/ci step).
require_relative "release"

module Upgrade
  class Guard
    Result = Struct.new(:ok, :lines) do
      def ok? = ok
    end

    ADVICE = "A released migration is never edited or deleted; add a new migration instead (.claude/rules/sqlite-and-migrations.md)."

    def initialize(release, root: Dir.pwd)
      @release = release
      @root = root
    end

    def call
      previous = @release.previous
      return Result.new(true, [ "no previous release; the migration guard has nothing to compare" ]) if previous.nil?

      edited, missing = released_files(previous.tag).partition { File.file?(File.join(@root, it)) }
      edited = edited.reject { File.binread(File.join(@root, it)) == @release.show(previous.tag, it) }
      problems = describe_edited(edited, previous.tag) + describe_missing(missing, previous.tag)
      return Result.new(true, [ "#{previous.tag}: its #{released_files(previous.tag).size} migrations are unchanged" ]) if problems.empty?

      Result.new(false, problems + [ ADVICE ])
    rescue Release::Error => error # TagsNotFetched, a git failure, a GITHUB_REF_NAME that is no release tag
      Result.new(false, [ error.message ])
    end

    private
      def released_files(tag) = @release.migration_files(tag)

      def describe_edited(files, tag) = files.map { "#{it} was edited since #{tag}." }

      def describe_missing(files, tag)
        return [] if files.empty?
        return files.map { "#{it} was deleted or renamed since #{tag}." } if @release.ancestor?(tag)

        [ "the code under test is behind #{tag}: it lacks #{files.join(", ")}." ]
      end
  end
end

if $PROGRAM_NAME == __FILE__
  result = Upgrade::Guard.new(Upgrade::Release.new).call
  puts result.lines
  exit(result.ok? ? 0 : 1)
end
