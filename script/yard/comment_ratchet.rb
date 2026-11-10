# Fails when a branch adds or changes public code that has no comment (spec 056, issue #264). ADR 0027 kept a
# coverage gate out of bin/ci because a gate on the total would demand comments written for their own sake, and said
# a later spec may add one; this looks only at what the branch changed, so the code a branch doesn't touch is never
# judged and the documentation grows as code is touched. It enforces the easiest part of
# .claude/rules/code-documentation.md (a summary on public classes, modules and methods in the reusable code);
# whether a comment is current, or says why, stays with reviews.
#
# It doesn't read a diff. It parses the judged files at the head (the working tree) and at the base (the merge base
# with origin/main) with YARD and compares each object's text by name, so a rename, a move, a deletion next to a
# method or the place Git puts a hunk can't matter. Run as `ruby script/yard/comment_ratchet.rb` from the repository
# root (the bin/ci step). Development tooling: outside app/ and lib/ (the app never loads it) and, under script/,
# outside the image.
return if defined?(YardRatchet)

require "bundler/setup" if $PROGRAM_NAME == __FILE__
require "fileutils"
require "open3"
require "pathname"
require "tmpdir"
require "yard"

module YardRatchet
  RULE = ".claude/rules/code-documentation.md".freeze

  # The files judged (spec 056 decision 1): the reusable code the rule lists.
  module Scope
    PATTERNS = [ %r{\Aapp/models/}, %r{\Aapp/helpers/}, %r{\Aapp/[^/]+/concerns/}, %r{\Alib/}, %r{\Aspec/support/} ].freeze

    def self.include?(path) = path.end_with?(".rb") && PATTERNS.any? { it.match?(path) }
  end

  # The base can't be determined: the check fails instead of passing where it can't see (decision 5).
  class Unseen < StandardError; end

  # The repository's side of the check: which files, and the base's blobs.
  class Git
    CLEARED = { "GIT_DIR" => nil, "GIT_WORK_TREE" => nil, "GIT_INDEX_FILE" => nil, "GIT_COMMON_DIR" => nil }.freeze

    def initialize(root) = @root = root.to_s

    # The commit the branch is compared with. Phase 3 replaces this with the merge base and its guards.
    def base = run("rev-parse", "refs/remotes/origin/main").strip

    # Judged files at the head: tracked or untracked, never ignored, and present on disk.
    def head_files
      run("ls-files", "-z", "--cached", "--others", "--exclude-standard").split("\0").uniq.sort
        .select { Scope.include?(it) && File.file?(File.join(@root, it)) }
    end

    # Judged files at the base.
    def base_files(base) = run("ls-tree", "-r", "-z", "--name-only", base).split("\0").select { Scope.include?(it) }.sort

    # Writes the base's version of each path under `into`, through one `git cat-file --batch`.
    def export(base, paths, into)
      Open3.popen3(CLEARED, "git", "cat-file", "--batch", chdir: @root) do |stdin, stdout, stderr, _thread|
        stdout.binmode
        paths.each do |path|
          stdin.puts("#{base}:#{path}")
          stdin.flush
          header = stdout.gets or raise Unseen, "git cat-file stopped: #{stderr.read}"
          size = Integer(header.split.last, exception: false) or raise Unseen, "#{path} is not in #{base}"
          target = File.join(into, path)
          FileUtils.mkdir_p(File.dirname(target))
          File.binwrite(target, stdout.read(size))
          stdout.read(1)
        end
      end
    end

    private

    def run(*args)
      out, err, status = Open3.capture3(CLEARED, "git", *args, chdir: @root)
      return out if status.success?

      raise Unseen, "git #{args.join(' ')} failed: #{err.strip}"
    end
  end

  # What YARD sees in a set of files: one Item per class, module and method, by qualified name.
  module Snapshot
    Item = Data.define(:name, :namespace, :nested, :file, :line, :commented, :exempt)

    # root: the directory the files are in; files: paths relative to it. Parses in memory (writes nothing). YARD's
    # registry is cleared before and after, and its logger's level is put back.
    def self.build(root, files)
      return {} if files.empty?

      root = Pathname(root)
      level = YARD::Logger.instance.level
      YARD::Logger.instance.level = YARD::Logger::FATAL
      YARD::Registry.clear
      YARD.parse(files.map { root.join(it).to_s })
      YARD::Registry.all(:class, :module, :method).each_with_object({}) do |object, items|
        items[object.path] = item(object, root) unless object.files.empty?
      end
    ensure
      YARD::Registry.clear
      YARD::Logger.instance.level = level if level
    end

    def self.item(object, root)
      Item.new(name: object.path, namespace: object.type != :method, nested: !object.namespace.root?,
               file: Pathname(object.file).relative_path_from(root).to_s, line: object.line,
               commented: !object.docstring.to_s.strip.empty?, exempt: exempt?(object))
    end
    private_class_method :item

    # Not judged (decision 3): non-public objects, `@api private`, attribute methods and `initialize`. A
    # `@!visibility private` directive makes YARD call a method private, but it is not an exemption: only the
    # `private` keyword is, and `@api private` is the mark.
    def self.exempt?(object)
      return true if object.tag(:api)&.text == "private"
      return true if object.visibility != :public && !object.docstring.all.match?(/^\s*@!visibility\s+private\b/)

      object.type == :method && (!object.attr_info.nil? || object.name == :initialize)
    end
    private_class_method :exempt?
  end

  # Compares the head with the base and reports the added or changed public objects that have no summary.
  class Check
    Result = Data.define(:ok, :lines) do
      def ok? = ok
    end
    Offender = Data.define(:file, :line, :name, :kind, :hint)

    NAMESPACE_HINT = "; a comment above an enclosing namespace documents the namespace, not this one".freeze

    def initialize(root: Dir.pwd, git: Git.new(root))
      @root = root.to_s
      @git = git
    end

    # @return [Result] ok when every added or changed judged object has a summary; lines is what to print.
    def call
      base = @git.base
      Dir.mktmpdir("yard-ratchet") do |tmp|
        before_files = @git.base_files(base)
        @git.export(base, before_files, tmp)
        head = Snapshot.build(@root, @git.head_files)
        before = Snapshot.build(tmp, before_files)
        report(base, *judge(head, before))
      end
    rescue Unseen => error
      Result.new(ok: false, lines: [ error.message ])
    end

    private

    # Phase 2 replaces this with the comparison of text.
    def change(_item, old) = old.nil? ? :added : nil

    def judge(head, before)
      checked = 0
      offenders = head.each_value.filter_map do |item|
        next if item.exempt

        kind = change(item, before[item.name])
        next unless kind

        checked += 1
        next if item.commented

        Offender.new(file: item.file, line: item.line, name: item.name, kind:, hint: item.namespace && item.nested)
      end
      [ offenders, checked ]
    end

    def none(base) = "Found no added or changed public code in scope (compared with #{base[0, 8]})."

    def report(base, offenders, checked)
      return Result.new(ok: true, lines: [ none(base) ]) if checked.zero?

      if offenders.empty?
        return Result.new(ok: true, lines: [ "#{checked} added or changed public #{checked == 1 ? 'object' : 'objects'}, all with a comment (compared with #{base[0, 8]})." ])
      end

      lines = offenders.sort_by { [ it.file, it.line, it.name ] }.map { describe(it) }
      noun = offenders.size == 1 ? "object" : "objects"
      lines << "#{offenders.size} added or changed public #{noun} without a comment (compared with #{base[0, 8]}). Add a one-line summary above each (#{RULE}); mark a helper that exists for one caller `@api private`."
      lines << "Only a missing summary is checked: whether a comment is current, or says why, is not checked here and stays with reviews."
      Result.new(ok: false, lines:)
    end

    def describe(offender)
      "#{offender.file}:#{offender.line}: #{offender.name} has no comment (#{offender.kind})#{NAMESPACE_HINT if offender.hint}"
    end
  end
end
