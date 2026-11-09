# Ruby & Rails Conventions

- ✓ Follow Rails naming: `snake_case` files/methods/variables, `CamelCase` classes/modules, singular models (`Card`), plural controllers/tables (`CardsController`, `cards`), `SCREAMING_SNAKE_CASE` constants.
- ✓ File path must mirror constant name (Zeitwerk): `app/models/collectibles/printing.rb` → `Collectibles::Printing`. Run `bin/rails zeitwerk:check` after adding namespaces.
- ✓ Keep the core domain collectible-agnostic (`Collection`, `Item`, `Catalog::Entry`); put game-specific code in namespaces such as `MTG::` (`app/models/mtg/`) — never leak `mana_cost`-style concepts into core models.
- ✓ Predicate methods end in `?`, dangerous/raising variants in `!`; avoid `get_`/`set_` prefixes.
- ✓ Use `rubocop-rails-omakase` as the base, layer `rubocop-rspec` for specs, keep local overrides minimal and commented.
- ✓ Run `bin/rubocop` and `bin/brakeman` before committing; CI must fail on offenses.
- ✓ Point a comment at an area doc or an ADR with a YARD tag, `@see file:<file name>.md` (for example `@see file:release-and-deploy.md`), not wrapped in braces; a spec stays a plain mention ("spec 015 AC-2.16"), as in the existing comments. Comments are Markdown (`bin/yard doc`, spec 054).
- ✓ Keep `{…}` out of comments unless it is YARD's link syntax: put paths and formats that contain braces in backticks. An unresolved `{…}` or a malformed tag fails `bin/ci checks` (step "Docs: YARD builds without warnings").
- ✗ Don't disable cops inline without a justification comment on the same line.
- ✗ Don't create god-object services or `utils.rb` dumping grounds; name classes after what they do (`MTG::BulkImporter`, `Exports::CollectionArchive`).
- ✗ Don't add gems for trivial functionality; prefer Rails built-ins (Solid*, `has_secure_password`, Active Storage, `Rails.cache`).
