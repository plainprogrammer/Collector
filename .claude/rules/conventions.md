# Ruby & Rails Conventions

- ✓ Follow Rails naming: `snake_case` files/methods/variables, `CamelCase` classes/modules, singular models (`Card`), plural controllers/tables (`CardsController`, `cards`), `SCREAMING_SNAKE_CASE` constants.
- ✓ File path must mirror constant name (Zeitwerk): `app/models/collectibles/printing.rb` → `Collectibles::Printing`. Run `bin/rails zeitwerk:check` after adding namespaces.
- ✓ Keep the core domain collectible-agnostic (`Collection`, `Item`, `Catalog::Entry`); put game-specific code in namespaces such as `Mtg::` (`app/models/mtg/`) — never leak `mana_cost`-style concepts into core models.
- ✓ Predicate methods end in `?`, dangerous/raising variants in `!`; avoid `get_`/`set_` prefixes.
- ✓ Use `rubocop-rails-omakase` as the base, layer `rubocop-rspec` for specs, keep local overrides minimal and commented.
- ✓ Run `bin/rubocop` and `bin/brakeman` before committing; CI must fail on offenses.
- ✗ Don't disable cops inline without a justification comment on the same line.
- ✗ Don't create god-object services or `utils.rb` dumping grounds; name classes after what they do (`Mtg::BulkImporter`, `Exports::CollectionArchive`).
- ✗ Don't add gems for trivial functionality; prefer Rails built-ins (Solid*, `has_secure_password`, Active Storage, `Rails.cache`).
