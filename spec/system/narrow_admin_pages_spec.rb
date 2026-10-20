require "rails_helper"

# Spec 015 AC-7.4: the admin catalog and jobs pages fit a phone. Firefox won't open a window narrower than 500px, so
# each page is loaded in a narrow frame (spec/support/narrow_frame.rb), at the design system's 360px floor and at 375px.
RSpec.describe "Admin catalog and jobs pages on a phone", :art_matching, :solid_queue, type: :system do
  let(:long_error) { "Catalog::Sources::TransientError: GET https://api.scryfall.com/bulk-data returned 503 #{"x" * 120}" }

  it "never scroll sideways, whatever they show", :aggregate_failures do
    create(:catalog_refresh_run, source_version: "default-cards-20261005090555", started_at: 2.days.ago, finished_at: 2.days.ago)
    create(:catalog_refresh_run, :running, stage: "sync", stage_done: 61, stage_total: 100, seen_count: 66_140)
    create(:mtg_art_build, status: "running", finished_at: nil, heartbeat_at: Time.current, total_count: 31_904, fingerprinted_count: 7_976)
    failed = fail_job(queue_job(Catalog::RefreshJob, "x" * 200, "manual"), RuntimeError.new(long_error)) # one long unbroken argument
    queue_job(MTG::Art::BuildJob)
    system_sign_in_as(create(:admin))

    [ 360, 375 ].each do |width|
      [ admin_catalog_path, admin_jobs_path, admin_jobs_path(status: "queued"), admin_job_path(failed.id),
        new_admin_job_discard_path(failed.id) ].each do |path|
        expect(open_in_narrow_frame(path, width:, ready: "main")).to eq([ width, true ]), "#{path} scrolls sideways at #{width}px"
      end
    end
  end

  it "keeps every action reachable at 375px", :aggregate_failures do
    failed = fail_job(queue_job(Catalog::RefreshJob, "mtg", "manual"), RuntimeError.new(long_error))
    system_sign_in_as(create(:admin))

    open_in_narrow_frame(admin_catalog_path, width: 375, ready: "main")
    within_narrow_frame do
      expect(page).to have_button("Refresh now")
      expect(page).to have_link("Jobs", class: "c-admin__add")
    end

    open_in_narrow_frame(admin_jobs_path, width: 375, ready: "main")
    within_narrow_frame do
      find("summary[aria-label='Actions for Catalog::RefreshJob #{failed.id}']").click
      expect(page).to have_button("Retry")
      expect(page).to have_link("Discard…")
    end
  end
end
