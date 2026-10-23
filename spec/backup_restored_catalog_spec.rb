require "rails_helper"

RSpec.describe "a restored instance's catalog page and stored import", :backup, :committed, :solid_queue, type: :request do
  let!(:admin) { create(:admin) }
  let(:volume) { scratch("volume") }
  let(:restored) { volume.join("production.sqlite3") }

  def page = Nokogiri::HTML5(response.body)

  it "reads a refresh recorded as running as interrupted, and lets a refresh start (AC-2.9)", :aggregate_failures do
    create(:catalog_refresh_run, :running, stage: "sync", started_at: 1.hour.ago, heartbeat_at: 5.minutes.ago, job_id: "job-1") # older than JOB_ENDED_GRACE, younger than STALL_AFTER: only the missing job reads it as interrupted
    restore_backup(create_backup, volume:)

    with_restored_instance(restored) do
      SolidQueueHelpers.load_tables # the queue's tables are part of the test database, and a fresh instance has its own
      sign_in_as(admin)
      get admin_catalog_path
      expect(page.at_css("#mtg_refresh .c-operation__summary").text.squish).to eq("Interrupted while syncing cards.")
      expect(page.at_css("#mtg_refresh button")["disabled"]).to be_nil
      post admin_catalog_operation_starts_path, params: { collectible_type: "mtg", operation: "refresh" }
      expect(response).to redirect_to(admin_catalog_path)
      expect(SolidQueue::Job.where(class_name: "Catalog::RefreshJob").count).to eq(1)
    end
  end

  it "answers 'Preview the file again.' for an upload whose file isn't there, and the sweep removes its row (AC-2.10)", :aggregate_failures do
    entry = import_printing
    upload = store_import!(account: admin.account, data: import_file(admin, [ import_row(entry) ]))
    path = create_backup
    ActiveStorage::Blob.service.delete(upload.file.blob.key) # the backup holds the database only
    restore_backup(path, volume:)

    with_restored_instance(restored) do
      sign_in_as(admin)
      post collection_import_path, params: { fingerprint: ImportUpload.sole.fingerprint, confirm_removal: "1" }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Preview the file again.")
      expect(Lot.count).to eq(0)
      travel_to(2.hours.from_now) { ImportUpload.sweep! }
      expect(ImportUpload.count).to eq(0)
    end
  end
end
