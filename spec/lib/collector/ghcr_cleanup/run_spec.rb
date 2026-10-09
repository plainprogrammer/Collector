require "rails_helper"

RSpec.describe Collector::GhcrCleanup::Run do
  let(:now) { Time.utc(2026, 10, 20, 12) }
  let(:out) { StringIO.new }
  let(:cleanup) { Collector::GhcrCleanup }

  # In-memory packages API and registry; the Client itself is specced against WebMock in client_spec.rb.
  let(:registry) do
    Class.new do
      attr_reader :versions, :manifests, :deleted, :missing, :refuse, :gone, :broken

      def initialize(versions, manifests)
        @versions, @manifests, @deleted, @missing, @refuse, @gone, @broken = versions, manifests, [], [], {}, [], []
      end

      def manifest(digest)
        manifests.fetch(digest) { raise Collector::GhcrCleanup::Failure, "GET #{digest} answered 404" }
      end

      def fetchable?(digest) = !missing.include?(digest)

      def delete(version)
        status = refuse[version.digest]
        raise Collector::GhcrCleanup::Refused, "DELETE #{version.digest} answered #{status}" if status
        raise Collector::GhcrCleanup::Failure, "DELETE #{version.digest} failed: Net::ReadTimeout" if broken.include?(version.digest)

        deleted << version.digest
        versions.delete(version)
        gone.include?(version.digest) ? :gone : :deleted
      end
    end
  end

  def version(name, age_days, tags: [])
    cleanup::Version.new(id: name.sum, digest: "sha256:#{name}", created_at: now - (age_days * 86_400), tags:)
  end

  def list(*children)
    cleanup::Manifest.new(media_type: cleanup::LIST_TYPES.first, children: children.map { |c| "sha256:#{c}" },
                          platforms: cleanup::PLATFORMS)
  end

  def image = cleanup::Manifest.new(media_type: cleanup::IMAGE_TYPES.first, children: [], platforms: [])

  # The live shape: edge with two children, and an orphan list from a re-run with its two children.
  def package
    versions = [ version("edge", 1, tags: %w[edge sha-a89f870]), version("e1", 1), version("e2", 1),
                 version("orphan", 9), version("o1", 9), version("o2", 9) ]
    registry.new(versions, { "edge" => list("e1", "e2"), "orphan" => list("o1", "o2"), "o1" => image, "o2" => image }
                             .transform_keys { |name| "sha256:#{name}" })
  end

  def run(client, delete: false) = described_class.new(client:, out:, now:, delete:).call

  it "dry-runs by default: deletes nothing and reports each selection and the counts (AC-4.1, FR-3)", :aggregate_failures do
    client = package
    run(client)
    expect(client.deleted).to be_empty
    expect(out.string).to include("Dry run: nothing is deleted")
    expect(out.string).to include("select sha256:orphan created 2026-10-11T12:00:00Z tags (none): orphan manifest list, unit age 9d 0h")
    expect(out.string).to include("select sha256:o1 created 2026-10-11T12:00:00Z tags (none): unreferenced image")
    expect(out.string).to include("6 versions: 1 tagged, 2 referenced, 0 too young, 3 selected")
  end

  it "reports young units with their ages (AC-4.3)" do
    client = registry.new([ version("fresh", 2.5) ], { "sha256:fresh" => image })
    run(client)
    expect(out.string).to include("too young sha256:fresh created 2026-10-18T00:00:00Z tags (none): unreferenced image, unit age 2d 12h")
  end

  it "deletes the orphan unit, list first, and nothing a tag needs (AC-1.2, AC-2.2, FR-1)", :aggregate_failures do
    client = package
    run(client, delete: true)
    expect(client.deleted).to eq(%w[sha256:orphan sha256:o1 sha256:o2])
    expect(out.string).to include("deleted sha256:orphan")
  end

  it "deletes nothing on a second run (AC-1.6)" do
    client = package
    run(client, delete: true)
    expect { run(client, delete: true) }.not_to(change { client.deleted.size })
  end

  it "fails naming the tag and digest when a tag's child is missing after deleting (AC-2.4)", :aggregate_failures do
    client = package
    client.missing << "sha256:e2"
    expect { run(client, delete: true) }.to raise_error(cleanup::Failure, /tag edge, sha-a89f870 \(sha256:edge\): child sha256:e2 is missing/)
    expect(client.deleted).to eq(%w[sha256:orphan sha256:o1 sha256:o2])
  end

  it "skips the post-delete check when nothing was deleted" do
    client = registry.new([ version("edge", 1, tags: %w[edge]) ], { "sha256:edge" => list("e1", "e2") })
    client.missing << "sha256:e1"
    expect { run(client, delete: true) }.not_to raise_error
  end

  it "deletes nothing when a tagged manifest can't be read, naming the tag (AC-3.3)", :aggregate_failures do
    client = package
    client.manifests.delete("sha256:edge")
    expect { run(client, delete: true) }.to raise_error(cleanup::Failure, /\Atag edge, sha-a89f870 \(sha256:edge\): GET .* answered 404/)
    expect(client.deleted).to be_empty
  end

  it "deletes nothing when a candidate can't be read, naming the digest (AC-3.5)", :aggregate_failures do
    client = package
    client.manifests.delete("sha256:o2")
    expect { run(client, delete: true) }.to raise_error(cleanup::Failure, /\Asha256:o2: GET .* answered 404/)
    expect(client.deleted).to be_empty
  end

  it "stops at a refused delete, still checks the tags, and fails naming it (AC-3.6)", :aggregate_failures do
    client = package
    client.refuse["sha256:o1"] = 403
    client.missing << "sha256:e1"
    expect { run(client, delete: true) }.to raise_error(cleanup::Failure) do |error|
      expect(error.message).to include("DELETE sha256:o1 answered 403", "child sha256:e1 is missing")
    end
    expect(client.deleted).to eq([ "sha256:orphan" ])
  end

  it "stops at a failed delete request and still checks the tags (AC-3.6)", :aggregate_failures do
    client = package
    client.broken << "sha256:o1"
    client.missing << "sha256:e1"
    expect { run(client, delete: true) }.to raise_error(cleanup::Failure) do |error|
      expect(error.message).to include("DELETE sha256:o1 failed: Net::ReadTimeout", "child sha256:e1 is missing")
    end
    expect(client.deleted).to eq([ "sha256:orphan" ])
  end

  it "reports a 404 on delete as already deleted and carries on (AC-3.9)", :aggregate_failures do
    client = package
    client.gone << "sha256:o1"
    run(client, delete: true)
    expect(out.string).to include("already deleted sha256:o1", "deleted sha256:o2")
    expect(client.deleted).to eq(%w[sha256:orphan sha256:o1 sha256:o2])
  end

  context "with the real client against stubbed GitHub and GHCR" do
    let(:client) { cleanup::Client.new(token: "gh-secret") }

    def entry(id, name, created, tags = [])
      { "id" => id, "name" => name, "created_at" => created, "metadata" => { "container" => { "tags" => tags } } }
    end

    def stub_manifest(digest, body, method: :get)
      stub_request(method, "#{cleanup::Client::REGISTRY}#{digest}")
        .to_return(body: body.to_json, headers: { "Content-Type" => body["mediaType"] || cleanup::IMAGE_TYPES.first })
    end

    def index(*children)
      { "mediaType" => cleanup::LIST_TYPES.first, "manifests" => children.zip(%w[amd64 arm64]).map do |digest, arch|
        { "digest" => digest, "platform" => { "os" => "linux", "architecture" => arch } }
      end }
    end

    it "deletes the orphan unit and checks the tag's children (AC-1.2, AC-2.4)", :aggregate_failures do
      stub_request(:get, "#{cleanup::Client::API}?per_page=100&page=1").to_return(body: [
        entry(1, "sha256:edge", "2026-10-19T00:00:00Z", %w[edge]), entry(2, "sha256:e1", "2026-10-19T00:00:00Z"),
        entry(3, "sha256:e2", "2026-10-19T00:00:00Z"), entry(4, "sha256:orphan", "2026-10-08T14:42:46Z"),
        entry(5, "sha256:o1", "2026-10-08T14:42:03Z") ].to_json)
      stub_request(:get, cleanup::Client::PULL_TOKEN).to_return(body: { token: "pull" }.to_json)
      [ [ "sha256:edge", index("sha256:e1", "sha256:e2") ], [ "sha256:orphan", index("sha256:o1", "sha256:o2") ],
        [ "sha256:o1", {} ] ].each { |digest, body| stub_manifest(digest, body) }
      %w[sha256:e1 sha256:e2].each { |digest| stub_manifest(digest, {}, method: :head) }
      deletes = [ 4, 5 ].map { |id| stub_request(:delete, "#{cleanup::Client::API}/#{id}").to_return(status: 204) }
      run(client, delete: true)
      expect(deletes).to all(have_been_requested.once)
      expect(out.string).to include("deleted sha256:orphan", "deleted sha256:o1")
    end
  end
end
