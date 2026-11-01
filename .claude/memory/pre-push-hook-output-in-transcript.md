---
name: pre-push-hook-output-in-transcript
description: A push's PreToolUse hook runs before the command, so `time git push` and the background output show only the push; read the hook's Pre-push line and bin/ci result from the session transcript's hook_success record
metadata:
  type: reference
---

A PreToolUse hook runs before the Bash command, and its output isn't in the command's output.

- **What the push shows:** a background `time git push … | tail -3` reports a couple of seconds and the `->` ref line, even when the hook ran a 9-minute `bin/ci` first.
- **2026-10-31 (spec 035):** a 2-second push looked as if the hook hadn't run. It had: `bin/ci` passed, 2,357 examples.
- **The output is recorded in the transcript:** each hook result is a JSON line in `~/.claude/projects/<project dir>/<session id>.jsonl`, with `attachment.type` `hook_success` or `hook_blocking_error`. The line carries `toolUseID` and the hook's `stderr`.

**How to apply:** after a background push's notification, read the push's own output for the ref line. Then pull the hook's verdict from the transcript by the push call's tool-use ID:

```sh
f=~/.claude/projects/-home-user-Collector/<session>.jsonl
grep '<toolu_id>' "$f" | python3 -c "
import sys,json,re
for l in sys.stdin:
  a=(json.loads(l).get('attachment') or {}); e=re.sub(r'\x1b\[[0-9;]*m','',a.get('stderr',''))
  if 'Pre-push' in e: print('\n'.join(x for x in e.splitlines() if re.search(r'Pre-push|examples,|Continuous Integration',x)))"
```

- **A blocked push** returns the hook's whole output as the tool's error. The transcript isn't needed then.
- **The line to look for** is the hook's `Pre-push: running bin/ci[ checks] in <dir> (<reason>)`. It says which group ran and why.

Related: [[push-in-background]] (its 2026-10-31 correction), [[hooks-need-repo-project-dir]], [[pre-push-hook-trigger-text]].
