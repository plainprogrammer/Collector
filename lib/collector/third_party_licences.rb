module Collector
  # The third-party software and assets in the image and their licences, for the page at `/licences` (spec 087): the
  # gems of the running bundle, whose licence files the reader finds in each gem's directory, and the OCR engine, the
  # JavaScript the gems serve, the fonts and the icons, which `config/third_party_licences.yml` lists with their texts
  # in `config/third_party_licences/`. The core names no collectible: what is listed is whatever the bundle and the
  # manifest hold.
  #
  # A licence asks that its notice travel with the copies, so a text is read from the file the work ships (a gem's
  # directory) or was copied from (a manifest text), never written from memory (spec 087 decision 5).
  #
  # @see file:catalog-core.md
  class ThirdPartyLicences
    # One listed work: its `name`, `version` (a string), SPDX `identifiers` (an array of strings), `home` (an absolute
    # http or https address, or nil), `copyright` line (or nil), `texts` (an array of `[title, text]` pairs, where a
    # gem's title is the file's name) and a `note` (or nil) shown after the identifiers.
    Component = Data.define(:name, :version, :identifiers, :home, :copyright, :texts, :note)

    # One group of the page: a `key` (a symbol, one of {TITLES}), the section's `title` and its `components`.
    Section = Data.define(:key, :title, :components)

    # The names a licence file has in the bundle: `MIT-LICENSE`, `LICENSE.SPECS`, `LICENSE-DEPENDENCIES.md`,
    # `license_of_rb-readline`, `COPYING`, `NOTICE`, and the Ruby gems' `BSDL` and `LEGAL`. Matched against the
    # top-level files of a gem's directory only, so a `lib/LICENSE` or a README is not taken for one.
    TEXT_FILE = /licen[sc]e|copying|copyright|notice|\A(bsdl|legal)(\.\w+)?\z/i

    # The largest text the reader keeps. The biggest licence text in the bundle is some tens of kilobytes; a larger
    # file is not a licence text, and a page that embeds every text must stay small.
    MAX_TEXT_BYTES = 1.megabyte

    # The manifest of what isn't a gem, relative to `Rails.root`.
    MANIFEST = "config/third_party_licences.yml"

    # The manifest's texts, relative to `Rails.root`.
    TEXT_DIR = "config/third_party_licences"

    # The sections in page order, with their titles; a manifest key that isn't here is ignored.
    TITLES = { javascript: "JavaScript", ocr: "OCR engine", fonts: "Fonts", icons: "Icons", gems: "Ruby gems" }.freeze

    @current = nil
    @lock = Mutex.new

    # @param sections [Array<Section>] the sections in page order
    def initialize(sections)
      @sections = sections
    end

    # @return [Array<Section>] the groups of the page in order, each with its components
    attr_reader :sections

    class << self
      # The list this process serves, built on the first call and kept.
      #
      # Safe to keep because the bundle and the manifest are fixed for the life of an image (spec 087 decision 3), so
      # the page costs no file read after the first. Built under a lock, so two first requests build it once. A build
      # that raises is not kept: the next call tries again, so a transient read failure can't pin an error for the
      # whole process (spec 087 AC-1.8). The builder must not call `current` itself.
      #
      # @param builder [#call] returns the list; the default reads the real bundle and manifest, and a spec passes its own
      # @return [ThirdPartyLicences]
      # @raise whatever the builder raises, on the call that built
      def current(builder: method(:build))
        @lock.synchronize { @current ||= builder.call }
      end

      # Replaces the list this process serves.
      #
      # @api private
      # @param list [ThirdPartyLicences, nil] what {.current} returns next; used by `spec/support/third_party_licences.rb`
      def current=(list)
        @lock.synchronize { @current = list }
      end

      # Forgets the kept list, so the next {.current} builds again.
      #
      # @api private
      # @return [void] used by `spec/support/third_party_licences.rb` so one example's list never reaches another
      def reset
        @lock.synchronize { @current = nil }
        nil
      end

      # Reads the bundle and the manifest into a list: the JavaScript, OCR engine, font and icon sections from the
      # manifest, and the gems from the bundle's specs.
      #
      # Reads every gem's licence files and every text the manifest names, so call it through {.current}, not per
      # request. A missing or unparsable manifest raises: a list that silently lacked the non-gem works would be
      # wrong, and the guard spec exists to fail first.
      #
      # @param specs [Enumerable<#name, #version, #licenses, #homepage, #full_gem_path>] the gems; the running bundle's
      # @param manifest [String, Pathname] the manifest's path
      # @param text_dir [String, Pathname] the directory the manifest's texts are in
      # @return [ThirdPartyLicences]
      # @raise [Psych::DisallowedClass] when the manifest holds anything but plain data
      # @raise [SystemCallError] when the manifest can't be read
      def build(specs: Bundler.load.specs, manifest: Rails.root.join(MANIFEST), text_dir: Rails.root.join(TEXT_DIR))
        specs = specs.to_a
        entries = load_manifest(manifest)
        sections = TITLES.map do |key, title|
          components = if key == :gems
            gem_components(specs)
          else
            (entries[key.to_s] || []).map { manifest_component(it, specs, text_dir) }.sort_by { it.name.downcase }
          end
          Section.new(key:, title:, components:)
        end
        new(sections)
      end

      # The manifest's data, with string keys.
      #
      # Parsed with `YAML.safe_load_file`: the manifest is a checked-in file, but nothing in it should ever build an
      # object, so a tag that asks for one fails instead (spec 087 decision 3).
      #
      # @param path [String, Pathname] the manifest's path
      # @return [Hash{String=>Array<Hash>}] section key to entries; empty for an empty file
      # @raise [Psych::DisallowedClass] for an object tag
      def load_manifest(path)
        YAML.safe_load_file(path) || {}
      end

      # The components of a bundle's gems, one per spec, sorted by name regardless of case.
      #
      # Reads each gem's directory (a handful of small files); a gem with no licence file, or no directory at all (a
      # default gem such as `bundler`), shows its identifiers and no texts.
      #
      # @param specs [Enumerable<#name, #version, #licenses, #homepage, #full_gem_path>] Bundler's specs, or stand-ins
      # @return [Array<Component>]
      def gem_components(specs)
        specs.map { gem_component(it) }.sort_by { it.name.downcase }
      end

      # The licence files at the top level of a directory, as `[file name, text]` pairs in file-name order.
      #
      # A file that can't be read, is over {MAX_TEXT_BYTES}, is empty, or isn't a regular file (a directory named
      # `LICENSE`) is left out and never raises, so one odd file can't take the page down (spec 087 AC-4.3). Text is
      # read as UTF-8 and scrubbed, so a stray byte can't break the page's rendering.
      #
      # @param directory [String, Pathname, nil] a gem's directory; one that isn't there gives no texts
      # @return [Array<Array(String, String)>]
      def texts_in(directory)
        Dir.children(directory.to_s).sort.filter_map do |name|
          next unless TEXT_FILE.match?(name)

          text = read_text(File.join(directory.to_s, name))
          [ name, text ] if text
        end
      rescue SystemCallError
        []
      end

      # An address safe to put in a link: absolute, with a host, and http or https.
      #
      # A gem's metadata is the gem author's, so a `javascript:` address, a relative one or a blank one gives no link
      # rather than a link a visitor could be led through (spec 087 AC-4.4).
      #
      # @param address [String, nil] a homepage as a gem or the manifest gives it
      # @return [String, nil] the address stripped of surrounding space, or nil
      def safe_home(address)
        candidate = address.to_s.strip
        uri = URI.parse(candidate)
        candidate if uri.is_a?(URI::HTTP) && uri.host.present?
      rescue URI::InvalidURIError
        nil
      end

      private

      # An entry of the manifest. A `gem` takes its texts from that gem's own licence files (none when the gem isn't in
      # the bundle); otherwise the entry's `texts` are read from the text directory, and `text: none` has none.
      def manifest_component(entry, specs, text_dir)
        texts = if entry["gem"]
          texts_in(specs.find { it.name == entry["gem"] }&.full_gem_path)
        else
          Array(entry["texts"]).filter_map { manifest_text(it, text_dir) }
        end
        Component.new(name: entry["name"].to_s, version: entry["version"].to_s, identifiers: Array(entry["spdx"]), home: safe_home(entry["home"]),
          copyright: entry["copyright"], texts:, note: entry["note"])
      end

      # One `[title, text]` pair of a manifest entry, or nil when its file can't be read: the page shows what it has
      # rather than failing (spec 087 AC-4.3), and the guard spec reports the missing file.
      def manifest_text(text, text_dir)
        content = read_text(File.join(text_dir.to_s, File.basename(text["file"].to_s)))
        [ text["title"].to_s, content ] if content
      end

      def gem_component(spec)
        Component.new(name: spec.name, version: spec.version.to_s, identifiers: Array(spec.licenses), home: safe_home(spec.homepage),
          copyright: nil, texts: texts_in(spec.full_gem_path), note: nil)
      end

      # A file's text, or nil when it isn't a regular file, can't be read, is empty or is over the limit.
      def read_text(path)
        return unless File.file?(path) && File.size(path) <= MAX_TEXT_BYTES

        text = File.read(path, encoding: "UTF-8").scrub
        text unless text.strip.empty?
      rescue SystemCallError, IOError
        nil
      end
    end
  end
end
