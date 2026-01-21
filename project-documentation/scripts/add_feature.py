#!/usr/bin/env python3
"""
Add a new feature to the docs structure.

Usage:
    python add_feature.py <feature-name> [project_root]
    
Examples:
    python add_feature.py user-authentication
    python add_feature.py game-lobby /path/to/project
"""

import argparse
import re
from pathlib import Path
from datetime import date

def to_title(kebab_name: str) -> str:
    """Convert kebab-case to Title Case."""
    return " ".join(word.capitalize() for word in kebab_name.split("-"))

FEATURE_INDEX = '''# {title}

<brief description of what this feature does and why it exists>

## Documents

| Document | Purpose |
|----------|---------|
| [DESIGN.md](DESIGN.md) | Components, user flows, design decisions |
| [TECHNICAL.md](TECHNICAL.md) | Implementation details, data models, APIs |

## Last Updated

{date}
'''

DESIGN_TEMPLATE = '''# {title} — Design

## Overview

<what does this feature do? one paragraph>

## Components

### <Component Name>

<description of this component and its responsibility>

## User Flows

### <Flow Name>

<describe the main flow: screens, user interactions, what happens step by step>

## Design Decisions

*Document key decisions as they are made.*

## Out of Scope

- <explicitly excluded functionality>
'''

TECHNICAL_TEMPLATE = '''# {title} — Technical

## Architecture

<how does this feature fit into the overall system?>

## Data Model

<tables, schemas, or data structures>

## API / Interfaces

<endpoints, function signatures, or module interfaces>

## Implementation Notes

<key implementation details, gotchas, performance considerations>

## Dependencies

- <dependencies>

## Testing

<how to test this feature>
'''

def add_feature(project_root: Path, feature_name: str):
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
    today = date.today().isoformat()
    
    # Create required files
    (feature_dir / "INDEX.md").write_text(FEATURE_INDEX.format(title=title, date=today))
    print(f"✅ Created INDEX.md")
    
    (feature_dir / "DESIGN.md").write_text(DESIGN_TEMPLATE.format(title=title))
    print(f"✅ Created DESIGN.md")
    
    (feature_dir / "TECHNICAL.md").write_text(TECHNICAL_TEMPLATE.format(title=title))
    print(f"✅ Created TECHNICAL.md")
    
    print(f"\n🎉 Feature '{feature_name}' documentation created!")
    print(f"\nNext steps:")
    print(f"  1. Edit the files in {feature_dir}")
    print(f"  2. Add optional files: FLOW.mermaid, CHANGELOG.md, or topic-specific .md files")
    print(f"  3. Update docs/INDEX.md with an entry for this feature")
    
    return 0

def main():
    parser = argparse.ArgumentParser(description="Add a new feature to docs")
    parser.add_argument("feature_name", help="Feature name in kebab-case (e.g., 'user-authentication')")
    parser.add_argument("project_root", nargs="?", default=".", help="Project root directory")
    
    args = parser.parse_args()
    project_root = Path(args.project_root).resolve()
    
    return add_feature(project_root, args.feature_name)

if __name__ == "__main__":
    exit(main())
