# Codex workflow

## 1. Resolve reviewers

Select the newest Sol model in the session's available agent models. Use that
explicit model at **high** effort for both review and synthesis. Prefer native
agents; if unavailable, use the [CLI fallback](#sol-cli-fallback). If neither
route provides Sol, report the missing capability.

Use the installed `opus -p` command when it accepts Claude CLI options;
otherwise use `claude -p --model opus`. The `opus` alias selects the latest Opus
supported by the CLI. Inspect `--help` for installed options. Shell aliases may
be absent in noninteractive shells; for mise wrappers that try to update, use
the existing executable from `mise which claude` or `mise which codex`.

**Ready:** a supported Sol model and Opus command are identified.

## 2. Review independently

Start these two reviews in parallel from the same repository:

- **Sol:** spawn a fresh agent with the resolved `model`,
  `reasoning_effort: "high"`, and `fork_turns: "none"` (or the host's equivalent).
- **Opus:** launch the CLI below, with the review brief on stdin.

Give each reviewer only the repository path, shared scope, and this brief:

> Review the requested changes using read-only operations. Gather the diff and
> surrounding code yourself; include relevant untracked files for the default
> scope. Report the scope actually inspected and any incomplete coverage.
>
> Find correctness bugs, regressions, security issues, and material design risks
> introduced by the changes. Each finding needs severity, file:line, a concrete
> trigger and impact, supporting evidence, and a suggested fix. A clean review
> must state what was checked. Return findings only; leave files unchanged and
> leave orchestration to the host.

Keep each reviewer's context independent until both finish.

### Opus command

Create a unique temporary directory outside the reviewed repository. Write the
brief and scope to `prompt.txt` without shell interpolation. Replace the example
paths below with that directory; when available, substitute `opus -p` for
`claude -p --model opus`.

```bash
claude -p --model opus \
  --permission-mode dontAsk \
  --tools 'Read,Grep,Glob,Bash' \
  --allowedTools 'Read,Grep,Glob,Bash(git diff *),Bash(git status *),Bash(git log *),Bash(git show *),Bash(git ls-files *),Bash(git rev-parse *)' \
  --output-format json --no-session-persistence \
  < /tmp/REVIEW_RUN/prompt.txt \
  > /tmp/REVIEW_RUN/opus.json 2> /tmp/REVIEW_RUN/opus.stderr
```

`dontAsk` denies operations that need approval; the allowlist permits review
reads. Tell Opus to use `git diff`, etc., matching those prefixes; use
`GIT_PAGER=cat` in the process environment if needed. Retain permission checks.

Use asynchronous execution while the reviews run. Check the CLI exit status,
JSON `is_error`, `result`, and `permission_denials`; the review is `result`.
Count a review as complete only when its final output covers the requested
scope. A failed process, empty output, or blocked inspection is incomplete;
a denied tool recovered through another read tool need not invalidate coverage.

**Complete:** both reviewers have ended, with their full findings, model
identities, and coverage or failure status recorded.

## 3. Verify and deduplicate

Start a fresh Sol agent with the same model and high effort. Give it the
repository, original scope, both review outputs, and completion statuses, with
this assignment:

> Produce a fix plan using read-only operations. Merge findings about the same
> underlying issue, preserving reviewer attribution. Inspect the actual code
> and requested diff for every candidate. Classify each as verified, dismissed
> with a reason, or unverified because evidence was unavailable.
>
> Return Markdown: a verdict and verified-issue count, then confirmed issues
> critical-first. Each issue needs severity, reviewer attribution, file:line,
> trigger and impact, what you checked, and a concrete **Fix approach**. Include
> **Dismissed** and **Unverified** sections when applicable, and disclose any
> missing reviewer or coverage. Leave files unchanged.

If one reviewer failed, synthesize the available findings as an **incomplete
review**. If both failed, report their failures. Retry empty or failed synthesis
once in a fresh Sol context; if it still fails, present the raw reviews as
**unverified** with the synthesis failure.

**Complete:** every candidate is accounted for, or synthesis failure is explicit.
Render the plan with the models and coverage that actually completed. Remove
this run's temporary artifacts when no longer needed.

## Sol CLI fallback

When native Sol agents are unavailable, resolve an available Sol model from the
installed CLI's model catalog. Run each Sol role as a fresh process with its
brief on stdin, using separate prompt and output files for synthesis:

```bash
codex exec --model SOL_MODEL \
  -c 'model_reasoning_effort="high"' \
  -c 'approval_policy="never"' --sandbox read-only \
  --ephemeral -o /tmp/REVIEW_RUN/sol-review.md \
  - < /tmp/REVIEW_RUN/prompt.txt
```

Replace `SOL_MODEL` with the resolved model ID. Check exit status and the final
message file. Start the review alongside Opus; start synthesis after both end.
These overrides apply only to this run.
