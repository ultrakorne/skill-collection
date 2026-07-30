#!/usr/bin/env bash
# new-worktree.sh — create a Herdr-tracked worktree + space, provision it, and launch
# a coding agent in it. Run from anywhere inside any repo, in a Herdr session.
#
# This script is GENERIC: it holds nothing project-specific and takes no project
# config. Everything a given repo needs at worktree-creation time lives in that
# repo, in two files this script calls into:
#
#   <repo>/.herdr/setup.sh    provisioning (deps, secrets, caches, ports). Invoked
#                             with CWD = the new worktree. It owns its own
#                             "already provisioned?" early-exit — only it knows what
#                             provisioned means for that stack. Optional: a repo
#                             that needs no provisioning just omits it.
#   <repo>/.herdr/sprawl.env  KEY=VALUE dotenv sourced into both panes (SPRAWL_AGENT_SECRET).
#                             Its presence is also what OPTS THE REPO IN to the sprawl
#                             pane: no sprawl.env, no split, agent gets the whole space.
#
# Install — from this directory, wherever you cloned it. $PWD keeps it machine-agnostic
# and absolute; a relative source resolves against ~/.local/bin, not your cwd, and lands
# dangling:
#   ln -sfn "$PWD/new-worktree.sh" ~/.local/bin/wt
#
#   wt [name] [prompt...] [--agent CMD] [--base REF] [--name NAME]
#     name       branch + worktree + space label (e.g. shop-ui). OPTIONAL — see below.
#     prompt...  optional initial prompt — every bare (non-flag) arg that didn't land
#                in the name slot, joined with spaces. When given, the agent opens
#                INTERACTIVELY and starts on this prompt (not headless -p/exec/run).
#                Omit it and the agent just opens an empty session. Quoting is
#                optional: the words are re-joined, so `wt fix add a button` and
#                `wt fix "add a button"` are equivalent.
#     --agent CMD, -a CMD   agent launched in the pane (default: claude; also codex,
#                           opencode). Put it anywhere.
#     --base REF,  -b REF   ref to branch from (default: HEAD).
#     --name NAME, -n NAME  name the worktree explicitly, wherever it sits in the args.
#
#   e.g.  wt shop-ui "add the checkout button"
#         wt "add the checkout button"            # auto-named, agent renames it
#         wt shop-ui "add the checkout button" --agent codex
#         wt shop-ui --base main "rework the header"
#
# NAMING — the name is optional. The first bare arg claims the name slot only if it
# LOOKS like a branch name (one token, [A-Za-z0-9._/-] only). A sentence has spaces,
# so it can't be mistaken for a name and falls through to the prompt:
#
#   wt shop-ui "do task x"   → name shop-ui, prompt "do task x"
#   wt "do task x"           → no name  → auto-named wip-xxxxxx, prompt "do task x"
#   wt shop-ui               → name shop-ui, no prompt, interactive
#
# When no name is given the worktree is created as wip-<random> and the agent is told,
# in an appendix to its prompt, to rename the branch + space itself once it knows what
# the task actually is. That's the whole point: you shouldn't have to name the work
# before understanding it — the agent does, a few seconds later, from the same prompt.
# The DIRECTORY keeps its wip- path (the agent runs inside it; moving it out from under
# itself would break its own absolute paths) — harmless, nobody looks at it.
#
# The heuristic only misfires on an unquoted prompt whose first word is a bare token
# (`wt do task x` reads `do` as the name). Escape hatches: quote the prompt, pass
# `--name`, or use `--` to force everything after it into the prompt (`wt -- do task x`).
#
# PROMPTS GO THROUGH A FILE, NOT THE KEYBOARD. The prompt is written to
# <git-common-dir>/wt-prompts/<name>.txt and the pane is only ever sent the short line
#   claude "$(cat /abs/path/to/that/file)"
# The prompt used to be typed into the pane inline, %q-quoted. That breaks on long
# prompts: a pane's tty in canonical mode (which it is until the shell finishes
# starting and hands over to its line editor) holds at most MAX_CANON — 1024 bytes on
# Darwin — and silently DISCARDS the rest, trailing newline included. The command then
# sits half-typed at the prompt, unsubmitted, forever. %q made it far worse: under the
# C locale every byte of a non-ASCII char becomes a 4-char octal escape, so one em-dash
# costs 12 bytes instead of 3 and a few paragraphs of prose blow past 1024 easily.
# Sending ~100 bytes regardless of prompt size takes the whole class of failure off the
# table. The files are tiny, live outside every working tree, and are overwritten per
# name — they double as a record of what each worktree was launched with.
#
# Each call makes ONE space = ONE agent = ONE worktree — Herdr's native grain, so
# each agent gets its own sidebar row + rolled-up state. Run it once per agent.
#
# In a repo that has .herdr/sprawl.env, the space is split top/bottom: the agent
# runs in the top pane, and a bottom pane (~1/3 height, labelled "sprawl") runs the
# sprawl TUI. Both panes source that file first so SPRAWL_AGENT_SECRET is exported
# for sprawl. Without the file the repo doesn't use sprawl, so the space is left
# unsplit and the agent gets all of it.
set -euo pipefail

USAGE="usage: wt [name] [prompt...] [--agent CMD] [--base REF] [--name NAME]"

# Quote a string as a single token for the pane's shell. The C locale is load-bearing:
# in a UTF-8 locale, bash 3.2's %q leaves the LEAD byte of a multi-byte char raw and
# octal-escapes only the continuation bytes (em-dash -> 0xE2 then a literal \200\224),
# which is invalid UTF-8 — and `herdr pane send-text` takes this as a Rust argv, so it
# panics on it rather than typing it. Under LC_ALL=C every high byte is octal-escaped,
# so the quoted form is pure ASCII and the pane's shell (zsh or bash) decodes $'\342...'
# back to the real bytes. It MUST be a subshell assignment: bash caches locale state, so
# an `LC_ALL=C printf ...` env-prefix on the builtin is silently a no-op.
shquote() ( LC_ALL=C; printf '%q' "$1" )

# A bare arg can only be the name if it would survive as a git branch / directory
# name. Anything with a space (i.e. a prompt) fails this and falls through.
is_name_like() {
  case "$1" in
    ""|-*)                 return 1 ;;   # empty, or a flag we don't know
    *[!A-Za-z0-9._/-]*)    return 1 ;;   # any char outside the branch-safe set
    *)                     return 0 ;;
  esac
}

AGENT="claude"
BASE="HEAD"
NAME=""
PROMPT_WORDS=()
NAME_SLOT_OPEN=1   # closed by --name, by --, or once any bare word is taken as name/prompt

while [ "$#" -gt 0 ]; do
  case "$1" in
    --agent|-a) AGENT="${2:?--agent needs a value}"; shift 2 ;;
    --base|-b)  BASE="${2:?--base needs a value}";   shift 2 ;;
    --name|-n)  NAME="${2:?--name needs a value}"; NAME_SLOT_OPEN=0; shift 2 ;;
    --agent=*)  AGENT="${1#*=}"; shift ;;
    --base=*)   BASE="${1#*=}";  shift ;;
    --name=*)   NAME="${1#*=}";  NAME_SLOT_OPEN=0; shift ;;
    --)         shift; NAME_SLOT_OPEN=0; PROMPT_WORDS+=("$@"); break ;;   # rest is literal prompt
    *)
      if [ "$NAME_SLOT_OPEN" -eq 1 ] && is_name_like "$1"; then
        NAME="$1"
      else
        PROMPT_WORDS+=("$1")
      fi
      NAME_SLOT_OPEN=0
      shift ;;
  esac
done

# Guard the join: on macOS's stock bash 3.2, ${arr[*]} on an EMPTY array trips
# `set -u` as an unbound variable, so only expand when we actually have words.
PROMPT=""
[ "${#PROMPT_WORDS[@]}" -gt 0 ] && PROMPT="${PROMPT_WORDS[*]}"

[ -n "$NAME" ] || [ -n "$PROMPT" ] || { echo "$USAGE" >&2; exit 1; }

# Resolve the repo from the CALLER's cwd, never from $0: this script lives on PATH,
# outside any repo, so dirname $0 would point at ~/.local/bin. `worktree list` run
# from anywhere inside a repo — including from another worktree — lists the MAIN
# checkout first, which is where .herdr/ and the real .git live.
git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || { echo "wt: not inside a git repo (cwd: $PWD)" >&2; exit 1; }
MAIN="$(git worktree list --porcelain | awk 'NR==1{print $2}')"

# No name → mint a throwaway one and let the agent rename it later. -N3 reads exactly
# 3 bytes, so nothing closes the pipe early and trips `set -o pipefail` (which is what
# `tr -dc ... | head -c` would do).
AUTO_NAME=0
if [ -z "$NAME" ]; then
  AUTO_NAME=1
  while :; do
    NAME="wip-$(LC_ALL=C od -An -tx1 -N3 /dev/urandom | tr -d ' \n')"
    [ -e "$MAIN/.claude/worktrees/$NAME" ] || break
  done
fi

WT="$MAIN/.claude/worktrees/$NAME"

# .herdr/sprawl.env is the repo's opt-in to sprawl, and it does two jobs. Its
# CONTENTS become a prefix each pane runs before its command, exporting sprawl's
# env (dotenv file, plain KEY=VALUE) so sprawl authenticates — absolute path, so
# it works before the file is committed and regardless of the pane's cwd, and
# `set -a` exports the assignments even though the file has no `export` keyword.
# Its EXISTENCE decides whether there's a sprawl pane at all (step 4). A repo
# without it gets no split and a bare command line, not a dead pane running a
# tool it doesn't use.
ENVFILE="$MAIN/.herdr/sprawl.env"
USE_SPRAWL=0
SRC=""
if [ -f "$ENVFILE" ]; then
  USE_SPRAWL=1
  SRC="set -a; . \"$ENVFILE\"; set +a; "
fi

# Focus policy: an interactive (no-prompt) launch means you want to jump INTO the
# new space and start typing, so focus it. But when a prompt is passed the agent
# runs on its own — so stay put in the pane you issued the command from and let it
# work in the background. Prompt present → --no-focus; absent → --focus.
FOCUS_FLAG="--focus"; [ -n "$PROMPT" ] && FOCUS_FLAG="--no-focus"

# 1) Herdr owns lifecycle: worktree + its own workspace (space) + focused pane.
#    Take the NEW pane's id from the create response — NOT `pane current`, which
#    returns the pane this script runs in, so the agent would launch here instead.
#    If the worktree already exists (a prior run, or you're re-attaching an agent
#    to it), `create` would abort with "already exists" — so reuse it via `open`
#    instead of failing. Same JSON shape either way.
if [ -e "$WT" ]; then
  echo "worktree '$NAME' already exists at $WT — reusing it (open)."
  CREATED="$(herdr worktree open --cwd "$MAIN" --path "$WT" --label "$NAME" "$FOCUS_FLAG" --json)"
else
  CREATED="$(herdr worktree create --cwd "$MAIN" --path "$WT" --branch "$NAME" --base "$BASE" \
    --label "$NAME" "$FOCUS_FLAG" --json)"
fi
PANE="$(printf '%s' "$CREATED" | jq -r '.result.root_pane.pane_id')"
[ -n "$PANE" ] && [ "$PANE" != "null" ] || { echo "could not resolve new pane id from:" >&2; echo "$CREATED" >&2; exit 1; }
WS="$(printf '%s' "$CREATED" | jq -r '.result.workspace.workspace_id')"

# 2) An auto-named worktree carries its own rename instructions in the prompt. The
#    space id has to come from the create response above, which is why the agent
#    command is assembled here and not up with the arg parsing.
if [ "$AUTO_NAME" -eq 1 ]; then
  [ -n "$WS" ] && [ "$WS" != "null" ] || { echo "could not resolve new workspace id from:" >&2; echo "$CREATED" >&2; exit 1; }
  # Plain multi-line assignment, NOT $(cat <<EOF ...) — bash 3.2 (macOS stock) has a
  # parser bug with heredocs inside command substitution. No backticks or double quotes
  # in the prose below for the same reason: the string has to survive this quoting.
  PROMPT="$PROMPT

---
Housekeeping, before anything else: this worktree was created without a name, so it is
parked on the throwaway branch '$NAME' and its Herdr space is labelled the same. As soon
as the task above is clear enough to name (which should be within your first few steps),
give it a short kebab-case name describing the work (e.g. 'checkout-button',
'fix-save-race') and apply it in both places, from inside this worktree:

    git branch -m <new-name>
    herdr workspace rename $WS <new-name>

Do that once, early, then carry on with the task and don't bring it up again. Leave the
worktree DIRECTORY alone: you are running inside it, so moving it would break your own
absolute paths. It stays at .claude/worktrees/$NAME, which bothers nobody.
---"
fi

# Build the agent launch command. The prompt itself goes to a file and the pane gets a
# short $(cat …) line instead — see the note at the top on why it can't be typed inline.
# All three agents open interactively with an initial prompt (never the headless path):
# claude/codex take it as a positional arg, opencode via --prompt.
AGENT_CMD="$AGENT"
if [ -n "$PROMPT" ]; then
  # The git common dir is shared by every worktree and is never itself a working tree,
  # so a file dropped here can't be staged, can't show up as untracked, and can't
  # collide with the agent's own edits. A name may contain '/', hence the mkdir -p.
  GITDIR="$(cd "$MAIN" && git rev-parse --git-common-dir)"
  case "$GITDIR" in /*) ;; *) GITDIR="$MAIN/$GITDIR" ;; esac
  PROMPT_FILE="$GITDIR/wt-prompts/$NAME.txt"
  mkdir -p "$(dirname "$PROMPT_FILE")"
  printf '%s\n' "$PROMPT" > "$PROMPT_FILE"

  # Only the PATH goes through shquote now, and $(cat …) stays unexpanded here so the
  # pane's shell is the one that reads the file.
  READ_PROMPT="\"\$(cat $(shquote "$PROMPT_FILE"))\""
  case "$AGENT" in
    opencode*) AGENT_CMD="$AGENT --prompt $READ_PROMPT" ;;
    *)         AGENT_CMD="$AGENT $READ_PROMPT" ;;  # claude, codex: positional prompt
  esac
fi

# 3) Repo owns provisioning. Always call it — setup.sh owns the "already provisioned?"
#    early-exit, since the sentinel (node_modules / _build / buildServer.json / …) is
#    the one thing that differs per stack and only that repo knows it. Keeping the
#    check there is what lets THIS script stay project-agnostic.
SETUP="$MAIN/.herdr/setup.sh"
if [ -x "$SETUP" ]; then
  ( cd "$WT" && "$SETUP" )
elif [ -e "$SETUP" ]; then
  echo "wt: $SETUP is not executable — skipping provisioning (chmod +x it)." >&2
else
  echo "wt: no $SETUP — skipping provisioning." >&2
fi

# 4) Split the space top/bottom, but only in a repo that uses sprawl. --ratio is
#    the fraction the ORIGINAL (top) pane keeps, so 0.67 leaves the bottom pane
#    ~1/3. --no-focus keeps focus on the agent pane. Take the new (bottom) pane id
#    from the split response.
# 5) Label the bottom pane's border and run sprawl in it (interactive TUI).
#    These herdr calls echo a JSON pane_info blob we don't need — mute it.
if [ "$USE_SPRAWL" -eq 1 ]; then
  SPLIT="$(herdr pane split "$PANE" --direction down --ratio 0.67 --cwd "$WT" --no-focus)"
  SPRAWL_PANE="$(printf '%s' "$SPLIT" | jq -r '.result.pane.pane_id')"
  [ -n "$SPRAWL_PANE" ] && [ "$SPRAWL_PANE" != "null" ] || { echo "could not resolve sprawl pane id from:" >&2; echo "$SPLIT" >&2; exit 1; }

  herdr pane rename "$SPRAWL_PANE" sprawl >/dev/null
  herdr pane send-text "$SPRAWL_PANE" "${SRC}sprawl"$'\n' >/dev/null
fi

# A pane's foreground process is its login shell while it sits at a prompt, and becomes
# the agent the moment one launches — so "a foreground pid that isn't the shell" tells us
# the send actually took. Worth checking: the failure mode this replaced was silent, a
# half-typed command line nobody noticed until the agent was hours late.
agent_is_up() {
  local info sp
  info="$(herdr pane process-info --pane "$1" 2>/dev/null)" || return 1
  sp="$(printf '%s' "$info" | jq -r '.result.process_info.shell_pid // -1')"
  printf '%s' "$info" | jq -e --argjson sp "$sp" \
    '[.result.process_info.foreground_processes[]?.pid] | map(. != $sp) | any' >/dev/null 2>&1
}

wait_agent_up() {   # pane, seconds
  local deadline=$(( SECONDS + $2 ))
  while [ "$SECONDS" -lt "$deadline" ]; do
    agent_is_up "$1" && return 0
    sleep 1
  done
  return 1
}

# 6) Launch the agent inside the top pane so its SessionStart hook registers with
#    Herdr → tracked from t=0. Works for claude, codex AND opencode. A trailing
#    prompt (if any) is already baked into $AGENT_CMD, so the agent opens
#    interactively and starts working on it.
herdr pane send-text "$PANE" "${SRC}${AGENT_CMD}"$'\n' >/dev/null

if ! wait_agent_up "$PANE" 25; then
  # Retry once, after a Ctrl-U to kill whatever partial line might be sitting there —
  # appending to a half-typed command would just run garbage.
  herdr pane send-text "$PANE" $'\025' >/dev/null 2>&1 || true
  herdr pane send-text "$PANE" "${SRC}${AGENT_CMD}"$'\n' >/dev/null
  wait_agent_up "$PANE" 25 \
    || echo "wt: $AGENT never started in pane $PANE — check the pane. Prompt kept at ${PROMPT_FILE:-<none>}" >&2
fi

if [ "$AUTO_NAME" -eq 1 ]; then
  echo "✓ $NAME — $AGENT ready (unnamed: agent will rename branch + space $WS once the task is clear)"
else
  echo "✓ $NAME — $AGENT ready${PROMPT_FILE:+ (prompt: $PROMPT_FILE)}"
fi
