---
name: github-comment-tool-mangles-mentions
description: The GitHub comment tool rewrites @mentions (`@dependabot rebase` became `·@·d·ependabot r·ebase`), so a Claude session can't command a bot from a comment; the maintainer posts it
metadata:
  type: reference
---

In the 2026-11-03 session, four comments reading `@dependabot rebase` were posted on Dependabot's pull requests with `mcp__github__add_issue_comment`. Reading them back showed the stored body as `·@·d·ependabot r·ebase`, Dependabot never reacted, and the pull requests kept their old head commits. The maintainer posted the commands by hand, and all four rebased.

**Why:** the tool (or the harness around it) defangs `@name` text so a session can't notify someone by accident, and a bot command is the same text. The system rule for this repository's sessions is to write a bare `@name` only for a real login you mean to notify; here the intent was right and the delivery still failed.

**How to apply:** don't plan a step that depends on a comment command (`@dependabot rebase`, `recreate`, `ignore`, or another bot's) landing from this session. Read the comment back once to see whether it was mangled, don't repost it (it comes out the same), and don't try to get past the rewriting. Tell the maintainer exactly what to post and on which pull requests, as one list, early. Alternatives that don't need the command: merging the base into the branch with the update-branch API (it puts a commit on Dependabot's branch, so Dependabot usually stops managing that pull request; ask first), or asking the maintainer to do the rebase from the web page. Related: [[cloud-session-github-limits]].
