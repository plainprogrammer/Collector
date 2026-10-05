---
name: device-sitting-account-check
description: Before scoring or resetting a device sitting, check which account actually holds the scanner sitting; the phone may be signed in as someone else
metadata:
  type: feedback
---

In spec 009's live sitting (2026-10-04) the plan said the maintainer would sign in on the iPhone as `sitting@localhost`, but the phone was signed in as `findings@localhost`. Two things went wrong:
- The reset checked only `sitting@localhost`, so the first attempt's adds stayed in `findings@localhost`'s sitting and collection.
- The first `scanner:sitting_findings` run scored 0/35 "not added".

**Why:** the sitting report finds entries by account plus reading key, and nothing tied the phone to the planned account.

**How to apply:** before a device sitting, and before scoring or resetting one, run `Scanner::Sitting.includes(:account)` and match the capture files' reading keys against `Scanner::SittingEntry` to find the account that holds the sitting. Then pass that account's email as `SCANNER_EMAIL`. When resetting, move the run directory aside and end or clear that account's sitting. Related: [[card-scanner-direction]], [[phone-lan-dev-access]].
