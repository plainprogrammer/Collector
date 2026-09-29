# Implementation Plan: Rails Application Skeleton

**Spec:** docs/specs/001-rails-app-skeleton/spec.md
**Decisions:** none (stack fixed by `.claude/memory/steering/tech-stack.md`)
**Created:** 2026-09-29

## Context

Collector has a foundation and rules but no application. Spec 001 (approved) asks for a runnable Rails 8 skeleton with RSpec, the full quality toolchain, `bin/ci` as the single CI gate (local + GitHub Actions), and verified Docker Compose + Kamal self-hosting paths. The user wants **one small Conventional Commit per step**.

Environment facts (checked): Ruby 4.0.7 (system, gems install to `~/.local/share/gem/ruby`), Rails latest = 8.1.4 (requires Ruby ≥ 3.2), `ruby:4.0.7-slim` image exists, Podman 5.8.7 (no Docker, no compose provider), Firefox installed (no Chrome), `ruby-devel`/`libyaml-devel`/`redhat-rpm-config` missing.

Decisions made during planning (user-approved): development mirrors production (Solid Queue/Cache/Cable on separate SQLite DBs; test keeps defaults) → **AC-1.1 amended via sdd-spec-update**; containers verified with **podman + podman-compose** (files stay Docker-standard); system specs use **headless Firefox**.

## Global Constraints

- Rails 8.1.x (8.1.4), Ruby 4.0.7, SQLite for every database; no Redis, no DB server, no Node.js at build or runtime.
- RSpec is the only test framework; no `test/` directory.
- `bin/ci` is the single CI entrypoint; GitHub Actions calls it.
- Every commit: Conventional Commits, types from `docs/git-convention.md` (feat, fix, docs, chore, refactor, test, perf, ci); one step per commit; RSpec green at every commit from RSpec install onward.
- Branch: `feat/001-rails-app-skeleton`.
- No secrets committed; container runs as non-root.

## Goal

A generated Rails 8.1 app that boots locally and in a container, serves `/` and `/up`, passes `bin/ci` (RuboCop, Brakeman, bundler-audit, importmap audit, RSpec), and has validated Compose and Kamal deployment configs, landed as ~13 small commits.

---

## Phase 0: Prerequisites, spec amendment, doc-first commit

**Implements:** — | **Satisfies:** — (enables all)
**Files:** `docs/specs/001-rails-app-skeleton/spec.md`, `docs/specs/001-rails-app-skeleton/plan.md`
**Interfaces:** Consumes: nothing. Produces: branch `feat/001-rails-app-skeleton`, `rails` 8.1.4 CLI, podman-compose.

- [ ] **User runs** (needs sudo): `! sudo dnf install -y ruby-devel libyaml-devel redhat-rpm-config podman-compose`
- [ ] Verify: `podman compose version` prints a podman-compose version; `rpm -q ruby-devel` succeeds.
- [ ] `gem install rails -v 8.1.4` → `rails -v` prints `Rails 8.1.4`.
- [ ] Run `sdd-superpowers:sdd-spec-update` to amend AC-1.1 → "Given a fresh clone… When the developer runs the setup command Then it exits 0, dependencies are installed, the development environment has separate primary, queue, cache, and cable databases, and the test database exists" (test env keeps Rails' in-process defaults).
- [ ] Create branch `feat/001-rails-app-skeleton` (sdd-execute / using-git).
- [ ] Commit: `docs(specs): add spec and plan for 001 Rails app skeleton`

---

## Phase 1: Generate the application

**Implements:** FR-1 (partial), FR-6 (Kamal generated), FR-7 (omakase) | **Satisfies:** AC-2.4 (no `test/`), AC-2.6
**Files:** everything `rails new` produces (`Gemfile`, `app/`, `config/`, `bin/ci`, `config/ci.rb`, `Dockerfile`, `.dockerignore`, `config/deploy.yml`, `.kamal/secrets`, `.github/`, `.rubocop.yml`, `.gitignore`, `README.md`, …)
**Interfaces:** Consumes: rails CLI. Produces: `bin/rails`, `bin/rubocop`, `bin/brakeman`, `bin/bundler-audit`, `bin/importmap`, `bin/ci`, `bin/kamal`, `bin/setup`.

- [ ] Generate in place (repo already has `.claude/`, `docs/`, `CLAUDE.md`, `LICENSE`):
  ```bash
  rails new . --database=sqlite3 --skip-test --force
  ```
  (`--skip-test` omits Minitest and system-test scaffolding; `--force` overwrites the template `.gitignore`.)
- [ ] Review `git diff .gitignore`; confirm Rails' version ignores `/.env*`, `/config/*.key`, `/storage/*`, `/log/*`, `/tmp/*`. Re-add `/coverage/` from the old file if absent.
- [ ] Confirm `CLAUDE.md`, `LICENSE`, `.claude/`, `docs/` are untouched: `git status --short -- CLAUDE.md LICENSE .claude docs` → empty.
- [ ] Verify: `bin/rails about` exits 0; `test -d test && echo BAD || echo ok` → `ok`; `bin/rubocop` → `no offenses`; `bin/brakeman --no-pager -q` → 0 warnings; `grep -E 'bundler|github-actions' .github/dependabot.yml` shows both ecosystems.
- [ ] Commit: `chore: generate Rails 8.1 application`

---

## Phase 2: Test harness

**Implements:** FR-2, FR-7 | **Satisfies:** AC-1.5, AC-2.4
**Files:** `Gemfile`, `Gemfile.lock`, `.rspec`, `spec/spec_helper.rb`, `spec/rails_helper.rb`, `spec/support/*.rb`, `spec/network_isolation_spec.rb`, `bin/rspec`, `.rubocop.yml`
**Interfaces:** Consumes: Phase 1 app. Produces: `bin/rspec`; `spec/support/` auto-required; `type: :system` specs driven by headless Firefox; FactoryBot syntax methods in all specs.

### 2a — RSpec + FactoryBot
- [ ] Add to `Gemfile`:
  ```ruby
  group :development, :test do
    gem "rspec-rails"
    gem "factory_bot_rails"
  end

  group :test do
    gem "capybara"
    gem "selenium-webdriver"
  end
  ```
- [ ] `bundle install && bin/rails generate rspec:install && bundle binstubs rspec-core`
- [ ] In `spec/rails_helper.rb`, uncomment the support loader:
  ```ruby
  Rails.root.glob("spec/support/**/*.rb").sort_by(&:to_s).each { |f| require f }
  ```
- [ ] `spec/support/factory_bot.rb`:
  ```ruby
  RSpec.configure do |config|
    config.include FactoryBot::Syntax::Methods
  end
  ```
- [ ] `spec/support/system.rb`:
  ```ruby
  RSpec.configure do |config|
    config.before(:each, type: :system) do
      driven_by :selenium, using: :headless_firefox, screen_size: [ 1400, 1400 ]
    end
  end
  ```
- [ ] Run: `bin/rspec` → `0 examples, 0 failures`, exit 0. `bin/rubocop` clean.
- [ ] Commit: `test: set up RSpec with FactoryBot and Capybara`

### 2b — Block real HTTP (WebMock + VCR), test-first
- [ ] Write `spec/network_isolation_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe "Network isolation" do
    it "blocks real outbound HTTP requests" do
      expect { Net::HTTP.get(URI("https://example.com/")) }
        .to raise_error(VCR::Errors::UnhandledHTTPRequestError, %r{example\.com})
    end
  end
  ```
- [ ] Run: `bin/rspec spec/network_isolation_spec.rb` → FAIL (`uninitialized constant VCR`).
- [ ] Add `gem "webmock"` and `gem "vcr"` to the `:test` group; `bundle install`.
- [ ] `spec/support/http_stubbing.rb`:
  ```ruby
  require "webmock/rspec"
  require "vcr"

  WebMock.disable_net_connect!(allow_localhost: true)

  VCR.configure do |config|
    config.cassette_library_dir = "spec/cassettes"
    config.hook_into :webmock
    config.ignore_localhost = true
    config.configure_rspec_metadata!
  end
  ```
- [ ] Run: `bin/rspec spec/network_isolation_spec.rb` → `1 example, 0 failures`.
- [ ] Commit: `test: block real HTTP in specs with WebMock and VCR`

### 2c — rubocop-rspec
- [ ] Add `gem "rubocop-rspec", require: false` to `:development, :test`; `bundle install`.
- [ ] Append to `.rubocop.yml`:
  ```yaml
  plugins:
    - rubocop-rspec

  RSpec:
    Enabled: true
  ```
- [ ] Verify cops are live (probe written via shell so the format hook doesn't touch it):
  `printf 'RSpec.describe "x" do\n  fit "y" do\n  end\nend\n' > spec/probe_spec.rb && bin/rubocop spec/probe_spec.rb; rm spec/probe_spec.rb` → reports `RSpec/Focus`.
- [ ] `bin/rubocop` on the repo → no offenses (fix any generated-spec offenses with `bin/rubocop -a`).
- [ ] Commit: `chore: lint specs with rubocop-rspec`

---

## Phase 3: App surface (`/up`, `/`, system spec)

**Implements:** FR-1, FR-2 | **Satisfies:** AC-1.2, AC-1.3, AC-1.4
**Files:** `spec/requests/health_check_spec.rb`, `spec/requests/home_spec.rb`, `spec/system/home_spec.rb`, `config/routes.rb`, `app/controllers/home_controller.rb`, `app/views/home/index.html.erb`
**Interfaces:** Consumes: Phase 2 harness. Produces: `root "home#index"` route, `HomeController#index`.

### 3a — `/up` characterization spec
- [ ] `spec/requests/health_check_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe "Health check" do
    it "returns 200 when the app has booted" do
      get rails_health_check_path

      expect(response).to have_http_status(:ok)
    end
  end
  ```
- [ ] Run: `bin/rspec spec/requests/health_check_spec.rb` → PASS (route ships with Rails; this pins it).
- [ ] Commit: `test: cover the /up health check`

### 3b — Placeholder home page, test-first
- [ ] `spec/requests/home_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe "Home" do
    describe "GET /" do
      it "renders the placeholder page with the app name" do
        get root_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Collector")
      end
    end
  end
  ```
- [ ] Run: `bin/rspec spec/requests/home_spec.rb` → FAIL (`undefined local variable or method 'root_path'`).
- [ ] `config/routes.rb` — add `root "home#index"` (keep generated `/up` route).
- [ ] `app/controllers/home_controller.rb`:
  ```ruby
  class HomeController < ApplicationController
    def index
    end
  end
  ```
- [ ] `app/views/home/index.html.erb`:
  ```erb
  <main>
    <h1>Collector</h1>
    <p>Track your collectibles. Starting with Magic: The Gathering.</p>
  </main>
  ```
- [ ] Run: `bin/rspec spec/requests` → `2 examples, 0 failures`.
- [ ] Commit: `feat(home): add placeholder home page`

### 3c — System spec (proves browser, importmap, Turbo)
- [ ] `spec/system/home_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe "Home page", type: :system do
    it "shows the app name with Turbo loaded" do
      visit root_path

      expect(page).to have_css("h1", text: "Collector")
      expect(page.evaluate_script("typeof window.Turbo")).to eq("object")
    end
  end
  ```
- [ ] Run: `bin/rspec spec/system` → PASS (Selenium Manager fetches geckodriver on first run). If it fails, it's a harness issue → systematic-debugging, not a code change.
- [ ] Commit: `test: add home page system spec with headless Firefox`

---

## Phase 4: Development mirrors production (Solid Queue/Cache/Cable DBs)

**Implements:** FR-1 | **Satisfies:** AC-1.1 (as amended)
**Files:** `config/database.yml`, `config/environments/development.rb`, `config/cache.yml`, `config/cable.yml`, `config/puma.rb`
**Interfaces:** Consumes: Phase 1 config. Produces: dev DBs `storage/development{,_cache,_queue,_cable}.sqlite3`; jobs processed in-Puma in development.

- [ ] Failing check first:
  `bin/rails runner 'puts ActiveJob::Base.queue_adapter_name, Rails.cache.class'` → currently `async` / `ActiveSupport::Cache::MemoryStore` (expected: `solid_queue` / `SolidCache::Store`).
- [ ] `config/database.yml` — replace the `development:` block:
  ```yaml
  development:
    primary:
      <<: *default
      database: storage/development.sqlite3
    cache:
      <<: *default
      database: storage/development_cache.sqlite3
      migrations_paths: db/cache_migrate
    queue:
      <<: *default
      database: storage/development_queue.sqlite3
      migrations_paths: db/queue_migrate
    cable:
      <<: *default
      database: storage/development_cable.sqlite3
      migrations_paths: db/cable_migrate
  ```
- [ ] `config/environments/development.rb` — replace `config.cache_store = :memory_store` with `config.cache_store = :solid_cache_store`, and add:
  ```ruby
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }
  ```
- [ ] `config/cache.yml` — under `development:` add `database: cache`.
- [ ] `config/cable.yml` — replace `development:` with:
  ```yaml
  development:
    adapter: solid_cable
    connects_to:
      database:
        writing: cable
    polling_interval: 0.1.seconds
    message_retention: 1.day
  ```
- [ ] `config/puma.rb` — change the Solid Queue plugin line to:
  ```ruby
  plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"] || ENV.fetch("RAILS_ENV", "development") == "development"
  ```
- [ ] Run: `bin/setup --skip-server` → exit 0; `ls storage/development*.sqlite3` → 4 files; runner check → `solid_queue` / `SolidCache::Store`; `bin/rspec` still green.
- [ ] Commit: `feat(config): run Solid Queue, Cache and Cable on separate SQLite DBs in development`

---

## Phase 5: CI

**Implements:** FR-3, FR-4 | **Satisfies:** AC-2.1–AC-2.6
**Files:** `config/ci.rb`, `.github/workflows/ci.yml`
**Interfaces:** Consumes: `bin/rspec`, generated `bin/*` tools. Produces: `bin/ci` = the CI definition used by the pre-push hook and GitHub Actions.

### 5a — `bin/ci` runs RSpec and all checks in spec order
- [ ] `config/ci.rb`:
  ```ruby
  # Run using bin/ci

  CI.run do
    step "Setup", "bin/setup --skip-server"

    step "Style: Ruby", "bin/rubocop"
    step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
    step "Security: Gem audit", "bin/bundler-audit"
    step "Security: Importmap vulnerability audit", "bin/importmap audit"

    step "Tests: RSpec", "bin/rspec"
  end
  ```
- [ ] Run: `time bin/ci` → all steps green, exit 0, < 3 min.
- [ ] AC-2.2 probe: `printf 'RSpec.describe("probe") { it { expect(1).to eq(2) } }\n' > spec/ci_probe_spec.rb; bin/ci; echo "exit=$?"; rm spec/ci_probe_spec.rb` → non-zero, output marks `Tests: RSpec` failed.
- [ ] AC-2.3 probe: `printf "puts 'x'\n" > lib/ci_probe.rb; bin/ci; echo "exit=$?"; rm lib/ci_probe.rb` → non-zero, `Style: Ruby` failed.
- [ ] Commit: `ci: run RSpec and all quality gates through bin/ci`

### 5b — GitHub Actions calls `bin/ci`
- [ ] Replace `.github/workflows/ci.yml` (keep the `actions/checkout` major version Rails generated):
  ```yaml
  name: CI

  on:
    pull_request:
    push:
      branches: [ main ]

  jobs:
    ci:
      runs-on: ubuntu-latest
      steps:
        - name: Checkout code
          uses: actions/checkout@v5

        - name: Set up Ruby
          uses: ruby/setup-ruby@v1
          with:
            bundler-cache: true

        - name: Run bin/ci
          run: bin/ci

        - name: Keep screenshots from failed system specs
          uses: actions/upload-artifact@v4
          if: failure()
          with:
            name: screenshots
            path: tmp/capybara
            if-no-files-found: ignore
  ```
- [ ] Verify: `ruby -ryaml -e 'y = YAML.load_file(".github/workflows/ci.yml"); abort unless y.dig("jobs","ci","steps").any? { _1["run"] == "bin/ci" }; puts "ok"'` → `ok`. Dependabot file unchanged (bundler + github-actions).
- [ ] Commit: `ci: run bin/ci in GitHub Actions`

---

## Phase 6: Container and Kamal

**Implements:** FR-5, FR-6 | **Satisfies:** AC-3.1–AC-3.5, AC-4.1–AC-4.3
**Files:** `compose.yaml` (new); `config/deploy.yml` / `.kamal/secrets` only if validation needs changes
**Interfaces:** Consumes: generated `Dockerfile` (non-root `USER 1000:1000`, entrypoint runs `db:prepare`), `/up`. Produces: `compose.yaml` service `web`, volume `collector_storage`, env `SECRET_KEY_BASE`, `COLLECTOR_PORT` (default 3000).

### 6a — Image builds
- [ ] `podman build -t collector .` → exit 0 (AC-3.1). No Node in build.

### 6b — Compose
- [ ] `compose.yaml`:
  ```yaml
  # Self-host Collector with Docker Compose (or podman compose).
  # Required: SECRET_KEY_BASE (generate with: openssl rand -hex 64)
  # Optional: COLLECTOR_PORT (host port, default 3000)
  services:
    web:
      build: .
      image: collector:latest
      restart: unless-stopped
      ports:
        - "${COLLECTOR_PORT:-3000}:8080"
      environment:
        SECRET_KEY_BASE: ${SECRET_KEY_BASE:?SECRET_KEY_BASE is required (generate with: openssl rand -hex 64)}
        SOLID_QUEUE_IN_PUMA: "true"
        HTTP_PORT: "8080"
      volumes:
        - collector_storage:/rails/storage
      healthcheck:
        test: ["CMD", "curl", "-fsS", "http://localhost:8080/up"]
        interval: 10s
        timeout: 5s
        retries: 5
        start_period: 30s

  volumes:
    collector_storage:
  ```
  (Thruster listens on `HTTP_PORT`; 8080 avoids privileged-port issues for the non-root user under rootless runtimes.)
- [ ] AC-3.5: `env -u SECRET_KEY_BASE podman compose up -d` → refuses, message names `SECRET_KEY_BASE`.
- [ ] AC-3.2: `export SECRET_KEY_BASE=$(openssl rand -hex 64); podman compose up -d --build`; within 60s `podman inspect --format '{{.State.Health.Status}}' $(podman compose ps -q web)` → `healthy`; `curl -s -o /dev/null -w '%{http_code}' localhost:3000/up` → `200`; same for `/` → `200`.
- [ ] Non-root: `podman compose exec web id -u` → `1000`.
- [ ] AC-3.4: `podman compose exec web bin/rails runner 'puts SolidQueue::Process.where(kind: "Supervisor").count'` → ≥ `1`.
- [ ] AC-3.3: `podman compose exec web bin/rails runner 'Rails.cache.write("persistence-check", "ok")'`; `podman compose down && podman compose up -d`; wait healthy; `podman compose exec web bin/rails runner 'puts Rails.cache.read("persistence-check")'` → `ok`.
- [ ] Tear down: `podman compose down` (volume kept; remove manually only if desired).
- [ ] Commit: `feat(deploy): add Docker Compose setup for self-hosting`

### 6c — Kamal validates
- [ ] AC-4.1: `bin/kamal config` → exit 0 with generated placeholder host/registry.
- [ ] AC-4.2: confirm `config/deploy.yml` has `volumes: - "collector_storage:/rails/storage"` and `SOLID_QUEUE_IN_PUMA: true`.
- [ ] AC-4.3: `.kamal/secrets` contains only `$VAR` / `$(…)` references, no literals.
- [ ] Commit only if a change was needed: `fix(deploy): make Kamal config validate`

---

## Phase 7: Documentation

**Implements:** FR-6 (docs) | **Satisfies:** AC-3.2 (documented port/env), supports all
**Files:** `README.md`, `CLAUDE.md`, `.claude/memory/steering/tech-stack.md`

- [ ] `README.md` (replace generated stub): what Collector is; requirements (Ruby 4.0.7, SQLite, Firefox for system specs); `bin/setup`, `bin/dev`, `bin/rspec`, `bin/ci`; self-hosting via Compose (`SECRET_KEY_BASE`, `COLLECTOR_PORT`, volume `collector_storage`) and via Kamal (`config/deploy.yml`, `.kamal/secrets`, `RAILS_MASTER_KEY`); AGPL-3.0 license.
- [ ] Commit: `docs: document setup, CI, and self-hosting with Compose and Kamal`
- [ ] `CLAUDE.md`: remove "not generated yet", make commands real (single spec: `bin/rspec spec/requests/home_spec.rb:6`), note dev DB parity and podman usage; `tech-stack.md`: Ruby 4.0.7, Rails 8.1.4, Podman locally.
- [ ] Commit: `docs: update CLAUDE.md and tech-stack for the generated app`

---

## Phase 8: Integration Verification

**Implements:** All FRs | **Satisfies:** All ACs

- [ ] `time bin/ci` → green, < 3 min.
- [ ] AC-5.1/5.2: `git log --format=%s main..HEAD` → every subject matches `^(feat|fix|docs|chore|refactor|test|perf|ci)(\([a-z0-9-]+\))?: `; generator, each tool, CI, deploy, docs in separate commits.
- [ ] AC-5.3: in a scratch worktree, for each commit from `test: set up RSpec…` to HEAD: `bundle install --quiet && bin/rspec` → exit 0.
- [ ] Walk every AC in spec.md and record evidence; then `sdd-superpowers:sdd-review` (implementation mode) before merge.

---

## Quickstart Validation

```bash
bin/setup --skip-server          # installs gems, prepares 4 dev DBs
bin/rspec                        # request + system + isolation specs green
bin/ci                           # all gates green
export SECRET_KEY_BASE=$(openssl rand -hex 64)
podman compose up -d --build     # → healthy
curl -s localhost:3000/up        # 200
bin/kamal config                 # valid
```

## Gates

- Simplicity: 3 components (app, test harness/CI, container config); only spec-required deps. ✓
- Anti-abstraction: framework defaults used directly (Rails health check, Solid*, generated Dockerfile/Kamal). ✓
- Integration-first: request specs precede the home implementation; tooling phases use a failing check before the change. ✓

## Risks

- Ruby 4.0.7 + a gem without Ruby 4 support → surface via systematic-debugging; fallback is pinning the gem, not downgrading Ruby without asking.
- podman-compose healthcheck/interpolation quirks → verify each; files remain Docker-standard.
- `bin/kamal config` may shell out to docker → if so, validate by `ruby -ryaml` parsing + inspection and note it.

## Plan Changelog

| Version | Phase | Change |
|---------|-------|--------|
| 2.0.0 | Phase 4 | Implements rewritten AC-1.1 (dev mirrors prod; test keeps defaults). Phase already written against the new wording; no phases invalidated. |
