# Security

- ✓ Use `params.expect` / `require(...).permit(...)`; never allow `account_id`, `role`, or `admin` in mass assignment.
- ✓ Use bind params in all SQL; allowlist sort columns. Never interpolate strings into `where`, `order`, `pluck`, `find_by_sql`, or `Arel.sql`.
- ✓ Keep the CSP (`content_security_policy.rb`) with nonces for importmap/inline scripts; add sensitive fields to `filter_parameters`.
- ✓ Secrets live in Rails credentials or `.kamal/secrets` (fetched from a vault) — never in `deploy.yml`, the Dockerfile, seeds, or the repo.
- ✓ Validate Active Storage uploads (content type, size) and serve them tenant-scoped; no permanent public blob URLs.
- ✓ Gate CI (`bin/ci`) on `bin/brakeman`, `bin/bundler-audit`, `bin/importmap audit`, and `bin/rubocop`; any Brakeman ignore needs a written justification.
- ✗ No `html_safe`, `raw`, or `<%==` on user content; use `sanitize` with an allowlist.
- ✗ Don't skip CSRF protection, disable `force_ssl`/`assume_ssl` in production, or `redirect_to params[:url]`.
- ✗ No default admin credentials in seeds — self-hosters generate secrets at setup time.
- ✗ Never run `db:schema:load`, `db:reset`, or `db:drop` against production; SQLite files live on a persistent volume, never baked into the image.
