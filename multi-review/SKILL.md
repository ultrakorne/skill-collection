---
name: multi-review
description: >-
  Review code changes with several independent, fresh-context reviewers 
  running in parallel, then synthesize their findings into one verified, deduplicated,
  severity-ordered fix plan with Opus. 
disable-model-invocation: true
allowed-tools: Bash(git:*), Workflow, Read, Grep
---

# Multi-Review

Run a multi-reviewer pass over a set of changes and produce a single verified fix plan.

This skill fans out several **independent fresh-context reviewers** (Claude + Codex) in
parallel, then has **Opus** dedup their findings, verify each against the real code, and
write an issue-by-issue fix plan. Invoking it is an explicit opt-in to multi-agent
orchestration: use the **Workflow** tool — pointed at the bundled script — to do the work.

## The bundled workflow

The workflow lives **inside this skill's own directory** at `scripts/multi-review.mjs`.
Always run that bundled copy — do not look for a workflow in `~/.claude/workflows/`. Pass
its absolute path to `Workflow`'s `scriptPath`. For a personal install this resolves to:

```
~/.claude/skills/multi-review/scripts/multi-review.mjs
```

## Instruction (the optional argument)

The workflow takes **one optional free-form string** that is injected verbatim into *every*
reviewer (Claude + Codex), so they all review the same thing. Derive it from how the skill
was invoked:

- **No scope given** (e.g. the user just said "review my changes", or ran `/multi-review`
  with nothing after it) → omit the instruction. Each reviewer reviews the **uncommitted
  working-tree changes** (the default).
- **A scope was given** (e.g. `/multi-review review this branch against master`, or the user
  said "review master...feature, focus on the webhook auth") → pass it through **as-is**.
  Each reviewer is an agent that reads the instruction and gathers the right diff with git
  itself — no parsing on our side.

Pass the instruction straight through as `args` (a plain string). Do not reshape it into a
git range or an object.

## Steps

1. **Preflight (default scope only).** If the user gave **no** instruction, run
   `git status --short --untracked-files=all`; if it's empty, tell them there are no
   uncommitted changes and STOP. If an instruction was given, skip this — the reviewers
   resolve their own scope. (If the request is genuinely ambiguous, ask for clarification
   before launching.)

2. **Run the workflow.** Pass the instruction as `args` only when one was given:
   ```
   Workflow({ scriptPath: "~/.claude/skills/multi-review/scripts/multi-review.mjs", args: "<instruction or omit>" })
   ```
   It fans out every reviewer in `REVIEWERS` in parallel with fresh context, then has Opus
   dedup the findings, verify each against the real code, and write an issue-by-issue fix
   plan. Returns `{ reviewers, plan }`.

3. **Render the returned plan** as markdown for the user — do not just dump JSON:
   - Lead with `plan.summary` and which reviewers ran.
   - For each issue in `plan.issues` (already ordered critical-first): a heading with
     numbering + severity + title, the `sources` that flagged it, the `files` (file:line),
     the `problem`, and the **Fix approach**.
   - If `plan.dismissed` is non-empty, do not surface.
     each title + reason.
   - This is a plan only — do **NOT** start applying fixes unless the user asks.

## Extending

- **Add a reviewer**: append one entry to the `REVIEWERS` array in
  `scripts/multi-review.mjs`.
- **Instruction handling** is the `INSTRUCTION` const at the top of that file — Claude gets
  it in its prompt; Codex gets it via `adversarial-review <focus>` (which accepts free-form
  text). No instruction → plain working-tree `review`.
