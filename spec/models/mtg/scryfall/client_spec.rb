require "rails_helper"

RSpec.describe MTG::Scryfall::Client, type: :model do
  subject(:client) { described_class.new(sleeper: ->(seconds) { naps << seconds }, clock: -> { now }) }

  let(:naps) { [] }
  let(:now) { 100.0 }

  describe "#get_json" do
    it "sends a descriptive User-Agent and Accept header", :aggregate_failures do
      stub = stub_request(:get, "https://api.scryfall.com/sets")
        .with(headers: { "User-Agent" => %r{\ACollector/}, "Accept" => "application/json" })
        .to_return(json_response("data" => []))

      expect(client.get_json("/sets")).to eq("data" => [])
      expect(stub).to have_been_requested
    end

    it "waits at least 100 ms between API calls" do
      stub_request(:get, "https://api.scryfall.com/sets").to_return(json_response({}))

      2.times { client.get_json("/sets") }

      expect(naps).to eq([ 0.1 ])
    end

    it "backs off on 429 and retries", :aggregate_failures do
      stub_request(:get, "https://api.scryfall.com/sets")
        .to_return({ status: 429, headers: { "Retry-After" => "2" } }, json_response("ok" => true))

      expect(client.get_json("/sets")).to eq("ok" => true)
      expect(naps).to include(2)
    end

    it "raises a transient error when rate limiting persists" do
      stub_request(:get, "https://api.scryfall.com/sets").to_return(status: 429)

      expect { client.get_json("/sets") }.to raise_error(Catalog::Sources::TransientError, /rate limited/)
    end

    it "raises a transient error on timeouts" do
      stub_request(:get, "https://api.scryfall.com/sets").to_timeout

      expect { client.get_json("/sets") }.to raise_error(Catalog::Sources::TransientError)
    end
  end

  describe "#download" do
    it "streams the body into the given IO" do
      stub_request(:get, "https://data.scryfall.io/f.jsonl.gz").to_return(body: "abc")
      io = StringIO.new

      client.download("https://data.scryfall.io/f.jsonl.gz", to: io)

      expect(io.string).to eq("abc")
    end
  end

  describe "#fetch_image (spec 011 AC-3.4)" do
    let(:url) { "https://cards.scryfall.io/small/front/a/b/art.jpg" }

    it "asks for a JPEG with the app's User-Agent and returns its bytes", :aggregate_failures do
      stub = stub_request(:get, url).with(headers: { "User-Agent" => %r{\ACollector/}, "Accept" => "image/jpeg" })
        .to_return(body: "\xFF\xD8jpeg".b)

      expect(client.fetch_image(url)).to eq("\xFF\xD8jpeg".b)
      expect(stub).to have_been_requested
    end

    it "waits at least 100 ms between images, as between API calls" do
      stub_request(:get, url).to_return(body: "x")

      2.times { client.fetch_image(url) }

      expect(naps).to eq([ 0.1 ])
    end

    it "backs off on 429 (honouring Retry-After) and on 5xx, then succeeds", :aggregate_failures do
      stub_request(:get, url).to_return({ status: 429, headers: { "Retry-After" => "3" } }, { status: 503 }, { body: "x" })

      expect(client.fetch_image(url)).to eq("x")
      expect(naps).to include(3, 2)
    end

    it "gives up after 3 attempts" do
      stub_request(:get, url).to_return(status: 502)

      expect { client.fetch_image(url) }.to raise_error(Catalog::Sources::TransientError, /after 3 attempts/)
    end

    it "doesn't retry another error status", :aggregate_failures do
      stub = stub_request(:get, url).to_return(status: 404)

      expect { client.fetch_image(url) }.to raise_error(Catalog::Sources::TransientError, /404/)
      expect(stub).to have_been_requested.once
    end
  end
end
