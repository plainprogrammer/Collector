# Makes the links of the Markdown pages in YARD's site work (spec 054 FR-3, decision 6, ADR 0027). The area docs and
# ADRs keep plain relative links for GitHub; at generation this rewrites them in the text a page is rendered from,
# never on disk: a link to another page of the site becomes that page, any other relative link becomes the file on
# GitHub's main branch, and a link to a file that doesn't exist is a warning (so `bin/yard doc` fails); a fragment
# that matches no heading is left as written. Loaded by .yardopts (`--load`); the app never loads it (it is outside
# app/ and lib/). Standard library only, apart from the hook at the end, which needs YARD.
# `yard doc` parses its options a second time for its statistics, which loads this file again: once is enough.
return if defined?(YardLinks)

require "pathname"

module YardLinks
  GITHUB = "https://github.com/plainprogrammer/Collector".freeze
  TARGET = /(?<=\]\()([^)\s]+)(?=\))/ # the target of an inline Markdown link: ](target)
  HEADING = /\A[#]{1,6}\s+(.+?)\s*\z/

  # GitHub's anchor for a heading: lower case, punctuation dropped, spaces as hyphens.
  def self.slug(text) = text.downcase.gsub(/[^\p{Alnum}\s_-]/, "").gsub(/\s/, "-")

  # YARD's id for a heading: every character that isn't a letter or digit becomes an underscore, so
  # "A workflow run (`ci.yml`)" is "A_workflow_run___ci_yml__".
  def self.yard_id(text) = text.gsub(/[^A-Za-z0-9]/, "_")

  class Rewriter
    # root: the repository's directory; pages: { "docs/architecture/a.md" => "a" }, each page's path and the name YARD
    # gives its file (a live hash: YARD adds to it as it reads the file list); warn: called with a message.
    def initialize(root:, pages:, warn:)
      @root = Pathname(root).expand_path
      @pages = pages
      @warn = warn
      @warned = {}
      @headings = {}
    end

    # text: a page's Markdown; from: that page's path in the repository.
    def rewrite(text, from:)
      fenced = false
      text.each_line.map do |line|
        fenced = !fenced if line.lstrip.start_with?("```")
        fenced ? line : line.gsub(TARGET) { rewrite_target(Regexp.last_match(1), from) }
      end.join
    end

    private

    def rewrite_target(target, from)
      return target if target.start_with?("#") || target.match?(/\A[a-z][a-z0-9+.-]*:/i)

      path, fragment = target.split("#", 2)
      resolved = (Pathname(from).dirname + path).cleanpath.to_s
      if resolved.start_with?("..") || !@root.join(resolved).exist?
        warn_once(from, target, "the link #{target} points at #{resolved}, which doesn't exist")
        return target
      end

      if (name = @pages[resolved])
        "file.#{name}.html#{page_anchor(resolved, fragment)}"
      else
        kind = @root.join(resolved).directory? ? "tree" : "blob"
        "#{GITHUB}/#{kind}/main/#{resolved}#{"##{fragment}" if fragment}"
      end
    end

    def page_anchor(page, fragment)
      return "" unless fragment

      "##{headings(page).fetch(fragment, fragment)}" # a fragment that matches no heading is passed through
    end

    # GitHub's anchor => YARD's id, for each heading of a page outside fenced code (the first of equal anchors wins).
    def headings(page)
      @headings[page] ||= begin
        fenced = false
        @root.join(page).each_line.with_object({}) do |line, found|
          fenced = !fenced if line.lstrip.start_with?("```")
          next if fenced || !(match = line.match(HEADING))

          found[YardLinks.slug(match[1])] ||= YardLinks.yard_id(match[1])
        end
      end
    end

    # A page is read more than once (its contents are asked for again), a warning is said once.
    def warn_once(from, target, message)
      @warned[[ from, target ]] ||= @warn.call("#{from}: #{message}") || true
    end
  end
end

# The hook: only when YARD loads this file (`--load`); the unit specs load the file without YARD.
if defined?(YARD::CodeObjects::ExtraFileObject)
  module YardLinks
    class << self
      # The pages of the site: path in the repository => the name YARD gives its file. YARD builds a file object for
      # each page before it renders any, so the map is complete by the time contents are asked for.
      def pages = (@pages ||= {})

      def rewriter
        @rewriter ||= Rewriter.new(root: Dir.pwd, pages:, warn: ->(message) { YARD::Logger.instance.warn(message) })
      end
    end

    module ExtraFileHook
      def initialize(filename, contents = nil)
        super
        # YARD also builds throwaway file objects for `@see file:` links; only a file on disk is a page.
        YardLinks.pages[repository_path] = name if File.file?(filename)
      end

      def contents
        text = super
        text && YardLinks.rewriter.rewrite(text, from: repository_path)
      end

      private

      def repository_path = Pathname(filename).expand_path.relative_path_from(Pathname(Dir.pwd)).to_s
    end
  end

  YARD::CodeObjects::ExtraFileObject.prepend(YardLinks::ExtraFileHook)
end
