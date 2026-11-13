require "rails_helper"
require "tmpdir"
require "digest"

# Spec 087 decision 3 and Story 5: the guard's rules over injected inputs. Each rule has a fixture that fails and names the
# offender, and the baseline every fixture starts from passes, so a rule that stopped checking would fail its own example
# (AC-5.7). The same rules run on the repository's real files in spec/third_party_licences_manifest_spec.rb.
RSpec.describe Collector::ThirdPartyLicences::Audit, type: :model do
  let(:dir) { Pathname(Dir.mktmpdir("licences-audit")) }
  let(:app_javascript) { dir.join("app/javascript").to_s }

  before { write_baseline_files }

  after { FileUtils.remove_entry(dir) }

  def digest(text) = Digest::SHA256.hexdigest(text)

  # The files the baseline's entries name: one text file, and the file Turbo's pin serves.
  def write_baseline_files
    dir.join("texts").mkpath
    dir.join("texts/ok.txt").write("licence text")
    dir.join("gems").mkpath
    dir.join("gems/turbo.min.js").write("turbo source")
    dir.join("app/javascript").mkpath
    dir.join("app/javascript/application.js").write("own code")
  end

  # Each entry gets its own copy of the shared fields (`deep_dup`), so an example that edits one entry edits only it.
  def baseline_manifest
    entry = { "version" => "1.0", "spdx" => "MIT", "home" => "https://example.test", "source" => "a cited file", "texts" => [ { "title" => "LICENSE", "file" => "ok.txt" } ] }
    {
      "javascript" => [ entry.deep_dup.merge("name" => "Turbo", "gem" => "turbo-rails", "gem_version" => "2.0.23", "pins" => [ "@hotwired/turbo-rails" ],
        "files" => { "turbo.min.js" => digest("turbo source") }).except("texts") ],
      "ocr" => [ entry.deep_dup.merge("name" => "engine", "sha256" => "abc123") ],
      "fonts" => [ entry.deep_dup.merge("name" => "Serif", "files" => { "collector/serif.woff2" => digest("font") }) ],
      "icons" => [ entry.deep_dup.merge("name" => "Lucide", "files" => [ "_check.html.erb" ]) ]
    }
  end

  def baseline_inputs
    {
      manifest: baseline_manifest, text_dir: dir.join("texts").to_s,
      specs: [ stand_in_gem(dir.join("bundle").tap(&:mkpath), name: "turbo-rails", version: "2.0.23", licenses: [ "MIT" ]) ],
      ocr_digests: [ "abc123" ],
      pins: [ described_class::Pin.new(name: "application", asset: dir.join("app/javascript/application.js").to_s),
              described_class::Pin.new(name: "@hotwired/turbo-rails", asset: dir.join("gems/turbo.min.js").to_s) ],
      pin_directories: [ dir.join("app/javascript/controllers").to_s ],
      app_javascript: app_javascript,
      font_files: { "collector/serif.woff2" => digest("font") },
      icon_files: [ "_check.html.erb" ]
    }
  end

  # The baseline with `changes` laid over it; `manifest:` takes a block that edits a copy of the baseline manifest.
  def problems_with(**changes)
    inputs = baseline_inputs.merge(changes)
    yield inputs[:manifest] if block_given?
    described_class.new(**inputs).problems
  end

  it "finds no problem when the inputs agree" do
    expect(problems_with).to eq([])
  end

  describe "the OCR engine" do
    it "names a pinned package that no entry records (AC-5.2)" do
      expect(problems_with(ocr_digests: [ "abc123", "def456" ])).to contain_exactly(a_string_including("def456"))
    end

    it "names an entry whose digest is in no pinned package, as a bumped tarball leaves it (AC-5.2)" do
      expect(problems_with(ocr_digests: [ "new789" ])).to include(a_string_including("abc123"), a_string_including("new789"))
    end
  end

  describe "the JavaScript pins" do
    it "names a pin that finds no asset (AC-5.3)" do
      pins = baseline_inputs[:pins] + [ described_class::Pin.new(name: "https://cdn.test/x.js", asset: nil) ]

      expect(problems_with(pins:)).to contain_exactly(a_string_including("https://cdn.test/x.js", "no asset"))
    end

    it "names a pin outside app/javascript that no entry lists (AC-5.3)" do
      dir.join("vendor").mkpath
      dir.join("vendor/lib.js").write("vendored")
      pins = baseline_inputs[:pins] + [ described_class::Pin.new(name: "vendored", asset: dir.join("vendor/lib.js").to_s) ]

      expect(problems_with(pins:)).to contain_exactly(a_string_including("vendored", "no javascript entry"))
    end

    it "names a served file whose digest differs from the recorded one (AC-5.3)" do
      dir.join("gems/turbo.min.js").write("changed")

      expect(problems_with).to contain_exactly(a_string_including("turbo.min.js", "digest"))
    end

    it "names a served file the entry doesn't list (AC-5.3)" do
      dir.join("gems/other.js").write("other")
      pins = baseline_inputs[:pins] + [ described_class::Pin.new(name: "@hotwired/turbo-rails", asset: dir.join("gems/other.js").to_s) ]

      expect(problems_with(pins:)).to contain_exactly(a_string_including("other.js", "Turbo"))
    end

    it "names a gem whose version differs from the recorded one, though no file changed (AC-5.3)" do
      specs = [ stand_in_gem(dir.join("bundle2").tap(&:mkpath), name: "turbo-rails", version: "2.0.24") ]

      expect(problems_with(specs:)).to contain_exactly(a_string_including("turbo-rails", "2.0.24", "2.0.23"))
    end

    it "names an entry's gem that the bundle doesn't hold (AC-5.3)" do
      expect(problems_with(specs: [])).to contain_exactly(a_string_including("turbo-rails", "bundle"))
    end

    it "names an entry's pin that is gone and a file no pin serves (AC-5.3)", :aggregate_failures do
      problems = problems_with { |manifest| manifest["javascript"].first["pins"] << "@hotwired/old"; manifest["javascript"].first["files"]["old.js"] = "x" }

      expect(problems).to include(a_string_including("@hotwired/old", "gone"), a_string_including("old.js"))
    end

    it "names a pinned directory outside app/javascript (AC-5.3)" do
      expect(problems_with(pin_directories: [ dir.join("vendor/javascript").to_s ])).to contain_exactly(a_string_including("vendor/javascript"))
    end
  end

  describe "the fonts" do
    it "names a font file no entry lists (AC-5.4)" do
      expect(problems_with(font_files: { "collector/serif.woff2" => digest("font"), "collector/new.woff2" => "x" })).to contain_exactly(a_string_including("collector/new.woff2"))
    end

    it "names a font file whose digest differs (AC-5.4)" do
      expect(problems_with(font_files: { "collector/serif.woff2" => digest("redrawn") })).to contain_exactly(a_string_including("collector/serif.woff2", "digest"))
    end

    it "names an entry's font file that is gone (AC-5.4)" do
      expect(problems_with(font_files: {})).to contain_exactly(a_string_including("collector/serif.woff2", "gone"))
    end
  end

  describe "the icons" do
    it "names an icon file in no entry (AC-5.5)" do
      expect(problems_with(icon_files: [ "_check.html.erb", "_new.html.erb" ])).to contain_exactly(a_string_including("_new.html.erb"))
    end

    it "names an entry's icon file that is gone (AC-5.5)" do
      expect(problems_with(icon_files: [])).to contain_exactly(a_string_including("_check.html.erb", "gone"))
    end
  end

  describe "the gems" do
    it "names a gem with neither a licence identifier nor a licence file (AC-5.1)" do
      specs = baseline_inputs[:specs] + [ stand_in_gem(dir.join("bundle3").tap(&:mkpath), name: "bare", licenses: []) ]

      expect(problems_with(specs:)).to contain_exactly(a_string_including("bare"))
    end

    it "passes a gem with a file and no identifier, and one with an identifier and no file (AC-5.1)" do
      specs = baseline_inputs[:specs] + [ stand_in_gem(dir.join("bundle3").tap(&:mkpath), name: "filed", licenses: [], files: { "LICENSE" => "text" }) ]

      expect(problems_with(specs:)).to eq([])
    end
  end

  describe "the entries" do
    %w[name version spdx home source].each do |field|
      it "names an entry with no #{field} (AC-5.6)" do
        expect(problems_with { |manifest| manifest["fonts"].first[field] = " " }).to include(a_string_including("fonts", field))
      end
    end

    it "names an entry whose text file is missing (AC-5.6)" do
      expect(problems_with { |manifest| manifest["ocr"].first["texts"].first["file"] = "nope.txt" }).to contain_exactly(a_string_including("engine", "nope.txt"))
    end

    it "names an entry whose text file is empty (AC-5.6)" do
      dir.join("texts").mkpath
      dir.join("texts/empty.txt").write("")

      expect(problems_with { |manifest| manifest["ocr"].first["texts"].first["file"] = "empty.txt" }).to contain_exactly(a_string_including("engine", "empty.txt"))
    end

    it "names an entry whose text file lies outside the text directory (AC-5.6)" do
      dir.join("outside.txt").write("text")
      dir.join("texts").mkpath
      File.symlink(dir.join("outside.txt").to_s, dir.join("texts/linked.txt").to_s)

      expect(problems_with { |manifest| manifest["ocr"].first["texts"].first["file"] = "linked.txt" }).to contain_exactly(a_string_including("engine", "linked.txt"))
    end

    it "names an entry with neither texts nor text: none (AC-5.6)" do
      expect(problems_with { |manifest| manifest["ocr"].first.delete("texts") }).to contain_exactly(a_string_including("engine", "text"))
    end

    it "names an entry with text: none and no reason, and passes one with a reason (AC-5.6)", :aggregate_failures do
      without = problems_with { |manifest| manifest["ocr"].first.delete("texts"); manifest["ocr"].first["text"] = "none" }
      with = problems_with { |manifest| manifest["ocr"].first.delete("texts"); manifest["ocr"].first.merge!("text" => "none", "reason" => "ships no text") }

      expect(without).to contain_exactly(a_string_including("engine", "reason"))
      expect(with).to eq([])
    end

    it "lets only a JavaScript entry take its text from a gem (AC-5.6)" do
      expect(problems_with { |manifest| manifest["fonts"].first.delete("texts"); manifest["fonts"].first["gem"] = "turbo-rails" }).to contain_exactly(a_string_including("Serif", "text"))
    end
  end

  describe ".for_repository" do
    subject(:audit) { described_class.for_repository }

    it "reads the real importmap pins as the four explicit ones, each served from a file", :aggregate_failures do
      pins = Rails.application.importmap.packages

      expect(pins.keys).to eq(%w[application @hotwired/turbo-rails @hotwired/stimulus @hotwired/stimulus-loading])
      expect(Rails.application.assets.load_path.find("turbo.min.js").path.to_s).to end_with("turbo.min.js")
    end

    it "answers an audit whose problems are strings", :aggregate_failures do
      expect(audit).to be_a(described_class)
      expect(audit.problems).to all(be_a(String))
    end
  end
end
