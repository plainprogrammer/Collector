# Controllers, Views & Hotwire

- ✓ Keep controllers RESTful and thin: the 7 standard actions; add a new resource controller (e.g. `Collections::ImportsController#create`) instead of custom actions.
- ✓ Reach for tools in order: plain HTML → Turbo Drive → Turbo Frames → Turbo Streams → Stimulus → other JS.
- ✓ Return `:unprocessable_entity` on failed form submissions and `:see_other` on redirects after non-GET, so Turbo renders correctly.
- ✓ Keep Stimulus controllers small and single-purpose; configure via values/targets/classes and clean up in `disconnect()`.
- ✓ Pin JS with importmap and serve assets via Propshaft; reference assets with helpers.
- ✓ Use `broadcasts_refreshes`/morphing or scoped `turbo_stream_from` for live updates, backed by Solid Cable.
- ✗ Don't build client-side state stores or render JSON for your own UI — send HTML.
- ✗ Don't put queries or business logic in views/partials; pass prepared locals.
- ✗ Don't add a Node/bundler toolchain or npm-only dependencies without a strong reason; self-hosters shouldn't need Node.
- ✗ Never `permit!`; use `params.expect` / strong params.
