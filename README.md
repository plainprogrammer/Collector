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
- libvips, for Active Storage image variants (ADR 0013): `sudo dnf install vips` on Fedora,
  `sudo apt install libvips` on Debian or Ubuntu. `bin/setup` says so when it's missing
- ImageMagick, for the card scanner's art index build (ADR 0012): `sudo dnf install ImageMagick`
  on Fedora, `sudo apt install imagemagick` on Debian or Ubuntu

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

### Card scanner on a phone

`bin/setup` also runs `bin/fetch-ocr-engine`, which downloads the card scanner's OCR engine (about 15 MB) from
`registry.npmjs.org`, checks every file against a pinned SHA-256 and keeps it in `vendor/ocr/` (ignored by git).

The scanner is at `/scanner` ("Scan" in the navigation). Browsers only allow a live camera on HTTPS (or on
`localhost`), so to use it from a phone on your network, serve the dev server over HTTPS with a self-signed
certificate that the phone trusts:

```sh
bin/dev-certificate          # creates or reuses the certificate; prints the next command for your worktree's port
bin/dev -b "ssl://0.0.0.0:3000?key=$HOME/.local/share/collector-dev-https/dev.key&cert=$HOME/.local/share/collector-dev-https/dev.crt"
bin/dev-certificate --serve  # in another terminal: serves only the certificate on port 3579 until you press Ctrl-C
```

Then, once per certificate, on the iPhone:

1. In Safari, open the download URL that `bin/dev-certificate --serve` prints (`http://<your address>:3579/`) and allow the profile.
2. Settings → General → VPN & Device Management: install the profile.
3. Settings → General → About → Certificate Trust Settings: turn on full trust for the certificate.
4. Open `https://<your address>:<port>/scanner` in any browser.

- The key and certificate stay outside the repository, in `~/.local/share/collector-dev-https/`
  (`COLLECTOR_DEV_CERT_DIR` overrides it). Only the certificate is ever served; the key never leaves your machine.
- The certificate names your machine's local network addresses (or the ones you pass as arguments). Run
  `bin/dev-certificate` again after the address changes; it makes a new certificate, which the phone must trust again.
- Puma ends TLS itself, so Rails sees real HTTPS and needs no other setting.
- An HTTPS tunnel of your choice also works: set `RAILS_DEVELOPMENT_HOSTS` to the tunnel's host names
  (comma-separated) and `COLLECTOR_HTTPS=true` (the tunnel ended TLS), then run `bin/dev`.
- Over plain HTTP from another device, the page offers a photo instead.

**Measurement mode** (development only) records live captures of known cards for the scanner's findings, at
`/scanner/measurement`. It reads the manifest at `COLLECTOR_SCANNER_MANIFEST` (default
`~/card-scanner-corpus/manifest.csv`, columns `file,set,number,foil[,era]`) and stores each capture's text and
strip images under `COLLECTOR_SCANNER_RUN_DIR` (default `~/card-scanner-corpus/runs/live`), outside the
repository. `bin/rails scanner:findings` scores a run; `bundle exec ruby script/scanner/replay.rb <label>`
re-reads its strips on the desktop (`SCANNER_URL=https://127.0.0.1:<port>` points it at an HTTPS server).
`SCANNER_EMAIL=… SCANNER_PASSWORD=… bundle exec ruby script/scanner/photo_run.rb` replays the photos beside the
manifest through the scanner's photo picker, storing each as a capture. For a sitting scanned and added in
measurement mode, `SCANNER_EMAIL=… GROUND_TRUTH=… bin/rails scanner:sitting_findings` scores what each card ended as
(run it before pressing Done).
`COLLECTOR_REQUEST_LOG=1` logs each response's size to `log/requests.jsonl`.

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

GitHub Actions (`.github/workflows/ci.yml`) runs `bin/ci` first, so local and hosted CI are the same; it then
builds the container image for amd64 and arm64 and, on `main` and release tags, publishes it (see
[Self-hosting](#self-hosting) and `docs/releasing.md`). Dependabot keeps gems and GitHub Actions up to date.

## Self-hosting

Two deployment paths are supported: Docker Compose for a single machine, and Kamal for
deploying to your own servers. Both run the published image `ghcr.io/plainprogrammer/collector`
(built from the `Dockerfile` in this repository for amd64 and arm64) and keep all data in SQLite
on a persistent volume. `latest` is the newest release; `edge` follows `main`. Releases and their
tags are described in `docs/releasing.md`.

> **Before you expose Collector:** the first person to reach a new or freshly upgraded instance becomes its admin. Either sign up straight away while the instance is only reachable on your private network, or create the admin from the command line first (see [Accounts](#accounts)).

### Docker Compose

`compose.yaml` works with both `docker compose` and `podman compose`, and needs no checkout: download
the file and start it.

| Variable                    | Required | Default               | Purpose                                                                                                                               |
| --------------------------- | -------- | --------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `SECRET_KEY_BASE`           | yes      | none                  | Secret used to sign and encrypt sessions and cookies                                                                                  |
| `COLLECTOR_PORT`            | no       | `3000`                | Host port the app is published on                                                                                                     |
| `COLLECTOR_IMAGE`           | no       | `ghcr.io/plainprogrammer/collector:latest` | Image to run; set it to a tag such as `ghcr.io/plainprogrammer/collector:0.1` to pin a release, or to a locally built image |
| `COLLECTOR_MTG_LANGUAGES`   | no       | English only          | Extra card languages, e.g. `ja,de` (see [Card catalog](#card-catalog))                                                                |
| `COLLECTOR_MTG_ART_MATCHING` | no       | off                   | `true` turns on art matching for the card scanner (see [Card catalog](#card-catalog))                                                 |
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
- **Upgrades:** `docker compose pull && docker compose up -d`. Database migrations run automatically
  when the container starts.
- **Building from source:** `docker build -t collector:local .` in a checkout, then start Compose with
  `COLLECTOR_IMAGE=collector:local`.
- **HTTPS:** the Compose setup serves plain HTTP. Signing in over plain HTTP sends your password unencrypted, which is only acceptable on a trusted private network. Put an HTTPS reverse proxy (for example Caddy, nginx, or Traefik) in front of it and set `COLLECTOR_HTTPS=true`.

### Kamal

Kamal (`bin/kamal`) deploys the same image to servers you control over SSH.

1. Edit `config/deploy.yml`: replace the placeholder server (`192.168.0.1`) with your own. The
   registry is already `ghcr.io` with the published image.
2. Secrets come from `.kamal/secrets`, which reads `RAILS_MASTER_KEY` from `config/master.key`
   and the registry password from the `KAMAL_REGISTRY_PASSWORD` environment variable. Kamal
   needs registry credentials even to pull a public image: use a GitHub token with `read:packages`.
3. Check the configuration with `bin/kamal config`.
4. Run `bin/kamal setup --skip-push --version X.Y.Z` for the first deployment, and
   `bin/kamal deploy --skip-push --version X.Y.Z` after that, naming the release to deploy. Kamal
   pulls that tag; nothing is built or pushed.

To deploy an image you build yourself, change `image` and `registry` in `config/deploy.yml` to
a registry you own, then run `bin/kamal deploy`. Never run a plain `bin/kamal deploy` with the
registry set to `ghcr.io/plainprogrammer/collector`: it would push a single-architecture `latest`
over the published image.

Data is stored in the `collector_storage` volume (mounted at `/rails/storage`), and Solid
Queue runs inside Puma (`SOLID_QUEUE_IN_PUMA`).

### Card scanner

The card scanner ("Scan" in the navigation, at `/scanner`) reads a card with the camera of the phone it runs on, or
from a photo, which it finds and straightens first. You confirm the printing and finish and add the card to your
collection with one tap; the sitting's adds are listed with Undo until you press Done. Photos never leave the phone:
only the text read from the card and your add, Undo and printing choices are sent to your instance.
The image build downloads the scanner's OCR engine from `registry.npmjs.org` and checks each file against a pinned
SHA-256; your instance serves it from `/ocr/v7.0.0/`, so phones fetch it from you, not from a third party.
The published image already contains it.

Browsers only allow a live camera on HTTPS; that is the only part that needs it. Without HTTPS,
only the photo picker works, and adding cards from photos works the same way.

- **Docker Compose:** put an HTTPS reverse proxy in front of the app (see **HTTPS** under Docker Compose) and set
  `COLLECTOR_HTTPS=true`.
- **Kamal:** enable the proxy's certificate in `config/deploy.yml` (uncomment `proxy:` with `ssl: true` and set
  your `host:`), and uncomment `COLLECTOR_HTTPS: true` under `env: clear:`.

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

1. Pull the new image (`docker compose pull`, or pick the release for Kamal).
2. Run `docker compose up -d` (or `bin/kamal deploy --skip-push --version X.Y.Z`). Migrations run when the container starts.
3. Create or claim the admin account as described above.

## Card catalog

Card data comes from [Scryfall](https://scryfall.com)'s bulk data files, which the app
downloads in a background job and caches in its own database. Pages are rendered only from
that local copy; the app never calls Scryfall while rendering a page.

**The catalog is empty until the first refresh.** After the first deployment, sign in as an
admin and open **Catalog** (in the account menu, or under More on a phone). Press
**Refresh now** and the page shows the download and the sync as they go, without reloading.
Until then, search and the scanner say that the catalog hasn't been loaded. Nothing downloads
until you start it, so set the languages below first if you want more than English.

You can also queue the refresh from a shell:

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

- **Catalog page:** `/admin/catalog` shows each catalog's cards, its last applied refresh, when
  the next one is scheduled, the running refresh's stage and progress, and its recent runs. A
  refresh that stops making progress for 15 minutes is shown as interrupted (after a restart,
  for example); pressing **Refresh now** then starts it again.
- **Jobs page:** `/admin/jobs` lists the app's background jobs that failed, are running, are
  queued or are scheduled. A failed job shows its error and backtrace, and can be retried or
  discarded there. Both pages are for admins only.

- **Schedule:** in production the catalog refreshes weekly, on Mondays at 03:15 server time
  (`config/recurring.yml`). A scheduled run is skipped when the same Scryfall file and
  language set were already applied; a manual run always applies. Only one refresh per
  collectible type runs at a time.
- **Languages:** set `COLLECTOR_MTG_LANGUAGES` to a comma-separated, case-insensitive list of
  extra languages (for example `ja,de`). The default is English only, and English is always
  included. Accepted codes: `en es fr de it pt ja ko ru zhs zht he la grc ar sa ph qya`.
  Changes take effect at the next refresh. Printings in a language you remove are retired,
  not deleted. An unsupported code fails the refresh before anything is downloaded.
- **Art matching (optional):** set `COLLECTOR_MTG_ART_MATCHING=true` and the card scanner also
  recognises a card by its artwork on live captures. It's off by default because the first
  build costs about 708 MB of downloads (one small image per artwork from Scryfall),
  about 2.6 hours of throttled fetching and then fingerprinting, and leaves an index of
  about 7.3 MB. The build runs in the background after a catalog refresh; to start it now, press
  **Build art index** on the Catalog page, which also shows its progress, or run
  `bin/rails "catalog:refresh[mtg]"` (Kamal: `bin/kamal catalog-refresh`), and follow it with
  `bin/rails "catalog:status[mtg]"`. Later refreshes fetch only new artworks. Until the first
  build finishes, and whenever art matching is off, the scanner works on text alone. Images
  are cached in `storage/catalog/mtg/art`; after turning art matching off you can delete that
  folder to reclaim the space.
- **Disk:** downloads are kept in `storage/catalog/mtg/` on the persistent volume, and only the
  two newest are kept. English only uses Scryfall's `default_cards` file (about 80 MB each);
  any other language needs the `all_cards` file (about 400 MB each). They can always be
  downloaded again, so they don't need backing up.
- **Attribution:** card data and images are © Wizards of the Coast and are provided by
  Scryfall. Collector follows Scryfall's API guidelines.

## License

Collector is licensed under the GNU Affero General Public License v3.0. See [LICENSE](LICENSE).
