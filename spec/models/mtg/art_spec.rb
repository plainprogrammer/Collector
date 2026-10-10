require "rails_helper"

RSpec.describe MTG::Art, type: :model do
  describe ".enabled_in?" do
    it "is on for 1, true, yes and on, in any case and with surrounding spaces (AC-1.2)" do
      values = [ "1", "true", "yes", "on", "TRUE", " On " ]
      expect(values.map { described_class.enabled_in?(described_class::ENV_NAME => it) }).to all(be(true))
    end

    it "is off when unset, empty or anything else (AC-1.1, AC-1.2)" do
      envs = [ {}, { described_class::ENV_NAME => "" }, { described_class::ENV_NAME => "0" }, { described_class::ENV_NAME => "enabled" } ]
      expect(envs.map { described_class.enabled_in?(it) }).to all(be(false))
    end
  end

  describe ".enabled?" do
    it "is off in tests unless an example turns it on" do
      expect(described_class).not_to be_enabled
    end

    it "reads the app's configuration", :art_matching do
      expect(described_class).to be_enabled
    end
  end

  it "keeps its files under the catalog download directory" do
    expect(described_class.root).to eq(Rails.root.join("tmp/catalog/mtg/art"))
  end

  describe ".after_refresh (spec 011 AC-3.1)" do
    def refresh_run(status) = build(:catalog_refresh_run, collectible_type: "mtg", status:, source_version: "default-cards-1")

    it "queues one build after an applied refresh", :art_matching do
      expect { described_class.after_refresh(refresh_run("applied")) }.to have_enqueued_job(MTG::Art::BuildJob).exactly(:once)
    end

    it "queues one after an already-applied skip only when that version has no index at the current settings", :aggregate_failures, :art_matching do
      expect { described_class.after_refresh(refresh_run("skipped")) }.to have_enqueued_job(MTG::Art::BuildJob)
      MTG::Art::Index.write!("default-cards-1", [])
      expect { described_class.after_refresh(refresh_run("skipped")) }.not_to have_enqueued_job(MTG::Art::BuildJob)
    end

    it "queues nothing with art matching off (AC-1.1)" do
      expect { described_class.after_refresh(refresh_run("applied")) }.not_to have_enqueued_job(MTG::Art::BuildJob)
    end
  end

  describe ".status_line (spec 011 AC-3.11)" do
    it "says when art matching is off" do
      expect(described_class.status_line).to start_with("Art matching: off")
    end

    it "says when no build has run yet", :art_matching do
      expect(described_class.status_line)
        .to eq("Art matching: on; no build has run yet (it starts after the next catalog refresh, or from the admin catalog page)")
    end

    it "reports a running build's progress", :art_matching do
      create(:mtg_art_build, status: "running", finished_at: nil, heartbeat_at: 1.minute.ago, total_count: 10, fetched_count: 4, fingerprinted_count: 3)
      expect(described_class.status_line).to include("building", "4 images fetched", "3 of 10 artworks fingerprinted")
    end

    it "reports a running build whose heartbeat stopped as interrupted, with how to resume", :art_matching do
      create(:mtg_art_build, status: "running", finished_at: nil, heartbeat_at: 1.hour.ago, total_count: 10, fingerprinted_count: 3)
      expect(described_class.status_line).to include("interrupted", "3 of 10", 'bin/rails "catalog:refresh[mtg]"')
    end

    it "reports a finished build's counts and index", :art_matching do
      create(:mtg_art_build, indexed_count: 9, without_image_count: 1, failed_count: 2, index_file: "art-index-v1-0123456789abcdef-9.bin.gz")
      expect(described_class.status_line).to include("ready", "9 artworks indexed", "1 without an image", "2 failed images", "art-index-v1-0123456789abcdef-9.bin.gz")
    end

    it "reports a failed build with its message and the index still in use", :art_matching do
      kept = MTG::Art::Index.write!("v1", [])
      create(:mtg_art_build, status: "failed", message: "Errno::ENOSPC: No space left on device")
      expect(described_class.status_line).to include("failed", "No space left on device", kept.basename.to_s)
    end
  end

  describe ".page_config (spec 011 AC-5.1)" do
    it "gives the page the current index's name and the settings, only with art on and an index built", :aggregate_failures, :art_matching do
      expect(described_class.page_config).to be_nil
      older = MTG::Art::Index.write!("v1", [])
      FileUtils.touch(older, mtime: 1.minute.ago.to_time)
      path = MTG::Art::Index.write!("v2", [])
      expect(described_class.page_config).to eq(name: path.basename.to_s, settings: MTG::Art::Settings.for_page) # the newest (AC-4.3)
      Rails.configuration.x.mtg_art_matching = false
      expect(described_class.page_config).to be_nil
    end
  end
end
