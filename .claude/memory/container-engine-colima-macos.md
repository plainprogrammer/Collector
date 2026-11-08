---
name: container-engine-colima-macos
description: On the macOS arm64 dev machine there is no podman; docker 29 runs through colima (shares only $HOME); anonymous ghcr pull of edge is denied; macOS mktemp -d ignores TMPDIR, so bin/backup-smoke needs a mktemp shim
metadata:
  type: reference
---

Checked 2026-11-06 while working #217 (macOS, Darwin, arm64):

- **No podman.** `podman` isn't on the PATH. `/opt/homebrew/bin/docker` (client 29.x) talks to a running colima VM (`colima status`: aarch64, `docker` runtime, virtiofs, 4 CPUs, 8 GiB). `bin/backup-smoke` and `bin/image-smoke` pick docker when present, so they run as on CI; put `/opt/homebrew/bin` on the PATH.
- **The VM shares only `$HOME`.** A bind mount of a path outside it (macOS's `mktemp -d` makes `/var/folders/…`) comes up empty and silently, so `bin/backup-smoke` fails at "placing the file in the host directory failed". `mktemp -d` ignores `TMPDIR` on macOS. Run the smoke with a `mktemp` shim ahead of the real one on the PATH that makes the directory under the worktree (`/usr/bin/mktemp -d "$worktree/tmp/…/work/tmp.XXXXXXXX"`).
- **`docker pull ghcr.io/plainprogrammer/collector:edge` is denied** ("error from registry: denied"), though the package is public. On 2026-11-08 the coordinator found anonymous registry access works: a pull token, then the `edge` and `latest` manifests, return 200. `~/.docker/config.json` holds a saved `ghcr.io` login, so Docker sends those credentials instead of pulling anonymously. A stale or under-scoped token is the likely cause (inferred; a pull with an empty config wasn't run). The likely fix is `docker logout ghcr.io`, or a new login with `read:packages`; that's the maintainer's machine. Until then, build locally: `docker build -t collector:smoke .`, then `bin/backup-smoke collector:smoke`.
- `CLAUDE.md` still says "podman, no Docker on the dev machine"; that is the maintainer's to decide, not edited by #217.

**How to apply:** a brief that says "use podman" or "pull `edge`" doesn't hold on this machine: use docker through colima and a local build, and keep scratch scripts and logs under the worktree's ignored `tmp/` so the VM can see them. Related: [[dev-machine-image-tools]].
