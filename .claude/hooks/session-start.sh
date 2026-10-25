#!/bin/bash
# SessionStart hook for Claude Code cloud sessions: makes the project's specs and linters runnable.
# Idempotent and non-interactive; the container state is cached after it finishes.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel)}"

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
