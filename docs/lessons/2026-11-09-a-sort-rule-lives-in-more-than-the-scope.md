---
date: 2026-11-09
spec: "none (issue #204)"
tags: [catalog, sorting, review]
---

# Lesson: A sort rule lives in more than the scope; grep the column too

## Context

#204 made collector numbers compare numerically in `Catalog::Entry.newest_first`. Every caller of the scope was checked and covered with an example.

## What happened

The implementation review (Opus) found a caller the grep for `newest_first` couldn't: `CollectionTable::Sort` repeats the grid's order with its own Arel nodes (`asc(entries[:number])`), and its comment and the area doc both say its default order "is the grid's". After the change the grid read 2, 10, 12 and the table 10, 12, 2. The fix put the same terms behind one `number_terms` method and added table examples.

## What to do next time

- When an order changes, grep the column (`entries[:number]`) as well as the scope's name, and read every doc line that says one list's order "is" another's.
- Ask the implementation review to look for a second copy of the rule, not only for callers of the changed method.

## Signals to watch for

- A comment or area-doc sentence of the form "the default order is the grid's".
- Arel `order` nodes built by hand beside a model scope that orders the same columns.
