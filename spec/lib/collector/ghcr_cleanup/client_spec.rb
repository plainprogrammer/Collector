require "rails_helper"

RSpec.describe Collector::GhcrCleanup::Client do
  subject(:client) { described_class.new(token: "gh-secret") }

  let(:failure) { Collector::GhcrCleanup::Failure }

  def entry(id, tags: [])
    { "id" => id, "name" => "sha256:#{id}", "created_at" => "2026-10-08T14:42:46Z",
      "metadata" => { "package_type" => "container", "container" => { "tags" => tags } } }
  end

  def stub_page(page, body, status: 200)
    stub_request(:get, "#{described_class::API}?per_page=100&page=#{page}")
      .with(headers: { "Authorization" => "Bearer gh-secret", "Accept" => "application/vnd.github+json" })
      .to_return(status:, body: body.to_json, headers: { "Content-Type" => "application/json" })
  end

  def stub_pull_token = stub_request(:get, described_class::PULL_TOKEN).to_return(body: { token: "pull" }.to_json)

  def stub_manifest(digest, status: 200, body: "{}", type: Collector::GhcrCleanup::IMAGE_TYPES.first, method: :get)
    stub_request(method, "#{described_class::REGISTRY}#{digest}")
      .with(headers: { "Authorization" => "Bearer pull", "Accept" => described_class::ACCEPT })
      .to_return(status:, body:, headers: { "Content-Type" => type })
  end

  describe "#versions" do
    it "reads every page by number until a short page (AC-3.2, FR-3)", :aggregate_failures do
      stub_page(1, (1..100).map { |id| entry(id) })
      stub_page(2, [ entry(101, tags: %w[latest 0.1]) ])
      versions = client.versions
      expect(versions.size).to eq(101)
      expect(versions.last).to have_attributes(id: 101, digest: "sha256:101", tags: %w[latest 0.1],
                                               created_at: Time.utc(2026, 10, 8, 14, 42, 46))
    end

    it "stops at an empty page after a full one" do
      stub_page(1, (1..100).map { |id| entry(id) })
      stub_page(2, [])
      expect(client.versions.size).to eq(100)
    end

    it "fails naming the request, not the token, when the API refuses (AC-3.1)", :aggregate_failures do
      stub_page(1, { message: "Bad credentials" }, status: 401)
      expect { client.versions }.to raise_error(failure, /page=1 answered 401/) { |error| expect(error.message).not_to include("gh-secret") }
    end

    it "fails on a response that is not a version list (AC-3.1)", :aggregate_failures do
      stub_page(1, { "message" => "moved" })
      expect { client.versions }.to raise_error(failure, /did not return a version list/)
      stub_page(1, [ entry(1).merge("metadata" => {}) ])
      expect { client.versions }.to raise_error(failure, /did not return a version list/)
      stub_page(1, [ entry(1).merge("created_at" => "yesterday") ])
      expect { client.versions }.to raise_error(failure, /did not return a version list/)
    end

    it "fails on a timeout, naming the request" do
      stub_request(:get, /api.github.com/).to_timeout
      expect { client.versions }.to raise_error(failure, /GET .*page=1 failed/)
    end

    it "sets explicit timeouts on every request (FR-2)" do
      allow(Net::HTTP).to receive(:start).and_call_original
      stub_page(1, [])
      client.versions
      expect(Net::HTTP).to have_received(:start).with("api.github.com", 443, hash_including(open_timeout: 10, read_timeout: 30))
    end
  end

  describe "#manifest" do
    let(:index) do
      { "manifests" => [ { "digest" => "sha256:a", "platform" => { "os" => "linux", "architecture" => "amd64" } } ] }.to_json
    end

    it "reads by digest with an anonymous pull token, fetched once per run (FR-1)", :aggregate_failures do
      token = stub_pull_token
      stub_manifest("sha256:list", body: index, type: Collector::GhcrCleanup::LIST_TYPES.first)
      stub_manifest("sha256:img")
      expect(client.manifest("sha256:list")).to have_attributes(children: [ "sha256:a" ], platforms: [ "linux/amd64" ])
      expect(client.manifest("sha256:img")).not_to be_list
      expect(token).to have_been_requested.once
    end

    it "fails naming the request when the registry answers otherwise (AC-3.3)" do
      stub_pull_token
      stub_manifest("sha256:gone", status: 404)
      expect { client.manifest("sha256:gone") }.to raise_error(failure, %r{GET https://ghcr.io/.*sha256:gone answered 404})
    end

    it "fails when no pull token is issued" do
      stub_request(:get, described_class::PULL_TOKEN).to_return(status: 500)
      expect { client.manifest("sha256:a") }.to raise_error(failure, /token\?scope=.* answered 500/)
    end
  end

  describe "#fetchable?" do
    before { stub_pull_token }

    it "answers from a HEAD with the same Accept (AC-2.4)", :aggregate_failures do
      stub_manifest("sha256:here", method: :head)
      stub_manifest("sha256:gone", method: :head, status: 404)
      expect(client.fetchable?("sha256:here")).to be(true)
      expect(client.fetchable?("sha256:gone")).to be(false)
    end

    it "fails on any other answer" do
      stub_manifest("sha256:odd", method: :head, status: 502)
      expect { client.fetchable?("sha256:odd") }.to raise_error(failure, /HEAD .* answered 502/)
    end
  end

  describe "#delete" do
    let(:version) { Collector::GhcrCleanup::Version.new(id: 42, digest: "sha256:x", created_at: Time.now, tags: []) }

    def stub_delete(status) = stub_request(:delete, "#{described_class::API}/42").to_return(status:)

    it "deletes by id, and treats a 404 as already deleted (AC-3.9)", :aggregate_failures do
      stub_delete(204)
      expect(client.delete(version)).to eq(:deleted)
      stub_delete(404)
      expect(client.delete(version)).to eq(:gone)
    end

    it "raises Refused naming the version and status on any other answer (AC-3.6)" do
      stub_delete(403)
      expect { client.delete(version) }.to raise_error(Collector::GhcrCleanup::Refused, %r{versions/42 \(sha256:x\) answered 403})
    end
  end
end
