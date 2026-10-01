require "rails_helper"
require "rubygems/package"

RSpec.describe Collector::OcrEngine do
  describe "the installed engine (AC-7.3)" do
    it "matches every pinned checksum (run bin/fetch-ocr-engine if not)", :aggregate_failures do
      described_class::FILES.each do |relative, digest|
        path = File.join(described_class::ROOT, relative)
        expect(File.file?(path) && Digest::SHA256.file(path).hexdigest).to eq(digest), relative
      end
    end
  end

  describe ".install!" do
    let(:root) { Dir.mktmpdir }
    let(:tarball) { tar("package/dist/engine.js" => contents) }
    let(:package) do
      described_class::Package.new(url: "https://registry.test/engine.tgz", sha256: Digest::SHA256.hexdigest(tarball),
        files: { "package/dist/engine.js" => "engine.js" })
    end
    let(:files) { { "engine.js" => Digest::SHA256.hexdigest(contents) } }
    let(:downloads) { [] }

    after { FileUtils.remove_entry(root) }

    def contents = "console.log('engine')"

    def install = described_class.install!(root:, packages: [ package ], files:, download: ->(url) { downloads << url && tarball })

    def tar(entries)
      io = StringIO.new
      Zlib::GzipWriter.wrap(io) do |gzip|
        Gem::Package::TarWriter.new(gzip) do |writer|
          entries.each { |name, data| writer.add_file_simple(name, 0o644, data.bytesize) { it.write(data) } }
        end
      end
      io.string
    end

    it "unpacks the pinned files", :aggregate_failures do
      expect(install).to eq([ "engine.js" ])
      expect(File.read(File.join(root, "engine.js"))).to eq(contents)
    end

    it "downloads nothing when every file is intact" do
      install
      expect { install }.not_to(change(downloads, :size))
    end

    it "rejects a tarball whose checksum differs" do
      package.sha256 = "0" * 64
      expect { install }.to raise_error(described_class::IntegrityError, /engine\.tgz/)
    end

    it "rejects a file whose checksum differs, writing nothing", :aggregate_failures do
      files["engine.js"] = "0" * 64
      expect { install }.to raise_error(described_class::IntegrityError, /engine\.js/)
      expect(File.exist?(File.join(root, "engine.js"))).to be(false)
    end
  end

  describe ".path_for" do
    it "knows only the pinned files", :aggregate_failures do
      expect(described_class.path_for("core/tesseract-core-simd-lstm.wasm.js")).to end_with("vendor/ocr/v7.0.0/core/tesseract-core-simd-lstm.wasm.js")
      expect(described_class.path_for("core/tesseract-core.wasm.js")).to be_nil
      expect(described_class.path_for("../../config/master.key")).to be_nil
    end
  end
end
