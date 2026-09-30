---
name: phone-lan-dev-access
description: Reaching a dev or spike server from the maintainer's iPhone on the LAN — address, firewall already open, browser is Brave (WebKit), camera needs HTTPS
metadata:
  type: reference
---

**Facts** (checked 2026-09-30 during spec 005):
- **Dev machine:** `192.168.1.76` on `ens3`. The DHCP-assigned address may change, so check it with `ip -4 -o addr show scope global`.
- **Firewall:** the active zone is `FedoraWorkstation`, which already allows TCP and UDP 1025–65535. A server bound to `0.0.0.0` on a high port is reachable from the phone as-is, with no `firewall-cmd` needed.
  - `bin/dev` and the Rails server bind to `127.0.0.1` by default. Pass `-b 0.0.0.0` to reach them from the phone.
- **Phone:** the iPhone was at `192.168.1.22`, running iOS 18.7. The maintainer's browser was **Brave**, which on iOS is WebKit. The user agent ends in `Brave`.
- **Camera:** iOS browsers only allow `getUserMedia` in a secure context. Over plain HTTP on the LAN, use a photo picker (`<input type=file accept=image/*>`). A live camera needs HTTPS.
- **Photo names:** the iOS photo picker renames picked files, typically to `image.jpeg`.

**Why:** these were found by probing during the Phase 0 iPhone timing run. The plan's `firewall-cmd` step turned out to be unnecessary.

**How to apply:** for on-device checks, bind to `0.0.0.0`, give the maintainer `http://<dev-ip>:<port>/…`, and record the phone's IP and user agent from the server log. Ask for Safari explicitly if a Safari-specific result matters. Related: [[card-scanner-direction]].
