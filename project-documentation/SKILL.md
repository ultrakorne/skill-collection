---
name: project-documentation
version: "0.6"
description: "Create, maintain, and query structured project documentation with progressive disclosure. Use when: (1) starting documentation for a new project, (2) adding documentation for a new feature, (3) after implementing a feature, trigger to update or create new documentation (4) reading project context before working on features, (5) answering questions about feature behavior or functionality (e.g., 'how does X work?', 'what does Y feature do?', 'explain the Z system'). When user asks about a feature, ALWAYS check docs/INDEX.md first to see if documentation exists. Triggers on phrases like 'document this', 'update the docs', 'add feature documentation', 'how does [feature] work', 'what does [feature] do'."
context: fork
agent: general-purpose
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Project Documentation Skill

Maintain structured, progressive-disclosure documentation that keeps context minimal while ensuring discoverability.

## Background Execution

This skill runs in a forked sub-agent context by default (`context: fork`), keeping the main conversation clean. The skill executes in isolation and returns only a summary of what was created/updated.

To disable background execution, remove `context: fork` from the frontmatter.

## Structure Overview

```
docs/
├── INDEX.md                      # Master TOC - ALWAYS read first
├── CONTEXT.md                    # Project-level ubiquitous language (glossary)
└── features/
    └── feature-name/
        ├── INDEX.md              # Feature TOC - read when working on feature
        ├── CONTEXT.md            # Optional: feature-specific terms only
        ├── DESIGN.md             # Required: what/why, requirements, user stories
        ├── TECHNICAL.md          # Required: how, implementation, data models
        ├── FLOW.mermaid          # Optional: visual diagrams
        ├── CHANGELOG.md          # Optional: feature change history
        └── [topic].md            # Optional: sub-components (scoring.md, etc.)
```

## Reading Pattern

1. **Always start** by reading `docs/INDEX.md` and `docs/CONTEXT.md` (the project glossary — terms used across features)
2. **When working on a feature** → read `docs/features/{feature}/INDEX.md`, and `docs/features/{feature}/CONTEXT.md` if it exists (feature-specific terms)
3. **Based on task** → read only relevant files:
   - Requirements/design questions → DESIGN.md
   - Implementation work → TECHNICAL.md
   - Specific subsystem → the relevant [topic].md

## Ubiquitous Language (CONTEXT.md)

`CONTEXT.md` captures the project's ubiquitous language — the precise terms the team uses for domain concepts, with aliases to avoid and relationships between concepts. Two levels:

- **`docs/CONTEXT.md`** (project-level): terms that have meaning across multiple features or at the app level. **Most terms live here** — features usually have implications at the project level, so shared vocabulary belongs in one place.
- **`docs/features/{feature}/CONTEXT.md`** (feature-level, optional): terms that are *only* meaningful inside one feature. Create this file only when a feature introduces genuinely local concepts that would clutter the project glossary.

When adding a term, ask: *is this term used (or might be used) anywhere outside this feature?* If yes → project-level. If strictly internal → feature-level.

## Workflows

### Initialize Documentation (new project)

1. Create `docs/` directory in project root
2. Create `docs/INDEX.md` using template from [references/templates.md](references/templates.md#master-index)
3. Create `docs/CONTEXT.md` using template from [references/templates.md](references/templates.md#project-context) (start with a few core domain terms; grow as the project does)
4. Create `docs/features/` directory

### Add Feature Documentation (IMPLEMENTED FEATURES ONLY)

**Use this workflow when**: A feature has been ACTUALLY IMPLEMENTED in the codebase and you need to document it.

**Do NOT use for**: Plans, proposed features, or features that haven't been coded yet.

1. Create `docs/features/{feature-name}/` directory (use kebab-case)
2. Create required files using templates:
   - `INDEX.md` — feature table of contents
   - `DESIGN.md` — design specification
   - `TECHNICAL.md` — technical specification
3. **Update the glossary**:
   - For each domain term the feature introduces, add it to `docs/CONTEXT.md` (project-level) — this is the default location.
   - Only if the feature introduces genuinely local concepts that don't surface anywhere else, create `docs/features/{feature-name}/CONTEXT.md` for those terms.
4. Add optional files as needed:
   - `FLOW.mermaid` — for flows benefiting from visualization (auth, state machines, pipelines)
   - `CHANGELOG.md` — if tracking feature-specific changes
   - `[topic].md` — for complex sub-components deserving isolation
5. Update `docs/INDEX.md` with new feature entry (and reference `CONTEXT.md` in its Quick Links if not already there)

### Update After Implementation

After implementing or modifying a feature:

1. Update `TECHNICAL.md` with implementation details
2. If design changed → update `DESIGN.md`
3. If new domain terms appeared or term meanings shifted → update `docs/CONTEXT.md` (or the feature-level one if strictly local)
4. If new sub-components added → create `[topic].md` and update feature `INDEX.md`
5. If flow changed → update `FLOW.mermaid`
6. Optionally add entry to `CHANGELOG.md`

### Migrate Existing Documentation

1. Initialize the structure (see above)
2. Identify existing features/modules in codebase
3. For each feature:
   - Extract design intent into `DESIGN.md`
   - Document current implementation in `TECHNICAL.md`
   - Harvest domain terms into `docs/CONTEXT.md` (or feature-level CONTEXT if strictly local). Flag any ambiguous or conflicting uses in the "Flagged ambiguities" section.
   - Break out complex subsystems into separate files
4. Build `docs/INDEX.md` as you go

## Guidelines

- **Feature names MUST be kebab-case** — lowercase letters, numbers, and hyphens only (e.g., `user-authentication`, `game-lobby`, `scoring-system`). Names like `UserAuth` or `user_auth` are invalid.
- **INDEX.md is a table of contents, nothing else.** One-paragraph description + Documents table. No test lists, no dev-tool walk-throughs, no implementation details, no quick-reference bullets. If a reader needs those, they click through to the relevant doc.
- **TECHNICAL.md is NOT an API reference.** Do NOT enumerate every function, changeset, schema field, LiveView event, hook attribute, or endpoint. Readers can open the source file for signatures. TECHNICAL.md describes: (a) the **architecture** — how the feature is wired together, (b) **what each source file is for** — one line per file, (c) **noteworthy or non-obvious decisions** — performance paths, race-condition handling, cascade algorithms, optimistic-UI contracts, anything a reader *can't* learn by reading the code.
- **The default mode is "point, don't paraphrase"**: prefer one sentence pointing at `lib/foo/bar.ex` over a bullet list that restates its public functions. If a fact is already visible in the file, don't restate it.
- **DESIGN.md answers**: What does it do? Why? Who uses it? What are the requirements? (UX-level, not implementation.)
- **Use FLOW.mermaid when**: The feature has a multi-step flow, state machine, or complex interactions.
- **Break out sub-components when**: A topic is complex enough that it clutters the main docs and is only relevant for specific tasks.
- **Size guardrail**: if a TECHNICAL.md exceeds ~300 lines, that's usually a signal the author is enumerating instead of distilling. Cut, or split a sub-component out into `[topic].md`.
- **CONTEXT.md is for domain language, not programming concepts.** Terms like "timeout", "error", "cache" don't belong unless they have a project-specific meaning. Ask: is this concept unique to this project, or general programming? Only the former belongs.
- **CONTEXT.md is opinionated.** When multiple words exist for the same concept, pick one and list the others under `_Avoid_:`. Keep each definition to one sentence — what it IS, not what it does.
- **Do not add timestamps** to any INDEX or documentation files. Remove if found.

## Templates

See [references/templates.md](references/templates.md) for all document templates.
