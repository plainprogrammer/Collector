---
name: spec-022-followups
description: Spec 022 (export a collection, #38): merged (PR #97, 2026-10-15); open UI nits; what import (#39, #40) inherits from the writer
metadata:
  type: project
---

Spec 022 built the export: `CollectionExport` and `GET /collection/export`, with "Export collection" in the account menu and on More. PR #97 merged on 2026-10-15 and closed #38. Spec 023 (PR #98, merged after it) split the header into a collector form and a visitor form; the export item is in the collector form's menu only.

**Rulings (maintainer, 2026-10-14):**
- The file is built in the request, with no job. The bar is under 10 s and under 300 MB at 50,000 lots; measured 1.23–1.27 s and +60–66 MB.
- The link goes in the account menu plus More, per the design system's Navigation rule, not on the collection page's head.

**Open, out of scope:**
- More's links show the browser's default focus outline, not the `--focus` ring (the admin links already did).
- The account menu stays open after the download starts.
- `DOWNLOADS` is a top-level constant in `spec/support/system.rb` (a review nit, left as is).

**What import (#39, #40) inherits:**
- `generator` is left out of the file, because the app knows no version at run time. Adding it later is information only.
- Lots are written in `lots.id` order. The format gives order no meaning.
- `added_at` and `changed_at` are the lot's `created_at` and `updated_at`, with the fraction dropped. A restore that keeps them keeps "the same collection".

Related: [[spec-017-followups]], [[orca-supervised-stages]].
