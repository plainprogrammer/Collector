require "rails_helper"

RSpec.describe "Art index file", :art_matching, type: :request do
  let(:records) { [ [ "aaaaaaaa-0000-4000-8000-000000000001", "\x00".b * 128 ] ] }

  def write(version) = MTG::Art::Index.write!(version, records)

  it "serves the current index pre-compressed, public and immutable for a year, without signing in (AC-4.1, AC-4.4)", :aggregate_failures do
    path = write("v1")

    get scanner_art_index_path(path.basename.to_s)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/octet-stream")
    expect(response.headers["Content-Encoding"]).to eq("gzip")
    expect(response.headers["Cache-Control"]).to include("max-age=31536000", "public", "immutable")
    expect(response.body.b).to eq(path.binread)
  end

  it "answers a repeat request carrying its ETag with 304" do
    path = write("v1")
    get scanner_art_index_path(path.basename.to_s)

    get scanner_art_index_path(path.basename.to_s), headers: { "If-None-Match" => response.headers["ETag"] }

    expect(response).to have_http_status(:not_modified)
  end

  it "keeps serving the previous index after a new one, but nothing older or unknown (AC-4.2, AC-4.3)", :aggregate_failures do
    old = write("v1")
    FileUtils.touch(old, mtime: 3.minutes.ago.to_time)
    previous = write("v2")
    FileUtils.touch(previous, mtime: 2.minutes.ago.to_time)
    write("v3")

    get scanner_art_index_path(previous.basename.to_s)
    expect(response).to have_http_status(:ok)
    [ old.basename.to_s, "art-index-v9-0123456789abcdef-1.bin.gz", "/scanner/art/..%2F..%2Fconfig%2Fmaster.key" ].each do |name|
      get name.start_with?("/") ? name : scanner_art_index_path(name)
      expect(response).to have_http_status(:not_found)
    end
  end

  it "answers 404 with art matching off, keeping the file on disk (AC-1.1, AC-1.4)", :aggregate_failures do
    path = write("v1")
    Rails.configuration.x.mtg_art_matching = false

    get scanner_art_index_path(path.basename.to_s)

    expect(response).to have_http_status(:not_found)
    expect(path).to exist
  end
end
