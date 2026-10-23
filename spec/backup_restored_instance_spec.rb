require "rails_helper"

RSpec.describe "an instance started from a restored backup", :backup, :committed, type: :request do
  let!(:seed) { seed_instance }
  let(:user) { seed.user }
  let(:volume) { scratch("volume") }
  let(:restored) { volume.join("production.sqlite3") }

  it "signs the collector in with their password, shows their lots and exports the same collection (AC-2.2)", :aggregate_failures do
    before_export = JSON.parse(CollectionExport.new(account: user.account, at: Time.utc(2026, 10, 21, 12)).to_json)
    restore_backup(create_backup, volume:)
    _output, error, status = app_command(restored, "db:prepare") # the entrypoint's command, on the restored file
    expect(status).to be_success, error

    with_restored_instance(restored) do
      sign_in_as(user)
      get "/collection"
      expect(response).to have_http_status(:ok)
      seed.entries.each { |entry| expect(response.body).to include(entry.name) }
      get "/collection/export"
      expect(ExportFormatRules.same_collection?(before_export, JSON.parse(response.body))).to be(true)
    end
  end

  it "ends every session: the old cookie is sent to sign in, and the password works (AC-2.4)", :aggregate_failures do
    sign_in_as(user) # a session row, and its cookie in this integration session
    expect(table_rows(instance_database).fetch("sessions")).not_to be_empty
    restore_backup(create_backup, volume:)

    expect(table_rows(restored).fetch("sessions")).to be_empty
    with_restored_instance(restored) do
      expect(Session.count).to eq(0)
      get "/collection"
      expect(response).to redirect_to(new_session_path)
      post session_path, params: { email_address: user.email_address, password: AuthenticationHelpers::PASSWORD }
      get "/collection"
      expect(response).to have_http_status(:ok)
    end
  end
end
