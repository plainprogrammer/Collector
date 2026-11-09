---
name: brainstorm-mockups-with-collector-css
description: Brainstorm visual companion serves /files/<basename> only; copy Collector's tokens/components/additions CSS and fonts flat into content/ (rewrite font URLs); restart keeps the port
metadata:
  type: reference
---

The brainstorm visual companion (superpowers brainstorming skill) serves `/files/<name>` by basename only, so assets must sit flat in the session's `content/` folder. To mock up with the real design system, copy `tokens.css` (rewrite its font URLs from `/collector/` to `/files/`), `components.css`, `additions.css` and the fonts from `app/assets/fonts/collector/` into `content/`, and write full HTML documents that link them.

A paused session stops the server: restart with the same `--project-dir` (the port and key are kept), then copy the content into the new session folder, since a restart makes a new one. Headless Firefox isn't installed on the Mac, so no screenshots of the mock-ups. Used for the decks scoping, 2026-11-09 ([[design-system-before-features]]).
