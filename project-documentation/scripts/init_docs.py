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

*Add links as documentation grows.*
'''

def init_docs(project_root: Path, project_name: str):
    """Initialize the docs structure."""
    docs_dir = project_root / "docs"
    features_dir = docs_dir / "features"
    plans_dir = docs_dir / "plans"
    
    # Create directories
    features_dir.mkdir(parents=True, exist_ok=True)
    plans_dir.mkdir(parents=True, exist_ok=True)
    print(f"✅ Created {docs_dir}")
    print(f"✅ Created {features_dir}")
    print(f"✅ Created {plans_dir}")
    
    # Create INDEX.md
    index_path = docs_dir / "INDEX.md"
    if not index_path.exists():
        index_path.write_text(MASTER_INDEX_TEMPLATE.format(project_name=project_name))
        print(f"✅ Created {index_path}")
    else:
        print(f"⚠️  {index_path} already exists, skipping")
    
    # Create .gitkeep in features and plans to ensure they're tracked
    gitkeep = features_dir / ".gitkeep"
    if not gitkeep.exists():
        gitkeep.touch()
    
    gitkeep_plans = plans_dir / ".gitkeep"
    if not gitkeep_plans.exists():
        gitkeep_plans.touch()
    
    print(f"\n🎉 Documentation structure initialized!")
    print(f"\nNext steps:")
    print(f"  1. Edit docs/INDEX.md with your project description")
    print(f"  2. Add feature documentation with: mkdir docs/features/{{feature-name}}")

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
