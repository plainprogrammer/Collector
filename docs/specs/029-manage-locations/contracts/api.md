# API Contracts: Manage Locations

All routes need a signed-in collector (`require_authentication`; a visitor is sent to sign in, GETs remember the page). Every id is looked up through `Current.account.locations`; another account's id, or one that no longer exists, answers 404. HTML only. Forms are CSRF-protected and work without scripting.

## GET /locations

**Purpose:** The locations page: heading "Locations", the add form, the account's locations in the order of decision 2, each with Rename and Remove; the empty state when there are none.
**Spec requirement:** FR-2, Story 1, AC-1.1, AC-1.4

### Response (200 OK)

HTML (`c-pagehead`, `c-form`, `c-list`). One query for the list. The header link "Locations" is current (`aria-current="page"`); no tab is marked.

### Error Responses

| Status | Condition | Body |
|--------|-----------|------|
| 302 | Not signed in | Redirect to sign in |

## POST /locations

**Purpose:** Add a location to the signed-in collector's account.
**Spec requirement:** FR-1, FR-2, Story 1, AC-1.2 to AC-1.14, AC-4.3

### Request

```
location[name]=Blue binder      (the only permitted parameter; account_id is ignored)
```

### Response (303 See Other)

Redirect to `/locations`, notice `Added “Blue binder”.` (the normalised name).

### Error Responses

| Status | Condition | Body |
|--------|-----------|------|
| 400 | No `location` parameter (`params.expect`) | Rails bad request |
| 422 | Name blank after normalisation | The page, "Give the location a name.", typed text kept |
| 422 | Over 60 code points | "Names can be at most 60 characters." |
| 422 | A Cc or Cf character left after normalising | "Names can't contain control characters." |
| 422 | Same comparison key as another location (also the unique-index race) | "You already have a location called “<normalised name>”." |
| 422 | The account has 500 locations | "You can have at most 500 locations." |

## GET /locations/:id/edit

**Purpose:** The rename page: name field holding the name, "Save", "Cancel".
**Spec requirement:** Story 2, AC-2.1, AC-2.7

### Response (200 OK)

HTML. Cancel links to `/locations`.

### Error Responses

| Status | Condition | Body |
|--------|-----------|------|
| 404 | Not this account's, or removed | Not found |

## PATCH /locations/:id

**Purpose:** Rename. Renaming to a name with its own key (box to Box) or to its own name is allowed; last write wins.
**Spec requirement:** Story 2, AC-2.2 to AC-2.10

### Request

```
location[name]=Trade binder
```

### Response (303 See Other)

Redirect to `/locations`, notice `Renamed “Blue binder” to “Trade binder”.` No lot changes (AC-2.8).

### Error Responses

| Status | Condition | Body |
|--------|-----------|------|
| 400 | No `location` parameter | Rails bad request |
| 404 | Not this account's, or removed meanwhile (nothing created) | Not found |
| 422 | The reasons of POST (not the cap) | The edit page with the reason beside the field, the location keeps its name |

## GET /locations/:id/removal/new

**Purpose:** The confirmation page (`ConfirmPage`): "Remove <name>?", a "Remove" button, "Cancel". Removes nothing.
**Spec requirement:** Story 3, AC-3.1, AC-3.3, decision 3

### Response (200 OK)

HTML. The paragraph says that no lot or copy is removed or changed.

### Error Responses

| Status | Condition | Body |
|--------|-----------|------|
| 404 | Not this account's, or removed | Not found |

## DELETE /locations/:id

**Purpose:** Remove the location. Never touches a lot (decision 3).
**Spec requirement:** Story 3, AC-3.2, AC-3.4 to AC-3.7

### Response (303 See Other)

Redirect to `/locations`, notice `Removed “Blue binder”.`

### Error Responses

| Status | Condition | Body |
|--------|-----------|------|
| 404 | Not this account's, or already gone (no redirect with a message, P7) | Not found |

## Changed contracts of spec 025 and 028 (extended, not rewritten)

### POST /collection/import_preview

Reads versions 1 and 2. A version above 2 is refused (422): "This instance reads version 2." A version 2 file with a bad `locations` is refused whole (422), naming the field: "locations is missing", "locations.1 has the same name as an earlier location, ignoring case", "locations.N.name isn't valid". The preview page gains the Locations section (counts of added, renamed, unchanged and removed; the first 100 names of the renamed and removed) or, for a version 1 file, "This file was written before locations existed, so your locations would stay as they are." A file whose only change is a location is applicable and stored. Spec 025 AC-1.x and 028 AC-1.11 otherwise as shipped.

### POST /collection/import

Unchanged routes, parameters (`fingerprint`, `confirm_removal`) and statuses (303, 409, 422, 500). The plan, fingerprint and confirmation cover locations; the checkbox reads "I understand this removes N lots and M locations" (or only the part that applies) and is required when the plan removes lots or locations; the notice adds "; 2 locations added, 1 renamed, 1 removed." after a version 2 file (parts that are zero left out) and says nothing about locations after a version 1 file.

### GET /collection/export

Writes version 2: `locations` present (empty for no locations), in the order of decision 2, names only.
