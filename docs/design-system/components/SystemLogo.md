# SystemLogo

The logo swap that follows the operating system's dark theme when the page doesn't pin a theme.

**Markup** — the consumer renders both logo images; the light one carries `c-logo--light`, the reversed one `c-logo--dark`.

```html
<span class="c-appbar__wordmark">
  <img src="/assets/collector/collector-wordmark-….svg" alt="" class="c-logo--light">
  <img src="/assets/collector/collector-wordmark-reversed-….svg" alt="" class="c-logo--dark">
</span>
```

- The export shows the reversed logo only when `<html data-theme="dark">` is set. This addition also swaps it under `prefers-color-scheme: dark` when `<html>` has no `data-theme`, so the logo stays readable when the page follows the system.
- An explicit `data-theme="light"` keeps the light logo even on a dark system.
- Only one image is ever displayed, so give both the same `alt`: empty when a link or label already names it ("Collector home"), "Collector" when the logo stands alone.
- Use the wordmark on wide screens and the mark in tight spaces (see the README's Logo rules).
