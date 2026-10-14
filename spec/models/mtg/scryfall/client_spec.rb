require "rails_helper"

RSpec.describe MTG::Scryfall::Client, type: :model do
  subject(:client) { described_class.new(sleeper: ->(seconds) { naps << seconds }, clock: -> { now }) }

  let(:naps) { [] }
  let(:now) { 100.0 }

  # The waits before a retry: every nap but the 100 ms between requests.
  def back_offs = naps - [ 0.1 ]

  # Scryfall limits access for 30 seconds after a 429 (https://scryfall.com/docs/api/rate-limits), and its pages don't
  # say whether a 429 carries Retry-After. With none to go by, the call ends where it is: the next request is the job's
  # retry, 30 seconds later at the soonest (Catalog::RateLimitRetry), never one of this call's own (issue #81).
  # Include with `url` and `call` (the request under test) defined.
  shared_examples "a call that doesn't ask again after a 429 with no usable Retry-After (issue #81)" do
    let(:asked_to_wait) { { status: 429, headers: { "Retry-After" => "2" } } }
    let(:no_usable_wait) do
      "GET #{url} returned 429 with no usable Retry-After; Scryfall limits access for 30 seconds after a 429, " \
        "so the client doesn't ask again in this call"
    end

    it "ends the call at its first attempt, without waiting or asking again", :aggregate_failures do
      stub = stub_request(:get, url).to_return({ status: 429 }, { body: "{}" })

      expect { call }.to raise_error(Catalog::Sources::RateLimitedError, no_usable_wait) { |error| expect(error.retry_after).to be_nil }
      expect(naps).to be_empty
      expect(stub).to have_been_requested.once
    end

    it "ends the call at a middle attempt, having waited only what the earlier answer asked", :aggregate_failures do
      stub = stub_request(:get, url).to_return(asked_to_wait, { status: 429 }, { body: "{}" })

      expect { call }.to raise_error(Catalog::Sources::RateLimitedError, no_usable_wait) { |error| expect(error.retry_after).to be_nil }
      expect(back_offs).to eq([ 2 ])
      expect(stub).to have_been_requested.twice
    end

    it "ends the call at its last attempt the same way", :aggregate_failures do
      stub = stub_request(:get, url).to_return(asked_to_wait, asked_to_wait, { status: 429 }, { body: "{}" })

      expect { call }.to raise_error(Catalog::Sources::RateLimitedError, no_usable_wait) { |error| expect(error.retry_after).to be_nil }
      expect(back_offs).to eq([ 2, 2 ])
      expect(stub).to have_been_requested.times(3)
    end

    [ "-5", "soon", "1.5", "0x1F", "1_0", "", "Tue, 13 Oct 2026 11:59:00 GMT" ].each do |value|
      it "takes a Retry-After of #{value.inspect} as none: no wait, no second request", :aggregate_failures do
        travel_to Time.utc(2026, 10, 13, 12, 0, 0) do
          stub = stub_request(:get, url).to_return({ status: 429, headers: { "Retry-After" => value } }, { body: "{}" })

          expect { call }.to raise_error(Catalog::Sources::RateLimitedError, no_usable_wait) { |error| expect(error.retry_after).to be_nil }
          expect(naps).to be_empty
          expect(stub).to have_been_requested.once
        end
      end
    end
  end

  describe "#get_json" do
    it_behaves_like "a call that doesn't ask again after a 429 with no usable Retry-After (issue #81)" do
      let(:url) { "https://api.scryfall.com/sets" }

      def call = client.get_json("/sets")
    end

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
      stub_request(:get, "https://api.scryfall.com/sets").to_return(status: 429, headers: { "Retry-After" => "1" })

      expect { client.get_json("/sets") }.to raise_error(Catalog::Sources::TransientError, /rate limited/)
    end

    it "says it is rate limited after its 3 attempts, without waiting after the last (issue #74)", :aggregate_failures do
      stub = stub_request(:get, "https://api.scryfall.com/sets").to_return(status: 429, headers: { "Retry-After" => "4" })

      expect { client.get_json("/sets") }.to raise_error(Catalog::Sources::RateLimitedError,
        "GET https://api.scryfall.com/sets still rate limited after 3 attempts")
      expect(back_offs).to eq([ 4, 4 ])
      expect(stub).to have_been_requested.times(3)
    end

    it "waits 60 seconds at most in one call: the longest wait, before each of its 2 retries (issue #74)", :aggregate_failures do
      stub_request(:get, "https://api.scryfall.com/sets").to_return(status: 429, headers: { "Retry-After" => "30" })

      expect { client.get_json("/sets") }.to raise_error(Catalog::Sources::RateLimitedError, /after 3 attempts/)
      expect(back_offs).to eq([ 30, 30 ])
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

    it "ends the call on a later attempt too, having waited only what the earlier one asked (issue #74)", :aggregate_failures do
      stub = stub_request(:get, "https://api.scryfall.com/sets")
        .to_return({ status: 429, headers: { "Retry-After" => "2" } }, { status: 429, headers: { "Retry-After" => "600" } })

      expect { client.get_json("/sets") }.to raise_error(Catalog::Sources::RateLimitedError, /asked for 600 seconds/)
      expect(back_offs).to eq([ 2 ])
      expect(stub).to have_been_requested.twice
    end

    # The caller comes back no sooner than this (Catalog::RateLimitRetry).
    it "tells its caller how long the server asked for, or nil when it never said", :aggregate_failures do
      stub_request(:get, "https://api.scryfall.com/sets").to_return(status: 429, headers: { "Retry-After" => "600" })
      stub_request(:get, "https://api.scryfall.com/bulk-data").to_return(status: 429, headers: { "Retry-After" => "7" })
      stub_request(:get, "https://api.scryfall.com/cards").to_return(status: 429)

      expect { client.get_json("/sets") }.to raise_error(Catalog::Sources::RateLimitedError) { |error| expect(error.retry_after).to eq(600) }
      expect { client.get_json("/bulk-data") }.to raise_error(/after 3 attempts/) { |error| expect(error.retry_after).to eq(7) }
      expect { client.get_json("/cards") }.to raise_error(/no usable Retry-After/) { |error| expect(error.retry_after).to be_nil }
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

    it_behaves_like "a call that doesn't ask again after a 429 with no usable Retry-After (issue #81)" do
      def call = client.fetch_image(url)
    end

    it "ends the call at a 429 with no Retry-After that follows a 5xx, having waited the 5xx's second (issue #81)", :aggregate_failures do
      stub = stub_request(:get, url).to_return({ status: 503 }, { status: 429 }, { body: "x" })

      expect { client.fetch_image(url) }.to raise_error(Catalog::Sources::RateLimitedError, /returned 429 with no usable Retry-After/)
      expect(back_offs).to eq([ 1 ])
      expect(stub).to have_been_requested.twice
    end

    # The 30 seconds are about a 429. A server error says nothing of the kind, so it keeps the short waits (issue #81).
    [ nil, "soon", "-5", "" ].each do |value|
      it "still retries a 5xx after 1 and then 2 seconds when its Retry-After is #{value.inspect}", :aggregate_failures do
        stub = stub_request(:get, url).to_return(status: 503, headers: { "Retry-After" => value }.compact)

        expect { client.fetch_image(url) }.to raise_error(Catalog::Sources::TransientError, /still failing after 3 attempts/)
        expect(back_offs).to eq([ 1, 2 ])
        expect(stub).to have_been_requested.times(3)
      end
    end

    it "waits 60 seconds at most in one call, as an API call does (issue #74)", :aggregate_failures do
      stub_request(:get, url).to_return({ status: 429, headers: { "Retry-After" => "30" } }, { status: 503, headers: { "Retry-After" => "30" } },
        { status: 429, headers: { "Retry-After" => "30" } })

      expect { client.fetch_image(url) }.to raise_error(Catalog::Sources::RateLimitedError, /after 3 attempts/)
      expect(back_offs).to eq([ 30, 30 ])
    end

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

    it "gives up after 3 attempts", :aggregate_failures do
      stub_request(:get, url).to_return(status: 502)

      expect { client.fetch_image(url) }.to raise_error(Catalog::Sources::TransientError, /still failing after 3 attempts/) { |error|
        expect(error).not_to be_a(Catalog::Sources::RateLimitedError) # the image failed; nothing asked the client to stay away
      }
      expect(back_offs).to eq([ 1, 2 ])
    end

    it "says it is rate limited when its 3 attempts end on a 429 (issue #74)", :aggregate_failures do
      stub_request(:get, url).to_return({ status: 503 }, { status: 429, headers: { "Retry-After" => "30" } }, { status: 429, headers: { "Retry-After" => "5" } })

      expect { client.fetch_image(url) }.to raise_error(Catalog::Sources::RateLimitedError, "GET #{url} still rate limited after 3 attempts")
      expect(back_offs).to eq([ 1, 30 ])
    end

    it "says how long a 5xx asked for too, even on the last attempt (issue #74)", :aggregate_failures do
      stub_request(:get, url).to_return({ status: 503 }, { status: 503 }, { status: 503, headers: { "Retry-After" => "600" } })

      expect { client.fetch_image(url) }.to raise_error(Catalog::Sources::RateLimitedError, /returned 503 and asked for 600 seconds/)
      expect(back_offs).to eq([ 1, 2 ])
    end

    it "doesn't retry another error status", :aggregate_failures do
      stub = stub_request(:get, url).to_return(status: 404)

      expect { client.fetch_image(url) }.to raise_error(Catalog::Sources::TransientError, /404/)
      expect(stub).to have_been_requested.once
    end
  end
end
