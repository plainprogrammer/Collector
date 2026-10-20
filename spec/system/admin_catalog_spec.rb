require "rails_helper"

# Spec 015 Stories 1 and 2 in a browser: an admin starts the first refresh from the catalog page and
# watches it go without reloading. No worker runs in tests, so the examples play the job's part by changing its records.
RSpec.describe "Admin catalog page", :solid_queue, type: :system do
  let(:admin) { create(:admin) }

  def summary = find("#mtg_refresh .c-operation__summary")

  def current_stage = find("#mtg_refresh [aria-current='step']")

  # The refresh job in the queue, picked up by a worker and working on the given stage.
  def work_on(stage, **progress)
    job = SolidQueue::Job.sole
    claim_job(job) unless job.claimed?
    run = Catalog::RefreshRun.find_or_create_by!(collectible_type: "mtg", trigger: "manual", status: "running", job_id: job.active_job_id) do |new|
      new.started_at = Time.current
    end
    run.progress!(stage:, **progress)
    run
  end

  def apply(run)
    run.update!(source_version: "default-cards-7")
    run.finish!(:applied, counts: { seen: 108_412, inserted: 108_412 })
    finish_job(SolidQueue::Job.sole)
  end

  it "starts the first refresh from the empty state (AC-1.4, AC-2.1, AC-2.2)", :aggregate_failures do
    system_sign_in_as(admin)
    visit admin_catalog_path
    expect(page).to have_css(".c-empty", text: "No cards are loaded yet.")

    click_button "Refresh now"

    expect(page).to have_css("#status", text: "Refresh queued.")
    expect(summary).to have_text("Queued.")
    expect(page).to have_button("Refresh now", disabled: true)
    expect(SolidQueue::Job.sole.arguments["arguments"]).to eq(%w[mtg manual])
  end

  it "shows a refresh's stages and progress as they change, then stops asking (AC-2.10, AC-2.11)", :aggregate_failures do
    queue_job(Catalog::RefreshJob, "mtg", "manual")
    system_sign_in_as(admin)
    visit admin_catalog_path

    using_wait_time(5) do
      work_on("download", done: 20_600_000, total: 82_400_000)
      expect(current_stage).to have_text("Download In progress 25% 19.6 MB of 78.6 MB", normalize_ws: true)
      run = work_on("sync", done: 61, total: 100, counts: { seen: 66_140, inserted: 66_140 })
      expect(current_stage).to have_text("Sync cards In progress 61% 66,140 seen · 66,140 inserted · 0 updated", normalize_ws: true)
      apply(run)
      expect(summary).to have_text("Applied.")
      expect(page).to have_css("#catalog_mtg .c-details", text: "default-cards-7")
      expect(page).to have_button("Refresh now", disabled: false)
      expect(page).to have_no_css("[data-controller~='poll']") # nothing is in flight: the page stops asking
    end
  end

  it "doesn't ask for updates while nothing is in flight (AC-2.12)", :aggregate_failures do
    create(:catalog_refresh_run)
    system_sign_in_as(admin)

    visit admin_catalog_path

    expect(summary).to have_text("Applied.")
    expect(page).to have_no_css("[data-controller~='poll']")
  end

  it "keeps the scroll position across an update (AC-2.10)", :aggregate_failures do
    8.times { |n| create(:catalog_refresh_run, started_at: (n + 1).days.ago) }
    queue_job(Catalog::RefreshJob, "mtg", "manual")
    system_sign_in_as(admin)
    page.current_window.resize_to(1000, 500)
    visit admin_catalog_path
    expect(summary).to have_text("Queued.")
    page.execute_script("window.scrollTo(0, 150)")

    work_on("retire")

    using_wait_time(5) { expect(summary).to have_text("Running.") }
    expect(page.evaluate_script("window.scrollY")).to eq(150)
  end
end
