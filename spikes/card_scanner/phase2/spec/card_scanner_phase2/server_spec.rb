require_relative "../phase2_helper"
require "card_scanner_phase2/server"
require "fileutils"
require "rack/mock"
require "tmpdir"

RSpec.describe CardScannerPhase2::Server do
  let(:root) do
    Pathname(Dir.mktmpdir).tap do |root|
      %w[public opencv/4.13.0 corpus/phase1-live work runs logs].each { root.join(it).mkpath }
      root.join("public/detect.html").write("<!doctype html>")
      root.join("opencv/4.13.0/opencv.js").write("// cv")
      root.join("corpus/IMG_1.jpeg").binwrite("\xFF\xD8\xFF".b)
      root.join("corpus/phase1-live/IMG_2.jpeg").binwrite("\xFF\xD8\xFF".b)
      root.join("settings.json").write("{}")
    end
  end
  let(:dirs) do
    { public_dir: root.join("public"), opencv_dir: root.join("opencv"), corpus_dir: root.join("corpus"), work_dir: root.join("work"),
      runs_dir: root.join("runs"), log_dir: root.join("logs"), settings_path: root.join("settings.json") }
  end
  let(:app) { described_class.new(**dirs) }
  let(:local) { { "REMOTE_ADDR" => "127.0.0.1" } }

  after { FileUtils.remove_entry(root) }

  def get(path, env = local) = Rack::MockRequest.new(app).get(path, env)
  def post(path, env) = Rack::MockRequest.new(app).post(path, env)

  it "serves the page with the scanner page's policy plus a nonce and a report endpoint", :aggregate_failures do
    response = get("/detect.html")
    policy = response.headers["content-security-policy"]
    expect(response.status).to eq(200)
    expect(policy).to start_with("default-src 'self'; script-src 'self' 'wasm-unsafe-eval' 'nonce-")
    expect(policy).to include("worker-src 'self' blob:", "connect-src 'self'", "object-src 'none'", "report-uri /csp-report")
    expect(policy).not_to match(%r{https?:|\*})
  end

  it "widens script-src only when asked, for the AC-2.8 diagnosis" do
    loose = described_class.new(**dirs, unsafe_eval: true)
    expect(Rack::MockRequest.new(loose).get("/detect.html", local).headers["content-security-policy"]).to include("'unsafe-eval'")
  end

  it "serves the settings file" do
    expect(get("/settings.json").body).to eq("{}")
  end

  it "serves OpenCV.js immutably", :aggregate_failures do
    response = get("/opencv/4.13.0/opencv.js")
    expect(response.status).to eq(200)
    expect(response.headers["cache-control"]).to eq("public, max-age=31536000, immutable")
  end

  it "serves corpus photos, including subdirectories, to this machine only", :aggregate_failures do
    expect(get("/corpus/IMG_1.jpeg").status).to eq(200)
    expect(get("/corpus/phase1-live/IMG_2.jpeg").status).to eq(200)
    expect(get("/corpus/IMG_1.jpeg", "REMOTE_ADDR" => "192.168.1.9").status).to eq(403)
  end

  it "serves working files (artwork, index) to this machine only", :aggregate_failures do
    root.join("work/index.bin").binwrite("abc")
    expect(get("/work/index.bin").body).to eq("abc")
    expect(get("/work/index.bin", "REMOTE_ADDR" => "192.168.1.9").status).to eq(403)
  end

  it "stores a page's output under the run directory", :aggregate_failures do
    response = post("/outputs/dev-hand/IMG_1/card.png", local.merge(input: "\x89PNG".b, "CONTENT_TYPE" => "image/png"))
    expect(response.status).to eq(201)
    expect(root.join("runs/dev-hand/IMG_1/card.png").binread).to eq("\x89PNG".b)
  end

  it "refuses output paths that leave the run directory or carry odd names", :aggregate_failures do
    expect(post("/outputs/dev-hand/../x/card.png", local.merge(input: "x")).status).to eq(400)
    expect(post("/outputs/dev-hand/IMG_1/card.exe", local.merge(input: "x")).status).to eq(400)
    expect(post("/outputs/dev-hand/IMG_1/card.png", { "REMOTE_ADDR" => "192.168.1.9", input: "x" }).status).to eq(403)
  end

  it "records policy violation reports", :aggregate_failures do
    expect(post("/csp-report", local.merge(input: '{"csp-report":{}}')).status).to eq(204)
    expect(root.join("logs/csp-reports.jsonl").read).to include("csp-report")
  end
end
