# Contract: `expected_changes.yml` and `seed_exceptions.yml`

**Spec requirements:** decisions 5, 6, 9; AC-2.5, AC-2.6, AC-4.4, AC-4.5, AC-4.6, AC-9.1.

Both live in `script/upgrade/`, are read with `YAML.safe_load_file` (no classes, no aliases) and are not in the published image.

## `expected_changes.yml`

```yaml
# A change a migration is meant to make to data a release already holds (spec 031 decision 6).
changes:
  - table: lots                     # required: a table of the old database
    column: lot_key                 # required for `rewritten`; optional for the other kinds (omit it for a whole table, or for row counts)
    kind: rewritten                 # required: dropped | rewritten | rows_removed | rows_added
    migration: "20261101100001"     # required: the migration's version (a string); a file in db/migrate/ of the code under test
    reason: "Spec 033 decision 2: the lot key now includes the location"   # required: names the spec
```

| Kind | What it excuses | Matches the difference |
|---|---|---|
| `dropped` | A column (with `column`) or a whole table (without) the new database lacks | `column_dropped` / `table_dropped` |
| `rewritten` | Values of a column both databases have that changed, for rows both have | `value_changed` on that column |
| `rows_removed` | Rows of the old table missing in the new one | `rows_removed` |
| `rows_added` | Rows the new table holds that the old one did not (a backfill) | `rows_added` |

Rules, applied in this order by `ExpectedChanges.load` and `Compare`:

1. A top-level key other than `changes`, an entry that is not a mapping, one missing `table`, `kind`, `migration` or `reason`, a `kind` outside the four, or a `rewritten` without `column` is an error naming the entry's position.
2. A `migration` that is not the version of a file in the code under test's `db/migrate/` is an error naming the entry (a typo must not excuse another migration's difference).
3. An entry whose migration the previous release already has is **retired**: ignored, printed as `retired: ...`, never a failure (decision 6).
4. A live entry (its migration is not in the previous release) that matches no difference in the comparison is an error naming the entry (AC-4.5).
5. A difference no live entry matches is a failure of the proof (AC-4.6).

The file ships as `changes: []` (spec 031 adds no migration, and the migrations between `v0.2.1` and `main` change no existing value: `AddProgressToCatalogRefreshRuns` adds nullable columns, the others create tables; research.md section 4).

**Release housekeeping (decision 9):** after a tag, delete the entries whose migration the tag contains.

## `seed_exceptions.yml`

```yaml
# Tables a seed cannot fill (spec 031 decision 5), by the release whose seed they excuse, or `next` for seeds/next.rb.
"0.2.1": []
next: []
# Each entry:
#   - table: mtg_artworks
#     reason: "needs the art index build, a long job"
```

Rules (`SeedExceptions.load` and `.coverage`):

1. Only the key of the previous release (`"0.2.1"`) and `next` are read; other keys are ignored.
2. An entry without `table` or `reason` is an error.
3. After a seed runs, every table of the database other than SQLite's own, the FTS5 virtual tables with their shadow tables, `schema_migrations` and `ar_internal_metadata`, must hold a row, except the listed tables. A table without a row fails the run naming the table and the seed file.
4. An exception for a table the database does not have fails the run (a release or code that lacks the table).
5. Every used exception is printed on every run: `seed exception: <table> (<reason>)`.

Both files start empty: the seeds fill every table of `v0.2.1` (19 tables) and of `main` (26 tables) through the models (research.md section 3).

**Release step (decision 9):** rename `next.rb` to the version being cut, rename the `next` key to that version, add a new `next.rb` (and a `next` key where it needs exceptions).
