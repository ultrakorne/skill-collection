# skill-collection

Agent skills for Claude Code, Codex, Cursor, OpenCode and any other agent that reads `.agents/skills`.

## Skills

- `project-documentation` — maintain `docs/` as lean, present-state project documentation (index, context, per-feature docs, ADRs)
- `grill-with-docs` — stress-test a plan against the project's domain language and documented decisions
- `improve-codebase-architecture` — find deepening and refactoring opportunities, informed by `CONTEXT.md` and `docs/adr/`
- `multi-review` — run several independent reviewers in parallel and merge their findings into one verified, deduplicated fix plan

## Install with skillm

[skillm](https://github.com/ultrakorne/skillm) installs one canonical copy into `.agents/skills` and symlinks it into every agent you enable.

```sh
curl -fsSL https://raw.githubusercontent.com/ultrakorne/skillm/master/install.sh | sh
```

```sh
skillm install ultrakorne/skill-collection --global     # pick skills, install for your user
skillm install ultrakorne/skill-collection --local      # or install into the current project (committable)
```

## Install with npx skills

Vercel's [`skills`](https://github.com/vercel-labs/skills) CLI uses the same layout and `skills-lock.json`, so both tools can manage the same project.

```sh
npx skills add ultrakorne/skill-collection                              # pick skills, install into the project
```

## Attribution

grill with docs is heavily based on <https://github.com/mattpocock/skills>
I incorporated the context into the project-documentation skill and have the grill one use that structure
