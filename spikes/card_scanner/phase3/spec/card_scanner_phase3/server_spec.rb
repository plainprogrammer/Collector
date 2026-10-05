require_relative "../phase3_helper"
require "card_scanner_phase3/server"
require "fileutils"
require "rack/mock"
require "tmpdir"
require "zlib"

RSpec.describe CardScannerPhase3::Server do
  let(:root) do
    Pathname(Dir.mktmpdir).tap do |root|
      %w[p2 p3 app work/index corpus/phase2-sitting runs cards/IMG_1].each { root.join(it).mkpath }
      root.join("p2/search.js").write("export {}")
      root.join("p3/timing.html").write("<!doctype html>")
      root.join("p3/replay.html").write("<!doctype html>")
      root.join("app/detector.js").write("export {}")
      root.join("work/index/art_index.bin.gz").binwrite(Zlib.gzip("x" * 144))
      root.join("corpus/phase2-sitting/IMG_9.jpeg").binwrite("\xFF\xD8\xFF".b)
      root.join("cards/IMG_1/card.png").binwrite("\x89PNG".b)
      root.join("settings.json").write({ "fingerprint" => { "grid" => [ 17, 16 ] }, "hand" => {} }.to_json)
      root.join("queries.json").write([ { "file" => "IMG_1.jpeg", "hashes" => [ "00" * 128 ] } ].to_json)
    end
  end
  let(:app) do
    described_class.new(phase2_public: root.join("p2"), phase3_public: root.join("p3"), app_scanner: root.join("app"), work_dir: root.join("work"),
      corpus_dir: root.join("corpus"), runs_dir: root.join("runs"), settings_path: root.join("settings.json"), queries_path: root.join("queries.json"),
      cards_dir: root.join("cards"))
  end
  let(:lan) { { "REMOTE_ADDR" => "192.168.1.22" } }
  let(:local) { { "REMOTE_ADDR" => "127.0.0.1" } }

  after { FileUtils.remove_entry(root) }

  def get(path, env) = Rack::MockRequest.new(app).get(path, env)

  it "serves the timing page to the phone under a strict policy without inline script (AC-2.1, FR-2)", :aggregate_failures do
    response = get("/phone/timing.html", lan)
    expect(response.status).to eq(200)
    expect(response.headers["content-security-policy"]).to include("script-src 'self';", "connect-src 'self'", "report-uri /csp-report")
    expect(response.headers["content-security-policy"]).not_to include("unsafe-inline", "nonce-")
  end

  it "serves the index gzipped and cacheable, with the encoded size (AC-2.1)", :aggregate_failures do
    response = get("/phone/index.bin", lan)
    expect(response.headers).to include("content-encoding" => "gzip", "cache-control" => "public, max-age=31536000, immutable")
    expect(response.headers["content-length"].to_i).to eq(root.join("work/index/art_index.bin.gz").size)
  end

  it "serves the queries, the straightened cards and only the fingerprint settings to the phone", :aggregate_failures do
    expect(JSON.parse(get("/phone/queries.json", lan).body).map { it["file"] }).to eq([ "IMG_1.jpeg" ])
    expect(get("/phone/cards/IMG_1.png", lan).status).to eq(200)
    expect(JSON.parse(get("/settings.json", lan).body).keys).to eq([ "fingerprint" ])
  end

  it "keeps the corpus, the working folder, the app's modules and the replay off the LAN (FR-2)", :aggregate_failures do
    %w[/corpus/phase2-sitting/IMG_9.jpeg /work/index/art_index.bin.gz /app/scanner/detector.js /replay.html].each do |path|
      expect(get(path, lan).status).to eq(403), path
      expect(get(path, local).status).to eq(200), path
    end
  end

  it "ignores a forwarded header claiming loopback (FR-2)" do
    expect(get("/corpus/phase2-sitting/IMG_9.jpeg", lan.merge("HTTP_X_FORWARDED_FOR" => "127.0.0.1")).status).to eq(403)
  end

  it "accepts the timing page's results on one path from the LAN, and nothing else", :aggregate_failures do
    response = Rack::MockRequest.new(app).post("/phone/results", lan.merge(input: { "mode" => "cold" }.to_json))
    expect(response.status).to eq(201)
    expect(root.join("runs/phone").glob("*.json").size).to eq(1)
    expect(Rack::MockRequest.new(app).post("/outputs/x/y/z.json", lan.merge(input: "{}")).status).to eq(404)
  end

  it "refuses an oversized results body" do
    response = Rack::MockRequest.new(app).post("/phone/results", lan.merge(input: "x" * 1_000_001))
    expect(response.status).to eq(413)
  end

  it "sends the policy on the phone's routes and not on the loopback replay" do
    expect([ get("/phone/timing.html", lan), get("/replay.html", local) ].map { it.headers.key?("content-security-policy") }).to eq([ true, false ])
  end
end
