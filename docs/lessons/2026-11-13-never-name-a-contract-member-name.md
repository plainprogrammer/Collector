---
date: 2026-11-13
spec: "085"
tags: [prices, contracts, ruby]
---

# Lesson: don't name a class-level contract member `name`

## Context

Spec 085, the price source contract. A source is a class, and the contract lists the members it must answer (`.key`, `.title`, `.attribution`, ...). `Prices::Sources.verify!` refuses a class that lacks one.

## What happened

The first draft listed `.name` as the source's display name. Every Ruby class already answers `.name` (its constant, such as `MTG::Scryfall::PriceQuotes`), so `verify!` could never find it missing: a source that forgot it would have passed and written its class name into `price_sources.name`. The spec review (round 2) caught it; the member became `.title`, as the catalog contract already has.

## What to do next time

When a contract's members are answered by a class (or an object), check each member name against `Class`, `Module`, `Object` and `Kernel` before listing it: `name`, `hash`, `class`, `display`, `method` and `send` are all taken. Use a name nothing answers by default.

## Signals to watch for

A `respond_to?` check as the only test that a member exists; a contract member whose name is a common English noun; a check that passes for a class that defines nothing.
