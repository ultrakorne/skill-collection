#!/usr/bin/env bash
# .herdr/setup.sh — provision a fresh idle_collect worktree.
#
# Run with CWD = the new worktree. `wt` (herdr-kit/new-worktree.sh) does this for
# you, or run it by hand right after `herdr worktree create` / `git worktree add`.
#
# This is the ONE place per-repo worktree setup lives — the generic launcher holds
# nothing project-specific and calls straight into here. Herdr has no post-create
# hook, so a wrapper (or you) invokes this after the worktree exists.
set -euo pipefail

# Idempotency is OURS to decide: the launcher always calls this, because only this
# script knows what "already provisioned" means for a Vite/npm repo.
[ -d node_modules ] && { echo "already provisioned (node_modules present) — skipping setup."; exit 0; }

MAIN="$(git worktree list --porcelain | awk 'NR==1{print $2}')"   # main checkout path

# .env.local is gitignored, so a fresh worktree doesn't have it (see AGENTS.md).
cp "$MAIN/.env.local" .env.local 2>/dev/null || true

# Dependencies are gitignored and NOT shared across worktrees. Install an
# isolated copy so this worktree's Vite cache (node_modules/.vite) can't collide
# with the main checkout's when both dev servers run at once.
#
# Fast alternative — instant, but shares Vite cache with main (only safe if you
# won't run both dev servers concurrently):
#   ln -sfn "$MAIN/node_modules" node_modules
#
# Keep the install quiet: hide the "added N packages / funding / audit" noise and
# buffer everything to a log. Only spill the log if npm actually fails.
LOG="$(mktemp)"
if ! npm ci --no-audit --no-fund --loglevel=error >"$LOG" 2>&1; then
  cat "$LOG" >&2
  rm -f "$LOG"
  exit 1
fi
rm -f "$LOG"
