# Be sure to restart your server when you modify this file.

# No app-wide policy: only the card scanner's pages send one (spec 007 AC-2.3, AC-2.4), from
# app/controllers/concerns/scanner_page.rb. A nonce is made only for a request that has a policy, so the
# import map tags of other pages carry none and Turbo Drive keeps working between them.
Rails.application.configure do
  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) if request.content_security_policy }
  config.content_security_policy_nonce_directives = %w[script-src]
end
