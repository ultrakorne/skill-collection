#!/usr/bin/env bash
# .herdr/setup.sh — provision a fresh Go worktree. Linux and macOS.
#
# Run with CWD = the new worktree. `wt` (herdr-kit/new-worktree.sh) does this for
# you, or run it by hand right after `herdr worktree create` / `git worktree add`.
#
# This is the .herdr entry point and it is SELF-CONTAINED: the launcher is generic
# and holds nothing stack-specific, so everything a Go worktree needs lives here.
# Nothing below is app-specific beyond the config block — drop this into any Go repo
# and set BINARY/BUILD_TARGET.
#
# A Go repo needs strikingly little compared to the Phoenix/npm ones, and it's worth
# saying why, so nobody comes looking for the missing sections:
#
#   - NO deps to clone. Go's module cache (GOMODCACHE, ~/go/pkg/mod) and build cache
#     (GOCACHE, ~/.cache/go-build) are per-USER, not per-checkout, so every worktree
#     shares them the moment it exists. There is no deps/ or node_modules/ to copy —
#     the equivalent is already warm. `go mod download` below is only for the case
#     where this branch's go.mod adds something the cache hasn't seen.
#
#   - NO secrets to copy, in the usual case. Go repos typically gitignore only build
#     output (/bin/, /dist/, *.test), and a binary built from another branch is worse
#     than no binary. If this repo does have a gitignored .env or credentials file,
#     add it to FILES_TO_COPY below.
#
#   - NO port to allocate, for a CLI. A Go SERVER repo is the exception: give it the
#     port block from the elixir/ or npm_js/ template — pick from a high band, check
#     both sibling worktrees' env files and what's actually listening, and write the
#     result where the app reads it.
#
#   - NO mise trust step, when mise.toml is a plain [tools] pin: mise treats that as
#     a safe config and shares trust across worktrees of the same repo anyway.
#
# What's left is: warm the module cache, and build the binary so the worktree starts
# out with something runnable.
#
# Provisioning is best-effort: a step that fails warns on stderr and leaves the
# worktree usable rather than aborting it.
set -euo pipefail

# --- project config -----------------------------------------------------------
# BINARY is BOTH the build output and the provisioned-sentinel, so point it at
# whatever BUILD_TARGET actually writes. BUILD_TARGET goes through the Makefile
# rather than reimplementing the command: -ldflags that stamp version/API/app name
# are usually duplicated in .goreleaser.yaml already, and a third copy here would be
# a third thing to keep in sync. A repo with no Makefile can set
# BUILD_CMD=(go build -o bin/foo ./cmd/foo) instead.
BINARY="bin/myapp"
BUILD_TARGET="build"
FILES_TO_COPY=()   # gitignored paths to seed from the main checkout, e.g. (".env.local")

# Idempotency is OURS to decide: the launcher always calls this, because only this
# script knows what "already provisioned" means for a Go repo. The binary is the
# sentinel, and it's built LAST — `go build` only writes its -o target on success, so
# a run that dies partway leaves no binary and the next run redoes the work.
[ -f "$BINARY" ] && { echo "already provisioned ($BINARY present) — skipping setup."; exit 0; }

MAIN="$(git worktree list --porcelain | awk 'NR==1{print $2}')"   # main checkout path
[ -n "$MAIN" ] && [ -d "$MAIN" ] || { echo "setup: could not resolve main checkout" >&2; exit 1; }

WT="$(pwd)"
echo "Provisioning worktree: $WT"

# --- gitignored files from main -----------------------------------------------
# Best-effort and never clobbering. The ${arr[@]+...} guard is load-bearing: on
# macOS's stock bash 3.2 a plain "${arr[@]}" on an EMPTY array trips `set -u`, and
# the array is empty in most Go repos.
for rel in ${FILES_TO_COPY[@]+"${FILES_TO_COPY[@]}"}; do
  if [ -f "$MAIN/$rel" ] && [ ! -e "$WT/$rel" ]; then
    mkdir -p "$(dirname "$WT/$rel")"
    cp "$MAIN/$rel" "$WT/$rel"
    echo "  - copied $rel"
  else
    echo "  - skip $rel (source missing or already present)"
  fi
done

# --- toolchain ----------------------------------------------------------------
# The Go version is typically pinned in mise.toml. A shell with `mise activate` in
# its profile already has it on PATH, which is the normal case since `wt` runs this
# from your shell — but a cron/CI/bare-sh caller doesn't, and would otherwise fail
# here with a bare "go: command not found". `mise exec --` puts the pinned toolchain
# on PATH for one command, so both callers take the same path through the rest of
# the script. Same empty-array guard as above at each expansion.
RUN=()
if ! command -v go >/dev/null 2>&1; then
  if command -v mise >/dev/null 2>&1; then
    RUN=(mise exec --)
    echo "  - go not on PATH; running through 'mise exec'."
  else
    echo "setup: no go on PATH and no mise to provide it — install one, then re-run this script." >&2
    exit 1
  fi
fi

# --- module cache -------------------------------------------------------------
# Usually a no-op (the cache is shared and already warm from the main checkout); it
# only does real work when this branch's go.mod pulls in something new. Doing it here
# means the first `go build`/`go test` in the pane isn't a surprise download.
${RUN[@]+"${RUN[@]}"} go mod download \
  || echo "WARN: 'go mod download' failed — deps will be fetched on first build." >&2

# --- build --------------------------------------------------------------------
# Deliberately NOT an `install` target: a worktree silently replacing the binary on
# your PATH is a nasty surprise. Install from here by hand when you mean to.
if ! command -v make >/dev/null 2>&1; then
  echo "WARN: make not found — skipping the build. Run 'make $BUILD_TARGET' once it's installed." >&2
elif ! ${RUN[@]+"${RUN[@]}"} make "$BUILD_TARGET"; then
  echo "WARN: 'make $BUILD_TARGET' failed — the worktree is usable, but fix the build before relying on it." >&2
fi

echo "worktree provisioned: $WT"
[ -f "$BINARY" ] && echo "  binary: $WT/$BINARY"
