require "rails_helper"

RSpec.describe Collector::GhcrCleanup do
  let(:now) { Time.utc(2026, 10, 20, 12) }

  def version(name, age_days, tags: [])
    described_class::Version.new(id: name.sum, digest: "sha256:#{name}", created_at: now - (age_days * 86_400), tags:)
  end

  def list(*children, platforms: described_class::PLATFORMS)
    described_class::Manifest.new(media_type: described_class::LIST_TYPES.first,
                                  children: children.map { |child| "sha256:#{child}" }, platforms:)
  end

  def image = described_class::Manifest.new(media_type: described_class::IMAGE_TYPES.first, children: [], platforms: [])

  # manifests: { "name" => Manifest } for every tagged version and every candidate.
  def plan_for(versions, manifests)
    by_digest = manifests.transform_keys { |name| "sha256:#{name}" }
    referenced = described_class.referenced(versions.select(&:tagged?).to_h { |v| [ v, by_digest.fetch(v.digest) ] })
    described_class.plan(versions:, referenced:, manifests: by_digest, now:)
  end

  def names(units) = units.flat_map(&:members).map { |v| v.digest.delete_prefix("sha256:") }

  describe ".plan" do
    it "selects an unreferenced image past the grace period (AC-1.1)" do
      expect(names(plan_for([ version("orphan", 8) ], "orphan" => image).selected)).to eq([ "orphan" ])
    end

    it "selects an orphan list with its children, list first (AC-1.2, FR-1)" do
      plan = plan_for([ version("old", 8), version("a", 8.01), version("b", 8.01) ], "old" => list("a", "b"), "a" => image, "b" => image)
      expect(names(plan.selected)).to eq(%w[old a b])
    end

    it "keeps a unit whose list is inside the grace period although its children are not (AC-1.3)", :aggregate_failures do
      plan = plan_for([ version("new", 6), version("a", 8), version("b", 8) ], "new" => list("a", "b"), "a" => image, "b" => image)
      expect(plan.selected).to be_empty
      expect(names(plan.young)).to eq(%w[new a b])
    end

    it "keeps a young unreferenced image (AC-1.4)" do
      expect(names(plan_for([ version("fresh", 6) ], "fresh" => image).young)).to eq([ "fresh" ])
    end

    it "selects only strictly past 7 × 86,400 seconds (Terms)", :aggregate_failures do
      plan = plan_for([ version("exact", 7), version("over", 7 + (1.0 / 86_400)) ], "exact" => image, "over" => image)
      expect(names(plan.selected)).to eq([ "over" ])
      expect(names(plan.young)).to eq([ "exact" ])
    end

    it "keeps tagged versions of any age, with several tags (AC-2.1)", :aggregate_failures do
      plan = plan_for([ version("rel", 400, tags: %w[latest 0.1 0.1.0]), version("a", 400), version("b", 400) ],
                      "rel" => list("a", "b"))
      expect(plan.selected).to be_empty
      expect(plan.counts).to eq(tagged: 1, referenced: 2, young: 0, selected: 0)
    end

    it "keeps old children of a tagged list (AC-2.2)" do
      plan = plan_for([ version("edge", 1, tags: %w[edge]), version("a", 30), version("b", 30) ], "edge" => list("a", "b"))
      expect(plan.counts).to include(referenced: 2, selected: 0)
    end

    it "deletes an old list but keeps a child it shares with a tagged list (AC-2.3)" do
      versions = [ version("rel", 1, tags: %w[latest]), version("new2", 1), version("shared", 9), version("old", 9), version("old2", 9) ]
      plan = plan_for(versions, "rel" => list("shared", "new2"), "old" => list("shared", "old2"), "old2" => image)
      expect(names(plan.selected)).to eq(%w[old old2])
    end

    it "merges untagged lists that share a child and judges them by the newest member (Terms)", :aggregate_failures do
      versions = [ version("young", 2), version("old", 10), version("shared", 10), version("y2", 2), version("o2", 10) ]
      manifests = { "young" => list("shared", "y2"), "old" => list("shared", "o2"), "shared" => image, "y2" => image, "o2" => image }
      plan = plan_for(versions, manifests)
      expect(plan.selected).to be_empty
      expect(names(plan.young)).to contain_exactly("young", "old", "shared", "y2", "o2")
    end

    it "ignores a child that is no longer in the version list (Terms)" do
      expect(names(plan_for([ version("old", 10), version("a", 10) ], "old" => list("a", "gone"), "a" => image).selected)).to eq(%w[old a])
    end

    it "counts four disjoint buckets that sum to the version total (AC-4.1)", :aggregate_failures do
      versions = [ version("edge", 1, tags: %w[edge]), version("a", 9), version("b", 9), version("fresh", 1), version("orphan", 9) ]
      plan = plan_for(versions, "edge" => list("a", "b"), "fresh" => image, "orphan" => image)
      expect(plan.counts).to eq(tagged: 1, referenced: 2, young: 1, selected: 1)
      expect(plan.counts.values.sum).to eq(versions.size)
    end

    it "fails closed on a candidate with an unknown media type (AC-3.5)" do
      odd = described_class::Manifest.new(media_type: "application/vnd.example+json", children: [], platforms: [])
      expect { plan_for([ version("odd", 9) ], "odd" => odd) }.to raise_error(described_class::Failure, %r{sha256:odd is "application/vnd.example\+json"})
    end
  end

  describe ".referenced" do
    it "fails closed on a tag pointing at a single image (AC-3.4)" do
      expect { plan_for([ version("kamal", 1, tags: %w[latest]) ], "kamal" => image) }
        .to raise_error(described_class::Failure, /tag latest \(sha256:kamal\) is "application\/vnd.oci.image.manifest.v1\+json", not a manifest list/)
    end

    it "fails closed on a tagged list without exactly amd64 and arm64 (AC-3.8)" do
      expect { plan_for([ version("one", 1, tags: %w[edge]) ], "one" => list("a", platforms: %w[linux/amd64])) }
        .to raise_error(described_class::Failure, /tag edge \(sha256:one\) has platforms linux\/amd64; expected/)
    end
  end

  describe "Manifest.parse" do
    let(:index) do
      { "mediaType" => described_class::LIST_TYPES.first,
        "manifests" => [ { "digest" => "sha256:a", "platform" => { "os" => "linux", "architecture" => "amd64" } },
                         { "digest" => "sha256:b", "platform" => { "os" => "linux", "architecture" => "arm64" } } ] }.to_json
    end

    it "reads the type from Content-Type and the children with their platforms", :aggregate_failures do
      manifest = described_class::Manifest.parse("#{described_class::LIST_TYPES.first}; charset=utf-8", index)
      expect(manifest.children).to eq(%w[sha256:a sha256:b])
      expect(manifest.platforms).to eq(%w[linux/amd64 linux/arm64])
    end

    it "falls back to the body's mediaType without a Content-Type (FR-1)" do
      expect(described_class::Manifest.parse(nil, index)).to be_list
    end

    it "fails on a child without a digest" do
      body = { "manifests" => [ { "platform" => { "os" => "linux", "architecture" => "amd64" } } ] }.to_json
      expect { described_class::Manifest.parse(described_class::LIST_TYPES.first, body) }
        .to raise_error(described_class::Failure, /child without a digest/)
    end

    it "fails on a body that is not JSON" do
      expect { described_class::Manifest.parse("text/html", "<html>") }.to raise_error(described_class::Failure, /not JSON/)
    end
  end

  describe ".token_from" do
    it "prefers GH_TOKEN and falls back to GITHUB_TOKEN (FR-3)", :aggregate_failures do
      expect(described_class.token_from("GH_TOKEN" => "a", "GITHUB_TOKEN" => "b")).to eq("a")
      expect(described_class.token_from("GH_TOKEN" => "", "GITHUB_TOKEN" => "b")).to eq("b")
    end

    it "fails naming GH_TOKEN when neither is set (AC-3.7)" do
      expect { described_class.token_from({}) }.to raise_error(described_class::Failure, /GH_TOKEN/)
    end
  end
end
