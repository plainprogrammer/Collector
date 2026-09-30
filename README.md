# Collector

Collector is a self-hostable, multi-tenant web app for tracking collectibles, starting with
Magic: The Gathering. It is at an early stage: alongside the stack, tests, CI, and deployment
setup, it has a card catalog fed from Scryfall's bulk data and a public card search page at
`/catalog/entries` (see [Card catalog](#card-catalog)). Accounts and collections are not built
yet.

Built with Rails 8.1, SQLite, and Hotwire (Turbo + Stimulus via importmap and Propshaft; no
Node.js). Background jobs, caching, and Action Cable use Solid Queue, Solid Cache, and Solid
Cable, all backed by SQLite.

## Requirements

- Ruby 4.0.7 (see `.ruby-version`)
- SQLite is provided by the `sqlite3` gem; no separate database server is needed
- Firefox, for the system specs (run headless)

## Development

```sh
bin/setup   # install gems, prepare the database, then start the server
bin/dev     # start the server on http://localhost:3000 (another port in a worktree)
```

`bin/setup --skip-server` prepares everything without starting the server. `bin/setup` is
idempotent; run it again after pulling changes.

Development mirrors production: the app uses separate SQLite databases in `storage/`
(`development`, `development_cache`, `development_queue`, `development_cable`), and Solid Queue
runs inside Puma. `bin/dev` (or `bin/rails server`) therefore already processes background
jobs. Do not also run `bin/jobs`, as that starts a second supervisor on the same queue database.

### Worktrees

`bin/setup` also prepares git worktrees, so several branches can run side by side. Run it
once in your clone: it points `core.hooksPath` at the versioned `.githooks/` directory, and
from then on every new worktree runs `bin/setup --skip-server` automatically. This covers
plain `git worktree add`, `claude --worktree`, and Orca worktrees (local or remote); Orca
also runs the same command through `orca.yaml`. The hook ignores ordinary branch switches,
file checkouts, and the main checkout (including `git clone`), and concurrent runs in one
worktree are serialized (`tmp/setup.lock`), so running it twice is safe.

Enabling this replaces the clone's default `.git/hooks/` directory: setup lists any active
hooks there that stop running. An existing custom `core.hooksPath` is left alone, and
automatic setup stays off; run `bin/setup` in each new worktree yourself.

- **Copied from the main checkout:** the files listed in `.worktreeinclude`
  (`config/master.key` and `tmp/local_secret.txt`), only when missing in the worktree and
  with mode 0600. Existing files are never overwritten. If Orca's `ORCA_ROOT_PATH` disagrees
  with git about where the main checkout is, setup prints a notice and uses git's answer.
- **Regenerated per worktree:** the development databases (primary, queue, cache, cable),
  the test database, caches, logs, and pids. Nothing is shared between worktrees.
- **Ports:** the main checkout serves on 3000; each worktree gets a stable port in
  3001–3999, derived from its path and printed by `bin/setup`. Set `PORT` to override it,
  for example if two worktrees happen to get the same port.
- **Credentials:** a remote Orca runtime has no copy of your local `config/master.key`, so
  setup warns and continues; development and the specs work without it. Copy the key there,
  or set `RAILS_MASTER_KEY`, if you need credentials. A missing key only warns, but a wrong
  key makes the app fail to boot.
- **Failures:** if automatic setup fails, the worktree is still created; run `bin/setup` in
  it to finish.

## Testing and CI

```sh
bin/rspec                               # full suite
bin/rspec spec/requests/home_spec.rb:5  # a single file or example
```

The suite uses RSpec, FactoryBot, and Capybara. System specs run in headless Firefox; on the
first run Selenium Manager downloads geckodriver, which needs network access. WebMock and VCR
block all real HTTP from specs (cassettes live in `spec/cassettes`).

`bin/ci` is the single CI definition (`config/ci.rb`). It runs every step and exits non-zero,
naming the steps that failed:

1. Setup (`bin/setup --skip-server`)
2. Style: `bin/rubocop` (rubocop-rails-omakase + rubocop-rspec)
3. Security: `bin/brakeman`
4. Security: `bin/bundler-audit`
5. Security: `bin/importmap audit`
6. Tests: `bin/rspec`

GitHub Actions (`.github/workflows/ci.yml`) runs `bin/ci`, so local and hosted CI are the same.
Dependabot keeps gems and GitHub Actions up to date.

## Self-hosting

Two deployment paths are supported: Docker Compose for a single machine, and Kamal for
deploying to your own servers. Both use the `Dockerfile` in this repository and keep all
data in SQLite on a persistent volume.

> **Before you expose Collector:** the first person to reach a new or freshly upgraded instance becomes its admin. Either sign up straight away while the instance is only reachable on your private network, or create the admin from the command line first (see [Accounts](#accounts)).

### Docker Compose

`compose.yaml` works with both `docker compose` and `podman compose`.

| Variable                    | Required | Default               | Purpose                                                                                                                               |
| --------------------------- | -------- | --------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `SECRET_KEY_BASE`           | yes      | none                  | Secret used to sign and encrypt sessions and cookies                                                                                  |
| `COLLECTOR_PORT`            | no       | `3000`                | Host port the app is published on                                                                                                     |
| `COLLECTOR_MTG_LANGUAGES`   | no       | English only          | Extra card languages, e.g. `ja,de` (see [Card catalog](#card-catalog))                                                                |
| `COLLECTOR_CURRENCY`        | no       | `USD`                 | Currency for the price you paid: USD, CAD, AUD, NZD, EUR, GBP, CHF, SEK, NOK, DKK, PLN, CZK, JPY, CNY, KRW, SGD, HKD, BRL, MXN or ZAR |
| `COLLECTOR_HTTPS`           | no       | `false`               | Set to `true` when Collector is served over HTTPS (secure cookies, redirect to HTTPS)                                                 |
| `COLLECTOR_TRUSTED_PROXIES` | no       | Rails' private ranges | Extra reverse proxies (IPs or CIDRs, comma-separated) whose `X-Forwarded-For` is trusted                                              |
| `COLLECTOR_PASSWORD`        | no       | none                  | Password for the user command below; never stored in logs                                                                             |

Changing `COLLECTOR_CURRENCY` later doesn't convert prices you've already entered; they're shown with the new symbol. An unsupported code stops the app at boot, naming the setting.

Compose refuses to start without `SECRET_KEY_BASE`. Generate one with:

```sh
openssl rand -hex 64
# or, without openssl:
ruby -rsecurerandom -e 'puts SecureRandom.hex(64)'
```

Set the variables in your shell or in a `.env` file next to `compose.yaml`, then start it:

```sh
docker compose up -d     # or: podman compose up -d
```

The app is then available at `http://localhost:3000` (or your `COLLECTOR_PORT`).

- **Data:** all four production SQLite databases live in the named volume
  `collector_storage`, mounted at `/rails/storage`. Back up this volume.
- **Jobs:** Solid Queue runs inside the web process; no separate worker is needed.
- **Health:** the container has a healthcheck on `/up`, and runs as a non-root user (uid 1000).
- **Upgrades:** pull the new code, then run `docker compose up -d --build`. Database migrations
  run automatically when the container starts.
- **HTTPS:** the Compose setup serves plain HTTP. Signing in over plain HTTP sends your password unencrypted, which is only acceptable on a trusted private network. Put an HTTPS reverse proxy (for example Caddy, nginx, or Traefik) in front of it and set `COLLECTOR_HTTPS=true`.

### Kamal

Kamal (`bin/kamal`) deploys the same image to servers you control over SSH.

1. Edit `config/deploy.yml`: replace the placeholder server (`192.168.0.1`) and registry
   (`localhost:5555`) with your own. If your registry needs authentication, set `username`
   and uncomment the `KAMAL_REGISTRY_PASSWORD` password entry.
2. Secrets come from `.kamal/secrets`, which reads `RAILS_MASTER_KEY` from
   `config/master.key` and the registry password from the `KAMAL_REGISTRY_PASSWORD`
   environment variable.
3. Check the configuration with `bin/kamal config`.
4. Run `bin/kamal setup` for the first deployment, and `bin/kamal deploy` after that.

Data is stored in the `collector_storage` volume (mounted at `/rails/storage`), and Solid
Queue runs inside Puma (`SOLID_QUEUE_IN_PUMA`).

### Accounts

Each person has their own account and collection. The first account is the admin: whoever signs up first, or whoever you create with the user command. The admin opens or closes sign-up and manages users under **Users and sign-up** in the avatar menu (or **More** on a phone).

The user command sets a user's password, or creates an admin if no user has that email. It takes the password from `COLLECTOR_PASSWORD`, or asks for it when run in a terminal, or generates one and prints it once. Setting a password signs that user out everywhere.

```sh
bin/rails "collector:user[you@example.com]"                                                    # locally
docker compose exec -e COLLECTOR_PASSWORD='…' web bin/rails "collector:user[you@example.com]"  # Docker Compose
bin/kamal app exec -i "bin/rails 'collector:user[you@example.com]'"                           # Kamal
```

### Upgrading to accounts

**Read this before you upgrade.** An instance upgraded from a version without accounts has no users, and the first person to reach it becomes its admin. If others can reach your instance, stop exposing it (for example, take it off your reverse proxy) before you upgrade, or run the user command straight after the upgrade to create your admin. Then sign in, and only then expose it again.

1. Pull the new code.
2. Run `docker compose up -d --build` (or `bin/kamal deploy`). Migrations run when the container starts.
3. Create or claim the admin account as described above.

## Card catalog

Card data comes from [Scryfall](https://scryfall.com)'s bulk data files, which the app
downloads in a background job and caches in its own database. Pages are rendered only from
that local copy; the app never calls Scryfall while rendering a page.

**The catalog is empty until the first refresh.** After the first deployment, queue a manual
refresh:

```sh
bin/rails "catalog:refresh[mtg]"                          # locally
docker compose exec web bin/rails "catalog:refresh[mtg]"  # Docker Compose (or podman compose)
bin/kamal catalog-refresh                                 # Kamal
```

The command returns straight away; the refresh runs in the background (Solid Queue inside
Puma). To see how it went, list the 10 most recent runs, newest first, with their counts and
any error message:

```sh
bin/rails "catalog:status[mtg]"   # Kamal: bin/kamal catalog-status
```

- **Schedule:** in production the catalog refreshes weekly, on Mondays at 03:15 server time
  (`config/recurring.yml`). A scheduled run is skipped when the same Scryfall file and
  language set were already applied; a manual run always applies. Only one refresh per
  collectible type runs at a time.
- **Languages:** set `COLLECTOR_MTG_LANGUAGES` to a comma-separated, case-insensitive list of
  extra languages (for example `ja,de`). The default is English only, and English is always
  included. Accepted codes: `en es fr de it pt ja ko ru zhs zht he la grc ar sa ph qya`.
  Changes take effect at the next refresh. Printings in a language you remove are retired,
  not deleted. An unsupported code fails the refresh before anything is downloaded.
- **Disk:** downloads are kept in `storage/catalog/mtg/` on the persistent volume, and only the
  two newest are kept. English only uses Scryfall's `default_cards` file (about 80 MB each);
  any other language needs the `all_cards` file (about 400 MB each). They can always be
  downloaded again, so they don't need backing up.
- **Attribution:** card data and images are © Wizards of the Coast and are provided by
  Scryfall. Collector follows Scryfall's API guidelines.

## License

Collector is licensed under the GNU Affero General Public License v3.0. See [LICENSE](LICENSE).
