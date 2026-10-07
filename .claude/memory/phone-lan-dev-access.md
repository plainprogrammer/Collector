---
name: phone-lan-dev-access
description: Reaching a dev or spike server from the maintainer's iPhone on the LAN — address, open firewall, Brave (WebKit); camera HTTPS via a self-signed cert + Puma ssl bind (tunnel failed)
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
- **HTTPS that works (2026-10-01, spec 007):** a self-signed certificate for the LAN IP (CA:TRUE, serverAuth, SAN for the IP, ≤ 398 days), kept outside the repo in `~/.local/share/collector-dev-https/`, served by Puma directly: `bin/dev -b "ssl://0.0.0.0:<port>?key=<dir>/dev.key&cert=<dir>/dev.crt"`. No app change, and no `COLLECTOR_HTTPS` is needed, since Rails sees real HTTPS. The phone installs the cert once (Safari download → install the profile → Certificate Trust Settings → full trust).
  - The machine has **no `openssl` CLI**, so generate certificates with Ruby's `OpenSSL` stdlib.
  - Serve only the `.crt` (never the key) as `application/x-x509-ca-cert` on a separate high port for the phone to download.
- **The Cloudflare tunnel failed** with a 502 for `collector.thomps.onl`. No request ever reached Rails, although the maintainer's other hosts work through the same setup, and the cause wasn't found. Don't default to it.
- **The user agent's iOS version is frozen:** Brave on iOS reports "iPhone OS 18_7" even on iOS 26.6.1 (spec 010, 2026-10-05). Read the real version from `Version/…` in the user agent (`Version/26.6.1`), and report both.
- **Desktop Brave with the iPhone as a Continuity Camera webcam** works for scanning. It doesn't count as the on-phone device checks.

**Why:** these were found by probing during the Phase 0 iPhone timing run. The plan's `firewall-cmd` step turned out to be unnecessary.

**How to apply:** for on-device checks, bind to `0.0.0.0`, give the maintainer `http://<dev-ip>:<port>/…`, and record the phone's IP and user agent from the server log. Ask for Safari explicitly if a Safari-specific result matters. Related: [[card-scanner-direction]].
