---
date: 2026-10-14
spec: "022"
tags: [hotwire, turbo, downloads, authentication]
---

# Lesson: A download link in a Turbo app

## Context

Spec 022's "Export collection" link returns a JSON attachment from `GET /collection/export`.

## What happened

The first spec draft gave the link `download` and `data-turbo="false"`. The read-only review found three problems:

1. **The `download` attribute with an expired session** saves the sign-in page's HTML as the "export". `Content-Disposition: attachment` alone makes it a download, so the attribute was dropped.
2. **Turbo 8 prefetches links on hover.** A prefetch would build the whole file (16 MB at 50,000 lots) every time the pointer passed over the menu, so the link needs `data-turbo-prefetch="false"`. The header's Scan link already did this.
3. **The return path after sign-in.** `Authentication#request_authentication` stores `request.fullpath` for every GET. After sign-in, Turbo would follow the redirect to a JSON attachment from the form submission and couldn't render it. The controller overrides `request_authentication` to redirect without storing the path, and a path stored by an earlier page is still honoured. Both are tested.

## What to do next time

For any endpoint that answers with an attachment:
- link to it with `data-turbo="false"` and `data-turbo-prefetch="false"`, and no `download` attribute
- send `Cache-Control: no-store` if it holds personal data
- override `request_authentication` so it isn't stored as the page to return to
- route it with `format: false`

## Signals to watch for

- `send_data`, `send_file` or `disposition: :attachment` in a new controller.
- A link with `download` or `data-turbo="false"` in a view.
- A heavy GET reachable from a menu or header link.
