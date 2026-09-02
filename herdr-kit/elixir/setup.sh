#!/usr/bin/env bash
# .herdr/setup.sh — provision a fresh Phoenix/Elixir worktree. Linux and macOS.
#
# Run with CWD = the new worktree. `wt` (herdr-kit/new-worktree.sh) does this for
# you, or run it by hand right after `herdr worktree create` / `git worktree add`.
#
# This is the .herdr entry point and it is SELF-CONTAINED: the launcher is generic
# and holds nothing stack-specific, so everything a Phoenix worktree needs lives
# here. Nothing below is app-specific — drop this file into any phx.new-shaped repo
# as-is. Gitignored paths don't follow `git worktree add`, so we recreate them from
# the main checkout:
#   - .env.local — seeded from main (whatever secrets live there), plus a unique
#     PORT so a dev server started here never collides with another worktree's.
#     Main's own PORT line is dropped rather than left to be shadowed, and any
#     localhost URL naming a port in the human band (4000-4199) — an OAuth
#     redirect_uri, say — is repointed at THIS worktree, so a login round-trip
#     comes back here instead of to main's server.
#     config/runtime.exs reads PORT (default 4000) in EVERY env, not just prod, and
#     ./dev-server.sh sources .env.local before starting Phoenix.
#   - .mcp.json / opencode.jsonc — copied with their Tidewave URL repointed at THIS
#     worktree's port, so the agent's MCP talks to its own dev server rather than
#     the main checkout's.
#   - deps/ and _build/ — cloned from main so mix doesn't refetch and recompile from
#     cold (hundreds of MB, minutes).
#   - assets/node_modules — the moment a JS hook imports a real npm package rather
#     than something vendored in assets/vendor, esbuild can't resolve it without
#     this and the dev server's esbuild watcher fails on every rebuild — no app.js.
#   - node_modules — the repo-root one, if the repo has it (Playwright and friends),
#     so npm-driven test tasks work here too. Playwright's browsers live in a shared
#     per-user cache, so only the package tree needs copying.
#   - priv/static/assets — the built js/css. Dev regenerates it via the esbuild and
#     tailwind watchers, but a MIX_ENV=test server (what Playwright boots) has no
#     watchers, so an empty dir there means every browser test loads a JS-less page.
# Each is skipped if the main checkout doesn't have it, so a repo that uses only
# some of them gets only those.
#
# Clone strategy, portable across both platforms: `cp -a --reflink=auto` is GNU cp
# and gives copy-on-write on btrfs/xfs; `cp -Rc` is BSD/macOS cp and gives APFS
# clonefile. They are NOT interchangeable — GNU cp rejects -c outright and BSD cp
# has no --reflink — so we try both and keep rsync as the last resort.
#
# Provisioning is best-effort: a step that fails warns on stderr and leaves the
# worktree usable rather than aborting it.
set -euo pipefail

# Idempotency is OURS to decide: the launcher always calls this, because only this
# script knows what "already provisioned" means for a Phoenix/Elixir repo. _build is
# the sentinel, which is why it's cloned LAST below — a run that dies partway leaves
# no _build, so the next run redoes the work instead of skipping it.
[ -d _build ] && { echo "already provisioned (_build present) — skipping setup."; exit 0; }

MAIN="$(git worktree list --porcelain | awk 'NR==1{print $2}')"   # main checkout path
[ -n "$MAIN" ] && [ -d "$MAIN" ] || { echo "setup: could not resolve main checkout" >&2; exit 1; }

# --- port ---------------------------------------------------------------------
# Agent worktrees get 4201-4299, well clear of the 4000-4199 band a human's own
# checkouts use. 4201 is deliberately the same base Claude Code's WorktreeCreate
# hook uses: `wt` and that hook both create worktrees under .claude/worktrees/, so
# a divergent base would hand the same port to two live worktrees. A port is taken
# if another worktree's .env.local reserved it or something is already listening.
USED="$(grep -hs '^PORT=' "$MAIN"/.claude/worktrees/*/.env.local | cut -d= -f2 || true)"

port_taken() {
  printf '%s\n' "$USED" | grep -qx "$1" && return 0
  command -v lsof >/dev/null 2>&1 && lsof -nP -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1 && return 0
  return 1
}

PORT=4201
while [ "$PORT" -lt 4299 ] && port_taken "$PORT"; do
  PORT=$((PORT + 1))
done
port_taken "$PORT" && echo "WARN: no free port in 4201-4299; using $PORT anyway" >&2

# --- .env.local ---------------------------------------------------------------
if [ -f "$MAIN/.env.local" ]; then
  # Drop main's PORT (ours is appended below) and repoint any localhost URL that
  # names an app port at this worktree. Restricting the rewrite to the 4000-4199
  # human band is what keeps the infrastructure URLs untouched — a DATABASE_URL on
  # 5433 or a redis on 6379 must still point where it always did. The second
  # expression is the end-of-line case; the first refuses to match a longer port
  # (41000 is a real port, and `localhost:4100` must not rewrite the head of it).
  { grep -v '^PORT=' "$MAIN/.env.local" || true; } \
    | sed -E -e "s|localhost:4[01][0-9][0-9]([^0-9])|localhost:$PORT\1|g" \
             -e "s|localhost:4[01][0-9][0-9]$|localhost:$PORT|" \
    >.env.local
else
  echo "WARN: no $MAIN/.env.local to seed from — starting an empty one." >&2
  : >.env.local
fi
printf '\n# PORT assigned by .herdr/setup.sh — unique to this worktree.\nPORT=%s\n' "$PORT" >>.env.local \
  || echo "WARN: could not write PORT to .env.local — dev server will default to 4000" >&2

# --- .mcp.json / opencode.jsonc -------------------------------------------------
# Match any port, so this keeps working whatever port the main checkout sits on.
for cfg in .mcp.json opencode.jsonc; do
  [ -f "$MAIN/$cfg" ] || continue
  sed "s|localhost:[0-9]*/tidewave/mcp|localhost:$PORT/tidewave/mcp|g" "$MAIN/$cfg" >"$cfg" \
    || echo "WARN: could not repoint Tidewave in $cfg" >&2
done

# --- gitignored build/dependency trees ------------------------------------------
# _build stays LAST: it's the provisioned-sentinel checked at the top, so a run that
# dies partway leaves no _build and the next run redoes everything.
clone_dir() {   # src dst
  cp -a --reflink=auto "$1" "$2" 2>/dev/null && return 0   # GNU cp: CoW on btrfs/xfs
  rm -rf "$2"
  cp -Rc "$1" "$2" 2>/dev/null && return 0                 # BSD cp: APFS clonefile
  rm -rf "$2"
  rsync -a "$1/" "$2/" 2>/dev/null && return 0
  rm -rf "$2"
  return 1
}

for dir in node_modules assets/node_modules priv/static/assets deps _build; do
  src="$MAIN/$dir"
  [ -d "$src" ] || continue
  [ -e "$dir" ] && continue
  mkdir -p "$(dirname "$dir")"
  clone_dir "$src" "$dir" \
    || echo "WARN: could not copy $dir — recreate it here ('mix deps.get', 'npm install', 'mix assets.build')." >&2
done

echo "worktree provisioned: $(pwd) (PORT=$PORT)"
