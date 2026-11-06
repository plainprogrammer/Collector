---
name: parallel-bin-ci-tmpdir-race
description: With several worktrees running bin/ci at once, "Upgrade::Harness removes its temporary directory" can fail on the shared $TMPDIR (#178); push again, don't debug
metadata:
  type: project
---

`spec/script/upgrade/harness_spec.rb` "removes its temporary directory" compares `Dir.glob("$TMPDIR/upgrade-smoke*")` before and after, and `$TMPDIR` is machine-wide, so another worktree's `bin/ci` running at the same time can leave a directory in the window and fail it. Seen in spec 039's pre-push hook on 2026-11-06 while four Orca workers ran; the file passed alone and the retried push went through. Filed as [#178](https://github.com/plainprogrammer/Collector/issues/178).

**Why:** a red pre-push gate looks like a branch failure; this one isn't, and fixing it belongs to #178, not to whatever branch tripped it.

**How to apply:** if that one example fails while other worktrees run `bin/ci`, run `bin/rspec spec/script/upgrade/harness_spec.rb` alone to confirm, push again, and cite #178. Delete this memory once #178 is fixed. Related: [[reproduce-ci-with-seed]].
