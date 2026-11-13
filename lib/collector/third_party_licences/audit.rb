require "digest"

module Collector
  class ThirdPartyLicences
    # The guard's rules (spec 087 decision 3, Story 5): whether the manifest, the pinned OCR packages, the served
    # JavaScript, the fonts, the icons and the bundle still agree, as a list of problems each naming its offender.
    #
    # Every input is injected, so a spec shows each rule failing on a small fixture and passing on the baseline (AC-5.7);
    # {.for_repository} builds the real inputs, and `spec/third_party_licences_manifest_spec.rb` asserts there is no
    # problem. A rule exists because a licence asks that its notice travel with the copy: a changed pin, package, font or
    # icon is a copy whose notice must be looked at again, so the guard fails until the manifest is.
    #
    # @see file:catalog-core.md
    class Audit
      # An importmap pin as the guard sees it: its `name` and the absolute path of the `asset` it is served from, or nil
      # when it finds none (a URL pin, a missing file).
      Pin = Data.define(:name, :asset)

      # The manifest's kinds that list a work with its facts and its text, in page order.
      ENTRY_SECTIONS = %w[javascript ocr fonts icons].freeze

      # The fields every entry must have, so a row never shows a blank.
      REQUIRED_FIELDS = %w[name version spdx home source].freeze

      class << self
        # The audit of this repository: the running bundle, the pinned OCR packages, the importmap's pins and the files under
        # `app/assets/fonts` and `app/views/icons`, with the manifest and texts the reader reads.
        #
        # Hashes every font file and reads the manifest; it needs the application booted for the importmap and the asset
        # load path, and reads no network.
        #
        # @return [Audit]
        def for_repository
          importmap = Rails.application.importmap
          new(manifest: ThirdPartyLicences.load_manifest(Rails.root.join(MANIFEST)), text_dir: Rails.root.join(TEXT_DIR).to_s,
            specs: Bundler.load.specs.to_a, ocr_digests: Collector::OcrEngine::PACKAGES.map(&:sha256),
            pins: importmap.packages.map { |name, pin| Pin.new(name:, asset: Rails.application.assets.load_path.find(pin.path)&.path&.to_s) },
            pin_directories: importmap.directories.keys.map { Rails.root.join(it).to_s },
            app_javascript: Rails.root.join("app/javascript").to_s,
            font_files: font_files_under(Rails.root.join("app/assets/fonts")),
            icon_files: Dir.children(Rails.root.join("app/views/icons")).sort)
        end

        private

        # Path relative to the fonts directory => SHA-256, for every file below it.
        def font_files_under(root)
          Dir.glob("**/*", base: root.to_s).select { File.file?(File.join(root.to_s, it)) }.sort
            .to_h { [ it, Digest::SHA256.file(File.join(root.to_s, it)).hexdigest ] }
        end
      end

      # @param manifest [Hash{String=>Array<Hash>}] the loaded manifest, string keys
      # @param text_dir [String, Pathname] the directory the manifest's text files must be inside
      # @param specs [Enumerable<#name, #version, #licenses, #full_gem_path>] the bundle's gem specs
      # @param ocr_digests [Array<String>] the SHA-256 of each pinned OCR package
      # @param pins [Array<Pin>] the importmap's explicit pins
      # @param pin_directories [Array<String>] the absolute directories `pin_all_from` pins
      # @param app_javascript [String] the absolute path of Collector's own JavaScript, whose pins need no entry
      # @param font_files [Hash{String=>String}] a font file's path relative to `app/assets/fonts` to its SHA-256
      # @param icon_files [Array<String>] the file names under `app/views/icons`
      def initialize(manifest:, text_dir:, specs:, ocr_digests:, pins:, pin_directories:, app_javascript:, font_files:, icon_files:)
        @manifest = manifest
        @text_dir = text_dir.to_s
        @specs = specs.to_a
        @ocr_digests = ocr_digests
        @pins = pins
        @pin_directories = pin_directories
        @app_javascript = app_javascript.to_s
        @font_files = font_files
        @icon_files = icon_files
      end

      # What is out of step, one sentence per offender, each naming it (a digest, a pin, a file, a gem, an entry).
      #
      # Pure of side effects: it reads the files the pins serve and the manifest's texts, and writes nothing.
      #
      # @return [Array<String>] empty when everything agrees
      def problems
        [ ocr_problems, javascript_problems, font_problems, icon_problems, gem_problems, entry_problems ].flatten
      end

      private

      def entries(section) = Array(@manifest[section])

      # An entry's name, for a message.
      def label(section, entry) = "#{section} entry #{entry["name"].to_s.inspect}"

      def ocr_problems
        recorded = entries("ocr").map { it["sha256"] }
        (@ocr_digests - recorded).map { "the pinned OCR package with SHA-256 #{it} has no ocr entry" } +
          (recorded - @ocr_digests).map { "the ocr entry with SHA-256 #{it.inspect} is for no pinned OCR package" }
      end

      def javascript_problems
        pin_problems + gem_version_problems + stale_problems + directory_problems
      end

      def under_javascript?(path) = path.start_with?("#{@app_javascript}/")

      def own_pin?(pin) = pin.asset && under_javascript?(pin.asset)

      def third_party_pins = @pins.reject { own_pin?(it) }

      def entry_for(pin) = entries("javascript").find { Array(it["pins"]).include?(pin.name) }

      def pin_problems
        third_party_pins.flat_map do |pin|
          next [ "importmap pin #{pin.name} finds no asset" ] unless pin.asset

          entry = entry_for(pin)
          next [ "importmap pin #{pin.name} has no javascript entry" ] unless entry

          served_file_problems(pin, entry)
        end
      end

      def served_file_problems(pin, entry)
        file = File.basename(pin.asset)
        recorded = Hash(entry["files"])[file]
        return [ "importmap pin #{pin.name} serves #{file}, which #{label("javascript", entry)} doesn't list" ] unless recorded

        actual = Digest::SHA256.file(pin.asset).hexdigest
        actual == recorded ? [] : [ "#{file} (pin #{pin.name}) has digest #{actual}, but #{label("javascript", entry)} records #{recorded}" ]
      end

      def gem_version_problems
        entries("javascript").filter_map do |entry|
          next unless entry["gem"]

          spec = @specs.find { it.name == entry["gem"] }
          if spec.nil?
            "#{label("javascript", entry)} names gem #{entry["gem"]}, which isn't in the bundle"
          elsif spec.version.to_s != entry["gem_version"].to_s
            "#{label("javascript", entry)} records #{entry["gem"]} #{entry["gem_version"].to_s.inspect}, but the bundle holds #{spec.version}"
          end
        end
      end

      def stale_problems
        names = @pins.map(&:name)
        served = third_party_pins.select(&:asset).map { [ it.name, File.basename(it.asset) ] }
        entries("javascript").flat_map do |entry|
          gone = Array(entry["pins"]).reject { names.include?(it) }.map { "#{label("javascript", entry)} lists pin #{it}, which is gone" }
          unserved = Hash(entry["files"]).keys.reject { |file| served.any? { |name, basename| basename == file && Array(entry["pins"]).include?(name) } }
            .map { "#{label("javascript", entry)} lists file #{it}, which no pin serves" }
          gone + unserved
        end
      end

      def directory_problems
        @pin_directories.reject { under_javascript?("#{it}/") }.map { "importmap directory #{it} isn't under app/javascript, so its files need an entry" }
      end

      def font_problems
        listed = entries("fonts").map { Hash(it["files"]) }.reduce({}, :merge)
        @font_files.flat_map do |path, digest|
          if !listed.key?(path)
            [ "font file #{path} is in no fonts entry" ]
          elsif listed[path] != digest
            [ "font file #{path} has digest #{digest}, but the fonts entry records #{listed[path]}" ]
          else
            []
          end
        end + (listed.keys - @font_files.keys).map { "a fonts entry lists #{it}, which is gone" }
      end

      def icon_problems
        listed = entries("icons").flat_map { Array(it["files"]) }
        (@icon_files - listed).map { "icon file #{it} is in no icons entry" } +
          (listed - @icon_files).map { "an icons entry lists #{it}, which is gone" }
      end

      def gem_problems
        @specs.select { Array(it.licenses).empty? && ThirdPartyLicences.texts_in(it.full_gem_path).empty? }
          .map { "gem #{it.name} declares no licence and has no licence file" }
      end

      def entry_problems
        ENTRY_SECTIONS.flat_map do |section|
          entries(section).flat_map { |entry| field_problems(section, entry) + text_problems(section, entry) }
        end
      end

      def field_problems(section, entry)
        REQUIRED_FIELDS.select { entry[it].to_s.strip.empty? }.map { "#{label(section, entry)} has no #{it}" }
      end

      def text_problems(section, entry)
        if entry["texts"]
          Array(entry["texts"]).filter_map { |text| text_file_problem(section, entry, text["file"].to_s) }
        elsif entry["text"].to_s == "none"
          entry["reason"].to_s.strip.empty? ? [ "#{label(section, entry)} says text: none with no reason" ] : []
        elsif section == "javascript" && entry["gem"]
          []
        else
          [ "#{label(section, entry)} has no text files and no `text: none` with a reason" ]
        end
      end

      # A text file must exist, hold something and really lie inside the text directory (a symlink out of it is out).
      def text_file_problem(section, entry, file)
        path = File.realpath(File.join(@text_dir, file))
        root = File.realpath(@text_dir)
        if !path.start_with?("#{root}/")
          "#{label(section, entry)} names text file #{file}, which lies outside #{@text_dir}"
        elsif !File.file?(path) || File.size(path).zero?
          "#{label(section, entry)} names text file #{file}, which is empty"
        end
      rescue SystemCallError
        "#{label(section, entry)} names text file #{file}, which is missing"
      end
    end
  end
end
