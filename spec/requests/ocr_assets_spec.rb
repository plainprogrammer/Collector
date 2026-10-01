require "rails_helper"

RSpec.describe "OCR engine files", type: :request do
  let(:path) { "/ocr/v7.0.0/core/tesseract-core-simd-lstm.wasm.js" }

  it "serves a pinned file from the app, cacheable as immutable for a year (AC-2.2)", :aggregate_failures do
    get path
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/javascript")
    expect(response.headers["Cache-Control"]).to include("max-age=31536000", "public", "immutable")
    expect(response.body.bytesize).to eq(3_899_472)
  end

  it "answers either conditional request with 304 and no body (AC-2.2)", :aggregate_failures do
    get path
    { "If-None-Match" => response.headers["ETag"], "If-Modified-Since" => response.headers["Last-Modified"] }.each do |header, value|
      get path, headers: { header => value }
      expect(response).to have_http_status(:not_modified)
      expect(response.body).to be_empty
    end
  end

  it "serves the language data as gzip" do
    get "/ocr/v7.0.0/lang/eng.traineddata.gz"
    expect(response.media_type).to eq("application/gzip")
  end

  it "serves nothing outside the pinned files and version", :aggregate_failures do
    [ "/ocr/v7.0.0/core/tesseract-core.wasm.js", "/ocr/v6.0.0/tesseract.min.js", "/ocr/v7.0.0/%2E%2E/%2E%2E/config/master.key" ].each do |other|
      get other
      expect(response).to have_http_status(:not_found)
    end
  end
end
