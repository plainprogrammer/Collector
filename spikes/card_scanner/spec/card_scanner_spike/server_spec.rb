require_relative "../spike_helper"
require "card_scanner_spike/server"
require "tmpdir"

RSpec.describe CardScannerSpike::Server do
  subject(:app) do
    Rack::MockRequest.new(described_class.new(public_dir: root.join("public").to_s, ocr_dir: root.join("ocr").to_s,
      corpus_dir: root.join("corpus").to_s, log_dir: root.join("logs").to_s))
  end

  let(:root) { Pathname(Dir.mktmpdir("card-scanner-server")) }
  let(:loopback) { { "REMOTE_ADDR" => "127.0.0.1" } }

  before do
    { "public/ocr.html" => "<p>ocr</p>", "ocr/v7.0.0/worker.min.js" => "//", "corpus/a.jpg" => "jpg",
      "corpus/b.JPEG" => "jpg", "corpus/manifest.csv" => "file" }.each do |path, content|
      root.join(path).dirname.mkpath
      root.join(path).write(content)
    end
  end

  after { FileUtils.remove_entry(root) }

  it "serves spike pages under a self-only content security policy", :aggregate_failures do
    response = app.get("/ocr.html", loopback)
    expect(response.status).to eq(200)
    expect(response.body).to eq("<p>ocr</p>")
    expect(response.headers["content-security-policy"]).to eq(described_class::CSP)
    expect(described_class::CSP).not_to match(%r{https?:|\*})
  end

  it "serves the OCR engine as immutable" do
    expect(app.get("/ocr/v7.0.0/worker.min.js", loopback).headers["cache-control"]).to include("immutable")
  end

  it "answers an engine revalidation with 304 and no body", :aggregate_failures do
    response = app.get("/ocr/v7.0.0/worker.min.js", loopback.merge("HTTP_IF_MODIFIED_SINCE" => "Tue, 29 Sep 2026 00:00:00 GMT"))
    expect(response.status).to eq(304)
    expect(response.body).to eq("")
  end

  it "serves corpus photos to this machine only", :aggregate_failures do
    expect(app.get("/corpus/a.jpg", loopback).status).to eq(200)
    expect(app.get("/corpus/a.jpg", "REMOTE_ADDR" => "192.168.1.20").status).to eq(403)
    expect(app.get("/corpus/index.json", "REMOTE_ADDR" => "192.168.1.20").status).to eq(403)
  end

  it "lists only the corpus photos" do
    expect(JSON.parse(app.get("/corpus/index.json", loopback).body)).to eq(%w[a.jpg b.JPEG])
  end

  it "saves posted timings", :aggregate_failures do
    response = app.post("/timings", loopback.merge(input: { ready_ms: 900 }.to_json))
    files = root.glob("logs/timings-*.json")
    expect(response.status).to eq(201)
    expect(files.map { JSON.parse(it.read) }).to eq([ { "ready_ms" => 900 } ])
  end

  it "rejects timings that are not JSON" do
    expect(app.post("/timings", loopback.merge(input: "nope")).status).to eq(400)
  end

  it "records content security policy violation reports" do
    app.post("/csp-report", loopback.merge(input: { "csp-report" => { "blocked-uri" => "https://example.com" } }.to_json))
    expect(root.join("logs/csp-reports.jsonl").read).to include("example.com")
  end

  it "logs each request with the bytes sent" do
    app.get("/ocr.html", loopback)
    entry = JSON.parse(root.join("logs/requests.jsonl").readlines.last)
    expect(entry).to include("path" => "/ocr.html", "bytes" => 10, "ip" => "127.0.0.1", "status" => 200)
  end
end
