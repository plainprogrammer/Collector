require "rails_helper"

RSpec.describe "Home", type: :request do
  before { sign_in_as(create(:user)) }

  describe "GET /" do
    it "renders the placeholder page with the app name", :aggregate_failures do
      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Collector")
    end
  end
end
