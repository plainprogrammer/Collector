# ImportPreview

The upload page for an export file and the preview of what importing it would do (spec 025). Previewing changes nothing.

**Markup**: the upload page is a `Form` whose field holds a plain file input with `c-file`. The preview page wraps its sections in `c-import`: a status notice, the `c-stats` of outcomes, then sections, each opened by a `c-section__head`, whose lists are `c-list c-import__list`.

```html
<form class="c-form" action="/collection/import_preview" method="post" enctype="multipart/form-data" data-turbo="false">
  <div class="c-field">
    <label class="c-field__label" for="export_file">Export file</label>
    <input class="c-file" type="file" id="export_file" name="export_file" accept=".json,application/json" required aria-describedby="export_file_hint">
    <p class="c-field__hint" id="export_file_hint">A .json file from Export collection, at most 32 MB. Previewing shows what importing it would do and changes nothing.</p>
  </div>
  <div class="c-form__actions"><input type="submit" class="c-btn c-btn--primary" value="Preview import"><a class="c-btn c-btn--secondary" href="/collection">Cancel</a></div>
</form>

<div class="c-import">
  <p class="c-status__message c-status__message--alert">This file can't be applied: 2 rows have problems. Previewing changed nothing.</p>
  <dl class="c-stats">
    <div class="c-stat"><dt>Lots added</dt><dd>1</dd><small>6 copies</small></div>
    <div class="c-stat"><dt>Lots changed</dt><dd>2</dd><small>6 copies become 9</small></div>
    <div class="c-stat"><dt>Lots unchanged</dt><dd>1</dd><small>3 copies</small></div>
    <div class="c-stat"><dt>Lots removed</dt><dd>1</dd><small>7 copies</small></div>
  </dl>
  <section>
    <div class="c-section__head"><h2 class="c-section__title">Rows with problems</h2><span class="c-section__count">2 rows</span></div>
    <ol class="c-list c-import__list c-import__rows">
      <li>
        <span class="c-import__number">Row 1</span>
        <span>Serra Angel <span class="c-list__meta">DMR · 27 · EN · Etched</span></span>
        <div class="c-import__reasons"><p>This printing doesn't come in etched</p></div>
      </li>
    </ol>
    <p class="c-import__more">and 1 more</p>
  </section>
</div>
```

- The form is submitted without Turbo Drive, so the preview is an ordinary page. A refused file shows the form again (422) with the reason as the field's `c-field__error`.
- The file input is the browser's own control, in the page's text style with the `focus` ring. It accepts `.json` as a convenience; the server judges the file by its content.
- The notice says whether the file can be applied, in words. The alert form (`c-status__message--alert`) is used when it can't.
- Outcomes are counts of lots, with copies on the small line; the lots held by rows with problems are counted on the line under them (`c-import__note`), always shown. Only removed lots are listed, because removing is the one destructive outcome.
- A row with problems shows its number (mono), what the file says it is, and each reason on its own line in `danger` with the words carrying the meaning.
- Each list shows its first 100 entries and then "and N more" (`c-import__more`); the counts above it cover them all.
- Rows wrap (`flex-wrap`, `overflow-wrap:anywhere`), so a long name or email address never scrolls the page sideways at 360px.

## Apply form (spec 028)

A file that can be applied and has something to change also shows the apply form, below the held-lots line and above the profile notes. It is an ordinary `c-form`, submitted without Turbo Drive; no new class is needed.

```html
<form class="c-form" action="/collection/import" method="post" data-turbo="false">
  <input type="hidden" name="fingerprint" value="…">
  <p class="c-import__note">Applying removes 1 lot (2 copies) and can't be undone. <a href="/collection/export">Download your current collection first</a>.</p>
  <div class="c-field"><label class="c-check"><input type="checkbox" name="confirm_removal" value="1" required> I understand this removes 1 lot</label></div>
  <p class="c-import__note">This preview is kept for an hour.</p>
  <div class="c-form__actions"><input type="submit" class="c-btn c-btn--primary" value="Apply import"></div>
</form>
```

- The checkbox appears only when lots are removed. With nothing to remove, the note says only that applying can't be undone.
- A file with nothing to change says so in the notice and shows no form. A file that couldn't be stored shows an alert notice ("This file couldn't be kept, so it can't be applied. Choose it again.") and no form.
- The stale-plan page (409) and a refused apply (422) are this same page with an alert notice above it (`c-status` shows the message); a stale page carries the new fingerprint in its form.
