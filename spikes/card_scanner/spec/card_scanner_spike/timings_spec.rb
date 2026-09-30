require_relative "../spike_helper"

RSpec.describe CardScannerSpike::Timings do
  def line(path, bytes, ip: "192.168.1.20", method: "GET") = { at: "t", ip:, method:, path:, bytes: }.to_json

  it "splits one device's requests into page loads with their bytes", :aggregate_failures do
    lines = [ line("/ocr.html", 1000), line("/ocr/v7.0.0/core/x.wasm.js", 5000), line("/ocr.html", 1000, ip: "127.0.0.1"),
              line("/ocr.html", 1000), line("/timings", 20, method: "POST") ]
    sessions = described_class.sessions(lines, ip: "192.168.1.20")
    expect(sessions.map(&:bytes)).to eq([ 6000, 1020 ])
    expect(sessions.map(&:requests)).to eq([ 2, 2 ])
  end

  it "ignores requests before the first page load" do
    expect(described_class.sessions([ line("/favicon.ico", 10) ], ip: "192.168.1.20")).to eq([])
  end
end
