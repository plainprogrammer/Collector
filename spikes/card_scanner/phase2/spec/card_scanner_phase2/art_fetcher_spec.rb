require_relative "../phase2_helper"
require "card_scanner_phase2/art_fetcher"
require "fileutils"
require "tmpdir"

RSpec.describe CardScannerPhase2::ArtFetcher do
  before { stub_const("Response", Struct.new(:code, :body, :headers) { def [](name) = headers[name] }) }

  let(:dir) { Pathname(Dir.mktmpdir) }
  let(:sleeps) { [] }
  let(:requests) { [] }
  # The fake clock advances only by the fetcher's sleeps.
  let(:fetcher) do
    described_class.new(dir:, size: "small", http: ->(url, headers) { requests << [ url, headers ]; responses.shift },
      sleeper: ->(seconds) { sleeps << seconds }, clock: -> { sleeps.sum(0.0) })
  end

  after { FileUtils.remove_entry(dir) }

  context "with ordinary responses" do
    let(:responses) { [ Response.new("200", "jpg-a".b, {}), Response.new("200", "jpg-b".b, {}) ] }

    it "fetches each artwork with the headers the rules name, at least 100 ms apart, into the cache", :aggregate_failures do
      stats = fetcher.fetch({ "a" => { "small" => "https://cards.scryfall.io/small/front/a.jpg" }, "b" => { "small" => "https://cards.scryfall.io/small/front/b.jpg" } })
      expect(requests.map(&:first)).to eq(%w[https://cards.scryfall.io/small/front/a.jpg https://cards.scryfall.io/small/front/b.jpg])
      expect(requests.first.last).to include("User-Agent" => a_string_including("Collector"), "Accept" => "image/jpeg")
      expect(sleeps).to all(be >= 0.1)
      expect(dir.join("small/a.jpg").binread).to eq("jpg-a".b)
      expect(stats).to include("fetched" => 2, "bytes" => 10, "skipped" => 0, "failed" => [])
    end

    it "skips artworks already in the cache" do
      dir.join("small").mkpath
      dir.join("small/a.jpg").binwrite("cached")
      stats = fetcher.fetch({ "a" => { "small" => "u" }, "b" => { "small" => "https://cards.scryfall.io/small/front/b.jpg" } })
      expect(stats).to include("fetched" => 1, "skipped" => 1)
    end

    it "lists an artwork without an image URL as failed, without a request", :aggregate_failures do
      stats = fetcher.fetch({ "a" => { "small" => nil }, "b" => { "small" => "https://cards.scryfall.io/small/front/b.jpg" } })
      expect(requests.size).to eq(1)
      expect(stats).to include("fetched" => 1, "failed" => [ { "id" => "a", "error" => "no small image URL" } ])
    end
  end

  context "with a rate-limited host" do
    let(:responses) { [ Response.new("429", "", { "retry-after" => "2" }), Response.new("429", "", {}), Response.new("429", "", {}) ] }

    it "backs off on 429 using Retry-After, then gives up after three attempts", :aggregate_failures do
      stats = fetcher.fetch({ "a" => { "small" => "u" } })
      expect(sleeps).to include(2.0, 4.0)
      expect(stats["failed"]).to eq([ { "id" => "a", "error" => "HTTP 429 after 3 attempts" } ])
      expect(dir.join("small/a.jpg")).not_to exist
    end
  end
end
