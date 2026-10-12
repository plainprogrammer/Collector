# Verification: An Accurate README (spec 020)

**Spec:** [spec.md](spec.md) v1.4.2 · **Plan:** [plan.md](plan.md) · **Recorded:** 2026-10-12 ·
**Branch:** `020-readme-introduction` · **Issue:** [#63](https://github.com/plainprogrammer/Collector/issues/63)

Comparisons "with `origin/main`" are with the merge base, `3ab9864` (`origin/main...HEAD`). README line numbers are
the file's at the head this record was written against, `63703d2`, unless a row says otherwise. The sweep itself was
read against `9070ad4`; the four corrections made after it changed three lines in place and removed one table row,
so every line below that row is one lower than in the sweep.

## Commits

`git log --oneline origin/main..HEAD`, before the record's own commit:

```
63703d2 docs(readme): drop COLLECTOR_PASSWORD from the Compose variable table
e2155b2 docs(readme): say art matching sends the closest artworks' ids
ef46056 docs(readme): say the weekly schedule also starts the first download
58fa06b docs(readme): say the weekly refresh runs at 03:15 UTC
9070ad4 docs(claude): say catalog search needs sign-in
decacc3 docs: name a spec file that exists in the single-spec example
28e5bb5 docs(readme): say what Collector does today in the introduction
4ed3582 docs(rules): don't check prose documents from RSpec
593df2a test(export-format): remove the README link and ADR index examples
4b6a150 test(design-system): remove the examples that check documents
88dff35 test(image): remove the examples that check docs/releasing.md
a5f6cfa test: remove the README spec
9d11106 test(image): keep the art matching configuration checks in the image publishing spec
4628945 docs(020): approve the plan
4dd48be docs(020): apply the plan's second review
04dbbc1 docs(020): revise the plan after its review
37477d1 docs(020): draft the plan for an accurate README
d793c83 docs(020): apply the third review of the spec
6eea53f docs(020): remove every prose-document check from the suite
11e85a1 chore(memory): widen the ruling to all prose documents
82a09d7 docs(020): apply the second review and mark the spec approved
bc44d6a docs(020): remove the README spec and accept decision 5
8c20d32 chore(memory): record the ruling against README wording specs
14c3cdf docs(020): revise the spec after the Opus review
a69135c docs(020): bring CLAUDE.md's stale search phrase into scope
3a8f1b8 docs(020): draft the spec for an accurate README
45b3407 chore(memory): make Opus the default model for SDD reviews
```

## The suite (Story 4)

Baseline at the merge base (`bin/rspec`): `1219 examples, 0 failures, 1 pending`. At the head: `1206 examples, 0
failures` (`bin/rspec --dry-run`), 13 fewer: 15 removed, 2 added.

| File | Examples at the merge base | Examples at the head | Change |
|---|---|---|---|
| `spec/readme_spec.rb` | 8 | file deleted | 8 removed |
| `spec/image_publishing_spec.rb` | 23 | 22 | 3 removed (`describe "docs/releasing.md"`), 2 added |
| `spec/design_system_files_spec.rb` | 6 | 4 | 2 removed; the first example renamed "installs the export's stylesheets, fonts and logos" |
| `spec/export_format_document_spec.rb` | 11 | 9 | 2 removed (`describe "the repository around it (AC-4.4)"`) |
| `spec/export_format_examples_spec.rb` | 16 | 16 | unchanged |

Run at the head: `bin/rspec spec/image_publishing_spec.rb` gives `22 examples, 0 failures`;
`bin/rspec spec/design_system_files_spec.rb` gives `4 examples, 0 failures`;
`bin/rspec spec/export_format_document_spec.rb spec/export_format_examples_spec.rb` gives `25 examples, 0 failures`.

**The two new examples can fail** (each run with the configuration file changed, then the file restored):

- With `compose.yaml` passing `COLLECTOR_MTG_ART_MATCHING: "true"`:
  `1) Image publishing files compose.yaml passes the art matching setting to the container, empty unless it is set (spec 011 AC-1.3)`,
  `Failure/Error: expect(compose.read).to include('COLLECTOR_MTG_ART_MATCHING: "${COLLECTOR_MTG_ART_MATCHING:-}"')`,
  `1 example, 1 failure`.
- With the commented line deleted from `config/deploy.yml`:
  `1) Image publishing files config/deploy.yml offers art matching as a commented-out setting (spec 011 AC-1.3)`,
  `Failure/Error: expect(Rails.root.join("config/deploy.yml").read).to include("# COLLECTOR_MTG_ART_MATCHING: true")`,
  `1 example, 1 failure`.

**The three Phase 0 verification commands:**

```
$ git diff --name-status origin/main...HEAD -- spec
M	spec/design_system_files_spec.rb
M	spec/export_format_document_spec.rb
M	spec/image_publishing_spec.rb
D	spec/readme_spec.rb

$ bin/rspec --dry-run | grep -E "^[0-9]+ examples"
1206 examples, 0 failures

$ grep -rnE '\.md\b|docs/' spec --include='*.rb'
spec/export_format_document_spec.rb:3:# Spec 017: the export format's document (docs/export-format/README.md), checked against its schema, its examples
spec/export_format_examples_spec.rb:4:# (docs/export-format/README.md). The rules themselves are in spec/support/export_format_rules.rb.
spec/image_publishing_spec.rb:5:# workflow runs and podman output (docs/specs/012-ghcr-registry-publishing/verification.md).
spec/image_publishing_spec.rb:13:      expect(rules).to include("/docs", "/spikes", "/spec", "/script", "/.claude", "/CLAUDE.md", "/.githooks",
spec/models/mtg/collector_line_spec.rb:46:  describe "Phase 0's parser inputs (research.md §3)" do
spec/support/export_format_rules.rb:3:# The export format's rules as the suite applies them (spec 017, docs/export-format/README.md): what makes a file
spec/support/export_format_rules.rb:14:  def self.directory = Rails.root.join("docs/export-format")
spec/support/export_format_rules.rb:16:  def self.document = directory.join("README.md").read
```

Also at the head: `git ls-files spec/readme_spec.rb` and `grep readme_spec .rubocop.yml` both print nothing (the one
line removed from `.rubocop.yml` is `- "spec/readme_spec.rb"`). `git diff --stat origin/main...HEAD -- .claude/rules/testing.md`
is `1 insertion(+)`, the file's last line: "✗ Don't check prose documents (`README.md`, `CLAUDE.md`, the files under
`.claude/`, the Markdown and reference files under `docs/`) from RSpec; a document criterion is verified by reading
and recorded in the spec's `verification.md`. The export format's document is the one exception (spec 020, decision 7)."

## The introduction (Story 1)

The paragraph (README lines 3 to 10), unchanged since `28e5bb5`:

> Collector is a self-hostable, multi-tenant web app for tracking collectibles, starting with
> Magic: The Gathering. Each person signs in to their own account and keeps their own collection.
> Cards come from a catalog fed from Scryfall's bulk data (see [Card catalog](#card-catalog)): you
> find a card by searching the catalog, or by reading it with the [card scanner](#card-scanner) on
> a phone, and add it to your collection. An admin manages users and sign-up (see
> [Accounts](#accounts)), starts and watches the catalog's refreshes, and sees, retries and
> discards background jobs. Collector is pre-1.0; the [roadmap](docs/roadmap.md) says what is
> built next.

- First sentence is the one AC-1.1 gives: true.
- Word count of the rendered text (link text, not addresses): 97, one paragraph (limit 130).
- Search for "not built" and "public", case-insensitive: no match. No sentence says accounts, collections, catalog
  search, the scanner or the admin pages are missing.
- "pre-1.0": 1 occurrence. Link to `docs/roadmap.md`: 1; the file exists.
- Roadmap candidates named: none. The roadmap's open items (export and import, typed entry, locations, scanner bulk
  entry, comics, and housekeeping #34, #35, #59, #19, #21, #31, #60, #61, #62, #63, #64) were read against the
  paragraph; it names none of them.
- Its three section links land on existing headings (`## Card catalog`, `### Card scanner`, `### Accounts`).

What it says Collector does, and where (routes from `bin/rails routes -g 'session|registration|collection|catalog|scanner|lots|admin'`):

| It says | README section or route |
|---|---|
| Each person signs in to their own account | `### Accounts`; `GET /session/new` (`sessions#new`), `GET /registration/new` (`registrations#new`) |
| Keeps their own collection | `GET /collection` (`collections#show`) |
| A catalog fed from Scryfall's bulk data | `## Card catalog` |
| Find a card by searching the catalog | `GET /catalog/entries` (`catalog/entries#index`) |
| Add it to your collection | `GET /catalog/entries/:entry_external_key/lots/new` (`lots#new`), `POST /catalog/entries/:entry_external_key/quick_add` (`catalog/quick_adds#create`) |
| Reading it with the card scanner on a phone | `### Card scanner`; `GET /scanner` (`scanners#show`) |
| An admin manages users and sign-up | `### Accounts`; `GET /admin/users` (`admin/users#index`) |
| Starts and watches the catalog's refreshes | `## Card catalog`; `GET /admin/catalog` (`admin/catalogs#show`) |
| Sees, retries and discards background jobs | `## Card catalog` (Jobs page); `GET /admin/jobs` (`admin/jobs#index`) |

## The sweep, by section

Every section was read claim by claim against the repository at `9070ad4` by four checkers, who changed nothing. The
counts are of the README as it was swept. "Corrected" counts the two stale claims with a plain correction and the two
claims corrected by ruling (R1, R2); "Left stale" is the one claim left by ruling (R3). True claims are not listed.

| Section | Claims | Claims checked | Checked against | True | Not refuted | Corrected | Left stale | Not checkable | Off-limits |
|---|---|---|---|---|---|---|---|---|---|
| Text before the first `##` (the "Built with" paragraph; the introduction was rewritten and checked in Phase 1, see above) | 8 | 8 | `Gemfile`, `Gemfile.lock`, `config/importmap.rb`, `config/database.yml`, `config/cable.yml`, `config/cache.yml`, `config/queue.yml`, `config/environments/{development,production,test}.rb`, `Dockerfile`, `bin/fetch-ocr-engine`, `git ls-files` (no `package.json`, no bundler configuration) | 7 | 1 | 0 | 0 | 0 | 0 |
| Requirements | 15 | 15 | `.ruby-version`, `Gemfile`, `spec/support/system.rb`, `lib/collector/libvips_check.rb`, `bin/setup`, `Dockerfile`, `app/models/mtg/art/decoder.rb`, `app/models/mtg/art/build.rb`, ADRs 0012 and 0013, `compose.yaml`, `config/deploy.yml` (no database service or accessory) | 14 | 1 | 0 | 0 | 0 | 0 |
| Development | 13 | 13 | `bin/setup`, `bin/dev`, `bin/jobs`, `config/puma.rb`, `lib/collector/dev_port.rb`, `config/database.yml`, `config/environments/development.rb`, `config/queue.yml`, `config/cable.yml` | 13 | 0 | 0 | 0 | 0 | 0 |
| Worktrees | 44 | 41 | `bin/setup`, `lib/collector/worktree_setup.rb`, `lib/collector/dev_port.rb`, `.githooks/post-checkout`, `.worktreeinclude`, `orca.yaml`, `config/puma.rb`, `.gitignore`, `config/application.rb`, the Rails 8.1.4 gem (`railties` `application/configuration.rb` and `tasks/tmp.rake`, `activesupport` `encrypted_configuration`) | 38 | 3 | 0 | 0 | 3 | 0 |
| Card scanner on a phone (with Measurement mode) | 45 | 39 | `bin/setup`, `bin/fetch-ocr-engine`, `lib/collector/ocr_engine.rb`, `.gitignore`, `bin/dev-certificate`, `lib/collector/dev_certificate.rb`, `lib/collector/dev_port.rb`, `bin/dev`, `config/puma.rb`, `config/environments/development.rb`, `config/application.rb`, `app/views/layouts/_appbar.html.erb`, `app/javascript/controllers/camera_controller.js` and `card_reader_controller.js`, `app/models/scanner/measurement_run.rb`, `app/controllers/concerns/measurement_mode.rb`, `app/controllers/scanner/measurements/{captures,photos}_controller.rb`, `lib/tasks/scanner.rake`, `lib/collector/scanner_findings/sitting_report.rb`, `lib/collector/request_log.rb`, `script/scanner/replay.rb`, `script/scanner/photo_run.rb`; `bin/rails routes -g scanner` and `-g ocr` | 37 | 2 | 0 | 0 | 6 | 0 |
| Testing and CI | 30 | 28 | `bin/rspec`, `bin/ci`, `config/ci.rb`, ActiveSupport 8.1.4 `continuous_integration.rb`, `.github/workflows/ci.yml`, `.github/dependabot.yml`, `spec/requests/health_check_spec.rb`, `spec/rails_helper.rb`, `spec/support/http_stubbing.rb`, `spec/support/system.rb`, `spec/network_isolation_spec.rb`, `spec/cassettes/`, `.rubocop.yml`, `Gemfile`, `docs/releasing.md` (exists) | 27 | 1 | 0 | 0 | 2 | 0 |
| Self-hosting (to `### Docker Compose`) | 16 | 15 | `compose.yaml`, `config/deploy.yml` (image, registry, volume), `Dockerfile`, `.github/workflows/ci.yml` (platforms, tags), `docs/releasing.md`, `config/database.yml`, `app/controllers/concerns/first_run.rb`, `app/models/registration.rb`, `app/controllers/registrations_controller.rb`, `app/models/user/command.rb` | 15 | 0 | 0 | 0 | 1 | 0 |
| Docker Compose | 46 | 41 | `compose.yaml` (each variable, default, port, volume, healthcheck; no `env_file`), `Dockerfile`, `bin/docker-entrypoint`, `config/database.yml`, `lib/collector/currency.rb` (the 20 codes compared by script), `config/initializers/currency.rb`, `app/helpers/lots_helper.rb`, `app/views/lots/_form.html.erb`, `db/schema.rb`, `config/environments/production.rb`, `config/application.rb`, `lib/collector/trusted_proxies.rb`, `lib/tasks/collector.rake`, `app/models/mtg/art.rb`, `config/initializers/art_matching.rb`, `app/models/mtg/scryfall/source.rb`, `config/puma.rb`, `.github/workflows/ci.yml`, `docs/releasing.md`; route `/up` (`health#show`) | 36 | 4 | 1 | 0 | 5 | 0 |
| Kamal | 18 | 9 | `config/deploy.yml` (server, registry, `image`, `env.secret`, `volumes`, `builder.arch`, aliases, `SOLID_QUEUE_IN_PUMA`), `bin/kamal`, `docs/releasing.md` (step 4) | 9 | 0 | 0 | 0 | 7 | 2 |
| Card scanner (under Self-hosting) | 21 | 20 | `config/routes.rb`, `bin/rails routes -g scanner` and `-g ocr`, `app/controllers/ocr_assets_controller.rb`, `lib/collector/ocr_engine.rb`, `Dockerfile`, `.github/workflows/ci.yml`, `app/helpers/scanners_helper.rb`, `app/views/scanners/`, `app/controllers/concerns/scanner_page.rb`, `app/javascript/scanner/{recognition,detector}.js`, `app/javascript/controllers/{card_reader,camera,measurement}_controller.js`, `app/controllers/scanner/{readings,printings}_controller.rb`, `app/controllers/scanner/sittings/`, `app/models/mtg/art/sent.rb`, `config/deploy.yml`, `config/environments/production.rb`, `compose.yaml` | 16 | 3 | 1 | 0 | 1 | 0 |
| Accounts | 17 | 16 | `lib/tasks/collector.rake`, `app/models/user/command.rb`, `app/models/user.rb`, `app/models/registration.rb`, `app/controllers/registrations_controller.rb`, `app/controllers/admin/users_controller.rb`, `app/controllers/admin/sign_up_settings_controller.rb`, `app/views/admin/users/index.html.erb`, `app/views/layouts/_appbar.html.erb`, `app/views/layouts/_tabbar.html.erb`, `app/views/mores/show.html.erb`, `app/assets/stylesheets/collector/components.css`, `compose.yaml` (service `web`); routes `admin/users`, `registration` | 16 | 0 | 0 | 0 | 1 | 0 |
| Upgrading to accounts | 8 | 8 | `app/controllers/concerns/first_run.rb`, `app/models/registration.rb`, `app/models/user/command.rb`, `db/migrate/20260930000003_create_accounts_users_sessions.rb`, `bin/docker-entrypoint`, `Dockerfile` (CMD), `config/deploy.yml`, `docs/releasing.md` | 8 | 0 | 0 | 0 | 0 | 0 |
| Card catalog | 78 | 72 | `lib/tasks/catalog.rake`, `config/deploy.yml` (aliases), `compose.yaml`, `config/recurring.yml`, `config/puma.rb`, `config/application.rb`, solid_queue 1.7.0 (`engine.rb`, `recurring_task.rb`), `app/jobs/catalog/refresh_job.rb`, `app/models/catalog/{refresh,refresh_run,refresh_operation,operation,health}.rb`, `app/models/background_jobs/list.rb`, `app/models/mtg/scryfall/{source,client}.rb`, `app/models/mtg/art.rb`, `app/models/mtg/art/{build,operation}.rb`, `config/initializers/art_matching.rb`, `app/controllers/concerns/admin_only.rb`, `app/controllers/admin/` (catalogs, operation starts, jobs, retries, discards), views `admin/catalogs/*`, `admin/jobs/show`, `layouts/_appbar`, `layouts/_tabbar`, `mores/show`, `catalog/_not_loaded`, `catalog/entries/index`, `scanners/show`, `app/javascript/controllers/poll_controller.js`; `bin/rails routes -g admin` and `-g catalog`; spec 015 line 25 | 63 | 6 | 2 | 1 | 6 | 0 |
| Your data | 11 | 11 | `docs/export-format/README.md`, `docs/export-format/v1.schema.json`, `docs/export-format/examples/`, ADR 0020; `bin/rails routes -g 'export\|import'` (no routes) | 9 | 2 | 0 | 0 | 0 | 0 |
| License | 2 | 2 | `LICENSE` | 2 | 0 | 0 | 0 | 0 | 0 |
| **Total** | **372** | **338** | | **310** | **23** | **4** | **1** | **32** | **2** |

The arithmetic holds in every row and in the totals: Claims = Claims checked + Not checkable + Off-limits (372 = 338 +
32 + 2), and Claims checked = True + Not refuted + Corrected + Left stale (338 = 310 + 23 + 4 + 1).

A note on the counts: the Docker Compose row counts the `COLLECTOR_PASSWORD` table row as swept: one claim corrected
(R2, the row's place in the table) and one not refuted ("never stored in logs"). R2 removed the row, so that
not-refuted claim is no longer in the README; the Not refuted list below has the other three Docker Compose claims
and a note.

## Corrections

| # | File and line | Old text | New text | Evidence | Searched in `CLAUDE.md` for | Result |
|---|---|---|---|---|---|---|
| 1 | `README.md` line 118 (Phase 2, `decacc3`) | `bin/rspec spec/requests/home_spec.rb:5` | `bin/rspec spec/requests/health_check_spec.rb:5` (the padding before the `#` comment on this line and on line 117 grew to keep the comments aligned) | `spec/requests/home_spec.rb` is not tracked; `spec/requests/health_check_spec.rb` line 5 is inside the example that begins on line 4; the command run as written gives `1 example, 0 failures` | `home_spec.rb` | Repeated in the Commands list; corrected (row 2) |
| 2 | `CLAUDE.md` line 20 (Phase 2, `decacc3`) | `bin/rspec spec/requests/home_spec.rb:5` | `bin/rspec spec/requests/health_check_spec.rb:5` | As row 1 | n/a (the repeat itself) | `grep -c home_spec README.md CLAUDE.md`: 0 in each |
| 3 | `CLAUDE.md` line 7, Project Status (Phase 2, `9070ad4`) | "and a public card search proof-of-concept at `/catalog/entries`." | "and a card search at `/catalog/entries`, which has needed sign-in since accounts (spec 004)." | `Catalog::EntriesController` inherits `ApplicationController`, which includes `Authentication` (`before_action :require_authentication`), and does not call `allow_unauthenticated_access` | n/a (spec decision 4) | The sentence is otherwise as at the merge base |
| 4 | `README.md` line 289, Card catalog, **Schedule** (`58fa06b`) | "on Mondays at 03:15 server time" | "on Mondays at 03:15 UTC" | `config/recurring.yml` has `schedule: every monday at 3:15am` with no zone; `config/application.rb:38` leaves `config.time_zone` commented out, so Rails' default `"UTC"` applies; solid_queue 1.7.0 `lib/solid_queue/engine.rb:19-21` sets `SolidQueue.time_zone = app.config.time_zone`, and `app/models/solid_queue/recurring_task.rb:182-184` applies it to a schedule with no zone | `server time`; `03:15` | Not repeated (no match for either) |
| 5 | `README.md` line 263, Card catalog (`ef46056`) | "Nothing downloads until you start it," (the changed words: "until you start it,") | "Nothing downloads until you start it or the weekly schedule first runs," (the line was not re-wrapped and runs past the wrap column) | `config/recurring.yml:16-20` queues `Catalog::RefreshJob` with `[ "mtg", "scheduled" ]` every Monday in production; `app/models/catalog/refresh.rb:27` and `:53-54` skip a scheduled run only when the same version and languages were already applied, so on an empty catalog the first scheduled run downloads and applies it | `Nothing downloads` | Not repeated (no match) |
| 6 | `README.md` line 220, Self-hosting → Card scanner (`e2155b2`; ruling R1) | "only the text read from the card and your add, Undo and printing choices are sent to your instance." | "only the text read from the card (and, with art matching on, the ids of the closest artworks) and your add, Undo and printing choices are sent to your instance." | `app/javascript/controllers/card_reader_controller.js:163-174` (sends the text, the reading key and a live capture's nearest artworks, "never the outline, timings or a fingerprint"); `app/models/mtg/art/sent.rb:1-3` (up to 10 artwork ids with distances, nil unless `MTG::Art.enabled?`); `app/controllers/scanner/readings_controller.rb:2-4` | `sent to your instance`; `Photos never leave` | Not repeated (no match for either) |
| 7 | `README.md`, Docker Compose variable table: the row that was line 164 at `9070ad4`, after the `COLLECTOR_TRUSTED_PROXIES` row (now line 163) (`63703d2`; ruling R2) | ``\| `COLLECTOR_PASSWORD` \| no \| none \| Password for the user command below; never stored in logs \|`` | (row removed) | `compose.yaml:16-23` passes eight variables to the container and has no `COLLECTOR_PASSWORD` and no `env_file:`; `lib/tasks/collector.rake:3` reads `ENV["COLLECTOR_PASSWORD"]` in the process that runs the task, which it reaches only through `docker compose exec -e COLLECTOR_PASSWORD='…'`, as the Accounts section shows (lines 237 and 241, unchanged) | `COLLECTOR_PASSWORD` | Not repeated (no match) |

The removed row's clause "never stored in logs" went with the row. It had been checked and not refuted
(`lib/tasks/collector.rake` prints a password only when it generated one, to stdout; `app/models/user/command.rb`
does no logging). No other row of the table changed and none was re-aligned.

`CLAUDE.md` was not changed by any of rows 4 to 7.

## Not refuted

| README line | Claim | Checked against |
|---|---|---|
| 12-13 | "no Node.js" | `git ls-files` has no `package.json`, lockfile or bundler configuration; `Gemfile` has no jsbundling, cssbundling, tailwind or execjs gem; `Dockerfile` and `bin/setup` never mention node, npm or yarn; `bin/fetch-ocr-engine` names `registry.npmjs.org` only as a download host; `config/importmap.rb` pins only local files |
| 19 | "no separate database server is needed" | `config/database.yml` (every environment uses `sqlite3`); `compose.yaml` (one `web` service); `config/deploy.yml` (`accessories:` is only a commented example) |
| 57 | "Existing files are never overwritten." | `lib/collector/worktree_setup.rb` `copy_included_files` (`next if File.exist?(destination)` before any copy); `copy_secret` writes a `.partial` file and renames it only for a destination that did not exist at that check |
| 60 | "Nothing is shared between worktrees." (of the databases, caches, logs and pids the bullet lists) | `config/database.yml` (paths relative to each worktree), `.gitignore` (`/log/*`, `/tmp/pids/*`). Shared, but not in this bullet's list: `core.hooksPath` (the README says so), the development certificate directory and `~/card-scanner-corpus` |
| 66 | "A missing key only warns" | `lib/collector/worktree_setup.rb` `missing_warning`, after which `bin/setup` goes on; Rails 8.1.4 returns empty credentials when the key is missing and falls back to `tmp/local_secret.txt` in development and test (`railties` `application/configuration.rb:523-533`); `config/environments/production.rb` has no `require_master_key`. Read as being about worktree setup and development |
| 94 | "Only the certificate is ever served; the key never leaves your machine." | `lib/collector/dev_certificate.rb:39-56` (`serve` reads only the certificate path); `bin/dev-certificate:36-44` passes only the certificate to `serve` |
| 97 | "Puma ends TLS itself, so Rails sees real HTTPS and needs no other setting." | `config/environments/development.rb:100` (`assume_ssl` only from `COLLECTOR_HTTPS`; no `force_ssl`, no `config.hosts` line), `config/application.rb`, `bin/dev`, `config/puma.rb` |
| 123 | "WebMock and VCR block all real HTTP from specs" | `spec/support/http_stubbing.rb` (`WebMock.disable_net_connect!(allow_localhost: true)`, `config.ignore_localhost = true`); `spec/network_isolation_spec.rb`. Localhost is allowed because the system specs' browser needs it; the maintainer reads "real HTTP" as traffic leaving the machine (ruling R4) |
| 151 | "needs no checkout: download the file and start it" | `compose.yaml`: one service from `image:`, no `build:`, no bind mount, no `env_file:`, only the named volume |
| 165 | "Changing `COLLECTOR_CURRENCY` later doesn't convert prices you've already entered; they're shown with the new symbol" | `db/schema.rb:144` (`price_paid_cents` is the only price column; no currency column on `lots`), `app/helpers/lots_helper.rb:16`, `app/views/lots/_form.html.erb:26-27`, `git grep x.currency` (no conversion code) |
| 185 | "Solid Queue runs inside the web process; no separate worker is needed" | `compose.yaml` (one service, `SOLID_QUEUE_IN_PUMA: "true"`), `config/puma.rb:41` |
| 219 | "Photos never leave the phone" | Every `fetch` and `FormData` in `app/javascript/controllers/*.js` and `app/javascript/scanner/*.js`; `app/controllers/scanner/readings_controller.rb`, `scanner/sittings/entries_controller.rb`, `undos_controller.rb`, `printings_controller.rb`, `endings_controller.rb` (ids and short strings only); the one file input is read on the device (`card_reader_controller.js:124`). Measurement mode, which stores strip images and can keep frames, is off outside development (`config/application.rb:52`, `app/controllers/concerns/measurement_mode.rb:11-13`) and the README's measurement paragraph says what it stores |
| 222 | "so phones fetch it from you, not from a third party" | `app/views/scanners/_head.html.erb:5`, `app/helpers/scanners_helper.rb:20`, `app/javascript/scanner/recognition.js:8-10`, the scanner pages' Content-Security-Policy in `app/controllers/concerns/scanner_page.rb` (`script_src :self`, `worker_src :self, :blob`, `connect_src :self`) |
| 225 | "that is the only part that needs it" (HTTPS) | `app/javascript/controllers/camera_controller.js:37` is the only secure-context check in the app's JavaScript; `card_reader_controller.js:216-218` uses `crypto.getRandomValues`, which works without one |
| 256-257 | "Pages are rendered only from that local copy" | `git grep` for `Scryfall::Client`, `Net::HTTP` and `scryfall` over `app/controllers`, `app/views`, `app/helpers`, `app/jobs`, `app/models`, `lib`, `config`: `MTG::Scryfall::Client` is built only in `MTG::Scryfall::Source#initialize` and `MTG::Art::Build#initialize`; the one view link to Scryfall is a hyperlink (`catalog/entries/show.html.erb:34-37`) |
| 257 | "the app never calls Scryfall while rendering a page" | The same reading; `Catalog::Health#languages` builds a `Source` but only reads the environment, and `Client` makes no request in `initialize` |
| 287 | "Both pages are for admins only." | `app/controllers/concerns/admin_only.rb`, included by all five controllers of the two pages; `bin/rails routes -g admin` (no other `/admin/catalog` or `/admin/jobs` route); the menu links are inside `if Current.user.admin?` |
| 291 | "a manual run always applies" | `app/models/catalog/refresh.rb` (`already_applied?` is `@trigger == "scheduled" && …`) |
| 291-292 | "Only one refresh per collectible type runs at a time." | `app/jobs/catalog/refresh_job.rb` (`limits_concurrency to: 1` keyed by collectible type), `app/models/catalog/refresh_run.rb` `start!` (a second attempt is recorded as skipped, "already running") |
| 294-295 | "English is always included" | `app/models/mtg/scryfall/source.rb` `languages`: `(requested \| [ "en" ]).sort` |
| 319-320 | "keyed by the catalog source's own ids and never by this instance's" | `docs/export-format/README.md:20` and its Entry, Profile and Lots tables; `docs/export-format/v1.schema.json` |
| 322-323 | "neither is in the app yet" (exporting and importing) | `bin/rails routes -g 'export\|import'` (no routes); `git grep -i export` over `config/routes.rb`, `app`, `lib`, `config`, `bin` finds only JavaScript `export` keywords and a comment about import maps |

22 rows. The 23rd not-refuted claim, "never stored in logs", was in the `COLLECTOR_PASSWORD` table row that ruling R2
removed (Corrections, row 7); it is the only claim counted as not refuted that is no longer in the README.

## Not checkable

| README line | Claim | Reason |
|---|---|---|
| 46 | "This covers … `claude --worktree`" | What Claude Code does when it makes a worktree is another tool's behaviour (the hook that runs `bin/setup --skip-server` for a new linked worktree is checked and true) |
| 46 | "and Orca worktrees (local or remote)" | Orca's behaviour (`orca.yaml`'s setup script is checked and true) |
| 64 | "a remote Orca runtime has no copy of your local `config/master.key`" | A fact about another machine's contents |
| 73 | "(about 15 MB)" | A download size; the code pins digests, not sizes |
| 76 | "Browsers only allow a live camera on HTTPS (or on `localhost`)" | Browser behaviour |
| 88 | "allow the profile" (Safari, after opening the URL; the URL is checked) | iPhone and Safari behaviour |
| 89 | "Settings → General → VPN & Device Management: install the profile." | iPhone Settings steps |
| 90 | "Settings → General → About → Certificate Trust Settings: turn on full trust for the certificate." | iPhone Settings steps |
| 96 | "which the phone must trust again" | Device behaviour (that a new certificate is made is checked and true) |
| 121-122 | "on the first run Selenium Manager downloads geckodriver" | Behaviour of Selenium Manager |
| 122 | "which needs network access" | A fact about that download, not the repository |
| 142 | "Both run the published image `ghcr.io/plainprogrammer/collector`" (that the image is published and can be pulled) | The state of a registry (the name and the two architectures are checked and true) |
| 151 | "`compose.yaml` works with both `docker compose` and `podman compose`" | Behaviour of two other tools |
| 170 | `openssl rand -hex 64` | Another tool's behaviour |
| 172 | `ruby -rsecurerandom -e 'puts SecureRandom.hex(64)'` | Ruby standard library behaviour |
| 175 | "Set the variables in your shell or in a `.env` file next to `compose.yaml`" (that Compose reads them from there) | Compose's behaviour; the `.env` file is not in the repository |
| 178 | `docker compose up -d     # or: podman compose up -d` | Other tools' commands; the file they read is `compose.yaml` |
| 195 | "deploys the same image to servers you control over SSH" (the SSH part) | Kamal's behaviour (`bin/kamal` and the image name are checked and true) |
| 200-201 | "Kamal needs registry credentials even to pull a public image" | Kamal's behaviour (`config/deploy.yml:35-36` says the same in a comment, but the rule is the tool's) |
| 201 | "use a GitHub token with `read:packages`" | GitHub's behaviour (which token scope lets a registry pull succeed) |
| 202 | "Check the configuration with `bin/kamal config`" | Kamal's own subcommand (`bin/kamal` exists) |
| 203 | "`bin/kamal setup --skip-push --version X.Y.Z` for the first deployment" | Kamal's own subcommand and flags |
| 204-205 | "Kamal pulls that tag; nothing is built or pushed" | Kamal's behaviour |
| 209-210 | "it would push a single-architecture `latest` over the published image" (that a plain `bin/kamal deploy` pushes `latest`) | Kamal's behaviour (the registry name and the single `builder.arch` are checked and true) |
| 225 | "Browsers only allow a live camera on HTTPS" | Browser behaviour (the second half of the sentence is under Not refuted) |
| 242 | `bin/kamal app exec -i "bin/rails 'collector:user[you@example.com]'"` | Kamal's own subcommand and flag (the task it runs is checked and true) |
| 269 | "(or podman compose)" | Another tool's behaviour (the service `web` and the task are checked and true) |
| 300 | "about 708 MB of downloads" | A download size the documents repeat |
| 301 | "about 2.6 hours of throttled fetching" | A duration |
| 301-302 | "an index of about 7.3 MB" | A size |
| 310 | "(about 80 MB each)" | A download size |
| 311 | "(about 400 MB each)" | A download size |

32 rows, the 32 counted.

## Off-limits

| README line | Claim | File |
|---|---|---|
| 199 | "Secrets come from `.kamal/secrets`, which reads `RAILS_MASTER_KEY` from `config/master.key`" | `.kamal/secrets`, `config/master.key` (what `config/deploy.yml` names is true: `env.secret: - RAILS_MASTER_KEY`) |
| 200 | "and the registry password from the `KAMAL_REGISTRY_PASSWORD` environment variable" | `.kamal/secrets` (`config/deploy.yml:38` names the variable under `registry.password`) |

Neither file was read, searched, listed or tested for by any step of this work.

## Questions and rulings

Put to the maintainer in one message when the sweep was done; ruled on 2026-10-12.

| Claim | Evidence | Recommendation | Ruling |
|---|---|---|---|
| **R1.** Card scanner (Self-hosting): "only the text read from the card and your add, Undo and printing choices are sent to your instance." | `card_reader_controller.js:163-174` also sends a random reading key and, with art matching on and for live captures, the ids and distances of the nearest artworks; `app/models/mtg/art/sent.rb:1-3`; `app/controllers/scanner/readings_controller.rb:2-4`. No photo, image or fingerprint is sent | Add the artwork clause: the sentence is a privacy statement and says "only". The reading key is a random id and need not be named | Add the artwork clause. Corrected (Corrections, row 6) |
| **R2.** Docker Compose variable table: the `COLLECTOR_PASSWORD` row | `compose.yaml:16-23` does not pass the variable and has no `env_file:`, so setting it in the shell or in `.env` does nothing; `lib/tasks/collector.rake:3` reads it in the process that runs the task. The row's place in a table of variables Compose passes on is what misleads | The checker recommended rewording the row's Purpose; deleting the row was the second option | Delete the row. Corrected (Corrections, row 7). The Accounts section still documents the variable |
| **R3.** Card catalog, **Catalog page**: "A refresh that stops making progress for 15 minutes is shown as interrupted (after a restart, for example); pressing **Refresh now** then starts it again." | `Catalog::RefreshRun::STALL_AFTER = 15.minutes` is right. `RefreshRun#status_label` shows "interrupted" only when no worker still holds the job; while one does, the page says "Running, no progress for N minutes" and **Refresh now** stays disabled (`Catalog::RefreshOperation#running_state`) | Leave it: the parenthesis names the case where the job died | Leave it as it is. "(after a restart, for example)" already implies the job died. Listed under Left stale |
| **R4.** Testing and CI: "WebMock and VCR block all real HTTP from specs" | `spec/support/http_stubbing.rb` has `WebMock.disable_net_connect!(allow_localhost: true)`; localhost is allowed because the system specs' browser needs it | Leave it | Leave it. The maintainer reads "real HTTP" as traffic leaving the machine. Listed under Not refuted, with the exception noted |

## Left stale

| README line | Claim | Evidence it is stale | Reason (spec or ADR, or the maintainer's ruling) |
|---|---|---|---|
| 282-284 | "A refresh that stops making progress for 15 minutes is shown as interrupted (after a restart, for example); pressing **Refresh now** then starts it again." | True only for a stalled run whose job no worker holds. While a worker still holds it, `Catalog::RefreshRun#status_label` gives "running (no progress for N minutes)" and `Catalog::RefreshOperation#running_state` returns `:stalled`, which keeps **Refresh now** disabled | Maintainer's ruling R3 (2026-10-12): leave it; "(after a restart, for example)" already implies the job died |

No claim was left stale because the code is what's wrong.

## Gaps

Noticed while checking claims; no reverse sweep was made. Nothing here was added to the README, no issue was opened
and `docs/roadmap.md` is unchanged.

- **There is no "Using Collector" section.** The README has never described the collection page, adding a card, or
  lots.
- Requirements says ImageMagick is "for the card scanner's art index build"; the art matching specs need it too
  (`bin/setup` says so). Testing and CI doesn't say which specs need ImageMagick or the OCR engine.
- Testing and CI doesn't say that the hosted workflow installs `libvips` and `imagemagick` before `bin/ci`, so a
  local `bin/ci` needs them too.
- Worktrees says nothing about `vendor/ocr/`: it is ignored by git, so `bin/setup` fetches the OCR engine again in
  every worktree.
- Neither scanner section said that art matching changes what the scanner sends. Ruling R1 now covers what is sent;
  the setting itself is still described only under Card catalog.
- Measurement mode doesn't say that `COLLECTOR_SCANNER_KEEP_FRAMES=1` also keeps each live capture's full frame
  (`config/environments/development.rb:89`).
- Neither scanner section says what the page shows when the OCR engine isn't installed.
- Accounts doesn't say that sign-up closes itself once the first account exists (`app/models/registration.rb`,
  `app/models/user/command.rb`), so a second person can't sign up until the admin opens it.
- The user command's password must be at least 12 characters (`User::PASSWORD_MINIMUM`); the README gives no length.
- The Kamal section doesn't mention the optional settings (`COLLECTOR_CURRENCY`, `COLLECTOR_MTG_LANGUAGES`,
  `COLLECTOR_MTG_ART_MATCHING`, `COLLECTOR_TRUSTED_PROXIES`); they exist only as commented lines in
  `config/deploy.yml`, whose line 55 points to the README's currency list in the Compose table.
- Nothing says which variables Compose passes to the container and which it doesn't. (With the `COLLECTOR_PASSWORD`
  row removed by R2, every row left in the table is a variable `compose.yaml` reads.)
- The first-run warning in Self-hosting is the only place that says the protection applies to a Compose or Kamal
  first start.
- The **Jobs page** bullet gives only the path `/admin/jobs`; it doesn't say the page is in the account menu, under
  More on a phone, and behind a "Jobs" button on the Catalog page.
- The Catalog page shows "Not scheduled" for the next refresh outside production; the README says the schedule is
  for production but not what a developer sees.
- An unsupported `COLLECTOR_MTG_LANGUAGES` code "fails the refresh"; the README doesn't say the reason is shown in
  `catalog:status` and on the Catalog page.
- About `CLAUDE.md`, outside the sweep's scope: its Project Status still says "The Rails app skeleton exists (stack,
  RSpec, `bin/ci`, Compose and Kamal deployment)". True; not changed (spec decision 4).

## Differing names

- **"avatar menu"** (Accounts, line 235) and **"account menu"** (Card catalog, line 260) name one menu. The view
  (`app/views/layouts/_appbar.html.erb:20-22`) is a `<details class="c-menu">` whose
  `<summary class="c-avatar" aria-label="Account: …">` has no visible name, so both fit. Neither was changed.

Checked and found consistent: "More" (the phone tab and the page title) and "Scan" (the navigation label).

## Safety warnings

`diff` of the six warning lines at the merge base against the same six at the head prints nothing (the command is in
the plan, Phase 3). Line numbers moved by +3 (the introduction grew from four lines to seven) and, below the Compose
variable table, by −1 (the removed row). None of the three warnings is stale (the checker read each against the code).

| Warning | Line at merge base | Line at HEAD | Text unchanged | Position unchanged |
|---|---|---|---|---|
| "Before you expose Collector: the first person to reach a new or freshly upgraded instance becomes its admin." (Self-hosting) | 144 | 147 | yes | yes: the blockquote before `### Docker Compose` (146, now 149) |
| "Read this before you upgrade. … the first person to reach it becomes its admin." (Upgrading to accounts) | 245 | 247 | yes | yes: before "1. Pull the new image" (247, now 249) |
| "Signing in over plain HTTP sends your password unencrypted, which is only acceptable on a trusted private network." (the **HTTPS** bullet) | 189 | 191 | yes | yes: the last bullet before `### Kamal` (191, now 193) |
| "Never run a plain `bin/kamal deploy` with the registry set to `ghcr.io/plainprogrammer/collector`: it would push a single-architecture `latest` over the published image." | 206-208 | 208-210 | yes | yes: between Kamal's step 4 (201, now 203) and "Data is stored in" (210, now 212) |

## Diff checks

**Mechanical checks, over the whole README at the head:**

- Scripts: every `bin/` name exists (`brakeman`, `bundler-audit`, `ci`, `dev`, `dev-certificate`, `fetch-ocr-engine`,
  `importmap`, `jobs`, `kamal`, `rails`, `rspec`, `rubocop`, `setup`); the check printed nothing.
- Rake tasks: `bin/rails -AT` lists `catalog:refresh[collectible_type]`, `catalog:status[collectible_type]`,
  `collector:user[email]`, `scanner:findings` and `scanner:sitting_findings` (five lines).
- Kamal subcommands: `app`, `config`, `deploy`, `setup` are Kamal's own; `catalog-refresh` and `catalog-status` are
  keys under `aliases:` in `config/deploy.yml` (lines 84 and 85).
- Environment variables: each of the 22 names the pattern finds, and `PORT`, has a tracked reader or namer outside
  the documents and specs: `COLLECTOR_CURRENCY`, `COLLECTOR_DEV_CERT_DIR`, `COLLECTOR_HTTPS`, `COLLECTOR_IMAGE`,
  `COLLECTOR_MTG_ART_MATCHING`, `COLLECTOR_MTG_LANGUAGES`, `COLLECTOR_PASSWORD` (`lib/tasks/collector.rake`),
  `COLLECTOR_PORT`, `COLLECTOR_REQUEST_LOG`, `COLLECTOR_SCANNER_MANIFEST`, `COLLECTOR_SCANNER_RUN_DIR`,
  `COLLECTOR_TRUSTED_PROXIES`, `GROUND_TRUTH`, `ORCA_ROOT_PATH`, `SCANNER_EMAIL`, `SCANNER_PASSWORD`, `SCANNER_URL`,
  `SOLID_QUEUE_IN_PUMA`, `PORT` (`config/puma.rb`, `lib/collector/dev_port.rb`). Named in the repository and read by
  a framework or tool: `SECRET_KEY_BASE` (`compose.yaml`; Rails), `RAILS_MASTER_KEY` (`config/deploy.yml`,
  `Dockerfile`; Rails), `RAILS_DEVELOPMENT_HOSTS` (`config/environments/development.rb`; Rails),
  `KAMAL_REGISTRY_PASSWORD` (named only in `config/deploy.yml`; Kamal, and its reader is off-limits). `HOME` has no
  reader in the repository: the shell expands it. Every lookup excluded `.kamal/secrets`.
- Paths: every repository path in backticks exists (`.ruby-version`, `.worktreeinclude`, `.githooks/`,
  `.github/workflows/ci.yml`, `orca.yaml`, `compose.yaml`, `config/ci.rb`, `config/deploy.yml`,
  `config/recurring.yml`, `docs/releasing.md`, `spec/cassettes` and the `bin/` scripts). Run-time paths were checked
  against the code that writes them, not by looking: `storage/` and `storage/catalog/mtg/` and
  `storage/catalog/mtg/art` (`config/application.rb:45`, `app/models/mtg/scryfall/source.rb`,
  `app/models/mtg/art.rb`), `log/requests.jsonl` (`config/environments/development.rb:95`), `tmp/setup.lock` and
  `tmp/local_secret.txt` (`lib/collector/worktree_setup.rb:11` and `:15`), `vendor/ocr/`
  (`lib/collector/ocr_engine.rb:20`), `~/.local/share/collector-dev-https/` (`lib/collector/dev_certificate.rb`),
  `~/card-scanner-corpus/…` (`config/environments/development.rb`). `.kamal/secrets`, `config/master.key` and `.env`
  are off-limits and were not tested for.
- Routes: `/scanner` (`scanners#show`), `/scanner/measurement` (`scanner/measurements#show`), `/admin/catalog`
  (`admin/catalogs#show`), `/admin/jobs` (`admin/jobs#index`), `/up` (`health#show`). `/ocr/v7.0.0/` is served by
  `ocr_asset GET /ocr/:version/*path ocr_assets#show`, and `v7.0.0` is `Collector::OcrEngine::VERSION`. The README no
  longer names `/catalog/entries` (the introduction's rewrite removed it); the route exists
  (`catalog/entries#index`).
- Links: all eight are `ok` (`#card-catalog`, `#card-scanner`, `#accounts`, `docs/roadmap.md`, `#self-hosting`,
  `https://scryfall.com`, `docs/export-format/README.md`, `LICENSE`).

**`git diff --word-diff origin/main...HEAD -- README.md`**, every changed word outside the introduction:

```
bin/rspec [-spec/requests/home_spec.rb:5-]{+spec/requests/health_check_spec.rb:5+}  # a single file or example
[-| `COLLECTOR_PASSWORD`        | no       | none                  | Password for the user command below; never stored in logs  … |-]
only the text read from the card {+(and, with art matching on, the ids of the closest artworks)+} and your add, Undo and printing choices are sent to your instance.
until you start [-it,-]{+it or the weekly schedule first runs,+} so set the languages below first if you want more than English.
- **Schedule:** in production the catalog refreshes weekly, on Mondays at 03:15 [-server time-]{+UTC+}
```

These are Corrections rows 1, 7, 6, 5 and 4. The plain diff has six hunks: the introduction (lines 4 to 10), the two
command lines 117 and 118 (118 is row 1; 117 changed only in the padding before its `#` comment, the allowed
exception), the removed table row (row 7), line 220 (row 6), line 263 (row 5) and line 289 (row 4). No other line
changed, no paragraph was re-wrapped and no other table row was re-aligned.

**Headings:** the comparison of the headings outside fenced code at the merge base and at the head prints nothing:
the same 15 headings in the same order.

**`git diff --word-diff origin/main...HEAD -- CLAUDE.md`**, every changed word:

```
[-public-] [-proof-of-concept-] [-`/catalog/entries`.-]{+`/catalog/entries`, which has needed sign-in since accounts (spec 004).+}
[-spec/requests/home_spec.rb:5`-]{+spec/requests/health_check_spec.rb:5`+}
```

The first is the Project Status sentence (Corrections, row 3); the second is the repeat of the single-spec example
(row 2). `CLAUDE.md` is unchanged since `9070ad4`.

**The lists:** the lines changed in `git diff origin/main...HEAD -- README.md` are 4 to 10, 117, 118, 220, 263 and
289 at the head, plus the removed row. No line of a claim in the Not refuted, Not checkable or Off-limits lists is
among them (the nearest are 219, "Photos never leave the phone", and 256-257). The one listed claim that changed is
the removed row's "never stored in logs", noted under Not refuted.

## `bin/ci`

Run at `63703d2` on 2026-10-12, after `git fetch origin`; exit status 0.

```
✅ Setup passed in 6.07s
✅ Style: Ruby passed in 1.75s                          (460 files inspected, no offenses detected)
✅ Security: Brakeman code analysis passed in 6.53s     (No warnings found)
✅ Security: Gem audit passed in 0.77s                  (No vulnerabilities found)
✅ Security: Importmap vulnerability audit passed in 1.81s (No vulnerable packages found)
✅ Tests: RSpec passed in 3m10.24s                      (1206 examples, 0 failures, 1 pending; seed 44272)
✅ Continuous Integration passed in 3m27.18s
```

The one pending example is `spec/system/art_agreement_spec.rb:16`, which needs `COLLECTOR_ART_AGREEMENT` set, as at
the baseline.

`git diff --name-status origin/main...HEAD`, before the record's commit:

```
M	.claude/memory/MEMORY.md
A	.claude/memory/no-readme-wording-specs.md
M	.claude/memory/plan-reviews-run-the-code.md
M	.claude/memory/sdd-review-model-choice.md
M	.claude/rules/testing.md
M	.rubocop.yml
M	CLAUDE.md
M	README.md
A	docs/specs/020-readme-introduction/plan.md
A	docs/specs/020-readme-introduction/spec.md
M	spec/design_system_files_spec.rb
M	spec/export_format_document_spec.rb
M	spec/image_publishing_spec.rb
D	spec/readme_spec.rb
```

Only the expected files; `docs/roadmap.md` is not listed.

## Acceptance criteria

| AC | Evidence | Result |
|---|---|---|
| AC-1.1 | The introduction: first sentence compared, true | pass |
| AC-1.2 | The introduction: "Each person signs in to their own account and keeps their own collection." | pass |
| AC-1.3 | The introduction: "a catalog fed from Scryfall's bulk data"; "by searching the catalog, or by reading it with the card scanner on a phone, and add it to your collection" | pass |
| AC-1.4 | The introduction: "An admin manages users and sign-up …, starts and watches the catalog's refreshes, and sees, retries and discards background jobs." | pass |
| AC-1.5 | The introduction: search for "not built" and "public" finds nothing; read-through | pass |
| AC-1.6 | The introduction: "pre-1.0" once, one link to `docs/roadmap.md`, no roadmap candidate named | pass |
| AC-1.7 | The introduction: one paragraph, 97 words | pass |
| AC-1.8 | The introduction: the table of sections and routes | pass |
| AC-2.1 | The sweep, by section; Corrections; Left stale (one claim, by ruling R3) | pass, on the four checkers' findings |
| AC-2.2 | Diff checks (scripts, rake tasks, Kamal subcommands); the sweep (arguments, the two `script/scanner/` files); Corrections row 1 (`:5` is inside an example) | pass |
| AC-2.3 | Diff checks (paths, routes) | pass |
| AC-2.4 | Diff checks (environment variables); defaults and accepted values in the sweep (Docker Compose, Card catalog, Card scanner on a phone) | pass |
| AC-2.5 | Corrections row 1; README line 118 | pass |
| AC-2.6 | Diff checks (links): eight `ok` | pass |
| AC-2.7 | Diff checks (the word diff and the plain diff of `README.md`) | pass |
| AC-2.8 | Diff checks (headings): no output | pass |
| AC-2.9 | Corrections rows 2 and 3; Diff checks (the word diff of `CLAUDE.md`); the exact sentence is present once | pass |
| AC-2.10 | Corrections row 2; `CLAUDE.md` line 20 | pass |
| AC-3.1 | The sweep, by section: 15 rows, each with its count and what it was checked against | pass |
| AC-3.2 | Corrections: seven rows, each with old text, new text, evidence, and for the README rows the term and the result | pass |
| AC-3.3 | Not refuted, Not checkable, Off-limits; Diff checks (the lists) | pass: 22 not refuted, 32 not checkable and 2 off-limits claims are listed, and none of their lines changed. The 23rd not-refuted claim, "never stored in logs", went with the row R2 removed (noted under Not refuted) |
| AC-3.4 | Gaps (with the missing "Using Collector" section); Differing names ("avatar menu", "account menu"); `docs/roadmap.md` is not in `git diff --name-status`; no issue was opened | pass |
| AC-3.5 | Left stale: one row, with the evidence and ruling R3 | pass |
| AC-3.6 | `bin/ci` | pass at `63703d2` (the head before the record's commit, which adds only this file) |
| AC-3.7 | The PR description | pending: PR not opened |
| AC-3.8 | Safety warnings: four rows, text and position unchanged | pass |
| AC-4.1 | The suite: `git ls-files spec/readme_spec.rb` and `grep readme_spec .rubocop.yml` print nothing | pass |
| AC-4.2 | The suite: `22 examples, 0 failures`; the two fail-first outputs | pass |
| AC-4.3 | The suite: `4 examples, 0 failures`; the first example's new name | pass |
| AC-4.4 | The suite: `25 examples, 0 failures`; `spec/export_format_examples_spec.rb` is not in the diff | pass |
| AC-4.5 | The suite: the `--name-status` list of `spec`; 1219 becomes 1206 | pass |
| AC-4.6 | The suite: the `grep` output, eight lines, all of them the ones the criterion names | pass |
| AC-4.7 | The suite: one inserted line, the last of `.claude/rules/testing.md` | pass |
