# Claude workflow

## 1. Launch

Read `scripts/multi-review.mjs` relative to the installed skill. Pass its complete
contents verbatim to `Workflow` as `script`, with the user's instruction as the
plain-string `args`; omit `args` for the default scope.

```text
Workflow({ script: "<bundled script contents>", args: "<user instruction>" })
```

The initial launch requires inline contents: `scriptPath` rejects installed
skill paths outside the working directory, even after reading them. Keep the
script in its installed location. To resume the same run, use the persisted
script path returned by the launch with `scriptPath` and `resumeFromRunId`.

The bundled script is the source of truth for reviewer models, prompts, and
retry behavior. It runs independent Claude and Codex reviewers in parallel,
then Opus verifies and deduplicates their findings.

**Complete:** Workflow returns `{ reviewers, synthesisFailed, plan }`, where
`plan` contains `summary` and `markdown`. If execution fails, report the failure
and any available partial results.

## 2. Present

Lead with `plan.summary` and the reviewers that ran, then render `plan.markdown`.
It already contains severity-ordered issues, fix approaches, and dismissals;
only adjust heading levels if needed.

When `synthesisFailed` is true, label the returned Markdown **raw, unverified
reviewer outputs** and report that synthesis failed. Otherwise present it as the
verified fix plan.
