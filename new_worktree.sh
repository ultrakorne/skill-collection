#!/bin/bash
# version 1.0
# Exit immediately if a command exits with a non-zero status.
set -e

# ANSI colors for terminal warnings.
RED=$'\033[31m'
RESET=$'\033[0m'

# --- Configuration ---
# The directory of your bare repository.
BARE_REPO_DIR=".bare"
# The source worktree from which to copy files and directories.
SOURCE_WORKTREE="master"
# The starting point for new branches.
DEFAULT_BRANCH="master"
# Files to copy to the new worktree.
FILES_TO_COPY=(".mcp.json" ".env.local" "opencode.jsonc")
# Directories to copy to speed up setup. Missing entries are skipped, so the
# same list works across stacks: Elixir (`deps`, `_build`), Node (`node_modules`),
# Go/PHP/Ruby (`vendor`). Avoid caches with embedded absolute paths
# (e.g. Python `.venv`, Rust `target`) — those don't survive a copy.
# These are treated as cache warmups: failures are non-fatal.
DIRS_TO_COPY=("deps" "_build" "node_modules" "vendor")

# `sed -i` takes different args on GNU (Linux) vs BSD (macOS). Detect once.
if sed --version >/dev/null 2>&1; then
  SED_INPLACE=(sed -i)
else
  SED_INPLACE=(sed -i '')
fi

# --- Init Mode ---
# Usage: ./new_worktree.sh --init git@github.com:username/repo-name.git
# Clones a bare repo into .bare, creates a master worktree, and configures fetch/tracking.

if [ "$1" = "--init" ]; then
  REPO_URL="$2"
  if [ -z "$REPO_URL" ]; then
    echo "Usage: $0 --init <git-repo-url>"
    echo "  Example: $0 --init git@github.com:username/repo-name.git"
    exit 1
  fi

  if [ -d "$BARE_REPO_DIR" ]; then
    echo "Error: '$BARE_REPO_DIR' already exists. This project is already initialized."
    exit 1
  fi

  echo "Cloning bare repository from '$REPO_URL'..."
  git clone --bare "$REPO_URL" "$BARE_REPO_DIR"

  echo "Configuring fetch refspec for remote tracking..."
  git --git-dir="$BARE_REPO_DIR" config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"

  echo "Fetching all remote branches..."
  git --git-dir="$BARE_REPO_DIR" fetch origin

  echo "Creating '$SOURCE_WORKTREE' worktree..."
  git --git-dir="$BARE_REPO_DIR" worktree add "$SOURCE_WORKTREE"

  echo "Setting upstream tracking for '$DEFAULT_BRANCH'..."
  git -C "$SOURCE_WORKTREE" branch -u "origin/$DEFAULT_BRANCH"

  echo ""
  echo "Bare repo initialized successfully!"
  echo "  Bare repo:  $BARE_REPO_DIR"
  echo "  Worktree:   $SOURCE_WORKTREE"
  echo ""
  echo "To create feature worktrees, run: $0 <branch-name>"
  exit 0
fi

# --- Script Logic ---

# Check if a branch name was provided.
if [ -z "$1" ]; then
  echo "Usage: $0 <branch-name|worktree-dir>"
  echo "  $0 --init <git-repo-url>  : Initialize a new bare repo workspace."
  echo "  $0 develop                : Create/use the dedicated 'develop' worktree (dir='develop', PORT=4100)."
  echo "  <branch-name>             : Create/use a feature worktree under the next available 'taskNN' (PORT=4000+NN)."
  echo "  <worktree-dir>            : Existing worktree directory ('taskNN' or 'develop') to delete (with confirmation)."
  exit 1
fi

TARGET_DIR=$1
BRANCH_NAME=$1

if [ -d "$TARGET_DIR" ]; then
  if [[ ! "$TARGET_DIR" =~ ^task[0-9][0-9]+$ ]] && [ "$TARGET_DIR" != "develop" ]; then
    echo "Error: deletion is only allowed for worktree folders named like 'taskNN' or 'develop'."
    exit 1
  fi
  echo "Directory '$TARGET_DIR' already exists."
  STATUS_MESSAGE="Not a git worktree or unable to read status."
  if git -C "$TARGET_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    STATUS_WARNINGS=()
    WORKTREE_STATUS=$(git -C "$TARGET_DIR" status --porcelain 2>/dev/null || true)
    if [ -n "$WORKTREE_STATUS" ]; then
      STATUS_WARNINGS+=("Uncommitted changes detected")
    fi

    CURRENT_BRANCH=$(git -C "$TARGET_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
    if [ -n "$CURRENT_BRANCH" ] && [ "$CURRENT_BRANCH" != "HEAD" ]; then
      UPSTREAM_BRANCH=$(git -C "$TARGET_DIR" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)
      if [ -z "$UPSTREAM_BRANCH" ]; then
        STATUS_WARNINGS+=("Branch '$CURRENT_BRANCH' has no upstream (likely local-only / not pushed)")
      else
        AHEAD_COUNT=$(git -C "$TARGET_DIR" rev-list --count "${UPSTREAM_BRANCH}..HEAD" 2>/dev/null || echo "0")
        if [ "$AHEAD_COUNT" -gt 0 ]; then
          STATUS_WARNINGS+=("Branch '$CURRENT_BRANCH' has $AHEAD_COUNT unpushed commit(s)")
        fi
      fi
    fi

    if [ ${#STATUS_WARNINGS[@]} -eq 0 ]; then
      STATUS_MESSAGE="No uncommitted changes and no unpushed commits detected."
    else
      STATUS_MESSAGE="${STATUS_WARNINGS[0]}"
      for warning in "${STATUS_WARNINGS[@]:1}"; do
        STATUS_MESSAGE="$STATUS_MESSAGE; $warning"
      done
      STATUS_MESSAGE="${RED}${STATUS_MESSAGE}.${RESET}"
    fi
  fi
  read -r -p "Delete worktree '$TARGET_DIR'? $STATUS_MESSAGE (y/N): " CONFIRM
  if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    rm -rf "$TARGET_DIR"
    git --git-dir="$BARE_REPO_DIR" worktree prune
    echo "Deleted worktree directory '$TARGET_DIR'."
  else
    echo "Deletion cancelled."
  fi
  exit 0
fi

# Determine target directory and port.
# 'develop' is a special branch that gets its own dedicated worktree dir and port.
if [ "$BRANCH_NAME" = "develop" ]; then
  TASK_DIR="develop"
  TASK_PORT=4100
  echo "Using dedicated 'develop' worktree directory."
  echo "Assigned PORT for this worktree: $TASK_PORT"
else
  # Find the next available 'taskXX' directory.
  i=1
  while true; do
    # Formats the number with a leading zero if it's less than 10 (e.g., 01, 02, ... 10).
    TASK_DIR=$(printf "task%02d" $i)
    if [ ! -d "$TASK_DIR" ]; then
      break
    fi
    i=$((i + 1))
  done

  echo "Found next available worktree directory: $TASK_DIR"
  TASK_NUMBER="${TASK_DIR#task}"
  TASK_PORT=$((4000 + 10#$TASK_NUMBER))
  echo "Assigned PORT for this worktree: $TASK_PORT"
fi

# Fetch latest remote refs so we know about new remote branches.
git --git-dir="$BARE_REPO_DIR" fetch origin

# Check if the branch already exists in the bare repository.
# We use --git-dir to point our git commands to the bare repo.
if git --git-dir="$BARE_REPO_DIR" rev-parse --verify --quiet "refs/heads/$BRANCH_NAME" >/dev/null; then
  echo "Branch '$BRANCH_NAME' already exists locally. Creating worktree from the existing branch."
  git --git-dir="$BARE_REPO_DIR" worktree add "$TASK_DIR" "$BRANCH_NAME"
elif git --git-dir="$BARE_REPO_DIR" rev-parse --verify --quiet "refs/remotes/origin/$BRANCH_NAME" >/dev/null; then
  echo "Branch '$BRANCH_NAME' found on remote. Creating worktree tracking the remote branch."
  git --git-dir="$BARE_REPO_DIR" worktree add "$TASK_DIR" "$BRANCH_NAME"
else
  echo "Branch '$BRANCH_NAME' does not exist. Creating a new branch from '$DEFAULT_BRANCH'."
  git --git-dir="$BARE_REPO_DIR" worktree add -b "$BRANCH_NAME" "$TASK_DIR" "$DEFAULT_BRANCH"
fi

echo "Successfully created worktree for branch '$BRANCH_NAME' in '$TASK_DIR'."

# --- Set Upstream Tracking ---
echo "Attempting to set up upstream tracking..."
(
  cd "$TASK_DIR"
  # Check if the remote branch exists. The command exits with 0 if it exists, 1 if not.
  if git ls-remote --exit-code --heads origin "$BRANCH_NAME" >/dev/null 2>&1; then
    echo "  - Remote branch 'origin/$BRANCH_NAME' found. Setting up tracking."
    if git branch --set-upstream-to="origin/$BRANCH_NAME" "$BRANCH_NAME" 2>/dev/null; then
      echo "  - Branch '$BRANCH_NAME' is now tracking 'origin/$BRANCH_NAME'."
    else
      echo "  - Warning: Could not set upstream tracking. You can set it manually with:"
      echo "    git branch --set-upstream-to=origin/$BRANCH_NAME $BRANCH_NAME"
    fi
  else
    echo "  - No remote branch 'origin/$BRANCH_NAME' found."
    echo "  - This is expected for a new feature branch."
    echo "  - To publish this branch and set up tracking, run the following from inside the '$TASK_DIR' directory:"
    echo "    git push --set-upstream origin $BRANCH_NAME"
  fi
) # This subshell isolates the 'cd' so we don't have to 'cd ..'

# --- File & Directory Synchronization ---

echo "Copying configuration and dependency files from '$SOURCE_WORKTREE'..."

FAILED_DIR_SYNCS=()

# Copy specified files.
for file in "${FILES_TO_COPY[@]}"; do
  if [ -f "$SOURCE_WORKTREE/$file" ]; then
    echo "  - Copying $file..."
    cp "$SOURCE_WORKTREE/$file" "$TASK_DIR/"
  else
    echo "  - Warning: Source file '$SOURCE_WORKTREE/$file' not found. Skipping."
  fi
done

# Always write PORT to .env.local so dev-server.sh picks it up, even if no
# source .env.local existed in the source worktree.
if [ -f "$TASK_DIR/.env.local" ]; then
  echo "  - Appending PORT to existing .env.local (PORT=$TASK_PORT)..."
else
  echo "  - Creating .env.local with PORT=$TASK_PORT..."
fi
printf '\nPORT=%s\n' "$TASK_PORT" >> "$TASK_DIR/.env.local"

# Update MCP config files with the worktree-specific port
for mcp_file in ".mcp.json" "opencode.jsonc"; do
  if [ -f "$TASK_DIR/$mcp_file" ]; then
    echo "  - Updating port in $mcp_file (localhost:4000 -> localhost:$TASK_PORT)..."
    "${SED_INPLACE[@]}" "s|localhost:4000|localhost:$TASK_PORT|g" "$TASK_DIR/$mcp_file"
  fi
done

# Copy specified directories using rsync for efficiency.
for dir in "${DIRS_TO_COPY[@]}"; do
  if [ -d "$SOURCE_WORKTREE/$dir" ]; then
    echo "  - Syncing directory $dir..."
    if ! rsync -a --delete "$SOURCE_WORKTREE/$dir/" "$TASK_DIR/$dir/"; then
      echo "  - Warning: Failed to sync '$dir'. Continuing; it can be rebuilt in '$TASK_DIR'."
      rm -rf "$TASK_DIR/$dir"
      FAILED_DIR_SYNCS+=("$dir")
    fi
  else
    echo "  - Info: Source directory '$SOURCE_WORKTREE/$dir' not found. Skipping."
  fi
done

if [ ${#FAILED_DIR_SYNCS[@]} -gt 0 ]; then
  echo ""
  echo "⚠️  Non-fatal cache sync failures: ${FAILED_DIR_SYNCS[*]}"
fi

echo ""
echo "✅ Worktree setup complete!"
echo "You can now navigate to the new directory to start working:"
echo "cd $TASK_DIR"
