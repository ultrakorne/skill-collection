---
name: project-documentation
version: "0.9"
description: "Maintain docs/ as lean, present-state project documentation (docs/INDEX.md, docs/CONTEXT.md, docs/features/*/{INDEX,DESIGN,TECHNICAL}.md, docs/adr/). Use when: a feature was implemented or changed and docs/ must follow; the user asks how a feature works (read docs/INDEX.md first); docs/ is being created, migrated or trimmed; a decision needs an ADR."
context: fork
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Project Documentation

`docs/` is a map of the present system for someone who will read the code next. The code is the source of truth; a doc **points** at it and **caches** only what the code cannot confess. Every doc describes the current state in the present tense.

## Layout

Reproduce these filenames exactly.

```
docs/
├── INDEX.md                      # Master TOC — always read first
├── CONTEXT.md                    # Ubiquitous language — this exact name
├── testing.md                    # Optional
├── adr/                          # Created lazily, one decision per file
│   └── 0001-slug.md
└── features/
    └── feature-name/             # kebab-case
        ├── INDEX.md              # One paragraph + Documents table
        ├── DESIGN.md             # What it does, for whom, the decisions that shape it
        ├── TECHNICAL.md          # Architecture, where things live, the non-obvious
        ├── CONTEXT.md            # Optional: terms used only inside this feature
        ├── FLOW.mermaid          # Optional: one diagram for a multi-step flow or state machine
        └── topic.md              # Optional: a sub-component that would clutter TECHNICAL.md
```

A feature earns its own folder when it has enough non-obvious behaviour to fill a TECHNICAL page. A small feature (a popup, a consent banner, a seed step) lives as a section of the feature it serves.

## Rules

Each rule is stated once here; the workflows apply them and the finish step checks them.

1. **Point, never paraphrase.** Name a file by path and say what it is for in one line. A fact visible by opening the file stays in the file: schema blocks, function lists, event and DOM-id inventories, test and migration tables, dependency lists all belong to the code. *Check:* no code blocks copied from source.
2. **Path only.** A path survives edits; a line number is stale on the next commit. *Check:* `grep -rnE '\.(ex|exs|js|ts|py|rb|go|heex|css):[0-9]+' docs` is empty.
3. **Every cited path exists.** *Check:* `test -e` on each backticked path before citing it.
4. **Present state only.** Describe what the system does today, in the present tense. History, plans, roadmaps, "future work" and comparisons with earlier versions live in git and in ADRs. *Check:* `grep -rniE 'previously|no longer|used to|replaced|future work|earlier version' docs` yields only present-tense hits.
5. **Cache the non-obvious.** TECHNICAL's "Noteworthy" section exists for what a reader cannot learn by opening the code: ordering invariants, race outcomes, optimistic-UI contracts, security gates, constants duplicated across layers that must change together, the reason behind a deliberate choice. One or two sentences each: the rule and the reason, not the mechanism.
6. **Budgets.** INDEX.md ≤ 12 lines. DESIGN.md 30–70. TECHNICAL.md 40–90 (an API surface may reach 120). Past the ceiling, the page is enumerating instead of distilling: cut, or split one sub-component into `topic.md`.
7. **Exact names.** The language file is `docs/CONTEXT.md` and `docs/features/{feature}/CONTEXT.md`; feature folders are kebab-case. *Check:* no `glossary.md`, `terms.md` or `vocabulary.md` under `docs/`.
8. **Links resolve.** Relative links only, to files that exist. *Check:* every `](path)` under `docs/` resolves with `test -e`.
9. **No timestamps, status lines or author notes** in any doc.

## What each file holds

- **INDEX.md (master)** — a two-sentence description of the project, the tech stack, a Features table with one line per feature, and Quick Links to `CONTEXT.md` and `testing.md`. A table of contents, nothing else.
- **INDEX.md (feature)** — one paragraph saying what the feature does, then the Documents table. Nothing else.
- **DESIGN.md** — the functional overview: what it does, for whom, the surface the user sees, the main flows, and the handful of decisions that shape it with their reasons. User-level vocabulary; no source files or code identifiers beyond routes and header names.
- **TECHNICAL.md** — three parts: *Architecture* (one or two paragraphs on how the feature is wired and where ownership is enforced), *Where things live* (a short file table, one line per file that matters), *Noteworthy* (rule 5). A data-model note appears only when a constraint or nullable semantic is load-bearing, in prose, pointing at the schema file.
- **CONTEXT.md** — the ubiquitous language: one-sentence definitions of what each term *is*, the canonical name bolded and rejected synonyms under `_Avoid_`, plus a short Relationships list. Domain terms only; general programming words stay out. Most terms live at the project level; the feature-level file exists only for terms that never leave the feature.
- **FLOW.mermaid** — one diagram at protocol level (participants and messages, or states and transitions), free of internal module and function names.
- **ADR** — why a hard-to-reverse, surprising decision was made. Read [ADR_FORMAT.md](ADR_FORMAT.md) for the criteria and template. Propose and confirm before writing one; an ADR is never a side effect of other work.

Templates for every file are in [references/templates.md](references/templates.md).

## Workflows

### Initialize (new project)

Create `docs/INDEX.md`, `docs/CONTEXT.md` (a few core terms, growing with the project) and `docs/features/` from the templates. Done when `INDEX.md` links `CONTEXT.md`.

### Document or update a feature (implemented code only)

1. Read `docs/INDEX.md` and the feature's folder if it exists. Decide whether this feature earns a folder or a section in a neighbour (Layout).
2. Write or update `DESIGN.md`, `TECHNICAL.md` and the feature `INDEX.md` from the templates, applying the Rules as you write.
3. Add new domain terms to `docs/CONTEXT.md`; create the feature-level `CONTEXT.md` only for terms that never leave the feature.
4. Add or update `FLOW.mermaid` when a multi-step flow or state machine changed; add `topic.md` when a sub-component would push TECHNICAL past budget.
5. Add or update the feature's row in `docs/INDEX.md`.
6. If a decision here meets the ADR criteria, propose one.

Done when every touched file passes the finish checks and the feature is reachable from `docs/INDEX.md`.

### Migrate or trim existing docs

1. Read the whole tree once and list, per feature: what stays (rule 5 material), what folds into a neighbour, what is history or plan (delete). Decide the target tree before editing.
2. Rewrite each page from scratch against the templates and budgets. Distil; editing sentences in place keeps the sediment.
3. Delete what nothing links to. Repoint links and any code comment that named a removed path (`grep -rn 'docs/'` over the source roots).
4. Rebuild `docs/INDEX.md` last.

Done when the finish checks pass on the whole tree and no path outside `docs/` names a removed file.

### Answer "how does X work?"

Read `docs/INDEX.md`, then the feature's `INDEX.md` and whichever of DESIGN or TECHNICAL the question needs. When the docs and the code disagree, the code is right: say so and fix the doc.

### Record a decision

Read [ADR_FORMAT.md](ADR_FORMAT.md), confirm with the user, create the next `docs/adr/NNNN-slug.md`.

## Before you finish

Run every *Check* in the Rules on the files you touched (on the whole tree after a migration). The task is complete when all checks are clean, budgets hold, and `docs/INDEX.md` links `docs/CONTEXT.md`.
