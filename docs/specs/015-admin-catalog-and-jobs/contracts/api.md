# Contracts: Admin Catalog Operations and Jobs

All endpoints answer HTML to a signed-in admin. A signed-in member gets **404** from every one of them, and a visitor who isn't signed in is redirected to `/session/new` (AC-7.1, AC-7.2). Non-GET requests carry the CSRF token. Redirects after a non-GET are **303 See Other**.

## GET /admin/catalog

**Purpose:** the catalog page: one panel per registered catalog type.
**Spec requirement:** Stories 1 to 5, FR-4.

### Response 200

- `main` carries `data-controller="poll"` only while any operation of any type is in flight.
- Per type: `section#catalog_<type>.c-panel` with its title (`h2`), an empty state (`p.c-empty`) while it isn't loaded and nothing is in flight, a `dl.c-details` (Cards, Last applied refresh, Next scheduled refresh), one `section#<type>_<operation key>.c-operation` per operation, and `ul.c-runs` with up to 5 recent runs.
- Per operation: its title (`h3`), a start form when it has a start label (button disabled unless it can start), its summary (`p.c-operation__summary`), a link to `/admin/jobs?status=failed` when its failed run's job is in the failed list, its stages (`ol.c-stages`), its meter (`div.c-meter` with a `<progress max="100" value="…" aria-label="…">`), and its facts (`dl.c-details`).

## POST /admin/catalog/operation_starts

**Purpose:** queue one operation's job.
**Spec requirement:** FR-3, AC-2.1, AC-2.3, AC-4.3 to AC-4.5, AC-5.6.

### Request

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| collectible_type | string | yes | A registered catalog type (`mtg`). |
| operation | string | yes | One of that type's operation keys (`refresh`, `art_index`). |

### Response 303 → /admin/catalog

| Outcome | Flash | Effect |
|---------|-------|--------|
| Queued | notice: the operation's queued notice ("Refresh queued.", "Art index build queued.") | One job queued with the operation's arguments (`Catalog::RefreshJob("mtg", "manual")`, `MTG::Art::BuildJob`). |
| Already in flight | notice: its in-flight notice ("A refresh is already queued or running.") | Nothing queued. |
| Unavailable | alert: the reason ("Refresh the catalog first: the art index is built from its cards.") | Nothing queued. |

### Error Responses

| Status | When |
|--------|------|
| 404 | Unknown catalog type, or an operation key the type doesn't have. Nothing is queued. |

## GET /admin/jobs

**Purpose:** the jobs in one state.
**Spec requirement:** AC-6.1 to AC-6.4, AC-6.10.

### Request

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| status | string | no | `failed` (default), `running`, `queued` or `scheduled`. Anything else shows `failed`. |
| page | integer | no | Clamped to the pages there are; 25 jobs a page. |

### Response 200

- `form.c-jobs__filters` (GET) with one `button.c-filter[name=status]` per state, `aria-pressed` on the one shown, each with its count.
- `table.c-jobs` (one row per job: class linked to its page, arguments, error line for a failed job, queue, the state's time) or `p.c-empty` ("No failed jobs."), then the pager.
- Order: Failed by failure time, newest first; Running by start time, newest first; Queued by queue time, oldest first; Scheduled by due time, soonest first.
- A failed row has a menu with "Retry" (POST) and "Discard…" (link to the confirmation).
- `main` carries `data-controller="poll"` only while any job is running or queued.

## GET /admin/jobs/:id

**Purpose:** one job in full.
**Spec requirement:** AC-6.5, AC-6.9.

### Response 200

Class, state, queue, priority, attempts, the times that apply (Queued, Due, Started, Failed, Finished), its arguments, and for a failed job the exception class, message and backtrace, with "Retry" and "Discard…". No actions for any other state.

### Error Responses

| Status | When |
|--------|------|
| 404 | The queue has no job with that id. |

## POST /admin/jobs/:job_id/retry

**Purpose:** queue a failed job to run again.
**Spec requirement:** AC-6.6, AC-6.8, AC-6.11.

### Response 303

| Outcome | Redirect | Flash |
|---------|----------|-------|
| Retried | `/admin/jobs?status=failed` | notice: "Retrying <job class>." |
| Not failed (any more) | `/admin/jobs` | alert: "That job isn't failed any more." Nothing changes. |

### Error Responses

| Status | When |
|--------|------|
| 404 | The queue has no job with that id. |

## GET /admin/jobs/:job_id/discard/new

**Purpose:** confirm a discard, without scripting.
**Spec requirement:** AC-6.7.

### Response 200

`section.c-confirm`: "Discard <job class>?", one sentence on what is removed, a POST form "Discard <job class>" and "Cancel" back to `/admin/jobs?status=failed`.

### Response 303 → /admin/jobs

When the job isn't failed: alert "That job isn't failed any more."

## POST /admin/jobs/:job_id/discard

**Purpose:** remove a failed job for good.
**Spec requirement:** AC-6.7, AC-6.8, AC-6.11.

### Response 303

| Outcome | Redirect | Flash |
|---------|----------|-------|
| Discarded | `/admin/jobs?status=failed` | notice: "Discarded <job class>." |
| Not failed (any more) | `/admin/jobs` | alert: "That job isn't failed any more." Nothing changes. |

### Error Responses

| Status | When |
|--------|------|
| 404 | The queue has no job with that id. |

## The source contract's optional hooks (`Catalog::Sources`)

**Purpose:** how a catalog type reaches the catalog page without the core naming it.
**Spec requirement:** FR-2, AC-2.8, AC-5.2 to AC-5.4.

| Hook | Called by | Contract |
|------|-----------|----------|
| `#progress=(callable)` | `Catalog::Refresh`, once, before the download | The source calls `callable.call(done, total)` as often as it likes during `#download` (bytes received, expected size) and `#each_entry` (bytes of the file read, its size). `total` may be nil. A source without it is tracked by stage and counts only. |
| `.title` | `Catalog.title_for` | The catalog's name for people ("Magic: The Gathering"). Without it, the type's name, humanized. |
| `.operations(collectible_type)` | `Catalog::Health#operations` | An array of `Catalog::Operation` objects shown after the refresh. Without it, the refresh alone. |

## The operation interface (`Catalog::Operation`)

**Purpose:** what the catalog page renders and the start request calls.
**Spec requirement:** FR-2, FR-3.

A subclass provides `key`, `title`, `start_label` (nil for no button), `queued_notice`, `in_flight_notice`, `job_class`, `summary` and `record_running?`, and may provide `job_arguments`, `queue_argument`, `stages` (`Stage(label, state, meter, note)`, state one of `:done`, `:current`, `:stopped`, `:pending`), `meter` (`Meter(label, done, total, text)`), `facts` (`Fact(label, value, relative)`, value a String, Integer or Time) and `unavailable_reason`. The base class gives `in_flight?`, `failed_job?`, `startable?` and `start` (true when it queued a job).
