require_relative "../phase2_helper"
require "card_scanner_phase2/opencv_asset"
require "digest"
require "fileutils"
require "tmpdir"

RSpec.describe CardScannerPhase2::OpencvAsset do
  let(:root) { Pathname(Dir.mktmpdir) }
  let(:content) { "// opencv".b }
  let(:pin) { described_class::Pin.new(url: "https://example.test/opencv.js", sha256: Digest::SHA256.hexdigest(content), served: "4.13.0/opencv.js") }

  after { FileUtils.remove_entry(root) }

  it "downloads, verifies and writes the pinned file", :aggregate_failures do
    written = described_class.install!(root:, pin:, download: ->(_url) { content })
    expect(written).to eq(root.join("4.13.0/opencv.js"))
    expect(written.binread).to eq(content)
  end

  it "skips a file that is already intact" do
    root.join("4.13.0").mkpath
    root.join("4.13.0/opencv.js").binwrite(content)
    expect(described_class.install!(root:, pin:, download: ->(_url) { raise "not called" })).to be_nil
  end

  it "refuses a download whose checksum differs and leaves nothing behind", :aggregate_failures do
    expect { described_class.install!(root:, pin:, download: ->(_url) { "// other".b }) }.to raise_error(described_class::IntegrityError, /sha256/)
    expect(root.join("4.13.0/opencv.js")).not_to exist
  end

  it "pins the official 4.13.0 build", :aggregate_failures do
    expect(described_class::PIN.url).to eq("https://docs.opencv.org/4.13.0/opencv.js")
    expect(described_class::PIN.sha256).to eq("63366510248adf3a7eddf3e793dd825404efb7df3749f4d6f8557c7fa4ca8aa0")
  end
end
