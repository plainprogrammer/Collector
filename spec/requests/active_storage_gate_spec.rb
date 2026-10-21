require "rails_helper"

# Spec 028 AC-1.12: Active Storage's routes need a sign-in and an owner; uploads through them are closed.
RSpec.describe "Active Storage gate", type: :request do
  let(:owner) { create(:user) }
  let(:other) { create(:user) }
  let!(:upload) { store_import!(account: owner.account, data: import_file(owner, [ import_row(import_printing) ])) }
  let(:blob) { upload.file.blob }

  def disk_path
    token = ActiveStorage.verifier.generate({ key: blob.key, content_type: blob.content_type, disposition: "attachment",
      service_name: blob.service_name }, expires_in: 5.minutes, purpose: :blob_key)
    rails_disk_service_path(token, filename: blob.filename)
  end

  it "sends a signed-out visitor to sign in and returns no content", :aggregate_failures do
    get rails_blob_path(blob)

    expect(response).to redirect_to(new_session_path)
    expect(response.body).not_to include("collector-export")
  end

  it "returns 404 to another account's collector, for the blob and for the disk URL", :aggregate_failures do
    sign_in_as(other)
    [ rails_blob_path(blob), disk_path ].each do |path|
      get path
      expect(response).to have_http_status(:not_found)
    end
  end

  it "serves the file to its owner, through the redirect to the disk service", :aggregate_failures do
    sign_in_as(owner)
    get rails_blob_path(blob)
    expect(response).to have_http_status(:redirect)
    follow_redirect!

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("collector-export")
  end

  it "returns 404 for a blob no record holds" do
    orphan = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("x"), filename: "x.txt", content_type: "text/plain")
    sign_in_as(owner)

    get rails_blob_path(orphan)

    expect(response).to have_http_status(:not_found)
  end

  describe "direct uploads and the disk service's upload (decision 8, ruled 2026-10-20)" do
    let(:declared) { { blob: { filename: "a.png", byte_size: 1, checksum: "x", content_type: "image/png" } } }

    it "answer 404 signed out and signed in, and create no blob", :aggregate_failures do
      before = ActiveStorage::Blob.count
      2.times do
        post rails_direct_uploads_path, params: declared, as: :json
        expect(response).to have_http_status(:not_found)
        put update_rails_disk_service_path("anything"), params: "bytes"
        expect(response).to have_http_status(:not_found)
        sign_in_as(owner)
      end
      expect(ActiveStorage::Blob.count).to eq(before)
    end
  end

  it "never puts a blob URL, key or signed id in the preview page", :aggregate_failures do
    sign_in_as(owner)
    post collection_import_preview_path, params: { export_file: import_upload_file(import_file(owner, [ import_row(import_printing, quantity: 2) ])) }
    kept = owner.account.reload.import_upload.file.blob

    expect(response.body).not_to include("active_storage", kept.key, kept.signed_id)
  end
end
