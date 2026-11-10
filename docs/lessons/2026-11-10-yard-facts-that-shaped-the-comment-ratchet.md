---
date: 2026-11-10
spec: 056 (#264)
tags: [yard, ci, tooling, testing]
---

# Lesson: what YARD 0.9.45 and the suite did that changed the design of the comment ratchet

## Context

Spec 056 adds a `bin/ci checks` step (`script/yard/comment_ratchet.rb`) that fails a branch adding or changing a public class, module or method with no comment. It parses the judged files with YARD at the head and at the merge base and compares each object's text by name. Two spec reviews, two plan reviews, a code review and two implementation reviews (all Opus, read-only) found the facts below; each one fixed a bug or corrected a statement the spec had made.

## What happened

- **A detached `HEAD` is the normal case on GitHub.** The pull request checkout is a merge commit, so the base can't be `Collector::PushScope`'s "refuse a detached `HEAD`" rule; it is `git merge-base HEAD origin/main` whatever `HEAD` is, and a shallow clone is refused because its merge base can't be trusted.
- **YARD attaches a comment to the namespace above it.** A header comment written above `module Collector` documents `Collector`, not the class the file defines, so the check says so for a nested class.
- **`@private` and `@!visibility private` leave an empty docstring or make the method private.** Only the `private` keyword and `@api private` are exemptions; the directive must be read from `docstring.all`, not from `visibility`.
- **A `Struct.new` or `Data.define` held in a constant is registered as a class**, with its block's methods; methods inside `RSpec.configure` blocks, `scope`, `define_method` and `delegate` are not registered at all.
- **`(see Other#method)` leaves an empty docstring while the target is unresolved and the target's text once it is in the registry**, so the check parses every scoped file at the head, not only the changed ones.
- **YARD drops a file it can't read and says so only at WARN.** An encoding error silently removed a whole changed file; with the logger at FATAL the check passed. The fix is YARD's `SourceParser.after_parse_file` callback (it runs only for files that parsed, empty ones included); `after_parse_file` returns the callbacks array, not the block, so keep your own `proc` to delete.
- **`YARD::DocstringParser#parse` executes `@!parse` directives**, re-parsing code into the live registry under the file name `(stdin)` while the check iterates it; reading a class's summary from its raw comment lines must not run directives.
- **YARD's `docstring` for a class is the last definition's**, so "a class defined in two files passes if any definition has a summary" can't use it alone; and its `@api` tag looks up through enclosing namespaces, so `@api private` on a class covers its members.
- **A new spec file that `require`s a development-only gem loads it into the RSpec process.** The plan assumed another spec already did; none did, and spec 054 AC-3.7 (`defined?(YARD)` is nil after the app boots) failed in the first full run. That example now boots the app in a fresh process.

## What to do next time

Before a plan says "this is already loaded in the suite", grep for it. When a check passes on a condition it can't see (a dropped file, a missing base), treat it as a bug in the check, not a known limit: a gate that silently passes where it can't see is the failure mode to design out first. Probe the library's behaviour with a throwaway script before writing the spec's decisions, as spec 054's lesson says; every correction to spec 056's text (v1.2.1 to v1.2.3) came from a probe.

## Signals to watch for

- `bin/ci checks` printing a backtrace from `script/yard/comment_ratchet.rb` instead of an offender line.
- A changed file under `app/models/`, `lib/` or `spec/support/` that the step reports nothing for although it holds an uncommented public method.
- `defined?(YARD)` true in the suite's process (a spec that requires the gem).
