---
date: 2026-10-11
spec: "017"
tags: [spec-writing, review, catalog]
---

# Lesson: Ask where a vocabulary lives before specifying it

## Context

Spec 017's first draft treated a lot's finish and its condition as the same kind of thing: values from a list that the collectible type registers. It had an acceptance criterion that compared the format document's finishes with "the vocabulary the application registers for Magic".

## What happened

The application registers no such list. `MTG::Collecting` has a closed list of conditions, but a finish is whatever the source lists for that printing, stored per printing and validated per entry. The criterion had nothing to compare against and could never pass. The Mode A review found it by reading `MTG::Collecting` and `Lot#finish_offered`.

This is the failure of [Read the build tools' mechanics before writing CI and registry criteria](2026-10-08-check-registry-mechanics-before-writing-acs.md), in the application's own code this time. What it adds: two fields that sit side by side in a form and in a table can get their allowed values from different places, and a format has to say which. Here that decided more than one criterion. Whether a finish is allowed became a question about one entry in one catalog (resolvable), never about the file alone (well-formed), and the schema lists no finishes.

## What to do next time

For each field a spec constrains, find the line of code that validates it and write down where its allowed values come from: a constant, a per-record list, a source's data. Do it before writing a criterion that compares the field with "the application's list".

## Signals to watch for

- A spec that names two fields in one breath ("finish and condition").
- A criterion that compares a document with what the application "registers".
- A validation that takes the record as an argument (`finishes_for(entry)`), which means the list isn't global.
