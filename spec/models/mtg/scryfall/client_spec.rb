require "rails_helper"

RSpec.describe MTG::Scryfall::Client, type: :model do
  subject(:client) { described_class.new(sleeper: ->(seconds) { naps << seconds }, clock: -> { now }) }

  let(:naps) { [] }
  let(:now) { 100.0 }

  # The waits before a retry: every nap but the 100 ms between requests.
  def back_offs = naps - [ 0.1 ]

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

    it "waits the 30 seconds a Retry-After asks for, the longest it waits (issue #74)", :aggregate_failures do
      stub_request(:get, "https://api.scryfall.com/sets")
        .to_return({ status: 429, headers: { "Retry-After" => "30" } }, json_response("ok" => true))

      expect(client.get_json("/sets")).to eq("ok" => true)
      expect(back_offs).to eq([ 30 ])
    end

    it "ends the call at once, without waiting, when Retry-After asks for more than 30 seconds (issue #74)", :aggregate_failures do
      stub = stub_request(:get, "https://api.scryfall.com/sets").to_return(status: 429, headers: { "Retry-After" => "31" })

      expect { client.get_json("/sets") }.to raise_error(Catalog::Sources::RateLimitedError,
        "GET https://api.scryfall.com/sets returned 429 and asked for 31 seconds before a retry; the client waits at most 30")
      expect(naps).to be_empty
      expect(stub).to have_been_requested.once
    end

    it "never waits for an absurd Retry-After", :aggregate_failures do
      stub_request(:get, "https://api.scryfall.com/sets").to_return(status: 429, headers: { "Retry-After" => "9" * 30 })

      expect { client.get_json("/sets") }.to raise_error(Catalog::Sources::RateLimitedError, /asked for 9{30} seconds/)
      expect(naps).to be_empty
    end

    context "when Retry-After isn't a plain number of seconds (issue #74)" do
      def rate_limited_once(retry_after)
        stub_request(:get, "https://api.scryfall.com/sets")
          .to_return({ status: 429, headers: { "Retry-After" => retry_after } }, json_response("ok" => true))
      end

      it "retries at once when it is zero", :aggregate_failures do
        rate_limited_once("0")

        expect(client.get_json("/sets")).to eq("ok" => true)
        expect(back_offs).to eq([ 0 ])
      end

      [ "-5", "soon", "1.5", "0x1F", "1_0", "" ].each do |value|
        it "waits its usual second when it is #{value.inspect}, as when there is none", :aggregate_failures do
          rate_limited_once(value)

          expect(client.get_json("/sets")).to eq("ok" => true)
          expect(back_offs).to eq([ 1 ])
        end
      end

      it "waits until an HTTP date, to the next whole second", :aggregate_failures do
        travel_to Time.utc(2026, 10, 13, 12, 0, 0, 500_000), with_usec: true do
          rate_limited_once("Tue, 13 Oct 2026 12:00:20 GMT")

          expect(client.get_json("/sets")).to eq("ok" => true)
          expect(back_offs).to eq([ 20 ])
        end
      end

      it "ends the call when an HTTP date is more than 30 seconds away", :aggregate_failures do
        travel_to Time.utc(2026, 10, 13, 12, 0, 0) do
          rate_limited_once("Tue, 13 Oct 2026 12:10:00 GMT")

          expect { client.get_json("/sets") }.to raise_error(Catalog::Sources::RateLimitedError, /asked for 600 seconds/)
          expect(naps).to be_empty
        end
      end

      it "waits its usual second when an HTTP date has passed", :aggregate_failures do
        travel_to Time.utc(2026, 10, 13, 12, 0, 0) do
          rate_limited_once("Tue, 13 Oct 2026 11:59:00 GMT")

          expect(client.get_json("/sets")).to eq("ok" => true)
          expect(back_offs).to eq([ 1 ])
        end
      end
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

    it "yields the bytes received so far to a block (spec 015 FR-2)", :aggregate_failures do
      stub_request(:get, "https://data.scryfall.io/f.jsonl.gz").to_return(body: "abcde")
      received = []

      client.download("https://data.scryfall.io/f.jsonl.gz", to: StringIO.new) { |bytes| received << bytes }

      expect(received).to eq(received.sort)
      expect(received.last).to eq(5)
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

    it "ends the call at once, without waiting, when Retry-After asks for more than 30 seconds (issue #74)", :aggregate_failures do
      stub = stub_request(:get, url).to_return(status: 429, headers: { "Retry-After" => "600" })

      expect { client.fetch_image(url) }.to raise_error(Catalog::Sources::RateLimitedError,
        "GET #{url} returned 429 and asked for 600 seconds before a retry; the client waits at most 30")
      expect(naps).to be_empty
      expect(stub).to have_been_requested.once
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
