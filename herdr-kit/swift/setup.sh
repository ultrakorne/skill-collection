#!/usr/bin/env bash
# .herdr/setup.sh — provision a fresh 2am.chat (chat-app) Swift/Xcode worktree.
#
# Run with CWD = the new worktree. `wt` (herdr-kit/new-worktree.sh) does this for
# you, or run it by hand right after `herdr worktree create` / `git worktree add`.
#
# This is the ONE place per-repo worktree setup lives — the generic launcher holds
# nothing project-specific and calls straight into here. Herdr has no post-create
# hook, so a wrapper (or you) invokes this after the worktree exists.
set -euo pipefail

# Idempotency is OURS to decide: the launcher always calls this, because only this
# script knows what "already provisioned" means for an Xcode repo. buildServer.json
# is the sentinel: it's generated below and gitignored, so its presence means this
# worktree has been through here.
[ -f buildServer.json ] && { echo "already provisioned (buildServer.json present) — skipping setup."; exit 0; }

# --- project config ---
XCODE_PROJECT="chat-app.xcodeproj"
XCODE_SCHEME="chat-app"

# Gitignored files that live only in the main checkout and must be copied into a
# fresh worktree (secrets etc). Paths are relative to the repo root. Best-effort:
# a missing source is skipped, not an error. (GoogleService-Info.plist is
# committed, so it comes with the checkout and is NOT listed here.)
FILES_TO_COPY=("fastlane/.env")

MAIN="$(git worktree list --porcelain | awk 'NR==1{print $2}')"   # main checkout path
WT="$(pwd)"

echo "Provisioning worktree: $WT"
echo "Main checkout:         $MAIN"

# 1) Copy gitignored secrets/config from main (best-effort, never clobber).
for rel in "${FILES_TO_COPY[@]}"; do
  if [ -f "$MAIN/$rel" ] && [ ! -e "$WT/$rel" ]; then
    mkdir -p "$(dirname "$WT/$rel")"
    cp "$MAIN/$rel" "$WT/$rel"
    echo "  - copied $rel"
  else
    echo "  - skip $rel (source missing or already present)"
  fi
done

# 2) Regenerate the SourceKit-LSP build server config so editor autocompletion /
#    diagnostics work in THIS worktree. buildServer.json (gitignored) embeds
#    absolute paths (project + DerivedData), so it must be regenerated per
#    worktree, not copied from main.
if command -v xcode-build-server >/dev/null 2>&1; then
  echo "  - generating buildServer.json (xcode-build-server)..."
  xcode-build-server config -project "$XCODE_PROJECT" -scheme "$XCODE_SCHEME" >/dev/null \
    || echo "  - warning: xcode-build-server config failed; LSP may be degraded."
else
  echo "  - info: xcode-build-server not installed; skipping buildServer.json (brew install xcode-build-server)."
fi

# 3) Pre-resolve SPM dependencies from the committed Package.resolved so the first
#    build / index is warm. Non-fatal and skippable (SKIP_SPM_RESOLVE=1). Each
#    worktree gets its own DerivedData (keyed by absolute path), so nothing here
#    can collide with the main checkout or other worktrees.
if [ "${SKIP_SPM_RESOLVE:-0}" != "1" ]; then
  echo "  - resolving Swift package dependencies (set SKIP_SPM_RESOLVE=1 to skip)..."
  xcodebuild -resolvePackageDependencies -project "$XCODE_PROJECT" -scheme "$XCODE_SCHEME" >/dev/null 2>&1 \
    || echo "  - warning: package resolution failed; it will resolve on first build in Xcode."
else
  echo "  - skip SPM resolve (SKIP_SPM_RESOLVE=1)."
fi

echo "worktree provisioned: $WT"
