# Draft issue for the coordinator to file (spec 030 decision 12)

Not filed by the plan's author. Suggested labels: `bug`, `catalog`. Suggested title and body follow.

---

**Title:** The art index shows as "ready" when its index file is missing

**Body:**

`MTG::Art.status_line` (`catalog:status[mtg]`) and `MTG::Art::Operation` (the **Art index** panel on `/admin/catalog`) say "ready" for a finished art build whenever the latest `mtg_art_builds` row has status `finished` (`app/models/mtg/art.rb`, the `elsif run.finished?` branch of `status_line`; `app/models/mtg/art/operation.rb`, `build.finished? ? :ready : :failed`). Neither looks at the index file, which lives outside the database under `storage/catalog/mtg/art/` (`MTG::Art::Index.current`, which is `nil` when the file is absent).

So any time the database and the volume disagree, the panel claims the scanner has art matching when it doesn't:

- a database restored onto a fresh volume (found while specifying spec 030, back up and restore an instance: a backup holds the primary database only, so the art index file is left behind);
- the `storage/catalog/mtg/art/` directory deleted or lost by hand;
- the index files pruned to the newest `KEEP` while a row still names an older one.

`MTG::Art.page_config` already does the right thing for the scanner page (it returns `nil` with no index, so the page offers text recognition only), so nothing breaks; the admin page and `catalog:status` just mislead the operator about why art matching isn't offered.

**Expected:** a finished build whose index file doesn't exist reads as such ("Index file missing. Build the art index again." with **Build art index** available) instead of "Ready.", on both the admin panel and the `catalog:status` art line. After a restore the build needs no image downloads when every artwork already holds a fingerprint at the current settings.

**Where:** `app/models/mtg/art.rb` (`status_line`), `app/models/mtg/art/operation.rb` (the state that yields `:ready`), `app/models/mtg/art/index.rb` (`current`, `built_for?`), the specs in `spec/models/mtg/art/operation_spec.rb` and `spec/requests/admin/catalogs_spec.rb`, and `docs/architecture/catalog-operations.md` (the "Finished" row and the status line paragraph).

**Not in spec 030.** That spec documents the workaround (press **Build art index** after a restore, AC-2.8) and tests that the build then writes the index without any HTTP request.
