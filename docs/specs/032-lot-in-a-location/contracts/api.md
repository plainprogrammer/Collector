# Contracts: pages, forms and routes

**Spec:** [spec.md](../spec.md) (v1.0.1) · **Plan:** [../plan.md](../plan.md) · The export format's contract is in [export-v3.md](export-v3.md).

Every route is under sign-in. Nothing in a request names an account; every location and lot is found through `Current.account` (`Current.account.locations.find`, `Current.account.lots.find`), so another account's id, or no such id, answers **404** and changes nothing (decision 6). Writes are `POST`/`PATCH`/`DELETE` with Rails' forgery protection and strong parameters (`params.expect`); no write is a `GET`.

## Routes

| Verb and path | Controller#action | New or changed | Spec |
|---|---|---|---|
| `GET /catalog/entries/:entry_external_key/lots/new` | `LotsController#new` | changed: Location field | Story 1 |
| `POST /catalog/entries/:entry_external_key/lots` | `LotsController#create` | changed: `lot[location_id]` | Story 1 |
| `GET /lots/:id/edit` | `LotsController#edit` | changed: Location field | Story 2 |
| `PATCH /lots/:id` | `LotsController#update` | changed: `lot[location_id]` | Story 2 |
| `GET /lots/:lot_id/move/new` | `Lots::MovesController#new` | **new** | Story 3 |
| `POST /lots/:lot_id/move` | `Lots::MovesController#create` | **new** | Story 3 |
| `GET /locations` | `LocationsController#index` | changed: counts | Story 4 (P2) |
| `GET /locations/:location_id/removal/new` | `Locations::RemovalsController#new` | changed: refusal page when the location holds lots | Story 5 (P1) |
| `DELETE /locations/:id` | `LocationsController#destroy` | changed: 409 when it holds lots | Story 5 |
| `POST /collection/bulk_removals/:bulk_removal_id/undo` | `Collections::BulkRemovals::UndosController#create` | changed: notice | Story 7 (P5) |
| `GET /catalog/entries/:external_key` | `Catalog::EntriesController#show` | changed: the lot table | Story 4 |
| `GET /collection/export`, `…/import_preview/new`, `POST …/import_preview`, `POST /collection/import` | | changed: format version 3 | Stories 8, 10, 11 |

`config/routes.rb` gains one line, inside `resources :lots, only: %i[edit update destroy]`:

```ruby
resource :move, only: %i[new create], module: :lots
```

(`new_lot_move_path(lot)`, `lot_move_path(lot)`.) The card page's `from=collection` and a table's `return_to` are carried as today (`card_params`, `lot_return_params`).

## Parameters

| Request | Parameters (all strings) | Rules |
|---|---|---|
| Add, edit | `lot[quantity]`, `lot[finish]`, `lot[condition]`, `lot[price_paid]` (as before) and **`lot[location_id]`** | Blank or absent on add: unplaced (AC-1.8). On edit, blank: unplaced; **absent**: the lot keeps its place (plan decision, research R5). A value that is not the id of one of the account's locations: 404, before the form is validated (AC-1.7, AC-2.7). |
| Move | **`move[copies]`**, **`move[location_id]`** | `copies` a whole number from 1 to the lot's quantity, else 422 "Choose from 1 to N copies." beside Copies. `location_id` blank: "No location"; otherwise one of the account's locations, else 404 (AC-3.9). The lot's own place: 422 "Those copies are already there." beside To (P4). |

`account_id`, `location_id` of another account, `lot_key` and `quantity` of the destination are never read from a request.

## Responses

| Situation | Response |
|---|---|
| Add, edit or move succeeds | **303** to the card page (add, move) or to where Edit copy returns (edit), with the notice below |
| Form invalid (quantity, price, copies, cap) | **422**, the form again, the reason beside the field, the chosen location still selected (AC-1.6) |
| Cap: the result would hold more than 9,999 copies in one lot | **422**, "One lot can hold at most 9,999 copies." beside Quantity (add, edit) or Copies (move); nothing changes |
| Location or lot of another account, or missing | **404** |
| A location removed between the form and the write (a lost race) | **404** (the foreign key refused the write; `rescue_from ActiveRecord::InvalidForeignKey` re-raises `RecordNotFound`); never 500 (AC-6.7) |
| `DELETE /locations/:id` for a location that holds lots, or one that gained a lot after its page opened | **409** with the refusal page; the location and every lot are unchanged (AC-5.4, AC-5.5) |
| `GET /locations/:location_id/removal/new` for an empty location | 200, spec 029's confirmation page, unchanged |
| `GET /locations/:location_id/removal/new` for a location that holds lots | 200, the refusal page (no Remove button) |

## Words

| Where | Text |
|---|---|
| Add notice | "Added 4 × Serra Angel (DMR 27) to Blue binder." / "…to your collection." when unplaced (AC-1.2) |
| Edit notice | "Saved." |
| Move notice | "Moved 2 × Serra Angel (DMR 27) to Blue binder." / "…to no location." (AC-3.2, AC-3.5) |
| Add and edit field | label "Location"; first option "No location"; then the account's locations in `Location.ordered` (comparison key, then name) |
| Add and edit, no locations | no field; a hint "Add a location to keep copies in one." with "Add a location" linking to `/locations` (P3) |
| Move page | title "Move copies of Serra Angel (DMR 27)"; fields "Copies" (number, 1 to quantity, value quantity) and "To"; buttons "Move" and "Cancel" |
| Move page, nothing to move to | "You have no locations yet." with a link to `/locations`, no Move button (AC-3.10) |
| Move errors | "Choose from 1 to 4 copies." · "Those copies are already there." · "One lot can hold at most 9,999 copies." |
| Locations page, per location | "12 copies in 3 lots" · "1 copy in 1 lot" · "Empty" (P2) |
| Refusal page | heading "“Blue binder” isn't empty"; "“Blue binder” holds 12 copies in 3 lots. Move them before removing it."; the first 100 lots (name, set and number, language, finish, condition, ×quantity, a link to the card page's copies); "and 150 more"; "Back to locations" (P1, AC-5.2, AC-5.3) |
| Bulk Undo notice | "Restored 5 copies to your collection." then, if any lot came back without a location, " 2 lots came back without a location." (P5) |
| Import preview, version 1 or 2 file | "This file was written before lots could be in a location, so its lots would be in none." (AC-10.4) |
| Import preview, a lot with an unlisted location | row reason "Its location “Box” isn't one of the file's locations." (AC-10.3) |
| Import preview, version above 3 | "This file was written by a newer version of Collector (format version 4). This instance reads version 3." (AC-10.1) |
| Import preview, removed lots | the lot's line gains "· in Blue binder" for a placed lot (AC-10.9) |

## The pages' markup

All from existing components (read `docs/design-system/components/Form.md`, `ConfirmPage.md`, `Locations.md`, `ItemPage.md` before writing; Phase 3 to 5 steps say which) and tokens; no new colour, font or spacing.

| Page | Built from |
|---|---|
| Location field | `c-field` with `c-field__label` and a `select`, as Finish and Condition |
| Hint when the account has no location | `c-field__hint` |
| Card page's Location column | a `th` and `td.is-opt` in the existing `c-table`; the place also in `c-table__sub` for the narrow layout (AC-4.1) |
| "Move copies" menu item | `c-menu__item` between "Edit copy" and the separator |
| Move copies page | `c-main c-page`, `c-pagehead`, `c-form` with two `c-field`s and `c-form__actions` (as Edit copy) |
| Counts on the locations page | `c-list__meta` inside the row |
| Refusal page | `c-confirm` (as `ConfirmPage`) with a `c-list` of lots and `c-locations__more` for "and N more" |

The only stylesheet addition expected is `c-locations__more` (the same declarations as `c-import__more`) and, if the counts need it, a rule for the count text under `c-locations`; each goes in `collector/additions.css` with the doc in `components/Locations.md` and a line in the README's app additions (Phase 8).
