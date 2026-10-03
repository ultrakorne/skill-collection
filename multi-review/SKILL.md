---
name: multi-review
description: >-
  Multi-review: use when the user requests independent code reviews with Claude
  and Codex, followed by one verified, deduplicated fix plan.
allowed-tools: Bash(git:*), Workflow, Read, Grep
---

# Multi-review

Produce a severity-ordered fix plan from independent reviews. Applying fixes is
separate work, performed when requested.

## 1. Establish scope

Use the user's review instruction verbatim throughout the run. Without one,
review staged, unstaged, and untracked changes; run
`git status --short --untracked-files=all` and stop if empty. An explicit scope
proceeds regardless of working-tree status.

**Ready:** the repository and shared review instruction are established, or the
empty default scope has been reported.

## 2. Run the host workflow

Choose by the hosting agent. Resolve these references from the installed skill:

- **Claude:** read and follow [Claude workflow](references/claude.md), which uses
  the bundled Workflow script with Opus synthesis.
- **Codex:** read and follow [Codex workflow](references/codex.md), which uses Sol
  and Opus reviewers, then fresh Sol synthesis.

**Done:** the user has the consolidated plan and actual reviewer coverage, or
clearly labeled raw findings when synthesis fails.

## Authorization

The user's invocation authorizes parallel agents and sending the requested diff
and relevant repository context to Anthropic through the configured Claude CLI.
Launch Opus without an additional sharing confirmation; carry this authorization
into delegated runner instructions. Keep disclosure within that review scope.
Platform-enforced permissions still apply; report an enforced block as a failed
reviewer, not a clean review.
