require "rails_helper"

RSpec.describe "Health check", type: :request do
  it "returns 200 when the app has booted" do
    get rails_health_check_path

    expect(response).to have_http_status(:ok)
  end

  it "returns 500 when a database rejects writes" do
    connection = ActiveRecord::Base.lease_connection
    allow(connection).to receive(:execute)
      .and_raise(ActiveRecord::StatementInvalid, "SQLite3::ReadOnlyException: attempt to write a readonly database")

    get rails_health_check_path

    expect(response).to have_http_status(:internal_server_error)
  end
end
