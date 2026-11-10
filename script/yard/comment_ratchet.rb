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
require "ripper"
require "tmpdir"
require "yard"

module YardRatchet
  RULE = ".claude/rules/code-documentation.md".freeze
  SHALLOW = "The checkout is shallow, so the merge base with origin/main can't be trusted. Fetch the full history " \
            "(actions/checkout: `fetch-depth: 0`; locally `git fetch --unshallow`).".freeze
  NO_ORIGIN = "There is no origin/main to compare with. Fetch it (`git fetch origin main`).".freeze
  NO_MERGE_BASE = "HEAD shares no history with origin/main. Fetch origin/main again (`git fetch origin main`) or rebase the branch onto it.".freeze

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

    # The merge base of HEAD and origin/main, whatever HEAD is: a branch, or the detached merge commit GitHub checks
    # out for a pull request or a tag (decision 5). Unlike Collector::PushScope, a detached HEAD isn't refused.
    #
    # @return [String] the merge base's commit id.
    # @raise [Unseen] when the repository is shallow, origin/main is missing or HEAD shares no history with it.
    def base
      raise Unseen, SHALLOW if run("rev-parse", "--is-shallow-repository").strip == "true"

      run("rev-parse", "--verify", "--quiet", "refs/remotes/origin/main^{commit}", fail_with: NO_ORIGIN)
      run("merge-base", "HEAD", "refs/remotes/origin/main", fail_with: NO_MERGE_BASE).strip
    end

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

    def run(*args, fail_with: nil)
      out, err, status = Open3.capture3(CLEARED, "git", *args, chdir: @root)
      return out if status.success?

      raise Unseen, fail_with || "git #{args.join(' ')} failed: #{err.strip}"
    end
  end

  # What YARD sees in a set of files: one Item per class, module and method, by qualified name.
  module Snapshot
    Item = Data.define(:name, :namespace, :nested, :file, :line, :commented, :exempt, :extents)

    # What `build` found: the items by qualified name, and the files (as given, relative to the root) that YARD
    # skipped without parsing them.
    Parsed = Data.define(:items, :dropped)

    # root: the directory the files are in; files: paths relative to it. Parses in memory (writes nothing). YARD's
    # registry is cleared before and after, its logger's level is put back and the callback below is removed.
    #
    # YARD drops a file it can't read (an invalid byte sequence is the common case, and Ripper accepts such a file
    # that YARD rejects) with a warning only, which the FATAL level hides, and the file then has no objects, which
    # looks the same as a file with nothing to judge. So the files YARD finishes parsing are recorded through its
    # after-parse callback, which runs only after a successful parse (an empty file included), and the rest are
    # `dropped`. This doesn't read YARD's log text and doesn't depend on whether a file defines anything.
    #
    # @return [Parsed]
    def self.build(root, files)
      return Parsed.new(items: {}, dropped: []) if files.empty?

      root = Pathname(root)
      level = YARD::Logger.instance.level
      YARD::Logger.instance.level = YARD::Logger::FATAL
      YARD::Registry.clear
      parsed = []
      recorder = proc { |parser| parsed << parser.file }
      YARD::Parser::SourceParser.after_parse_file(&recorder)
      YARD.parse(files.map { root.join(it).to_s })
      sources = Hash.new { |hash, path| hash[path] = File.readlines(path, chomp: true) }
      items = YARD::Registry.all(:class, :module, :method).each_with_object({}) do |object, found|
        found[object.path] = item(object, root, sources) unless object.files.empty?
      end
      Parsed.new(items:, dropped: files.reject { parsed.include?(root.join(it).to_s) })
    ensure
      YARD::Parser::SourceParser.after_parse_file_callbacks.delete(recorder)
      YARD::Registry.clear
      YARD::Logger.instance.level = level if level
    end

    def self.item(object, root, sources)
      namespace = object.type != :method
      exempt = exempt?(object)
      extents = exempt ? [] : object.files.map { |file, line| extent(object, file, line, namespace, sources[file]) }
      Item.new(name: object.path, namespace:, nested: !object.namespace.root?,
               file: Pathname(object.file).relative_path_from(root).to_s, line: object.line,
               commented: !object.docstring.to_s.strip.empty?, exempt:, extents:)
    end
    private_class_method :item

    # The text of one definition (decision 4): its own comment (the unbroken run of comment lines directly above it)
    # through its `end`; for a class or module, its comment and its opening line only, so its members' text is not
    # part of it. An alias's `source` is the original method's, so an alias is one line.
    def self.extent(object, file, line, namespace, lines)
      first = line
      first -= 1 while first > 1 && lines[first - 2].lstrip.start_with?("#")
      span = namespace || object.source.nil? || object.is_alias? ? 1 : object.source.lines.size
      lines[(first - 1)..(line + span - 2)].join("\n")
    end
    private_class_method :extent

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

    # @return [Result] ok when every added or changed judged object has a summary; lines is what to print. Not ok
    #   either when the base can't be determined (`Unseen`: shallow, no origin/main, no merge base) or when a changed
    #   judged file doesn't parse (a syntax error for Ripper, or any file YARD skips, an encoding error for one); the
    #   check never passes where it can't see. An unchanged file that doesn't parse is ignored.
    def call
      base = @git.base
      Dir.mktmpdir("yard-ratchet") do |tmp|
        before_files = @git.base_files(base)
        @git.export(base, before_files, tmp)
        head_files = @git.head_files
        differing = head_files.reject { identical?(it, tmp) }
        # Nothing added, edited or removed in the judged files: nothing can be changed, so YARD isn't started.
        next Result.new(ok: true, lines: [ none(base) ]) if differing.empty? && head_files == before_files

        broken = unparseable(differing)
        next Result.new(ok: false, lines: broken.map { "#{it}: YARD can't parse this file (a syntax error); fix it first." }) if broken.any?

        head = Snapshot.build(@root, head_files)
        dropped = head.dropped & differing
        next Result.new(ok: false, lines: dropped.map { "#{it}: YARD can't parse this file (an encoding error, for example); fix it first." }) if dropped.any?

        report(base, *judge(head.items, Snapshot.build(tmp, before_files).items))
      end
    rescue Unseen => error
      Result.new(ok: false, lines: [ error.message ])
    end

    private

    # Whether the head's file is byte for byte the base's (exported under `base_dir`).
    def identical?(path, base_dir)
      base_path = File.join(base_dir, path)
      File.file?(base_path) && File.binread(base_path) == File.binread(File.join(@root, path))
    end

    # The changed judged files that Ripper, which YARD parses with, rejects. An unchanged file that doesn't parse is
    # the site's build to report (spec 054), not this check's.
    def unparseable(files)
      files.select { Ripper.sexp(File.binread(File.join(@root, it)).force_encoding(Encoding::UTF_8)).nil? }
    end

    # :added, :changed or nil (decision 4). Text is compared by qualified name, so a rename, a move, a deletion
    # beside a method and the place Git puts a hunk can't matter. A method is changed when any of its extents is new;
    # a class or module the base has is changed only by an edit (a definition's text removed and another added),
    # never by a new file reopening it or a file that defined it going away. The comparison counts repeats (a class
    # defined in two files with the same opening line has that text twice), so it is a multiset difference.
    def change(item, old)
      return :added if old.nil?
      return nil if surplus(item.extents, old.extents).empty?
      return :changed unless item.namespace

      surplus(old.extents, item.extents).empty? ? nil : :changed
    end

    # The elements of `items` left over when each element of `others` cancels one equal element.
    def surplus(items, others)
      counts = others.tally
      items.reject { counts[it].to_i.positive? && (counts[it] -= 1) }
    end

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

if $PROGRAM_NAME == __FILE__
  result = YardRatchet::Check.new.call
  puts result.lines
  exit(result.ok? ? 0 : 1)
end
