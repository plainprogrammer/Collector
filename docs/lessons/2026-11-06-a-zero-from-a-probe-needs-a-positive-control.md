---
date: 2026-11-06
issue: "217"
tags: [debugging, probes, evidence]
---

# Lesson: a probe that finds nothing is evidence only if it can find something

## Context

While working [#217](https://github.com/plainprogrammer/Collector/issues/217) the pipe `curl | grep -q` (see [the pipe lesson](2026-11-06-a-pipe-into-grep-q-fails-under-pipefail.md)) had one probe that failed at once, 300 of 300, and a second, shaped like the real page, that did not.

## What happened

The second probe served a 13,516-byte page split in two writes and ran the check 100 times per case: 0 false failures even at a 12,000-byte split with a 10 ms gap. Read at face value that refuted the hypothesis. Two properties of the probe, not of the hypothesis, caused it: the fake page was one line with no newline, so grep had to read to the end of the line before it could match and had consumed everything by then; and the host's grep was BSD grep, which buffers. Giving the page lines still gave 0 on the host. Only running the same probe with GNU grep, in the collector image, gave a failure (100 of 100 at 13,000, 2 of 100 at 12,000).

## What to do next time

- Run a probe first against a case known to fail (here the 200 KB page, which failed on every run) and against the exact tool CI uses, before reading a zero as a result.
- Check the probe's shape against the real thing (lines, sizes, how the data arrives) and list what it does not model in the write-up.
- State the result as what was shown: here the mechanism was proven and the CI trigger was not, so the issue was referenced, not closed.

## Signals to watch for

- A clean result from a probe written in a few minutes, run with the host's tools instead of the CI's.
- Any "0 failures in N" that the write-up uses to rule out a hypothesis, with no run in which the probe was shown able to fail.
