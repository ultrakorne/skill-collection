#!/usr/bin/env bash
# .herdr/setup.sh — provision a fresh chat_app (Phoenix/Elixir) worktree.
#
# Run with CWD = the new worktree. `wt` (herdr-kit/new-worktree.sh) does this for
# you, or run it by hand right after `herdr worktree create` / `git worktree add`.
#
# This is the .herdr entry point and it is SELF-CONTAINED: the launcher is generic
# and holds nothing project-specific, so everything a chat_app worktree needs lives
# here. Gitignored files don't follow `git worktree add`, so we recreate them from
# the main checkout:
#   - .env.local — seeded from main (the WorkOS/FCM secrets), plus a unique PORT so
#     a dev server started here never collides with another worktree's.
#     config/runtime.exs reads PORT (default 4000) in EVERY env, not just prod, and
#     ./dev-server.sh sources .env.local before starting Phoenix.
#   - .mcp.json — copied with its Tidewave URL repointed at THIS worktree's port, so
#     the agent's MCP talks to its own dev server rather than master's on 4000.
#   - deps/ and _build/ — cloned from main so mix doesn't refetch and recompile
#     ~365MB from cold. cp -Rc uses APFS clonefile (instant, copy-on-write);
#     rsync is the fallback.
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
# Port map for this repo: master 4000, taskNN 4001-4099, develop 4100. Agent
# worktrees start at 4201 — the same base .claude/hooks/claude-worktree.sh uses,
# and deliberately so: `wt` and Claude Code's WorktreeCreate hook both create
# worktrees under .claude/worktrees/, so a divergent base would hand the same port
# to two live worktrees.
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
  cp "$MAIN/.env.local" .env.local
else
  echo "WARN: no $MAIN/.env.local to seed from — starting an empty one." >&2
  : >.env.local
fi
printf '\n# PORT assigned by .herdr/setup.sh — unique to this worktree.\nPORT=%s\n' "$PORT" >>.env.local \
  || echo "WARN: could not write PORT to .env.local — dev server will default to 4000" >&2

# --- .mcp.json ----------------------------------------------------------------
# Match any port, not just 4000, so this keeps working if main's .mcp.json moves.
if [ -f "$MAIN/.mcp.json" ]; then
  sed "s|localhost:[0-9]*/tidewave/mcp|localhost:$PORT/tidewave/mcp|g" "$MAIN/.mcp.json" >.mcp.json \
    || echo "WARN: could not repoint Tidewave in .mcp.json" >&2
fi

# --- deps/ and _build/ --------------------------------------------------------
for dir in deps _build; do
  src="$MAIN/$dir"
  [ -d "$src" ] || continue
  [ -e "$dir" ] && continue
  if ! cp -Rc "$src" "$dir" 2>/dev/null; then
    rm -rf "$dir"
    rsync -a "$src/" "$dir/" 2>/dev/null || {
      rm -rf "$dir"
      echo "WARN: could not copy $dir — run 'mix deps.get && mix compile' here." >&2
    }
  fi
done

echo "worktree provisioned: $(pwd) (PORT=$PORT)"
