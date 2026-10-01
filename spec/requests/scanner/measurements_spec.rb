require "rails_helper"

RSpec.describe "Scanner measurement mode", type: :request do
  let(:corpus) { Pathname(Dir.mktmpdir("corpus")) }
  let(:run_dir) { corpus.join("runs/live") }
  let(:png) { "\x89PNG\r\n\x1A\nstrip".b }
  let(:turbo) { { "Accept" => "text/vnd.turbo-stream.html" } }

  around do |example|
    corpus.join("manifest.csv").write("file,set,number,foil\nIMG_1.jpeg,mom,123,no\nIMG_2.jpeg,neo,51,yes\n")
    Rails.configuration.x.scanner_measurement = { manifest: corpus.join("manifest.csv").to_s, dir: run_dir.to_s }
    example.run
  ensure
    Rails.configuration.x.scanner_measurement = nil
    FileUtils.remove_entry(corpus)
  end

  before { sign_in_as(create(:user)) }

  def upload(data) = Rack::Test::UploadedFile.new(StringIO.new(data), "image/png", original_filename: "strip.png")

  def capture(file: "IMG_1.jpeg", strip: png)
    post scanner_measurement_captures_path, headers: turbo, params: { capture: { file:, name_text: "Lightning Bolt",
      collector_text: "R 0123\nMOM • EN", ms: "640", user_agent: "iPhone", name_strip: upload(strip), collector_strip: upload(strip) } }
  end

  def current = Scanner::MeasurementRun.current

  context "when measurement mode is off (AC-5.1)" do
    before { Rails.configuration.x.scanner_measurement = nil }

    it "answers 404 for every measurement route" do
      requests = [ -> { get scanner_measurement_path }, -> { capture }, -> { post scanner_measurement_skips_path, params: { file: "IMG_1.jpeg" } },
        -> { get scanner_measurement_replay_path(label: "a") }, -> { post scanner_measurement_replay_path, params: { label: "a", results: [] }, as: :json },
        -> { get scanner_measurement_strip_path("IMG_1.jpeg", strip: "name") } ]
      expect(requests.map { it.call && response.status }).to all(eq(404))
    end

    it "shows no measurement controls on the scanner" do
      get scanner_path
      expect(response.body).not_to include("measurement_panel", "Measured run") # the import map lists every controller, so not "measurement"
    end
  end

  it "shows the next manifest row and the card it should be (AC-5.2)" do
    create(:catalog_entry, set: create(:catalog_set, code: "mom"), number: "123", name: "Lightning Bolt")
    get scanner_measurement_path
    expect(response.body).to include('selected="selected" value="IMG_1.jpeg"', "expected Lightning Bolt (MOM · 123)")
  end

  it "stores the text and both strips outside the repository, then moves on (AC-5.3)", :aggregate_failures do
    capture
    expect(response.body).to include('<turbo-stream action="replace" target="measurement_panel">', "Stored IMG_1.jpeg as the measured capture")
    expect(response.body).to include('selected="selected" value="IMG_2.jpeg"')
    expect(JSON.parse(run_dir.join("IMG_1.jpeg/capture-001.json").read)).to include("kind" => "measured", "ms" => 640, "user_agent" => "iPhone")
    expect(run_dir.join("IMG_1.jpeg/capture-001-name.png").binread).to eq(png)
    expect(run_dir.to_s).not_to start_with(Rails.root.to_s)
  end

  it "keeps the first capture as the measured one; later ones are retakes (AC-5.4)", :aggregate_failures do
    2.times { capture }
    expect(response.body).to include("Stored IMG_1.jpeg as a retake", "1 retake")
    expect(current.measured_captures.map { it["kind"] }).to eq([ "measured" ])
  end

  it "records a skipped row (AC-5.5)", :aggregate_failures do
    post scanner_measurement_skips_path, params: { file: "IMG_2.jpeg" }, headers: turbo
    expect(response.body).to include("Skipped IMG_2.jpeg", "1 skipped")
    expect(current.status(current.row("IMG_2.jpeg"))).to eq(:skipped)
  end

  it "stores nothing for a strip that isn't a PNG, or a row the manifest doesn't list", :aggregate_failures do
    capture(strip: "GIF89a")
    expect(response).to have_http_status(:unprocessable_content)
    capture(file: "IMG_9.jpeg")
    expect(response).to have_http_status(:not_found)
    expect(run_dir).not_to exist
  end

  it "serves stored strips and takes replays from this machine only (AC-5.6)", :aggregate_failures do
    capture
    get scanner_measurement_strip_path("IMG_1.jpeg", strip: "name")
    expect(response.body.b).to eq(png)
    post scanner_measurement_replay_path, as: :json, params: { label: "desktop-a", results: [ { file: "IMG_1.jpeg", name_text: "Bolt", collector_text: "" } ] }
    expect(current.replays.fetch("desktop-a").first).to include("file" => "IMG_1.jpeg", "name_text" => "Bolt")
    get scanner_measurement_strip_path("IMG_1.jpeg", strip: "name"), env: { "REMOTE_ADDR" => "192.168.1.22" }
    expect(response).to have_http_status(:not_found)
  end

  it "says when the manifest is missing, and leaves the scanner alone", :aggregate_failures do
    corpus.join("manifest.csv").delete
    get scanner_measurement_path
    expect(response.body).to include("No manifest at")
    get scanner_path
    expect(response).to have_http_status(:ok)
  end
end
