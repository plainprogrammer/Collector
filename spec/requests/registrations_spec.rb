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
      expect(response).to have_http_status(:unprocessable_content)
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
      expect(response).to have_http_status(:unprocessable_content)
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
      expect(response).to have_http_status(:unprocessable_content)
      page = Nokogiri::HTML5(response.body)
      {
        "name" => "Name can't be blank",
        "email_address" => "Email must look like name@example.com",
        "password" => "Password must be at least 12 characters",
        "password_confirmation" => "Password confirmation doesn't match Password"
      }.each { |field, message| expect(page.at_css("##{field}-error")&.text&.squish).to eq(message), field }
      expect(page.css(".field_with_errors")).to be_empty
    end

    # Spec 004 AC-4.1 asks for "a matching confirmation" and AC-4.3 refuses a mismatch with 422; a confirmation that is
    # missing or blank is no match (#218 ruling 5, #230). The refusal reads as a mismatch does, under the same field.
    {
      "is missing" => ->(user) { user.except(:password_confirmation) },
      "is blank" => ->(user) { user.merge(password_confirmation: "") }
    }.each do |what, change|
      it "refuses a sign-up whose confirmation #{what}, as it does a mismatch", :aggregate_failures do
        users, accounts = User.count, Account.count
        post registration_path, params: { user: change.call(params[:user]) }
        expect([ User.count, Account.count ]).to eq([ users, accounts ])
        expect(response).to have_http_status(:unprocessable_content)
        page = Nokogiri::HTML5(response.body)
        expect(page.at_css("#password_confirmation-error")&.text&.squish).to eq("Password confirmation doesn't match Password")
        expect(page.at_css("#user_name")["value"]).to eq("Ann")
      end
    end
  end

  it "sends a signed-in user away from sign-up" do
    sign_in_as(create(:admin))
    get new_registration_path
    expect(response).to redirect_to(collection_path)
  end
end
