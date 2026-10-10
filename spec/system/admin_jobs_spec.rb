require "rails_helper"

# Spec 015 Story 6 in a browser: an admin retries one failed job and discards another, and the page keeps itself
# current while a job is queued. No worker runs in tests, so the example plays the worker's part.
RSpec.describe "Admin jobs page", :solid_queue, type: :system do
  let(:admin) { create(:admin) }
  # Calls the poll controller's refresh by hand in each state that should hold it, then once more with nothing in the
  # way, and returns the visits Turbo started: [[path, action], …].
  let(:held_refreshes_js) { <<~JS }
    (() => {
      const poll = window.Stimulus.getControllerForElementAndIdentifier(document.querySelector("main"), "poll")
      clearInterval(poll.timer)
      const visits = []
      document.addEventListener("turbo:visit", (event) => visits.push([ new URL(event.detail.url).pathname, event.detail.action ]))
      const menu = document.querySelector("details.c-menu")
      menu.open = true; poll.refresh()
      menu.open = false
      document.documentElement.setAttribute("aria-busy", "true"); poll.refresh()
      document.documentElement.removeAttribute("aria-busy")
      Object.defineProperty(document, "hidden", { value: true, configurable: true }); poll.refresh()
      delete document.hidden
      poll.refresh()
      return visits
    })()
  JS

  def failed_job(job_class, *arguments, message:) = fail_job(queue_job(job_class, *arguments), RuntimeError.new(message))

  def open_actions(job)
    find("summary[aria-label='Actions for #{job.class_name} #{job.id}']").click
  end

  it "retries a failed job from its row (AC-6.6)", :aggregate_failures do
    refresh = failed_job(Catalog::RefreshJob, "mtg", "manual", message: "the download broke")
    system_sign_in_as(admin)
    visit admin_jobs_path
    expect(page).to have_css(".c-filter[aria-pressed='true']", text: "Failed 1", normalize_ws: true)

    open_actions(refresh)
    click_button "Retry"

    expect(page).to have_css("#status", text: "Retrying Catalog::RefreshJob.")
    expect(page).to have_css(".c-filter", text: "Queued 1", normalize_ws: true)
    expect(page).to have_css(".c-empty", text: "No failed jobs.")
  end

  it "discards a failed job only after it is confirmed (AC-6.7)", :aggregate_failures do
    build = failed_job(MTG::Art::BuildJob, message: "the disk is full")
    system_sign_in_as(admin)
    visit admin_jobs_path
    open_actions(build)
    click_link "Discard…"
    expect(page).to have_css("h1", text: "Discard MTG::Art::BuildJob?")
    click_link "Cancel"
    expect(page).to have_text("the disk is full")

    open_actions(build)
    click_link "Discard…"
    click_button "Discard MTG::Art::BuildJob"

    expect(page).to have_css("#status", text: "Discarded MTG::Art::BuildJob.")
    expect(page).to have_css(".c-empty", text: "No failed jobs.")
    expect(SolidQueue::Job.count).to eq(0)
  end

  it "opens a failed job's page with its error and backtrace, and retries it there (AC-6.5, AC-6.6)", :aggregate_failures do
    failed_job(Catalog::RefreshJob, "mtg", "manual", message: "the download broke")
    system_sign_in_as(admin)
    visit admin_jobs_path

    click_link "Catalog::RefreshJob"
    expect(page).to have_css("h1", text: "Catalog::RefreshJob")
    expect(page).to have_css(".c-pre", text: "app/models/example.rb:1:in 'call'")

    click_button "Retry"
    expect(page).to have_css("#status", text: "Retrying Catalog::RefreshJob.")
  end

  it "shows jobs changing state by itself, and stops asking when none is running or queued (AC-6.10)", :aggregate_failures do
    job = queue_job(MTG::Art::BuildJob)
    system_sign_in_as(admin)
    visit admin_jobs_path(status: "queued")
    expect(page).to have_css(".c-jobs tbody tr", count: 1)

    using_wait_time(5) do
      claim_job(job)
      expect(page).to have_css(".c-filter", text: "Running 1", normalize_ws: true)
      expect(page).to have_css(".c-empty", text: "No queued jobs.")

      fail_job(job)
      expect(page).to have_css(".c-filter", text: "Failed 1", normalize_ws: true)
      expect(page).to have_no_css("[data-controller~='poll']")
    end
  end

  it "holds its refresh while a menu is open, Turbo is busy or the tab is hidden (FR-4)", :aggregate_failures do
    queue_job(MTG::Art::BuildJob)
    system_sign_in_as(admin)
    visit admin_jobs_path
    expect(page).to have_css("main[data-controller~='poll']")

    expect(page.evaluate_script(held_refreshes_js)).to eq([ [ admin_jobs_path, "replace" ] ])
  end
end
