# Testing (RSpec)

- ✓ `bin/ci` (driven by `config/ci.rb`) is the project's local CI tool and the pre-push gate. Keep it maintained: it runs `bundle exec rspec` (not the default `bin/rails test`), `bin/rubocop`, `bin/brakeman`, `bin/bundler-audit`, and `bin/importmap audit`. When adding a new check, add it to `config/ci.rb`.
- ✓ Mirror `app/` in `spec/` (`spec/models`, `spec/requests`, `spec/system`, `spec/jobs`); files end in `_spec.rb`.
- ✓ Prefer request specs over controller specs; keep system specs (Capybara) for critical Hotwire flows.
- ✓ FactoryBot with minimal valid factories and traits; prefer `build`/`build_stubbed` when persistence isn't needed.
- ✓ `describe` the unit (`".class_method"`, `"#instance_method"`), `context` for conditions ("when …"), one behavior per `it`.
- ✓ Explicitly test tenant isolation, job idempotency (perform twice → same result), and import/export round-trips.
- ✓ Use `have_enqueued_job`/`perform_enqueued_jobs` for jobs; WebMock/VCR for Scryfall; block real HTTP.
- ✓ Run specs in random order; use `rspec --bisect` for order-dependent failures.
- ✗ Don't use `let!`/`before` chains that create unused records; avoid deep nesting and `any_instance_of`.
- ✗ Don't `sleep` in system specs; rely on Capybara's waiting matchers.
- ✗ Don't mock the object under test or stub ActiveRecord internals.
