# Input

A single-line text field; with a leading search icon it is the collection search.

**Markup** — the wrapper is a `<label>` so the whole field is clickable; the consumer provides the `<input>` (with a visible label or `aria-label`), an optional leading 16px icon and an optional trailing `<kbd>` shortcut hint.

```html
<label class="c-input"><svg …/><input type="search" placeholder="Search your collection" aria-label="Search your collection"><kbd>/</kbd></label>
```

- The focus ring sits on the wrapper (`:focus-within`), 2px `focus`.
- Placeholders give an example, never the label.
- Border is `line-strong` (3:1 on every surface); don't lighten it.
- In Rails: `form.search_field :q, placeholder: …` inside the label.
