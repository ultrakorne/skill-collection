#!/usr/bin/env python3
"""
Add a new feature to the docs structure.

Usage:
    python add_feature.py <feature-name> [project_root] [--with-context]

Examples:
    python add_feature.py user-authentication
    python add_feature.py game-lobby /path/to/project
    python add_feature.py scoring-system --with-context
"""

import argparse
import re
from pathlib import Path

def to_title(kebab_name: str) -> str:
    """Convert kebab-case to Title Case."""
    return " ".join(word.capitalize() for word in kebab_name.split("-"))

FEATURE_INDEX = '''# {title}

<one paragraph summary: what this feature does and why it exists>

## Documents

| Document | Purpose |
|----------|---------|
| [DESIGN.md](DESIGN.md) | Components, user flows, design decisions |
| [TECHNICAL.md](TECHNICAL.md) | Architecture, source files, noteworthy behavior |
'''

FEATURE_INDEX_WITH_CONTEXT_ROW = (
    "| [CONTEXT.md](CONTEXT.md) | Feature-specific terms (only here because they don't surface outside this feature) |\n"
)

CONTEXT_TEMPLATE = '''# {title} — Context

<one or two sentences: what this feature-local glossary covers and why these terms didn't go into the project-level docs/CONTEXT.md.>

## Language

**<Term>**:
<one-sentence definition — what it IS, not what it does>
_Avoid_: <aliases or near-synonyms not to use>

## Relationships

- <express cardinality between bold terms>

## Example dialogue

> **Dev:** "<a question that uses the terms above>"
> **Domain expert:** "<an answer that clarifies a boundary or rule>"

## Flagged ambiguities

- <call out terms used in conflicting ways, with a resolution>
'''

DESIGN_TEMPLATE = '''# {title} — Design

## Overview

<what does this feature do? one paragraph>

## Components

### <Component Name>

<description of this component and its responsibility — visible UX, not code structure>

## User Flows

### <Flow Name>

<describe the main flow: screens, user interactions, what happens step by step>

## Design Decisions

*Document key decisions as they are made — the "why", not the "how".*
'''

TECHNICAL_TEMPLATE = '''# {title} — Technical

<!--
TECHNICAL.md is NOT an API reference.
- Do NOT list every function / changeset / event / assign / attribute.
- Do NOT restate what reading the source file already shows.
- DO describe architecture, what each source file is for, and non-obvious behavior.
-->

## Architecture

<one short paragraph: how the feature is wired end to end — which layer does what,
how data flows, any scope/ownership enforcement>

## Source Files

| File | Role |
|------|------|
| `lib/...` | <one-line role> |

## Data Model

<schema code blocks ONLY if the persisted shape is non-obvious or load-bearing.
Skip field-by-field prose.>

## Noteworthy Behavior

<The point of this doc. Things a reader CAN'T learn by reading the code:
performance paths, race-condition handling, cascade algorithms, optimistic-UI
contracts, migration quirks. Keep each item to 1-4 sentences. If there is nothing
non-obvious, this section is legitimately short or absent.>

## Dependencies

- <short bullet list>
'''

def add_feature(project_root: Path, feature_name: str, with_context: bool = False):
    """Add a new feature documentation folder."""
    # Validate feature name
    if not re.match(r'^[a-z][a-z0-9-]*$', feature_name):
        print(f"❌ Error: Feature name must be kebab-case (e.g., 'user-authentication')")
        return 1

    docs_dir = project_root / "docs"
    if not docs_dir.exists():
        print(f"❌ Error: docs/ directory not found. Run init_docs.py first.")
        return 1

    feature_dir = docs_dir / "features" / feature_name
    if feature_dir.exists():
        print(f"❌ Error: Feature '{feature_name}' already exists at {feature_dir}")
        return 1

    # Create feature directory
    feature_dir.mkdir(parents=True)
    print(f"✅ Created {feature_dir}")

    title = to_title(feature_name)

    # Create required files
    index_body = FEATURE_INDEX.format(title=title)
    if with_context:
        index_body += FEATURE_INDEX_WITH_CONTEXT_ROW
    (feature_dir / "INDEX.md").write_text(index_body)
    print(f"✅ Created INDEX.md")

    (feature_dir / "DESIGN.md").write_text(DESIGN_TEMPLATE.format(title=title))
    print(f"✅ Created DESIGN.md")

    (feature_dir / "TECHNICAL.md").write_text(TECHNICAL_TEMPLATE.format(title=title))
    print(f"✅ Created TECHNICAL.md")

    if with_context:
        (feature_dir / "CONTEXT.md").write_text(CONTEXT_TEMPLATE.format(title=title))
        print(f"✅ Created CONTEXT.md (feature-local glossary)")

    print(f"\n🎉 Feature '{feature_name}' documentation created!")
    print(f"\nNext steps:")
    print(f"  1. Edit the files in {feature_dir}")
    print(f"  2. Add this feature's domain terms to docs/CONTEXT.md (project-level glossary — default location)")
    if with_context:
        print(f"  3. Use docs/features/{feature_name}/CONTEXT.md ONLY for terms that are strictly local to this feature")
    else:
        print(f"  3. Only create a feature-level CONTEXT.md if the feature has terms with no meaning outside it (rerun with --with-context)")
    print(f"  4. Add optional files as needed: FLOW.mermaid or topic-specific .md files")
    print(f"  5. Update docs/INDEX.md with an entry for this feature")

    return 0

def main():
    parser = argparse.ArgumentParser(description="Add a new feature to docs")
    parser.add_argument("feature_name", help="Feature name in kebab-case (e.g., 'user-authentication')")
    parser.add_argument("project_root", nargs="?", default=".", help="Project root directory")
    parser.add_argument(
        "--with-context",
        action="store_true",
        help="Also create a feature-local CONTEXT.md. Use only when this feature has terms that don't exist anywhere else in the project.",
    )

    args = parser.parse_args()
    project_root = Path(args.project_root).resolve()

    return add_feature(project_root, args.feature_name, with_context=args.with_context)

if __name__ == "__main__":
    exit(main())
