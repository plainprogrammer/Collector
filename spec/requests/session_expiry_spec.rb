require "rails_helper"

RSpec.describe "Session idle expiry (spec 049)", type: :request do
  let(:user) { create(:user) }
  let(:signed_in_session) { user.sessions.last } # not `session`: an integration test has one of its own

  before { sign_in_as(user) }

  def stamp!(ago) = signed_in_session.update!(last_used_at: Time.current - ago) # sets the stamp without a request

  # Set-Cookie is an Array when a response sets two cookies (Rack 3), so find the session cookie's own line.
  def session_cookie = Array(response.headers["Set-Cookie"]).find { it.start_with?("session_id=") }

  def cookie_expiry = Time.httpdate(session_cookie[/expires=([^;]+)/i, 1])

  describe "expiry (Story 1)" do
    it "signs in a session 29 days and 23 hours old (AC-1.1)" do
      stamp!(29.days + 23.hours)
      get collection_path
      expect(response).to have_http_status(:ok)
    end

    it "sends a GET with a session 30 days and a second old to sign-in, keeping the page to return to (AC-1.2)", :aggregate_failures do
      stamp!(30.days + 1.second)
      get collection_path(q: "bolt")
      expect(response).to redirect_to(new_session_path)

      post session_path, params: { email_address: user.email_address, password: AuthenticationHelpers::PASSWORD }
      expect(response).to redirect_to(collection_path(q: "bolt"))
    end

    it "redirects a post with an expired session to sign-in and changes nothing (AC-1.3)", :aggregate_failures do
      lot = create(:lot, account: user.account, quantity: 2)
      stamp!(31.days)
      patch lot_path(lot), params: { lot: { quantity: 9 } }
      expect(response).to redirect_to(new_session_path)
      expect(lot.reload.quantity).to eq(2)
    end

    it "shows an open catalog page to an expired session as to a visitor (AC-1.4)", :aggregate_failures, :public_catalog do
      stamp!(31.days)
      get catalog_entries_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Sign in")
    end

    it "writes nothing to sessions and removes the cookie (AC-1.5)", :aggregate_failures do
      stamp!(31.days)
      writes = write_statements_to("sessions") { get collection_path }
      expect(writes).to be_empty
      expect(Session.exists?(signed_in_session.id)).to be(true)
      expect(session_cookie).to start_with("session_id=;")
    end

    it "makes a new session on the next sign-in, not reusing the expired one (AC-1.6)", :aggregate_failures do
      expired = signed_in_session
      stamp!(31.days)
      post session_path, params: { email_address: user.email_address, password: AuthenticationHelpers::PASSWORD }
      expect(user.sessions.where.not(id: expired.id).count).to eq(1)
      expect(expired.reload.expired?).to be(true)
    end

    it "keeps a session in regular use signed in for 100 days, with no absolute lifetime (AC-1.7)" do
      10.times do
        travel(10.days)
        get collection_path
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "recording use (Story 2)" do
    it "writes nothing to sessions for a stamp under 24 hours old (AC-2.2)", :aggregate_failures do
      stamp!(23.hours)
      expect(write_statements_to("sessions") { get collection_path }).to be_empty
      expect(session_cookie).to be_nil
    end

    it "stamps a session 24 hours old or more and sets the cookie again for 30 days (AC-2.3)", :aggregate_failures do
      stamp!(24.hours)
      get collection_path
      expect(signed_in_session.reload.last_used_at).to be_within(1.minute).of(Time.current)
      expect(cookie_expiry).to be_within(1.minute).of(30.days.from_now)
    end

    it "counts a page, a form post and an open catalog visit as use (AC-2.4)", :aggregate_failures, :public_catalog do
      lot = create(:lot, account: user.account)
      [ -> { get collection_path }, -> { patch lot_path(lot), params: { lot: { quantity: 3 } } }, -> { get catalog_entries_path } ].each do |call|
        stamp!(2.days)
        call.call
        expect(signed_in_session.reload.last_used_at).to be_within(1.minute).of(Time.current)
      end
    end

    it "records nothing for no cookie, a bad cookie or a cookie that names a gone row (AC-2.5)", :aggregate_failures do
      gone = signed_in_session.id
      Session.where(id: gone).delete_all # the cookie stays and now names no row
      expect(write_statements_to("sessions") { get collection_path }).to be_empty
      expect(response).to redirect_to(new_session_path)

      cookies[:session_id] = "not-a-signed-value"
      expect(write_statements_to("sessions") { get collection_path }).to be_empty
      expect(response).to redirect_to(new_session_path)

      cookies.delete(:session_id)
      expect(write_statements_to("sessions") { get collection_path }).to be_empty
      expect(Session.count).to eq(0)
    end

    it "sets a signed, HTTP-only, same-site-lax cookie that expires in 30 days and is not permanent (AC-2.6)", :aggregate_failures do
      delete session_path # the group's sign-in left a session; a signed-in user is redirected away from sign-in
      https!
      sign_in_as(user)
      expect(session_cookie).to match(/httponly/i).and match(/samesite=lax/i).and match(/secure/i)
      expect(cookie_expiry).to be_within(1.minute).of(30.days.from_now)
    end

    it "writes to sessions at most once for requests within a day (AC-2.7)", :aggregate_failures do
      stamp!(2.days)
      first = write_statements_to("sessions") { get collection_path }
      second = write_statements_to("sessions") { get collection_path }
      expect(first.size).to eq(1)
      expect(second).to be_empty
    end

    it "rewrites a stamp later than now (the clock was set back) and signs in (AC-2.8)", :aggregate_failures do
      stamp!(-3.days)
      get collection_path
      expect(response).to have_http_status(:ok)
      expect(signed_in_session.reload.last_used_at).to be_within(1.minute).of(Time.current)
    end
  end
end
