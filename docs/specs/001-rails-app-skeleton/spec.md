# Feature 001: Rails Application Skeleton

**Status:** Approved
**Version:** 2.0.0
**Created:** 2026-09-29
**Last Updated:** 2026-09-29
**Branch:** `feat/001-rails-app-skeleton`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-09-29 | Initial approved spec |
| 2.0.0 | 2026-09-29 | Rewrote AC-1.1: development mirrors production with separate primary/queue/cache/cable databases; test keeps Rails' in-process defaults (primary database only). Previously required all four databases in both development and test. |

---

## Problem Statement

Collector has a foundation, rules, and a chosen stack, but no runnable application. Every future feature needs a working, tested base that follows the project's principles from day one: easy self-hosting (Foundation principle 1), tests before merge (principle 5), and a single maintained local CI tool. Without it, there is nothing to specify features against, nothing for the Claude Code hooks to enforce, and no proof the chosen stack can be packaged and run by a self-hoster.

> **Stack constraints.** This feature *is* the stack setup, so the chosen technologies are fixed inputs rather than implementation choices. They are defined in `.claude/memory/steering/tech-stack.md`: Rails 8.x (latest), SQLite in all environments, Hotwire, Propshaft + importmap, Solid Queue / Solid Cache / Solid Cable, RSpec + FactoryBot + WebMock/VCR, RuboCop (`rubocop-rails-omakase` + `rubocop-rspec`), Brakeman, bundler-audit, importmap audit, `bin/ci`, Docker, Docker Compose, and Kamal. Requirements below refer to them by role; the plan decides how.

## Goals

- A freshly cloned repository can be set up and booted locally with one setup command, and serves a health check and a placeholder home page.
- One local CI command runs every quality gate (tests, lint, static security scan, gem vulnerability audit, JS dependency audit) and fails if any gate fails.
- Remote CI runs that same local CI command, so there is exactly one definition of "CI passes".
- The production container image builds, boots via Docker Compose with persistent storage, and passes its health check.
- The Kamal configuration is valid and documented as a supported deployment path alongside Docker Compose.
- Background jobs, caching, and websockets are backed by their own separate databases, with no additional services required.
- The work lands as a sequence of small commits, one per setup step, each following `docs/git-convention.md`.

## Non-Goals

- No user accounts, authentication, or tenant model.
- No collectible domain models, catalog data, or external data-source integration.
- No real deployment to a remote server.
- No backup/restore tooling.
- No visual design beyond a minimal placeholder page.

## Users and Context

**Primary users:** Collector developers (currently the maintainer, plus Claude Code sessions).
**Secondary users:** Self-hosters, who will eventually run the container image or Kamal deploy.
**Usage context:** Developers clone the repo, run setup, iterate with the test suite and the local CI command before pushing. Self-hosters pull the image and run it with Compose, or deploy with Kamal.
**User mental model:** "Clone, run setup, run CI, it's green." "`docker compose up` and it's running." Standard Rails 8 conventions apply — nothing surprising.

## User Stories

### Story 1: Developer boots and tests the app locally

**As a** developer
**I want** a one-command setup that yields a running app and a passing test suite
**So that** I can start building features immediately on a known-good base

**Acceptance criteria:**

- [ ] **AC-1.1** Given a fresh clone with the required Ruby version installed When the developer runs the setup command Then it exits 0, dependencies are installed, the development environment has separate primary, queue, cache, and cable databases (jobs, cache, and websockets run on them as in production), and the test database exists
- [ ] **AC-1.2** Given the app is running locally When a client requests `/up` Then the response status is 200
- [ ] **AC-1.3** Given the app is running locally When a client requests `/` Then the response status is 200 and the page contains the text "Collector"
- [ ] **AC-1.4** Given the test suite When the developer runs it Then it exits 0 and includes at least one request spec (for `/` and `/up`) and one browser-driven system spec (for `/`)
- [ ] **AC-1.5** Given the test suite When any spec attempts a real outbound HTTP request Then the spec fails with a blocked-network error

### Story 2: Developer runs a single CI gate

**As a** developer
**I want** one local command that runs every quality gate
**So that** "CI passes" means the same thing on my machine, in the pre-push hook, and on the remote

**Acceptance criteria:**

- [ ] **AC-2.1** Given a clean checkout of the skeleton When the developer runs the local CI command Then it runs, in order, the style check, static security scan, gem vulnerability audit, JS dependency audit, and the RSpec suite, and exits 0
- [ ] **AC-2.2** Given a failing spec is introduced When the local CI command runs Then it exits non-zero and identifies the test step as failed
- [ ] **AC-2.3** Given a style offense is introduced When the local CI command runs Then it exits non-zero and identifies the style step as failed
- [ ] **AC-2.4** Given the local CI command When its configuration is inspected Then the test step runs RSpec, not the default Minitest runner, and no Minitest `test/` directory exists in the repository
- [ ] **AC-2.5** Given the remote CI workflow definition When it is inspected Then its check job invokes the local CI command rather than duplicating individual checks
- [ ] **AC-2.6** Given the repository When dependency update automation config is inspected Then it covers both gems and GitHub Actions

### Story 3: Self-hoster runs the app with Docker Compose

**As a** self-hoster
**I want** to start Collector with a single Compose command
**So that** I can run my own instance without assembling services by hand

**Acceptance criteria:**

- [ ] **AC-3.1** Given the repository When the production image is built Then the build exits 0
- [ ] **AC-3.2** Given the Compose file and a documented secret-key environment variable is set When the self-hoster runs Compose up Then within 60 seconds the app container reports healthy and `/up` returns 200 on the documented host port
- [ ] **AC-3.3** Given the app is running under Compose When the container is stopped and started again Then the databases created on first boot still exist on the persistent volume (no re-creation, data retained)
- [ ] **AC-3.4** Given the app is running under Compose When the background job processor status is checked Then a job processor is running against the queue database in the same deployment, with no extra services (no Redis, no separate database server)
- [ ] **AC-3.5** Given the Compose setup When the required secret-key environment variable is missing Then Compose refuses to start the app with a message naming the missing variable

### Story 4: Self-hoster can deploy with Kamal

**As a** self-hoster
**I want** Kamal to be a supported deployment path
**So that** I can deploy to my own server with the standard Rails 8 tooling

**Acceptance criteria:**

- [ ] **AC-4.1** Given the Kamal configuration as committed When the Kamal config validation command runs (with placeholder host/registry values) Then it exits 0
- [ ] **AC-4.2** Given the Kamal configuration When it is inspected Then the SQLite storage directory is mounted on a persistent volume and the job processor runs in-process or as a declared role
- [ ] **AC-4.3** Given the Kamal secrets file as committed When it is inspected Then it contains no literal secret values, only references to environment variables or a secret manager

### Story 5: Maintainer gets an incremental, reviewable history

**As a** maintainer
**I want** each setup step committed separately
**So that** the history is easy to review, bisect, and revert

**Acceptance criteria:**

- [ ] **AC-5.1** Given the feature branch When its commits are listed Then every commit message matches the Conventional Commits format with an allowed type from `docs/git-convention.md`
- [ ] **AC-5.2** Given the feature branch When its commits are listed Then generator output, each added tool, CI wiring, and container/deploy configuration each appear in separate commits
- [ ] **AC-5.3** Given each commit from the one that installs RSpec onward When checked out and the RSpec suite is run Then it exits 0 at that commit

## Functional Requirements

### FR-1: Application boot

**Must:**
- Boot in development, test, and production environments.
- Serve a health check at `/up` returning 200 when the app has booted.
- Serve a placeholder root page containing the application name.
- Use SQLite for primary, queue, cache, and cable databases, each a separate file, stored under the app's storage directory in production.

**Must not:**
- Require any service beyond the app process(es) and the local filesystem (no Redis, no external database server, no Node.js runtime at runtime or build time).

### FR-2: Test suite

**Must:**
- Use RSpec as the only test framework, with factories and HTTP stubbing available.
- Block real outbound network access during tests.
- Include request specs for `/` and `/up` and one system spec exercising `/` in a browser.

**Must not:**
- Ship the default Minitest scaffolding.

### FR-3: Local CI command

**Must:**
- Provide `bin/ci` as the single local CI entrypoint, configured declaratively in one file.
- Run style check, static security scan, gem vulnerability audit, JS dependency audit, and the RSpec suite.
- Exit non-zero when any step fails, and report which step failed.

**Must not:**
- Require network access other than fetching vulnerability advisory data.

### FR-4: Remote CI and dependency automation

**Must:**
- Provide a remote CI workflow whose checks invoke `bin/ci`.
- Provide dependency update automation for gems and CI actions.

### FR-5: Container packaging

**Must:**
- Provide a production container image definition that builds without Node.js.
- Provide a Compose file that runs the app with a persistent volume for the storage directory, a health check against `/up`, and the job processor.
- Read the application secret from an environment variable documented in the Compose file.

**Must not:**
- Bake any database file or secret into the image.

### FR-6: Kamal configuration

**Must:**
- Keep the Rails-generated Kamal configuration, updated so it validates and mounts persistent storage.
- Document (in README) both Compose and Kamal as supported deployment paths, with the required environment variables.

**Must not:**
- Commit real host names, registry credentials, or secret values.

### FR-7: Linting configuration

**Must:**
- Use `rubocop-rails-omakase` as the base style configuration and add `rubocop-rspec` for spec files.
- Pass the style check with zero offenses on the generated skeleton.

## Non-Functional Requirements

### Performance

- The full local CI command completes in under 3 minutes on the skeleton on a typical developer machine.
- The production container reports healthy within 60 seconds of `compose up` on a warm image.

### Security

- Static security scan reports zero warnings on the skeleton.
- Gem and JS dependency audits report zero known vulnerabilities at merge time.
- The master key and any `.env` file are git-ignored; no secret values are committed.
- The container runs the app as a non-root user.

### Reliability

- Database files survive container restarts and image upgrades via the persistent volume.
- Booting a new image against an existing volume runs pending migrations automatically and does not recreate existing databases.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| Any CI step fails | `bin/ci` exits non-zero and names the failed step; pre-push hook blocks the push |
| Test attempts real network access | The spec fails with a blocked-request error naming the URL |
| Compose started without the secret-key variable | Compose refuses to start with an error naming the variable |
| App boots but a database is unreachable/unwritable | `/up` does not return 200 and the container is reported unhealthy |
| Kamal config missing required placeholder values | Validation command fails with Kamal's error naming the missing key |

## Open Questions

None — deployment scope, remote CI, and app surface were resolved during specification.

## Out of Scope (Future Considerations)

- Authentication and account/tenant model (`Current.account`).
- Collectible core domain and MTG extension namespace.
- Scryfall catalog sync.
- Real Kamal deploy to a server; TLS/proxy configuration for Compose.
- Backups (e.g. Litestream) and upgrade-notes process.
- ERB linting.
