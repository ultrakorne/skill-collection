# herdr-kit

The generic half of the Herdr worktree cockpit — one launcher, shared by every repo.

| file | what |
| --- | --- |
| `new-worktree.sh` | start a task: worktree + space + agent. Installed as `wt`. |

Install — run it from this directory, wherever you cloned the repo:

```sh
ln -sfn "$PWD/new-worktree.sh" ~/.local/bin/wt
```

`$PWD` is what makes this portable *and* correct. Don't hardcode a checkout path (it
differs per machine), and don't pass a relative source — `ln` stores the source string
verbatim, and the kernel resolves a relative one against `~/.local/bin/`, not your cwd,
so `ln -sfn new-worktree.sh ~/.local/bin/wt` silently creates a dangling link. Check
with `readlink -f ~/.local/bin/wt`; it should print a path that exists.

## The split

`new-worktree.sh` holds **nothing project-specific** and takes no project config. It
finds the repo from your cwd and calls into two files that live in that repo:

| in the repo | what | required |
| --- | --- | --- |
| `.herdr/setup.sh` | provisioning, run with CWD = the new worktree | no — skipped with a warning if absent |
| `.herdr/sprawl.env` | `KEY=VALUE` dotenv sourced into both panes (`SPRAWL_AGENT_SECRET`) | no — sourced only if present |

**`setup.sh` owns its own "already provisioned?" early-exit.** The launcher always
calls it. This is the whole trick that keeps the launcher generic: the sentinel is the
one thing that genuinely differs per stack, and only the repo knows it —
`node_modules` for npm, `_build` for Mix, `buildServer.json` for Xcode. Put the check
at the top of `setup.sh` and the launcher needs no knobs at all:

```sh
[ -d node_modules ] && { echo "already provisioned — skipping setup."; exit 0; }
```

Onboarding a new repo is therefore: write `.herdr/setup.sh` (executable), drop in a
`.herdr/sprawl.env`, done. Nothing to copy, nothing to keep in sync.

## Usage

```
wt [name] [prompt...] [--agent CMD] [--base REF] [--name NAME]
```

One call = one worktree = one space = one agent — Herdr's native grain, so each agent
gets its own sidebar row. Run it once per agent. It branches, provisions, splits the
space (agent on top, `sprawl` TUI below), and starts the agent on your prompt.

Pass a prompt and the agent works in the background (the space is created unfocused).
Omit it and the space takes focus with an empty agent session, ready to type into.

```sh
# usual way — just describe the task, quoted. Worktree is auto-named.
wt "add the checkout button"

# name it yourself
wt shop-ui "add the checkout button"

# no prompt: empty interactive agent
wt shop-ui

# other agent / other base
wt shop-ui "rework the header" --agent codex
wt shop-ui --base master "rework the header"
```

Runs from any subdirectory of any repo — it resolves the main checkout from your cwd.

### Naming

The name is optional. The first bare arg claims the name slot **only if it looks like a
branch name** (one token of `A-Za-z0-9._/-`). A quoted sentence has spaces, so it can't
be mistaken for one and falls through to the prompt.

| you type | name | prompt |
| --- | --- | --- |
| `wt shop-ui "do task x"` | `shop-ui` | do task x |
| `wt "do task x"` | auto `wip-a1b2c3` | do task x |
| `wt shop-ui` | `shop-ui` | — (interactive) |

Unnamed runs start on branch `wip-<random>`, and the agent is told — in an appendix to
its own prompt — to `git branch -m` + `herdr workspace rename` itself once it knows what
the task actually is. You name the work after understanding it, not before. The
directory keeps its `wip-` path: the agent is running inside it, so moving it would
break its own absolute paths. Nobody looks at the path; the branch and sidebar label are
what matter.

The heuristic only misfires on an **unquoted** prompt whose first word is a bare token —
`wt do task x` reads `do` as the name. Quote the prompt, or use `--name`, or `--`.

### Flags

| flag | default | |
| --- | --- | --- |
| `--agent CMD`, `-a` | `claude` | also `codex`, `opencode` |
| `--base REF`, `-b` | `HEAD` | ref to branch from |
| `--name NAME`, `-n` | — | force the name, anywhere in the args |
| `--` | — | everything after it is prompt, never a name |

Flags go anywhere. Re-running with an existing name reuses that worktree instead of
failing.

### Cleaning up

```sh
herdr worktree remove --workspace <id> --force   # worktree + space
git branch -D <name>                             # the branch it leaves behind
```

`herdr worktree remove` does **not** delete the branch, so abandoned `wip-*` runs
accumulate branches until you sweep them.

## Wired repos

`idle_collect` (Vite/npm) · `doodlebox` (Phoenix/Elixir) · `2am-swift` (Swift/Xcode)
