require "rails_helper"

RSpec.describe "Sign-up", type: :request do
  let(:params) { { user: { name: "Ann", email_address: "ann@example.test", password: "correct horse battery", password_confirmation: "correct horse battery" } } }

  context "when the instance has no users" do
    it "sends every page except sign-up and the health check to sign-up", :aggregate_failures do
      get catalog_entries_path
      expect(response).to redirect_to(new_registration_path)
      get new_session_path
      expect(response).to redirect_to(new_registration_path)
      get rails_health_check_path
      expect(response).to have_http_status(:ok)
    end

    it "explains that the first account is the admin and signs the new admin in", :aggregate_failures do
      get new_registration_path
      expect(response.body).to include("This first account will be the admin of this instance.")

      post registration_path, params: params
      expect(response).to redirect_to(collection_path)
      expect(User.sole).to be_admin
    end

    it "refuses a first-admin form submitted after someone else became the first user", :aggregate_failures do
      get new_registration_path
      create(:admin)
      expect { post registration_path, params: params }.not_to change(User, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Sign-up is closed on this instance.")
    end
  end

  context "when sign-up is closed" do
    before { create(:admin) }

    it "shows the closed message without a form, and refuses submissions", :aggregate_failures do
      get new_registration_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Sign-up is closed on this instance. Ask the person who runs it for an account.")
      expect(response.body).not_to include("<form")

      expect { post registration_path, params: params }.not_to change(User, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Sign-up is closed on this instance.")
    end
  end

  context "when sign-up is open" do
    before do
      create(:admin)
      InstanceSetting.current.update!(sign_up_open: true)
    end

    it "creates a non-admin user with their own account" do
      expect { post registration_path, params: params }.to change(Account, :count).by(1)
    end

    it "shows each invalid field's message with 422", :aggregate_failures do
      post registration_path, params: { user: { name: "", email_address: "nope", password: "short", password_confirmation: "other" } }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Name can&#39;t be blank", "Email must look like name@example.com",
        "Password must be at least 12 characters", "Password confirmation doesn&#39;t match Password")
    end
  end

  it "sends a signed-in user away from sign-up" do
    sign_in_as(create(:admin))
    get new_registration_path
    expect(response).to redirect_to(collection_path)
  end
end
