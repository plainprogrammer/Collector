#!/bin/bash
# SessionStart hook for Claude Code sessions.
#
# Cloud sessions (CLAUDE_CODE_REMOTE=true): makes the project's specs and linters runnable. Idempotent and
# non-interactive; the container state is cached after it finishes.
#
# Local sessions (an Orca worker's too, #289): puts .ruby-version's Ruby first on the PATH of the session's
# commands. Orca starts the session with macOS's Ruby 2.6 first, so a bare `ruby` or `bundle` failed with
# "Could not find 'bundler'" (#268's setup fix and #270's hook fix don't reach the model's own commands).
set -euo pipefail

cd "${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}" || exit 0

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  # Ask script/worktree/with_mise (which knows where mise lives, and drops mise's directories from the PATH
  # so it can put them first) which `ruby` it resolves. With --optional, no mise means the session's own ruby,
  # so CI runners, containers and any machine without mise get no change. Only Ruby's directory is added, not
  # the other tools mise has (node, java): this is the Ruby 2.6 problem, not a toolchain switch.
  [ -n "${CLAUDE_ENV_FILE:-}" ] && [ -x script/worktree/with_mise ] || exit 0
  session_ruby="$(command -v ruby 2>/dev/null || true)"
  mise_ruby="$(script/worktree/with_mise --optional sh -c 'command -v ruby' 2>/dev/null || true)"
  case "$mise_ruby" in /*) ;; *) exit 0 ;; esac
  [ "$mise_ruby" != "$session_ruby" ] || exit 0
  # The hook runs again on resume and compact; the line is written once, and is safe to source twice. It tests
  # for the directory *first* in the PATH, not anywhere in it: Orca's login shell keeps mise's directories
  # behind /usr/bin (#268). %q quotes a directory with spaces or shell characters.
  line="$(printf 'case ":$PATH:" in :%q:*) ;; *) export PATH=%q:"$PATH" ;; esac' "$(dirname "$mise_ruby")" "$(dirname "$mise_ruby")")"
  grep -qxF "$line" "$CLAUDE_ENV_FILE" 2>/dev/null || echo "$line" >> "$CLAUDE_ENV_FILE"
  exit 0
fi

RUBY_VERSION="$(tr -d '[:space:]' < .ruby-version | sed 's/^ruby-//')"
export RBENV_ROOT="${RBENV_ROOT:-/opt/rbenv}"
export PATH="$RBENV_ROOT/shims:$RBENV_ROOT/bin:$PATH"

# 1. Ruby. The image's default Ruby is older than .ruby-version, so build the pinned one with rbenv.
if [ ! -x "$RBENV_ROOT/versions/$RUBY_VERSION/bin/ruby" ]; then
  definitions="$RBENV_ROOT/plugins/ruby-build/share/ruby-build"
  build_definition="$RUBY_VERSION"
  if [ ! -e "$definitions/$RUBY_VERSION" ]; then
    # The image's ruby-build can lag behind a new patch release; derive a definition from the closest
    # older one and pin the tarball's checksum (from https://cache.ruby-lang.org/pub/ruby/index.txt).
    case "$RUBY_VERSION" in
      4.0.7) sha256="911ace20f90d068ca0e4dda6d0e4f0f81e52e52f2dd4f4004c721e253412e82d" ;;
      *) echo "No ruby-build definition or pinned checksum for Ruby $RUBY_VERSION; update this hook." >&2; exit 1 ;;
    esac
    base="$(ls "$definitions" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1)"
    build_definition="${TMPDIR:-/tmp}/ruby-build-$RUBY_VERSION"
    sed -E "s|ruby-[0-9.]+\.tar\.gz#[0-9a-f]+|ruby-$RUBY_VERSION.tar.gz#$sha256|; s|ruby-$base|ruby-$RUBY_VERSION|g; s|/ruby/[0-9]+\.[0-9]+/|/ruby/${RUBY_VERSION%.*}/|" \
      "$definitions/$base" > "$build_definition"
  fi
  MAKE_OPTS="-j$(nproc)" RUBY_CONFIGURE_OPTS="--disable-install-doc" \
    "$RBENV_ROOT/plugins/ruby-build/bin/ruby-build" "$build_definition" "$RBENV_ROOT/versions/$RUBY_VERSION"
fi
# .ruby-version names the version "ruby-4.0.7", which is the directory name rbenv looks for.
pinned="$(tr -d '[:space:]' < .ruby-version)"
[ "$pinned" = "$RUBY_VERSION" ] || ln -sfn "$RBENV_ROOT/versions/$RUBY_VERSION" "$RBENV_ROOT/versions/$pinned"
rbenv rehash

# Make the pinned Ruby the one the session's commands use.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  {
    echo "export RBENV_ROOT=\"$RBENV_ROOT\""
    echo "export PATH=\"$RBENV_ROOT/shims:$RBENV_ROOT/bin:\$PATH\""
  } >> "$CLAUDE_ENV_FILE"
fi

# 2. Gems (prefer install over a frozen install: the cached container reuses what is already there).
bundle check >/dev/null 2>&1 || bundle install

# 3. OCR engine (checksum-verified, ignored by git; the scanner specs fail without it).
bin/fetch-ocr-engine

# 4. Databases (development and test).
bin/rails db:prepare
[ ! -f db/schema.rb ] || bin/rails db:test:prepare
