# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Status

Collector is a self-hostable, multi-tenant web app for tracking collectibles, starting with Magic: The Gathering cards. The Rails app skeleton exists (stack, RSpec, `bin/ci`, Compose and Kamal deployment). Feature 002 added a collectible-agnostic catalog core (`app/models/catalog/`) with an MTG extension (`app/models/mtg/`), Scryfall bulk-data ingestion via a background refresh, and a public card search proof-of-concept at `/catalog/entries`. Accounts (row-level tenancy through `Current.account`) and collections of lots (spec 004, list view spec 006) exist, and the card scanner (specs 005, 007–009) adds scanned cards to the collection through its confirm flow. Admins start and watch catalog refreshes and art index builds at `/admin/catalog`, and see, retry and discard background jobs at `/admin/jobs` (spec 015). License: AGPL-3.0.

Mission and principles: `.claude/memory/foundation.md`. Detailed coding rules: `.claude/rules/`. Feature specs: `docs/specs/`.

## Stack

Ruby 4.0.7, Rails 8.1.4, SQLite in every environment (including production), Hotwire (Turbo + Stimulus), Propshaft + importmap (no Node toolchain), Solid Queue / Solid Cache / Solid Cable, RSpec + FactoryBot + Capybara, WebMock/VCR, RuboCop (`rubocop-rails-omakase` + `rubocop-rspec`), Brakeman, bundler-audit, Kamal 2.12.0.

## Commands

- Setup: `bin/setup` (idempotent; works in clones and worktrees, copies `.worktreeinclude` files from the main checkout, enables `.githooks/` auto-setup; starts the server afterwards, `--skip-server` to not)
- Run: `bin/dev` (just `bin/rails server`; port 3000, or the worktree's port printed by `bin/setup`)
- All specs: `bin/rspec`
- Single spec file / example: `bin/rspec spec/requests/home_spec.rb:5`
- Lint (autocorrect): `bin/rubocop -a`
- Security: `bin/brakeman`, `bin/bundler-audit`, `bin/importmap audit`
- Local CI (single CI definition, `config/ci.rb`): `bin/ci` — setup, RuboCop, Brakeman, bundler-audit, importmap audit, RSpec. GitHub Actions runs `bin/ci`, then builds the container image for amd64 and arm64 (smoke-tested with `bin/image-smoke`) and publishes it to `ghcr.io/plainprogrammer/collector` on `main` (`edge`) and release tags (spec 012, `docs/releasing.md`). Change CI steps in `config/ci.rb`.
- DB: `bin/rails db:prepare` (also what containers run on boot via `bin/docker-entrypoint`)
- Catalog: `bin/rails "catalog:refresh[mtg]"` (queues a background refresh), `bin/rails "catalog:status[mtg]"` (10 most recent runs); extra languages via `COLLECTOR_MTG_LANGUAGES`
- Containers locally: `podman compose up -d` (no Docker on the dev machine; `compose.yaml` needs `SECRET_KEY_BASE`, optional `COLLECTOR_PORT`)

## Non-obvious Facts

- **Dev mirrors prod.** Development uses separate SQLite DBs (`storage/development{,_cache,_queue,_cable}.sqlite3`) and runs Solid Queue inside Puma (`config/puma.rb` plugin), so the server already processes jobs. Never also run `bin/jobs` (two supervisors on one SQLite queue DB). The test env uses Rails defaults (primary DB only, `:test` job adapter, null cache); Solid Queue's tables are loaded into that one database for the admin pages' specs.
- **Worktrees:** `bin/setup` sets `core.hooksPath=.githooks` (unless a custom hooks path exists), so `git worktree add`, `claude --worktree` and Orca (`orca.yaml`) worktrees set themselves up via `.githooks/post-checkout` (new linked worktrees only; failures keep the worktree). Each worktree has its own DBs; dev port is 3000 in the main checkout, 3001–3999 per worktree (`lib/collector/dev_port.rb`), `PORT` overrides. Copy list = `.worktreeinclude` (copied only if missing, mode 0600; logic in `lib/collector/worktree_setup.rb`). A missing `config/master.key` only warns; a wrong one breaks boot.
- **Specs:** tag spec types explicitly (`type: :request`, `type: :system`; no inference); multi-expectation examples use `:aggregate_failures`. System specs run in headless Firefox. WebMock + VCR block all real HTTP (cassettes in `spec/cassettes`).
- **Deploy:** Compose (`compose.yaml`, `image:` defaults to the published `ghcr.io/plainprogrammer/collector:latest`, `COLLECTOR_IMAGE` overrides) and Kamal (`config/deploy.yml`, registry `ghcr.io`, placeholder server; deploy a release with `bin/kamal deploy --skip-push --version X.Y.Z`) both mount the `collector_storage` volume at `/rails/storage` and set `SOLID_QUEUE_IN_PUMA`. Both paths are documented in `README.md`; keep it in sync. `.dockerignore` keeps `docs/`, `spec/`, `spikes/`, `script/` and agent files out of the (public) image.
- **Catalog data is global** (no `account_id`) and changes only through `Catalog::Refresh` (weekly `config/recurring.yml` schedule + the manual rake task, via `Catalog::RefreshJob`) and, for the MTG art index (spec 011, opt-in `COLLECTOR_MTG_ART_MATCHING`), `MTG::Art::BuildJob`, which the refresh queues and which writes `mtg_artworks`, `mtg_art_builds`, the image cache and the index under `storage/catalog/mtg/art/`. Downloads are kept in `storage/catalog/<type>/`. Pages never call Scryfall during render.
- **Admin catalog and jobs (spec 015, ADRs 0014 and 0015):** `/admin/catalog` renders `Catalog::Health` (one per registered type) and its `Catalog::Operation`s: the core's `Catalog::RefreshOperation`, plus whatever a source's optional `.operations` hook adds (`MTG::Art::Operation`); the core code never names a collectible (`spec/admin_catalog_core_spec.rb`). A refresh run records its stage, progress, heartbeat and job id (`Catalog::Refresh::Progress`); 15 minutes without progress is a stall (`Catalog::RefreshRun::STALL_AFTER`), separate from the job's 6-hour queue lock (`Catalog::RefreshJob::LOCK_FOR`). "In flight" and the jobs pages (`BackgroundJobs::List`, `BackgroundJobs::Entry`) read Solid Queue's own tables. Pages poll with the `poll` Stimulus controller only while work is in flight. In specs, Solid Queue's tables are loaded into the test database (`spec/support/solid_queue.rb`); tag an example `:solid_queue` to queue through Solid Queue (no worker runs) and move jobs with `queue_job`, `claim_job`, `fail_job`, `finish_job`.
- **Active Storage variants (spec 014, ADR 0013)** use libvips through `ruby-vips`, which is bundled with `require: false` so the app boots without libvips (it then logs "requires the ruby-vips gem"). Development needs libvips (`vips` on Fedora, `libvips` on Debian/Ubuntu): `bin/setup` prints a hint when it's missing (`Collector::LibvipsCheck`), CI installs it, and `bin/image-smoke` fails an image whose variant transformer isn't vips. No upload feature exists yet.
- **Card scanner (specs 007, 009):** `/scanner`, linked from the navigation ("Scan") and the collection page. A scan is confirmed and added as a lot; the sitting's adds live in `scanner_sittings`/`scanner_sitting_entries` (one entry per reading key) until Done. Picked photos go through the hand-written detector (`app/javascript/scanner/detector.js`, ADR 0005); `script/scanner/detector_parity.rb` checks it against the spike's. Spec 009's findings tasks: `scanner:ranking`, `scanner:strong_sweep`, `scanner:foil_markers`, `scanner:detected_score`, `scanner:replay_score`, `scanner:overlap`, `scanner:sitting_findings` (results in `docs/specs/009-card-scanner-confirm-flow/research.md`). Its OCR engine is fetched and checksum-verified into the ignored `vendor/ocr/v7.0.0/` by `bin/fetch-ocr-engine` (run by `bin/setup` and the Dockerfile) and served by `OcrAssetsController`; scanner specs fail until it's installed. Art matching (spec 011, ADRs 0006, 0007 and 0012) needs ImageMagick (`magick` or `convert`) for the build and its specs; the page searches `/scanner/art/<index>` on the device. Only scanner pages send a Content-Security-Policy (`ScannerPage` concern); nonces exist only on those requests. Measurement mode (`/scanner/measurement`) is development-only (`config.x.scanner_measurement`; `COLLECTOR_SCANNER_MANIFEST`, `COLLECTOR_SCANNER_RUN_DIR`) and writes outside the repo. The art spike (spec 010) lives in `spikes/card_scanner/phase3/` (phone timing and replay server; spec 008's art tools take `CARD_SCANNER_WORK_DIR`, `CARD_SCANNER_TRUTH_CORPORA` and `CARD_SCANNER_BULK_FILE`), and measurement mode keeps live frames with `COLLECTOR_SCANNER_KEEP_FRAMES=1`. Phones need HTTPS: `bin/dev-certificate` makes a self-signed certificate outside the repo and prints the `bin/dev -b "ssl://…"` bind (alternative: a tunnel with `RAILS_DEVELOPMENT_HOSTS` + `COLLECTOR_HTTPS=true`).
- **Off-limits for reads (permission-denied):** `.kamal/secrets`, `config/master.key`, `.env*`, `storage/`. Don't try to read them.

## Architecture Intent

- **Collectible-agnostic core.** Core domain models (collections, items, conditions, valuations) must not know about any specific collectible; MTG-specific code lives under the `MTG::` namespace (inflector acronym in `config/initializers/inflections.rb`) behind an extension boundary.
- **Row-level multi-tenancy.** Every tenant-owned table carries `account_id`; requests resolve `Current.account` and all queries scope through it. Jobs and Turbo Stream broadcasts must carry/restore the tenant. Shared catalog data (e.g. Scryfall cards) is global.
- **External data behind adapters.** Sources such as Scryfall implement the `Catalog::Sources` contract and live in their collectible's namespace (`MTG::Scryfall`); they are synced in background jobs (bulk data, cached locally) and never called during page render.
- **Self-hosting & upgrades.** Separate SQLite DBs (primary/queue/cache/cable) live in `storage/` on a persistent volume. Released migrations are never edited; every migration must be safe to run unattended from any prior version. User data export/import uses a documented, versioned format keyed by external IDs.

## Claude Code Hooks (`.claude/settings.json`)

- After editing a Ruby file: `bin/rubocop -a` runs on that file; remaining offenses are reported back.
- Before `git commit`: RuboCop on staged Ruby files + Brakeman; failures block the commit.
- Before `git push`: `bin/ci`; failure blocks the push.

## UI and design system

All UI follows the Collector design system in `docs/design-system/`. Before creating or changing any view, partial, stylesheet or UI copy, use the `collector-design-system` skill (`.claude/skills/collector-design-system/SKILL.md`) and read `docs/design-system/README.md`. Use only the token variables and `c-*` classes from `app/assets/stylesheets/collector/`; never hard-code colours, spacing or fonts. The export's files (`tokens.css`, `components.css`, fonts, logos, `docs/design-system/`) are replaced wholesale by re-exporting the published design system; app-specific patterns live in `collector/additions.css` with a doc per pattern under `docs/design-system/components/`.
