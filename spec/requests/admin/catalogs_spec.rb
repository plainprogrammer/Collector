require "rails_helper"

RSpec.describe "Admin catalog page", :solid_queue, type: :request do
  let(:admin) { create(:admin) }

  def page = Nokogiri::HTML5(response.body)

  def panel(collectible_type = "mtg") = page.at_css("#catalog_#{collectible_type}")

  def section(key, collectible_type = "mtg") = page.at_css("##{collectible_type}_#{key}")

  # The node's text as a reader meets it: every piece of text, in order, a space apart.
  def text(node) = node.xpath(".//text()").map(&:text).join(" ").squish

  def start(operation, collectible_type: "mtg") = post admin_catalog_operation_starts_path, params: { collectible_type:, operation: }

  def running(**attributes) = create(:catalog_refresh_run, :running, **attributes)

  context "when signed in as an admin" do
    before { sign_in_as(admin) }

    describe "a catalog that isn't loaded (spec 015 Story 1)" do
      it "says so, with the languages, and makes the refresh the primary action (AC-1.4)", :aggregate_failures do
        get admin_catalog_path

        expect(text(panel.at_css(".c-empty"))).to eq("No cards are loaded yet. The first refresh downloads the source's " \
          "card data and may take several minutes. Languages: EN.")
        expect(section("refresh").at_css("button").to_h).to include("class" => "c-btn c-btn--primary")
        expect(section("refresh").at_css("button")["disabled"]).to be_nil
        expect(page.at_css("[data-controller~='poll']")).to be_nil
      end

      it "drops the empty state once a refresh is in flight" do
        queue_job(Catalog::RefreshJob, "mtg", "manual")

        get admin_catalog_path

        expect(panel.at_css(".c-empty")).to be_nil
      end
    end

    describe "the panel (Story 5)" do
      it "shows the type's title, cards, last applied refresh and next scheduled one (AC-5.1, AC-5.5)", :aggregate_failures do
        create(:catalog_entry)
        create(:catalog_entry, :retired)
        create(:catalog_refresh_run, source_version: "default-cards-7", finished_at: Time.utc(2026, 10, 5, 3, 20))
        SolidQueue::RecurringTask.create!(key: "refresh_mtg_catalog", class_name: "Catalog::RefreshJob",
          arguments: %w[mtg scheduled], schedule: "every monday at 3:15am", static: true)

        travel_to(Time.utc(2026, 10, 9, 12)) { get admin_catalog_path }

        expect(text(panel.at_css("h2"))).to eq("Magic: The Gathering")
        expect(text(panel.at_css(".c-details"))).to eq("Cards 1 Last applied refresh 5 Oct 2026 03:20 UTC default-cards-7 " \
          "Next scheduled refresh 12 Oct 2026 03:15 UTC")
        expect(section("refresh").at_css("button")["class"]).to eq("c-btn c-btn--secondary")
      end

      it "says when no refresh is scheduled, as in development (AC-5.5)" do
        get admin_catalog_path

        expect(text(panel.at_css(".c-details"))).to end_with("Next scheduled refresh Not scheduled")
      end

      it "lists the 5 most recent runs with their trigger, status and outcome (AC-5.1)", :aggregate_failures do
        6.times { |n| create(:catalog_refresh_run, started_at: (n + 2).days.ago, seen_count: 100, updated_count: n) }
        create(:catalog_refresh_run, status: "skipped", message: "already running", trigger: "manual", started_at: Time.utc(2026, 10, 9, 3, 15))

        get admin_catalog_path

        rows = panel.css(".c-runs li").map { |row| text(row) }
        expect(rows.size).to eq(5)
        expect(rows.first).to eq("9 Oct 2026 03:15 UTC manual · skipped already running")
        expect(rows.second).to end_with("scheduled · applied 100 seen · 0 changed")
      end

      it "shows a second type with its own title and extra operation, and starts it (AC-5.3)", :aggregate_failures, :other_catalog do
        get admin_catalog_path

        expect(page.css(".c-panel h2").map { |title| text(title) }).to eq([ "Magic: The Gathering", "Pocket Monsters" ])
        expect(text(section("price_sync", "other"))).to eq("Price sync Sync prices Never synced. 25% 1 of 4 prices")
        expect(section("price_sync", "other").at_css("progress").to_h).to include("value" => "25", "max" => "100", "aria-label" => "Prices")

        start("price_sync", collectible_type: "other")
        expect(flash[:notice]).to eq("Price sync queued.")
        expect(SolidQueue::Job.sole).to have_attributes(class_name: "OtherCatalogJob")
      end

      it "shows only the refresh for a type whose source adds nothing (AC-5.2)" do
        Catalog.sources["plain"] = "FakeCatalogSource"
        get admin_catalog_path
        expect(panel("plain").css(".c-operation__title").map { |title| text(title) }).to eq([ "Refresh" ])
      ensure
        Catalog.sources.delete("plain")
      end
    end

    describe "starting a refresh (Story 2)" do
      it "queues one manual refresh and says so; the panel shows it queued and the page polls (AC-2.1, AC-2.2)", :aggregate_failures do
        start("refresh")

        expect(response).to redirect_to(admin_catalog_path).and have_http_status(:see_other)
        expect(SolidQueue::Job.sole.arguments["arguments"]).to eq(%w[mtg manual])
        follow_redirect!
        expect(text(page.at_css("#status"))).to eq("Refresh queued.")
        expect(text(section("refresh").at_css(".c-operation__summary"))).to eq("Queued.")
        expect(section("refresh").at_css("button")["disabled"]).to be_present
        expect(page.at_css("main")["data-controller"]).to eq("poll")
      end

      it "queues nothing more while one is queued or running, whoever queued it (AC-2.3)", :aggregate_failures do
        queue_job(Catalog::RefreshJob, "mtg", "scheduled")

        start("refresh")

        expect(response).to redirect_to(admin_catalog_path)
        expect(flash[:notice]).to eq("A refresh is already queued or running.")
        expect(SolidQueue::Job.count).to eq(1)
      end

      it "answers 404 for an unknown type or operation, queuing nothing (AC-5.6)", :aggregate_failures do
        start("refresh", collectible_type: "pokemon")
        expect(response).to have_http_status(:not_found)
        start("art_index_rebuild")
        expect(response).to have_http_status(:not_found)
        start("constantize")
        expect(response).to have_http_status(:not_found)
        expect(SolidQueue::Job.count).to eq(0)
      end
    end

    describe "a running refresh (Stories 2 and 3)" do
      it "lists the stages, the download in megabytes with its bar, and when it started (AC-2.4, AC-2.5)", :aggregate_failures do
        travel_to(Time.utc(2026, 10, 9, 3, 17)) do
          running(stage: "download", stage_done: 41_200_000, stage_total: 82_400_000, started_at: Time.utc(2026, 10, 9, 3, 15))
          get admin_catalog_path
        end

        refresh = section("refresh")
        expect(text(refresh.at_css(".c-operation__summary"))).to eq("Running.")
        expect(refresh.css(".c-stages__stage").map { |stage| text(stage) }).to eq([ "Download In progress 50% 39.3 MB of 78.6 MB",
          "Sync cards Waiting", "Retire missing cards Waiting", "Rebuild name index Waiting" ])
        expect(refresh.at_css("[aria-current='step'] progress").to_h).to include("value" => "50", "aria-label" => "Download")
        expect(text(refresh.at_css(".c-details"))).to eq("Started 9 Oct 2026 03:15 UTC Trigger manual " \
          "Last progress 9 Oct 2026 03:15 UTC (2 minutes ago)")
        expect(refresh.at_css("button")["disabled"]).to be_present
      end

      it "shows the share of the file read and the counts while syncing (AC-2.6)" do
        running(stage: "sync", stage_done: 61, stage_total: 100, seen_count: 66_140, inserted_count: 18, updated_count: 312)

        get admin_catalog_path

        expect(text(section("refresh").at_css("[aria-current='step']")))
          .to eq("Sync cards In progress 61% 66,140 seen · 18 inserted · 312 updated")
      end

      it "marks a stage without a percentage current in words alone (AC-2.7, AC-2.8)", :aggregate_failures do
        running(stage: "index")

        get admin_catalog_path

        expect(text(section("refresh").at_css("[aria-current='step']"))).to eq("Rebuild name index In progress")
        expect(section("refresh").at_css("progress")).to be_nil
      end

      it "shows a run with no progress for 15 minutes as interrupted, and lets a refresh start (AC-3.2)", :aggregate_failures do
        running(stage: "sync", started_at: 1.hour.ago, heartbeat_at: 20.minutes.ago, job_id: "job-1")

        get admin_catalog_path

        expect(text(section("refresh").at_css(".c-operation__summary"))).to eq("Interrupted while syncing cards.")
        expect(section("refresh").css(".c-stages__state").map { |state| text(state) }).to eq([ "Done", "Stopped here", "Waiting", "Waiting" ])
        expect(section("refresh").at_css("button")["disabled"]).to be_nil
        expect(text(panel.at_css(".c-runs li"))).to include("manual · interrupted")
        expect(page.at_css("[data-controller~='poll']")).to be_nil
      end

      it "shows it as running with the minutes while a worker still holds its job (AC-3.6)", :aggregate_failures do
        running(stage: "sync", started_at: 1.hour.ago, heartbeat_at: 20.minutes.ago, job_id: "job-1")
        claim_job(queue_job(Catalog::RefreshJob, "mtg", "manual")).update!(active_job_id: "job-1")

        get admin_catalog_path

        expect(text(section("refresh").at_css(".c-operation__summary"))).to eq("Running, no progress for 20 minutes.")
        expect(section("refresh").at_css("button")["disabled"]).to be_present
        expect(text(panel.at_css(".c-runs li"))).to include("manual · running (no progress for 20 minutes)")
      end
    end

    describe "a refresh that ended (Stories 2 and 3)" do
      it "shows an applied run's counts, version and finish time (AC-2.13)", :aggregate_failures do
        create(:catalog_refresh_run, source_version: "default-cards-7", seen_count: 106_636, updated_count: 12,
          started_at: Time.utc(2026, 10, 5, 3, 15), finished_at: Time.utc(2026, 10, 5, 3, 20))

        get admin_catalog_path

        expect(text(section("refresh"))).to eq("Refresh Refresh now Applied. Started 5 Oct 2026 03:15 UTC Trigger scheduled " \
          "Finished 5 Oct 2026 03:20 UTC Source version default-cards-7 " \
          "Counts 106,636 seen · 0 inserted · 12 updated · 0 retired · 0 restored · 0 malformed")
      end

      it "shows a skipped run with its message (AC-2.14)" do
        create(:catalog_refresh_run, status: "skipped", message: "default-cards-7 already applied")

        get admin_catalog_path

        expect(text(section("refresh").at_css(".c-operation__summary"))).to eq("Skipped: default-cards-7 already applied.")
      end

      it "shows a failed run's stage and message, and links to its failed job (AC-3.1)", :aggregate_failures do
        create(:catalog_refresh_run, status: "failed", stage: "sync", message: "Catalog::Sources::Error: no valid records (3 malformed)")
        fail_job(queue_job(Catalog::RefreshJob, "mtg", "manual"))

        get admin_catalog_path

        expect(text(section("refresh").at_css(".c-operation__summary")))
          .to eq("Failed while syncing cards: Catalog::Sources::Error: no valid records (3 malformed)")
        expect(section("refresh").at_css("a")["href"]).to eq(admin_jobs_path(status: "failed"))
        expect(section("refresh").at_css("button")["disabled"]).to be_nil
      end

      it "shows a failed run whose job waits to retry as queued, without the failed link (AC-3.7)", :aggregate_failures do
        create(:catalog_refresh_run, status: "failed", stage: "download", message: "Catalog::Sources::TransientError: 503")
        travel_to(Time.utc(2026, 10, 9, 3, 15)) do
          queue_job(Catalog::RefreshJob, "mtg", "manual", wait: 3.minutes)
          get admin_catalog_path
        end

        refresh = section("refresh")
        expect(text(refresh.at_css(".c-operation__summary")))
          .to eq("Queued to retry. The last run failed while downloading: Catalog::Sources::TransientError: 503")
        expect(text(refresh.at_css(".c-details"))).to start_with("Retrying at 9 Oct 2026 03:18 UTC")
        expect(refresh.at_css("a")).to be_nil
        expect(refresh.at_css("button")["disabled"]).to be_present
      end
    end

    describe "the art index (Story 4)" do
      it "says art matching is off, with the setting and no button (AC-4.6)", :aggregate_failures do
        get admin_catalog_path

        expect(text(section("art_index"))).to eq("Art index Art matching is off. Set COLLECTOR_MTG_ART_MATCHING=true to turn it on.")
        expect(section("art_index").at_css("button")).to be_nil
      end

      it "needs the catalog refreshed first: a disabled button, and a refused start (AC-4.5)", :aggregate_failures, :art_matching do
        get admin_catalog_path
        expect(text(section("art_index"))).to eq("Art index Build art index Refresh the catalog first: the art index is built from its cards.")
        expect(section("art_index").at_css("button")["disabled"]).to be_present

        start("art_index")
        expect(flash[:alert]).to eq("Refresh the catalog first: the art index is built from its cards.")
        expect(SolidQueue::Job.count).to eq(0)
      end

      it "queues one build, shows it queued, and refuses a second (AC-4.3, AC-4.4)", :aggregate_failures, :art_matching do
        create(:catalog_refresh_run)

        start("art_index")
        expect(flash[:notice]).to eq("Art index build queued.")
        follow_redirect!
        expect(text(section("art_index").at_css(".c-operation__summary"))).to eq("Queued.")
        expect(section("art_index").at_css("button")["disabled"]).to be_present

        start("art_index")
        expect(flash[:notice]).to eq("An art index build is already queued or running.")
        expect(SolidQueue::Job.where(class_name: "MTG::Art::BuildJob").count).to eq(1)
      end

      it "shows a running build's bar, counts and heartbeat (AC-4.2)", :aggregate_failures, :art_matching do
        create(:catalog_refresh_run)
        create(:mtg_art_build, status: "running", finished_at: nil, started_at: Time.utc(2026, 10, 9, 3, 0),
          heartbeat_at: 20.seconds.ago, total_count: 31_904, fingerprinted_count: 7_976, fetched_count: 1_200, failed_count: 3)

        get admin_catalog_path

        expect(text(section("art_index"))).to start_with("Art index Build art index Building. 25% 7,976 of 31,904 artworks fingerprinted " \
          "Started 9 Oct 2026 03:00 UTC Images fetched 1,200 Failed images 3 Last heartbeat")
        expect(section("art_index").at_css("progress")["aria-label"]).to eq("Artworks fingerprinted")
        expect(page.at_css("main")["data-controller"]).to eq("poll")
      end

      it "shows a finished build's counts (AC-4.7) and a failed one's message and index (AC-4.8)", :aggregate_failures, :art_matching do
        create(:catalog_refresh_run)
        build = create(:mtg_art_build, indexed_count: 31_904, without_image_count: 12, failed_count: 3, finished_at: Time.utc(2026, 10, 9, 5, 0))
        get admin_catalog_path
        expect(text(section("art_index"))).to eq("Art index Build art index Ready. Finished 9 Oct 2026 05:00 UTC " \
          "Artworks indexed 31,904 Without an image 12 Failed images 3")

        build.update!(status: "failed", message: "Errno::ENOSPC: No space left on device")
        get admin_catalog_path
        expect(text(section("art_index"))).to eq("Art index Build art index Failed: Errno::ENOSPC: No space left on device " \
          "Finished 9 Oct 2026 05:00 UTC Index in use none")
      end
    end

    it "runs the same queries however many runs and jobs there are (NFR)", :aggregate_failures do
      create(:catalog_refresh_run)
      queue_job(Catalog::RefreshJob, "mtg", "manual")
      few = count_queries { get admin_catalog_path }
      8.times { |n| create(:catalog_refresh_run, started_at: (n + 2).hours.ago) }
      3.times { queue_job(Catalog::RefreshJob, "mtg", "manual") }
      4.times { fail_job(queue_job(MTG::Art::BuildJob)) }

      expect(count_queries { get admin_catalog_path }).to eq(few)
      expect(response).to have_http_status(:ok)
    end

    it "links to the jobs page" do
      get admin_catalog_path

      expect(page.at_css(".c-pagehead__actions a")["href"]).to eq(admin_jobs_path)
    end
  end

  it "is invisible to a member: 404, and nothing is queued (AC-7.1)", :aggregate_failures do
    sign_in_as(create(:user))

    get admin_catalog_path
    expect(response).to have_http_status(:not_found)
    start("refresh")
    expect(response).to have_http_status(:not_found)
    expect(SolidQueue::Job.count).to eq(0)
  end

  it "sends a visitor who isn't signed in to sign in (AC-7.2)", :aggregate_failures do
    create(:admin)

    get admin_catalog_path
    expect(response).to redirect_to(new_session_path)
    start("refresh")
    expect(response).to redirect_to(new_session_path)
    expect(SolidQueue::Job.count).to eq(0)
  end
end
