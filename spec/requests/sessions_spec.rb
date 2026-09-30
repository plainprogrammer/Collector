require "rails_helper"

RSpec.describe "Sign-in", type: :request do
  before { create(:user, email_address: "ann@example.test") }

  def sign_in(email: "ann@example.test", password: "correct horse battery", env: {})
    post session_path, params: { email_address: email, password: }, env:
  end

  it "redirects signed-out requests to sign-in and back after signing in", :aggregate_failures do
    get catalog_entries_path(q: "bolt")
    expect(response).to redirect_to(new_session_path)

    sign_in(email: "ANN@example.test")
    expect(response).to redirect_to(catalog_entries_path(q: "bolt"))
  end

  it "goes to the collection when no page was requested" do
    sign_in
    expect(response).to redirect_to(collection_path)
  end

  it "rejects a wrong password without saying which field was wrong", :aggregate_failures do
    sign_in(password: "wrong password!")
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Email or password is incorrect.")
  end

  it "lets the health check through without signing in" do
    get rails_health_check_path
    expect(response).to have_http_status(:ok)
  end

  it "signs out only the current session", :aggregate_failures do
    sign_in
    expect { delete session_path }.to change(Session, :count).by(-1)
    get collection_path
    expect(response).to redirect_to(new_session_path)
  end

  it "sends a signed-in user away from sign-in" do
    sign_in
    get new_session_path
    expect(response).to redirect_to(collection_path)
  end

  it "sets an http-only, same-site session cookie that is secure over https" do
    https!
    sign_in
    # Rack 3 writes cookie attributes in lowercase.
    expect(response.headers["Set-Cookie"].to_s).to match(/httponly/i).and match(/samesite=lax/i).and match(/secure/i)
  end

  describe "rate limiting" do
    it "refuses the 11th attempt for one email from one address within 3 minutes", :aggregate_failures do
      10.times { sign_in(password: "wrong password!") }
      sign_in
      expect(response).to have_http_status(:too_many_requests)
      expect(response.body).to include("Too many attempts. Try again in a few minutes.")
    end

    it "doesn't lock out a different email from the same address" do
      create(:user, email_address: "bo@example.test")
      10.times { sign_in(password: "wrong password!") }
      sign_in(email: "bo@example.test")
      expect(response).to redirect_to(collection_path)
    end

    it "doesn't lock out the same email from a different client address" do
      10.times { sign_in(password: "wrong password!") }
      sign_in(env: { "REMOTE_ADDR" => "203.0.113.9" })
      expect(response).to redirect_to(collection_path)
    end

    it "counts the address a trusted proxy forwards, not the proxy's own", :aggregate_failures do
      # Requests come from 127.0.0.1, a trusted proxy, so X-Forwarded-For is honoured.
      10.times { sign_in(password: "wrong password!", env: { "HTTP_X_FORWARDED_FOR" => "198.51.100.7" }) }
      sign_in(env: { "HTTP_X_FORWARDED_FOR" => "198.51.100.7" })
      expect(response).to have_http_status(:too_many_requests)
      sign_in(env: { "HTTP_X_FORWARDED_FOR" => "198.51.100.8" })
      expect(response).to redirect_to(collection_path)
    end
  end
end
