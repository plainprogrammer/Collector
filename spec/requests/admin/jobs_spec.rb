require "rails_helper"

RSpec.describe "Admin jobs pages", :solid_queue, type: :request do
  let(:admin) { create(:admin) }

  def page = Nokogiri::HTML5(response.body)

  # The node's text as a reader meets it: every piece of text, in order, a space apart.
  def text(node) = node.xpath(".//text()").map(&:text).join(" ").squish

  def rows = page.css(".c-jobs tbody tr")

  def failed_refresh(message = "GET /bulk-data returned 503")
    fail_job(queue_job(Catalog::RefreshJob, "mtg", "manual"), Catalog::Sources::TransientError.new(message))
  end

  context "when signed in as an admin" do
    before { sign_in_as(admin) }

    describe "the list (spec 015 AC-6.1 to AC-6.4)" do
      it "shows the failed list by default, with each state's count on its filter", :aggregate_failures do
        failed_refresh
        claim_job(queue_job(MTG::Art::BuildJob))
        2.times { queue_job(Catalog::RefreshJob, "mtg", "manual") }
        queue_job(MTG::Art::BuildJob, wait: 5.minutes)

        get admin_jobs_path

        filters = page.css(".c-jobs__filters button")
        expect(filters.map { |filter| [ text(filter), filter["aria-pressed"], filter["value"] ] }).to eq([ [ "Failed 1", "true", "failed" ],
          [ "Running 1", "false", "running" ], [ "Queued 2", "false", "queued" ], [ "Scheduled 1", "false", "scheduled" ] ])
        expect(rows.size).to eq(1)
        expect(text(page.at_css(".c-pagehead__stats"))).to eq("1 failed job")
      end

      it "shows a failed job's class, arguments, queue, failure time and error line, with its actions (AC-6.2, AC-6.3)", :aggregate_failures do
        job = travel_to(Time.utc(2026, 10, 9, 3, 15)) { failed_refresh("GET /bulk-data returned 503\nand more") }

        travel_to(Time.utc(2026, 10, 9, 3, 25)) { get admin_jobs_path(status: "failed") }

        cells = rows.first.css("td").map { |cell| text(cell) }
        expect(cells.first).to start_with('Catalog::RefreshJob ["mtg","manual"] Catalog::Sources::TransientError: GET /bulk-data returned 503 sync')
        expect(cells.first).not_to include("and more")
        expect(cells[1..2]).to eq([ "sync", "9 Oct 2026 03:15 UTC (10 minutes ago)" ])
        expect(rows.first.at_css("td a")["href"]).to eq(admin_job_path(job.id))
        expect(rows.first.at_css("form")["action"]).to eq(admin_job_retry_path(job.id))
        expect(rows.first.at_css(".c-menu__item--danger")["href"]).to eq(new_admin_job_discard_path(job.id))
      end

      it "marks queued jobs held by a concurrency limit as waiting, and offers them no actions (AC-6.2, AC-6.9)", :aggregate_failures do
        2.times { queue_job(Catalog::RefreshJob, "mtg", "manual") }

        get admin_jobs_path(status: "queued")

        expect(rows.map { |row| text(row.at_css(".c-jobs__detail")) }).to eq([ '["mtg","manual"]', '["mtg","manual"] · waiting' ])
        expect(page.css(".c-jobs .c-menu, .c-jobs form")).to be_empty
        expect(text(page.at_css(".c-jobs thead"))).to eq("Job Queue Queued Actions")
      end

      it "lists scheduled jobs with when they are due" do
        travel_to(Time.utc(2026, 10, 9, 3, 15)) do
          queue_job(MTG::Art::BuildJob, wait: 3.minutes)
          get admin_jobs_path(status: "scheduled")
        end

        expect(text(rows.first.css("td")[2])).to eq("9 Oct 2026 03:18 UTC (in 3 minutes)")
      end

      it "says when a state has no jobs (AC-6.4)", :aggregate_failures do
        get admin_jobs_path(status: "running")
        expect(text(page.at_css(".c-empty"))).to eq("No running jobs.")

        get admin_jobs_path(status: "nonsense")
        expect(text(page.at_css(".c-empty"))).to eq("No failed jobs.")
      end

      it "shows 25 jobs a page, with the pager keeping the state (AC-6.2)", :aggregate_failures do
        26.times { fail_job(queue_job(MTG::Art::BuildJob)) }

        get admin_jobs_path(status: "failed")
        expect(rows.size).to eq(25)
        expect(page.at_css(".c-pager a[rel=next]")["href"]).to eq(admin_jobs_path(status: "failed", page: 2))

        get admin_jobs_path(status: "failed", page: 2)
        expect(rows.size).to eq(1)
      end

      it "keeps itself current only while a job is running or queued (AC-6.10)", :aggregate_failures do
        failed_refresh
        queue_job(MTG::Art::BuildJob, wait: 5.minutes)
        get admin_jobs_path
        expect(page.at_css("[data-controller~='poll']")).to be_nil

        queue_job(MTG::Art::BuildJob)
        get admin_jobs_path
        expect(page.at_css("main")["data-controller"]).to eq("poll")
      end

      it "runs the same queries however many jobs it lists (NFR)" do
        2.times { failed_refresh }
        few = count_queries { get admin_jobs_path }
        9.times { failed_refresh }
        6.times { queue_job(MTG::Art::BuildJob) }

        expect(count_queries { get admin_jobs_path }).to eq(few)
      end
    end

    describe "a job's page (AC-6.5)" do
      it "shows a failed job in full, with Retry and Discard", :aggregate_failures do
        job = travel_to(Time.utc(2026, 10, 9, 3, 15)) { failed_refresh("GET /bulk-data returned <503>") }

        travel_to(Time.utc(2026, 10, 9, 3, 25)) { get admin_job_path(job.id) }

        main = text(page.at_css("main"))
        expect(main).to include("Catalog::RefreshJob Failed", "Queue sync", "Priority 0", "Attempts 0",
          "Queued 9 Oct 2026 03:15 UTC (10 minutes ago)", "Failed 9 Oct 2026 03:15 UTC (10 minutes ago)", 'Arguments ["mtg","manual"]',
          "Catalog::Sources::TransientError : GET /bulk-data returned <503>", "app/models/example.rb:1:in 'call'")
        expect(response.body).to include("returned &lt;503&gt;")
        expect(page.at_css("main form")["action"]).to eq(admin_job_retry_path(job.id))
        expect(page.at_css("main a.c-btn--danger")["href"]).to eq(new_admin_job_discard_path(job.id))
      end

      it "shows a running, a scheduled and a finished job without actions (AC-6.5, AC-6.9)", :aggregate_failures do
        running = claim_job(queue_job(MTG::Art::BuildJob))
        scheduled = queue_job(MTG::Art::BuildJob, wait: 5.minutes)
        finished = finish_job(queue_job(MTG::Art::BuildJob))

        { running => [ "Running", "Started" ], scheduled => [ "Scheduled", "Due" ], finished => [ "Finished", "Finished" ] }.each do |job, (state, label)|
          get admin_job_path(job.id)
          expect(text(page.at_css(".c-pagehead__stats"))).to eq(state)
          expect(page.css(".c-details dt").map { |term| text(term) }).to include(label)
          expect(page.css("main form, main a.c-btn--danger")).to be_empty
        end
      end

      it "renders a job whose class no longer exists (Error Scenarios)", :aggregate_failures do
        job = failed_refresh
        job.update_columns(class_name: "Removed::InAnUpgradeJob") # rubocop:disable Rails/SkipsModelValidations -- as an upgrade leaves it

        get admin_job_path(job.id)

        expect(response).to have_http_status(:ok)
        expect(text(page.at_css("h1"))).to eq("Removed::InAnUpgradeJob")
      end

      it "keeps itself current only while a job is running or queued (AC-6.10)", :aggregate_failures do
        job = failed_refresh
        get admin_job_path(job.id)
        expect(page.at_css("[data-controller~='poll']")).to be_nil

        queue_job(MTG::Art::BuildJob)
        get admin_job_path(job.id)
        expect(page.at_css("main")["data-controller"]).to eq("poll")
      end

      it "answers 404 for a job the queue doesn't have" do
        get admin_job_path(0)

        expect(response).to have_http_status(:not_found)
      end
    end

    describe "retrying (AC-6.6, AC-6.8)" do
      it "queues a failed job again and says so", :aggregate_failures do
        job = failed_refresh

        post admin_job_retry_path(job.id)

        expect(response).to redirect_to(admin_jobs_path(status: "failed")).and have_http_status(:see_other)
        expect(flash[:notice]).to eq("Retrying Catalog::RefreshJob.")
        expect(SolidQueue::FailedExecution.count).to eq(0)
        expect(job.reload).to be_ready
      end

      it "changes nothing for a job that isn't failed, and says so", :aggregate_failures do
        job = queue_job(MTG::Art::BuildJob)

        post admin_job_retry_path(job.id)

        expect(response).to redirect_to(admin_jobs_path)
        expect(flash[:alert]).to eq("That job isn't failed any more.")
        expect(job.reload).to be_ready
      end

      it "answers 404 for a job that is gone" do
        post admin_job_retry_path(0)

        expect(response).to have_http_status(:not_found)
      end
    end

    describe "discarding (AC-6.7, AC-6.8)" do
      it "asks first, naming the job and what happens", :aggregate_failures do
        job = failed_refresh

        get new_admin_job_discard_path(job.id)

        expect(text(page.at_css(".c-confirm"))).to eq("Discard Catalog::RefreshJob? This removes the failed job " \
          '(["mtg","manual"]) from the queue. It won\'t run again, and it can\'t be undone. Discard Catalog::RefreshJob Cancel')
        expect(page.at_css(".c-confirm form")["action"]).to eq(admin_job_discard_path(job.id))
        expect(page.at_css(".c-confirm a")["href"]).to eq(admin_jobs_path(status: "failed"))
        expect(SolidQueue::Job.count).to eq(1)
      end

      it "removes the job on confirmation and says so", :aggregate_failures do
        job = failed_refresh

        post admin_job_discard_path(job.id)

        expect(response).to redirect_to(admin_jobs_path(status: "failed")).and have_http_status(:see_other)
        expect(flash[:notice]).to eq("Discarded Catalog::RefreshJob.")
        expect(SolidQueue::Job.count).to eq(0)
      end

      it "changes nothing for a job that isn't failed, on either step", :aggregate_failures do
        job = claim_job(queue_job(MTG::Art::BuildJob))

        get new_admin_job_discard_path(job.id)
        expect(response).to redirect_to(admin_jobs_path)
        post admin_job_discard_path(job.id)
        expect(flash[:alert]).to eq("That job isn't failed any more.")
        expect(job.reload).to be_claimed
      end

      it "answers 404 for a job that is gone" do
        post admin_job_discard_path(0)

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  it "is invisible to a member: 404 everywhere, and nothing changes (AC-7.1)", :aggregate_failures do
    job = failed_refresh
    sign_in_as(create(:user))

    [ -> { get admin_jobs_path }, -> { get admin_job_path(job.id) }, -> { post admin_job_retry_path(job.id) },
      -> { get new_admin_job_discard_path(job.id) }, -> { post admin_job_discard_path(job.id) } ].each do |request|
      request.call
      expect(response).to have_http_status(:not_found)
    end
    expect(job.reload).to be_failed
  end

  it "sends a visitor who isn't signed in to sign in (AC-7.2)", :aggregate_failures do
    create(:admin)
    job = failed_refresh

    [ -> { get admin_jobs_path }, -> { post admin_job_retry_path(job.id) }, -> { post admin_job_discard_path(job.id) } ].each do |request|
      request.call
      expect(response).to redirect_to(new_session_path)
    end
    expect(job.reload).to be_failed
  end
end
