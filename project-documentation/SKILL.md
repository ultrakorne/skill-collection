---
name: project-documentation
version: "0.1"
description: "Create and maintain structured project documentation with progressive disclosure. Use when: (1) starting documentation for a new project, (2) adding documentation for a new feature, (3) updating docs after implementing changes, (4) reading project context before working on features. Triggers on phrases like 'document this', 'update the docs', 'add feature documentation', or when CLAUDE.md references this skill."
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
├── features/
│   └── feature-name/
│       ├── INDEX.md              # Feature TOC - read when working on feature
│       ├── DESIGN.md             # Required: what/why, requirements, user stories
│       ├── TECHNICAL.md          # Required: how, implementation, data models
│       ├── FLOW.mermaid          # Optional: visual diagrams
│       ├── CHANGELOG.md          # Optional: feature change history
│       └── [topic].md            # Optional: sub-components (scoring.md, etc.)
└── plans/                        # Archived plans - NEVER auto-read
    └── feature-name/
        └── YYYY-MM-DD-description.md
```

**Plans folder**: Stores approved implementation plans for historical reference. Plans are immutable after approval and are NOT read unless explicitly requested by the user.

## Reading Pattern

1. **Always start** by reading `docs/INDEX.md`
2. **When working on a feature** → read `docs/features/{feature}/INDEX.md`
3. **Based on task** → read only relevant files:
   - Requirements/design questions → DESIGN.md
   - Implementation work → TECHNICAL.md
   - Specific subsystem → the relevant [topic].md
4. **Never auto-read** `docs/plans/` — only read if user explicitly links or requests

## Workflows

### Initialize Documentation (new project)

1. Create `docs/` directory in project root
2. Create `docs/INDEX.md` using template from [references/templates.md](references/templates.md#master-index)
3. Create `docs/features/` directory
4. Create `docs/plans/` directory

### Add Feature Documentation

1. Create `docs/features/{feature-name}/` directory (use kebab-case)
2. Create required files using templates:
   - `INDEX.md` — feature table of contents
   - `DESIGN.md` — design specification
   - `TECHNICAL.md` — technical specification
3. Add optional files as needed:
   - `FLOW.mermaid` — for flows benefiting from visualization (auth, state machines, pipelines)
   - `CHANGELOG.md` — if tracking feature-specific changes
   - `[topic].md` — for complex sub-components deserving isolation
4. Update `docs/INDEX.md` with new feature entry

### Update After Implementation

After implementing or modifying a feature:

1. Update `TECHNICAL.md` with implementation details
2. If design changed → update `DESIGN.md`
3. If new sub-components added → create `[topic].md` and update feature `INDEX.md`
4. If flow changed → update `FLOW.mermaid`
5. Optionally add entry to `CHANGELOG.md`

### Archive a Plan (optional)

When an implementation plan is approved and worth preserving:

1. Create `docs/plans/{feature-name}/` if it doesn't exist
2. Save the plan as `YYYY-MM-DD-{description}.md` (e.g., `2025-01-18-initial-implementation.md`)
3. Plans are immutable — never modify after archiving

**When to archive plans:**
- After a plan is approved and implementation begins/completes
- When implementation is deferred but the plan should be preserved
- When user explicitly requests to save a plan

**When NOT to archive:**
- Quick iterations that don't need historical record
- Plans that were rejected or superseded before approval

### Migrate Existing Documentation

1. Initialize the structure (see above)
2. Identify existing features/modules in codebase
3. For each feature:
   - Extract design intent into `DESIGN.md`
   - Document current implementation in `TECHNICAL.md`
   - Break out complex subsystems into separate files
4. Build `docs/INDEX.md` as you go

## Guidelines

- **Feature names MUST be kebab-case** — lowercase letters, numbers, and hyphens only (e.g., `user-authentication`, `game-lobby`, `scoring-system`). Names like `UserAuth` or `user_auth` are invalid.
- **Keep INDEX.md files lean** — descriptions + links only, no implementation details
- **DESIGN.md answers**: What does it do? Why? Who uses it? What are the requirements?
- **TECHNICAL.md answers**: How is it built? What's the data model? What are the APIs/interfaces?
- **Use FLOW.mermaid when**: The feature has a multi-step flow, state machine, or complex interactions
- **Break out sub-components when**: A topic is complex enough that it clutters the main docs and is only relevant for specific tasks

## Templates

See [references/templates.md](references/templates.md) for all document templates.
