---
name: orchestrator
description: Enter orchestrator mode — from here on, every repo change is delegated to a spawned Herdr worktree agent rather than done inline.
disable-model-invocation: true
---

# Orchestrator mode

On from now, for the rest of the session.

You orchestrate, delegate execution. Every change to the repo leaves through
`wt` at Herdr's native **grain** — one call = one worktree = one space = one agent.

Mechanics (flags, naming, cleanup) live in the header comment of the script `wt` points
at; read it once, when you need more than the calls below.

## Fire one call per unit

From anywhere inside the repo, once per unit:

```sh
wt branch-name "<prompt>"
```

if you cannot choose or understand just from the prompt an appropriate branch name, let it auto name by the agent

```sh
wt "<prompt>"
```

Quote the prompt. Unquoted, a first bare word (`do task x`) is swallowed by the name slot.

The agent delegated to a task resolves a bad or thin prompt with the user itself — you
don't have to.

## Prompt only what the agent can't already know

It runs in the repo and loads the project instructions itself, do not add anything that is already stated in the AGENTS.md or things the agent will know. Restating them is bloat.

## Then say done

Once the calls are out, report **done** in a brief way

# Sprawl tasks

If the user mention a sprawl task, use the sprawl skill if the content here is not enough to fetch and pass the task to a new `wt`

If the user mention a task id, can fetch with (example for task 129)

```
sprawl task 129 --full --format=json
```

or a single item / checklist item with (item id is different, in this case 499)

```
sprawl item 499 --format=json
```

if the user mention all work ready to be picked up, the queue of work you can get all ready items with

```
 sprawl queue --full --format=json
```

IMPORTANT as the orchestrator: it is your judgement to decide if a task has independently implementable items, you can split every item to a different worktree (wt) and have multiple separate agent executing an item.

IF a task is highly coupled, the same work package (full task with all items OR a selected set of item, that you select) can be passed to the same agent. For a large work package, tell the agent it may drive the work with a Workflow (multi-agent orchestration) if the volume warrants it — its call.

Parallel worktrees on related items will sometimes collide; that's fine, the PRs resolve it.

## Item state

You flip an item to **in progress** as you dispatch it — before or right after the `wt`
call, so a second queue read can't hand the same item to a second agent:

```
sprawl item state 499 progress
```

The spawned agent sets **in review** when it's done, and attaches the PR. Tell it so in
your prompt, along with the id of the task and the id of all items it owns:

```
sprawl item state 499 review
sprawl item pr 499 1
```
