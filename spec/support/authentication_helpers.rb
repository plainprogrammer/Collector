module AuthenticationHelpers
  PASSWORD = "correct horse battery".freeze

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: PASSWORD }
    user
  end

  def system_sign_in_as(user)
    visit new_session_path
    fill_in "Email", with: user.email_address
    fill_in "Password", with: PASSWORD
    click_on "Sign in"
    # Turbo submits the form with fetch; wait for the signed-in page (every one renders the avatar)
    # so a following `visit` can't abort the POST before its session cookie lands.
    expect(page).to have_css(".c-avatar")
    user
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :request
  config.include AuthenticationHelpers, type: :system
  # The sign-in rate limit counts in a process-wide MemoryStore in test; start every request spec at zero.
  config.before(type: :request) { Rails.application.config.x.sign_in_rate_limit_store&.clear }
end
