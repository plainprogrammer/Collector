require "rails_helper"

# Spec 055 Stories 1-4 over HTTP: "Retry now" on /admin/catalog runs the job that waits to retry, once, for an admin only.
# No worker runs in tests: a job's records show where it stands.
RSpec.describe "Retrying a waiting refresh or art build now", :solid_queue, type: :request do
  let(:admin) { create(:admin) }

  def page = Nokogiri::HTML5(response.body)

  def section(key) = page.at_css("#mtg_#{key}")

  def retry_now(operation, collectible_type: "mtg", **extra) = post admin_catalog_operation_retries_path, params: { collectible_type:, operation:, **extra }

  # A refresh whose attempt a rate limit ended: its run failed and its own job waits.
  def waiting_refresh(wait: 10.minutes)
    queue_job(Catalog::RefreshJob, "mtg", "manual", wait:).tap do |job|
      create(:catalog_refresh_run, status: "failed", stage: "download", job_id: job.active_job_id,
        message: "Catalog::Sources::RateLimitedError: asked for 600 seconds")
    end
  end

  def waiting_build(wait: 10.minutes)
    create(:catalog_refresh_run)
    queue_job(MTG::Art::BuildJob, wait:).tap do |job|
      create(:mtg_art_build, status: "failed", job_id: job.active_job_id, finished_at: Time.current,
        message: "Catalog::Sources::RateLimitedError: asked for 600 seconds")
    end
  end

  context "when signed in as an admin" do
    before { sign_in_as(admin) }

    it "shows an enabled Retry now beside the disabled start button of a waiting refresh (AC-1.1)", :aggregate_failures do
      waiting_refresh

      get admin_catalog_path

      form = section("refresh").at_css("form[action='#{admin_catalog_operation_retries_path}']")
      expect(form.at_css("button").text).to eq("Retry now")
      expect(form.at_css("button")["disabled"]).to be_nil
      expect(form.at_css("button")["class"]).to eq("c-btn c-btn--secondary")
      expect(form.css("input[type=hidden]").to_h { |input| [ input["name"], input["value"] ] })
        .to include("collectible_type" => "mtg", "operation" => "refresh")
      expect(section("refresh").at_css("form[action='#{admin_catalog_operation_starts_path}'] button")["disabled"]).to be_present
    end

    it "shows it on a waiting art index build too (AC-1.2)", :aggregate_failures, :art_matching do
      waiting_build

      get admin_catalog_path

      expect(section("art_index").at_css("form[action='#{admin_catalog_operation_retries_path}'] button").text).to eq("Retry now")
      expect(section("art_index").at_css("form[action='#{admin_catalog_operation_starts_path}'] button")["disabled"]).to be_present
    end

    it "shows none when nothing waits to retry (AC-1.3)" do
      create(:catalog_refresh_run)

      get admin_catalog_path

      expect(page.css("form[action='#{admin_catalog_operation_retries_path}']")).to be_empty
    end

    it "runs the waiting refresh job at once, without queueing another or writing a run (AC-2.1, AC-2.8)", :aggregate_failures do
      job = waiting_refresh

      expect { retry_now("refresh") }.not_to change { [ SolidQueue::Job.count, Catalog::RefreshRun.count ] }

      expect(response).to redirect_to(admin_catalog_path)
      expect(response).to have_http_status(:see_other)
      expect(flash[:notice]).to eq("Retrying now.")
      expect(job.reload).to be_ready
      expect(job.scheduled_execution).to be_nil
    end

    it "runs the waiting art build job at once (AC-2.2)", :aggregate_failures, :art_matching do
      job = waiting_build

      expect { retry_now("art_index") }.not_to change(SolidQueue::Job, :count)

      expect(response).to have_http_status(:see_other)
      expect(flash[:notice]).to eq("Retrying now.")
      expect(job.reload).to be_ready
    end

    it "then reads Queued., with no Retry now, the start button disabled, and the page polling (AC-2.3, AC-5.3)", :aggregate_failures do
      waiting_refresh
      retry_now("refresh")

      follow_redirect!

      expect(section("refresh").at_css(".c-operation__summary").text.squish).to eq("Queued.")
      expect(section("refresh").at_css("form[action='#{admin_catalog_operation_retries_path}']")).to be_nil
      expect(section("refresh").at_css("button")["disabled"]).to be_present
      expect(section("refresh").at_css(".c-details")).to be_nil
      expect(page.at_css("main")["data-controller"]).to eq("poll")
    end

    it "says nothing is waiting, and changes nothing, on a second press (AC-3.1)", :aggregate_failures do
      job = waiting_refresh
      retry_now("refresh")

      expect { retry_now("refresh") }.not_to change { [ SolidQueue::Job.count, SolidQueue::ReadyExecution.count, SolidQueue::BlockedExecution.count ] }

      expect(response).to have_http_status(:see_other)
      expect(flash[:notice]).to eq("Nothing is waiting to retry.")
      expect(job.reload.ready_execution).to be_present
    end

    it "says nothing is waiting when the job has been claimed since the page was shown (AC-3.3)", :aggregate_failures do
      job = waiting_refresh
      claim_job(job)

      retry_now("refresh")

      expect(flash[:notice]).to eq("Nothing is waiting to retry.")
      expect(job.reload).to be_claimed
    end

    it "offers no button and moves nothing for an art build while art matching is off (spec 055 Error Scenarios)", :aggregate_failures do
      job = waiting_build # the example runs with art matching off: no :art_matching tag

      get admin_catalog_path
      expect(page.css("form[action='#{admin_catalog_operation_retries_path}']")).to be_empty

      retry_now("art_index")
      expect(flash[:notice]).to eq("Nothing is waiting to retry.")
      expect(job.reload).to be_scheduled
    end

    it "says nothing is waiting when no run is waiting at all" do
      retry_now("refresh")

      expect(flash[:notice]).to eq("Nothing is waiting to retry.")
    end

    it "moves only the operation's own run's job, whatever else the request carries (AC-4.4)", :aggregate_failures do
      other = queue_job(Catalog::RefreshJob, "mtg", "manual", wait: 1.minute)
      own = waiting_refresh

      retry_now("refresh", job_id: other.id, id: other.active_job_id)

      expect(own.reload).to be_ready
      expect(other.reload).to be_scheduled
    end

    it "answers 404 for an unknown type or operation, changing nothing (AC-4.3)", :aggregate_failures do
      job = waiting_refresh

      retry_now("refresh", collectible_type: "pokemon")
      expect(response).to have_http_status(:not_found)
      retry_now("art_index_rebuild")
      expect(response).to have_http_status(:not_found)
      retry_now("constantize")
      expect(response).to have_http_status(:not_found)
      expect(job.reload).to be_scheduled
    end
  end

  it "is invisible to a member: 404, and the waiting job is unchanged (AC-4.1)", :aggregate_failures do
    job = waiting_refresh
    sign_in_as(create(:user))

    retry_now("refresh")

    expect(response).to have_http_status(:not_found)
    expect(job.reload).to be_scheduled
  end

  it "sends a visitor who isn't signed in to sign in, changing nothing (AC-4.2)", :aggregate_failures do
    job = waiting_refresh
    admin

    retry_now("refresh")

    expect(response).to redirect_to(new_session_path)
    expect(job.reload).to be_scheduled
  end
end
