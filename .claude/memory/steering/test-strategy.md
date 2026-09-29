---
scope: test-strategy
loaded-by: sdd-plan, sdd-execute, sdd-review
---

# Test Strategy

## Test Framework
RSpec (rspec-rails) with FactoryBot; Capybara for system specs; WebMock/VCR for external HTTP.

## Local CI
`bin/ci` (configured in `config/ci.rb`) is the single local CI entrypoint and runs as a pre-push gate. It runs `bundle exec rspec`, `bin/rubocop`, `bin/brakeman`, `bin/bundler-audit`, and `bin/importmap audit`. Keep it maintained — new checks go into `config/ci.rb`.

## Test Levels
- Unit tests: model and PORO specs (`spec/models`), job specs (`spec/jobs`) including idempotency (perform twice → same result).
- Integration tests: request specs (`spec/requests`) for every endpoint, including a cross-tenant 404 check for each tenant-scoped resource; import/export round-trip specs.
- E2E tests: a small set of system specs (`spec/system`) for critical Hotwire flows only.

## Coverage Expectations
Every new or changed behavior ships with specs (Foundation principle 5). Tenant isolation, migrations/upgrade safety, and import/export are critical paths and must be explicitly tested. [Edit to add a numeric target if desired]

## Mocking Policy
Real SQLite database in all specs; mock only external HTTP (WebMock blocks real network; VCR cassettes for Scryfall). Don't mock the object under test or ActiveRecord internals.
