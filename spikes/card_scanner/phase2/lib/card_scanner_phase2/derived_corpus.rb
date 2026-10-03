require "fileutils"
require_relative "split" # scripts load units with require_relative, so lib isn't always on $LOAD_PATH

module CardScannerPhase2
  # Turns a detect run into a corpus the shipped photo path can read unchanged: one 3:4 picture per found
  # photo, named IMG_nnnn.png, beside a manifest with an era column (AC-1.1, AC-2.1). Photos the detector
  # didn't find are left out and scored as empty readings (AC-2.5).
  module DerivedCorpus
    ERA_OVERRIDES = { "phase0" => { "IMG_6718.jpeg" => "pre-M15" } }.freeze

    module_function

    def manifest_with_era(corpus, texts: Split.manifests)
      rows = Split.rows(texts.fetch(corpus))
      lines = rows.map do |row|
        era = ERA_OVERRIDES.dig(corpus, row["file"]) || row["era"].to_s
        [ row["file"], row["set"], row["number"], row["foil"], era ].join(",")
      end
      ([ "file,set,number,foil,era" ] + lines).join("\n") + "\n"
    end

    def detections(run_dir) = run_dir.glob("*/detect.json").map { JSON.parse(it.read) }.sort_by { it["file"] }

    def not_found(run_dir) = detections(run_dir).reject { it["found"] }.map { it.slice("file", "corpus") }

    def write!(run_dir, texts: Split.manifests)
      dir = run_dir.join("corpus")
      dir.mkpath
      rows = CORPORA.keys.flat_map { |corpus| Split.rows(manifest_with_era(corpus, texts:)).each { it["corpus"] = corpus } }.to_h { [ it["file"], it ] }
      lines = detections(run_dir).select { it["found"] }.map do |detection|
        row = rows.fetch(detection["file"])
        png = "#{File.basename(row["file"], ".*")}.png"
        FileUtils.cp(run_dir.join(File.basename(row["file"], ".*"), "picture.png"), dir.join(png))
        [ png, row["set"], row["number"], row["foil"], row["era"] ].join(",")
      end
      dir.join("manifest.csv").write(([ "file,set,number,foil,era" ] + lines).join("\n") + "\n")
      dir
    end
  end
end
