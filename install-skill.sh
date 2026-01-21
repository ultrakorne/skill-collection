#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Target directories
CLAUDE_SKILLS_DIR="$HOME/.claude/skills"
OPENCODE_SKILLS_DIR="$HOME/.config/opencode/skills"

# Script directory (where skills are located)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    echo "Usage: $0 <skill-name>"
    echo ""
    echo "Installs or updates a skill to Claude Code and OpenCode."
    echo ""
    echo "Arguments:"
    echo "  skill-name    The folder name of the skill to install"
    echo ""
    echo "Available skills:"
    for dir in "$SCRIPT_DIR"/*/; do
        if [ -d "$dir" ] && [ "$(basename "$dir")" != ".claude" ]; then
            echo "  - $(basename "$dir")"
        fi
    done
    exit 1
}

# Check if skill name is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: No skill name provided${NC}"
    echo ""
    usage
fi

SKILL_NAME="$1"
SKILL_SOURCE="$SCRIPT_DIR/$SKILL_NAME"

# Check if skill exists
if [ ! -d "$SKILL_SOURCE" ]; then
    echo -e "${RED}Error: Skill '$SKILL_NAME' not found at $SKILL_SOURCE${NC}"
    echo ""
    usage
fi

echo -e "${YELLOW}Installing skill: $SKILL_NAME${NC}"
echo ""

# Install to Claude Code
if [ -d "$HOME/.claude" ]; then
    echo -n "Installing to Claude Code ($CLAUDE_SKILLS_DIR)... "
    mkdir -p "$CLAUDE_SKILLS_DIR"
    rm -rf "$CLAUDE_SKILLS_DIR/$SKILL_NAME"
    cp -r "$SKILL_SOURCE" "$CLAUDE_SKILLS_DIR/$SKILL_NAME"
    echo -e "${GREEN}Done${NC}"
else
    echo -e "${YELLOW}Claude config folder not found, skipping${NC}"
fi

# Install to OpenCode
if [ -d "$HOME/.config/opencode" ]; then
    echo -n "Installing to OpenCode ($OPENCODE_SKILLS_DIR)... "
    mkdir -p "$OPENCODE_SKILLS_DIR"
    rm -rf "$OPENCODE_SKILLS_DIR/$SKILL_NAME"
    cp -r "$SKILL_SOURCE" "$OPENCODE_SKILLS_DIR/$SKILL_NAME"
    echo -e "${GREEN}Done${NC}"
else
    echo -e "${YELLOW}OpenCode config folder not found, skipping${NC}"
fi

echo ""
echo -e "${GREEN}Skill '$SKILL_NAME' installed successfully!${NC}"
