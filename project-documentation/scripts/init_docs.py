#!/usr/bin/env python3
"""
Initialize the docs/ structure for a project.

Usage:
    python init_docs.py [project_root] [--name "Project Name"]
    
Examples:
    python init_docs.py .
    python init_docs.py /path/to/project --name "My Game"
"""

import argparse
import os
from pathlib import Path

MASTER_INDEX_TEMPLATE = '''# {project_name} Documentation

<one paragraph description of the project>

## Tech Stack

- **Framework**: <framework>
- **Database**: <database>
- **Hosting**: <hosting>

## Features

| Feature | Description |
|---------|-------------|
| *No features documented yet* | |

## Quick Links

- [CONTEXT.md](CONTEXT.md) — Ubiquitous language / project glossary
'''

CONTEXT_TEMPLATE = '''# {project_name} — Context

<one or two sentences: what this glossary covers and why it exists.>

## Language

**<Term>**:
<one-sentence definition — what it IS, not what it does>
_Avoid_: <aliases or near-synonyms not to use>

## Relationships

- <express cardinality between bold terms, e.g. "An **Order** produces one or more **Invoices**">

## Example dialogue

> **Dev:** "<a question that uses the terms above>"
> **Domain expert:** "<an answer that clarifies a boundary or rule>"

## Flagged ambiguities

- <call out terms used in conflicting ways, with a resolution>
'''

def init_docs(project_root: Path, project_name: str):
    """Initialize the docs structure."""
    docs_dir = project_root / "docs"
    features_dir = docs_dir / "features"

    # Create directories
    features_dir.mkdir(parents=True, exist_ok=True)
    print(f"✅ Created {docs_dir}")
    print(f"✅ Created {features_dir}")

    # Create INDEX.md
    index_path = docs_dir / "INDEX.md"
    if not index_path.exists():
        index_path.write_text(MASTER_INDEX_TEMPLATE.format(project_name=project_name))
        print(f"✅ Created {index_path}")
    else:
        print(f"⚠️  {index_path} already exists, skipping")

    # Create CONTEXT.md
    context_path = docs_dir / "CONTEXT.md"
    if not context_path.exists():
        context_path.write_text(CONTEXT_TEMPLATE.format(project_name=project_name))
        print(f"✅ Created {context_path}")
    else:
        print(f"⚠️  {context_path} already exists, skipping")

    # Create .gitkeep in features to ensure it's tracked
    gitkeep = features_dir / ".gitkeep"
    if not gitkeep.exists():
        gitkeep.touch()

    print(f"\n🎉 Documentation structure initialized!")
    print(f"\nNext steps:")
    print(f"  1. Edit docs/INDEX.md with your project description")
    print(f"  2. Seed docs/CONTEXT.md with core domain terms (most terms live here, not in feature-level CONTEXT.md)")
    print(f"  3. Add feature documentation with: mkdir docs/features/{{feature-name}}")

def main():
    parser = argparse.ArgumentParser(description="Initialize project documentation structure")
    parser.add_argument("project_root", nargs="?", default=".", help="Project root directory")
    parser.add_argument("--name", default="Project", help="Project name for INDEX.md")
    
    args = parser.parse_args()
    project_root = Path(args.project_root).resolve()
    
    if not project_root.exists():
        print(f"❌ Error: {project_root} does not exist")
        return 1
    
    init_docs(project_root, args.name)
    return 0

if __name__ == "__main__":
    exit(main())
