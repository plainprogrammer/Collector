require "rails_helper"

RSpec.describe Collector::RequestLog do
  let(:path) { Pathname(Dir.mktmpdir("log")).join("requests.jsonl") }
  let(:middleware) { described_class.new(->(_env) { [ 200, {}, [ "ab", "cde" ] ] }, path:) }

  after { FileUtils.remove_entry(path.dirname) }

  it "logs each response's size once the body is sent", :aggregate_failures do
    _status, _headers, body = middleware.call(Rack::MockRequest.env_for("/ocr/v7.0.0/tesseract.min.js", "HTTP_USER_AGENT" => "iPhone"))
    body.each { nil }
    body.close
    expect(JSON.parse(path.read)).to include("path" => "/ocr/v7.0.0/tesseract.min.js", "status" => 200, "bytes" => 5, "user_agent" => "iPhone")
  end
end
