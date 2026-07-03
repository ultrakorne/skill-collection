export const meta = {
  name: 'multi-review',
  description: 'Run N independent reviewers in parallel (Claude + Codex), then have Opus dedup, verify, and write an issue-by-issue fix plan. Optional free-form instruction string steers every reviewer; no string = uncommitted changes',
  phases: [
    { title: 'Review', detail: 'Independent reviewers in parallel, fresh context each' },
    { title: 'Synthesize', detail: 'Opus dedups, verifies against the code, writes the fix plan' },
  ],
}

// ─────────────────────────────────────────────────────────────────────────────
// INSTRUCTION — a single free-form string passed as the Workflow `args`. It is
// injected verbatim into EVERY reviewer (Claude + Codex), so they all review the
// same thing. Examples:
//
//   (no args)                                  → uncommitted working-tree changes
//   "review this branch against master"        → branch diff (each reviewer runs git itself)
//   "review master...feature, focus on auth"   → that range, with a focus
//
// No git-range parsing here on purpose: each reviewer is an agent that reads the
// instruction and gathers the right diff with git itself.
// ─────────────────────────────────────────────────────────────────────────────

const INSTRUCTION = typeof args === 'string' && args.trim() ? args.trim() : ''
const DEFAULT_SCOPE =
  'Review the current UNCOMMITTED changes in this repository (staged + unstaged + untracked).'

// Shell-quote a string for safe interpolation into the Codex bash command.
function shQuote(s) {
  return `'` + s.replace(/'/g, `'\\''`) + `'`
}

const CLAUDE_REVIEW_PROMPT = `You are an independent senior code reviewer. You have no other reviewer's output — form your own opinion.

WHAT TO REVIEW: ${INSTRUCTION || DEFAULT_SCOPE}

Gather the changes yourself with Bash, choosing the git command that fits the instruction above:
  - uncommitted changes:  git --no-pager diff HEAD   (+ git --no-pager diff --cached, and git ls-files --others --exclude-standard then Read each untracked file)
  - a branch / range:     git --no-pager diff <base>...<head>   (and git --no-pager log --oneline <base>..<head>)
Read enough surrounding code (not just the diff hunks) to judge correctness in context.

Focus, in priority order:
  1. Correctness bugs — wrong logic, off-by-one, nil/error handling, race conditions, data loss, security, broken edge cases.
  2. Real regressions or behavior changes the diff introduces.
  3. Design risks worth flagging (only if material).
Do NOT report style/formatting nits unless they cause a real bug. Be concrete: cite file and line, and explain WHY it is wrong, not just what it is.

Return findings via the structured output tool. If the code looks correct, return an empty findings array with a short note.`

// Codex native reviewer. With an instruction, use `adversarial-review`, which
// accepts free-form focus text and infers scope from it. With no instruction,
// use the plain working-tree `review`.
const CODEX_BASE =
  'COMPANION="$(ls -d "$HOME"/.claude/plugins/cache/openai-codex/codex/*/ 2>/dev/null | sort -V | tail -1)scripts/codex-companion.mjs"'
const CODEX_COMMAND = INSTRUCTION
  ? `${CODEX_BASE}; node "$COMPANION" adversarial-review --wait ${shQuote(INSTRUCTION)}`
  : `${CODEX_BASE}; node "$COMPANION" review --wait --scope working-tree`

const REVIEWERS = [
  {
    name: 'claude',
    kind: 'claude',
    model: 'opus',
    effort: 'xhigh',
    prompt: CLAUDE_REVIEW_PROMPT,
  },
  {
    name: 'codex',
    kind: 'bash',
    command: CODEX_COMMAND,
  },
]

// ─────────────────────────────────────────────────────────────────────────────

const REVIEW_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['findings', 'notes'],
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['severity', 'title', 'detail'],
        properties: {
          severity: { type: 'string', enum: ['critical', 'high', 'medium', 'low', 'nit'] },
          file: { type: 'string' },
          line: { type: 'string' },
          title: { type: 'string' },
          detail: { type: 'string' },
          suggested_fix: { type: 'string' },
        },
      },
    },
    notes: { type: 'string' },
  },
}

// The synthesis output is deliberately SHALLOW — two scalar string fields, no
// nested arrays-of-objects. A deep schema (issues[]/dismissed[] each with many
// required fields) makes the model pack a huge JSON blob into one tool call, and
// large nested array arguments get silently dropped at the tool-call boundary —
// leaving only the leading scalar (`summary`) and collapsing the whole plan to an
// empty stub. Prose in a single `markdown` string sidesteps that failure mode
// entirely, and it's what the skill renders to the user anyway.
const PLAN_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['summary', 'markdown'],
  properties: {
    summary: {
      type: 'string',
      description: 'One or two sentences: the overall verdict and how many verified issues there are.',
    },
    markdown: {
      type: 'string',
      description:
        'The FULL issue-by-issue fix plan as GitHub-flavored markdown, ready to show the user (headings per issue with severity + title, the reviewers that flagged each, file:line refs, the problem, a "Fix approach" line, and a Dismissed section). Must not be empty.',
    },
  },
}

function bashRunnerPrompt(command) {
  return `You are a command runner. Execute EXACTLY the following shell command from the current working directory, using a Bash timeout of 600000 ms (it is a Codex review and may take several minutes). Return its complete stdout as your final message, VERBATIM — no summary, no commentary, no added markdown fences, no preamble. If the command exits non-zero, return its stderr verbatim instead.

COMMAND:
${command}`
}

const SCOPE_LABEL = INSTRUCTION || 'uncommitted working-tree changes'

// ── Phase 1: fan out every reviewer in parallel, each with fresh context ──
phase('Review')
log(`Reviewing: ${SCOPE_LABEL}. Launching ${REVIEWERS.length} independent reviewers in parallel: ${REVIEWERS.map(r => r.name).join(', ')}`)

const reviews = await parallel(
  REVIEWERS.map((r) => async () => {
    if (r.kind === 'bash') {
      const out = await agent(bashRunnerPrompt(r.command), {
        label: `review:${r.name}`,
        phase: 'Review',
        model: 'haiku',
      })
      return { name: r.name, kind: 'bash', output: out }
    }
    const res = await agent(r.prompt, {
      label: `review:${r.name}`,
      phase: 'Review',
      model: r.model || 'opus',
      effort: r.effort || 'xhigh',
      schema: REVIEW_SCHEMA,
    })
    return { name: r.name, kind: 'claude', output: res }
  })
)

const ok = reviews.filter(Boolean)
log(`${ok.length}/${REVIEWERS.length} reviewers returned. Synthesizing...`)

// ── Phase 2: Opus dedups, verifies against the real code, writes the plan ──
phase('Synthesize')

const reviewBlocks = ok
  .map((r) => {
    const body = r.kind === 'bash' ? r.output : JSON.stringify(r.output, null, 2)
    return `===== REVIEWER: ${r.name} (${r.kind}) =====\n${body}`
  })
  .join('\n\n')

const synthesisPrompt = `You are the lead reviewer. Below are ${ok.length} INDEPENDENT reviews of the SAME set of changes, produced by different reviewers with no knowledge of each other. Some findings will overlap, some will be wrong.

WHAT WAS REVIEWED: ${INSTRUCTION || DEFAULT_SCOPE}

Your job — do NOT fix anything, only produce a plan:
1. DEDUP: merge findings that describe the same underlying issue (even if worded differently). Note which reviewers flagged each.
2. VERIFY: for every candidate issue, open the actual code with Read/Grep/Bash (gather the same diff the instruction above describes) and confirm it is genuinely a problem in the current changes. Keep an issue only when you have confirmed it against the real code; say what you checked. If a reviewer clearly reviewed the WRONG scope (e.g. a different branch than the instruction names), dismiss its findings and say so.
3. DISMISS false positives: if a finding does not hold up against the code, list it under a "Dismissed" section with the reason — do not silently drop it.
4. For each REAL issue give: severity, file:line, a clear problem statement, and a concrete fix approach (file/function and the change). Order issues by severity (critical first).

Return your result as the structured output with exactly two fields:
  - "summary": one or two sentences — the overall verdict and how many verified issues there are.
  - "markdown": the FULL plan as GitHub-flavored markdown, ready to show the user. Use a "## " heading per issue (numbered, with severity + title), and under each: the reviewers that flagged it, the file:line references, the problem, and a "**Fix approach:**" line. End with a "## Dismissed" section (title + reason each) when any findings were dismissed. If the code is genuinely clean, say so plainly in the markdown.

Be concise and concrete. Reference file:line. Prefer fewer, verified, high-signal issues over a long unverified list. Put ALL substantive content in "markdown" — never leave it empty.

${reviewBlocks}`

// A plan is degenerate when the model failed to deliver real content — null (agent
// died), or a blank/stub markdown body. Legitimate "code is clean" verdicts still
// carry a real markdown explanation, so they are NOT degenerate.
function isDegeneratePlan(p) {
  if (!p || typeof p !== 'object') return true
  const md = typeof p.markdown === 'string' ? p.markdown.trim() : ''
  return md.length < 40
}

// Build a fallback plan straight from the raw reviewer outputs so that a broken
// synthesis step never silently discards findings the reviewers actually reported.
function rawFallbackMarkdown(reviews) {
  return reviews
    .map((r) => {
      if (r.kind === 'bash') {
        return `## Reviewer: ${r.name} (raw)\n\n\`\`\`\n${String(r.output || '').trim()}\n\`\`\``
      }
      const out = r.output || {}
      const findings = Array.isArray(out.findings) ? out.findings : []
      const body = findings.length
        ? findings
            .map((f, i) => {
              const loc = f.file ? `\`${f.file}${f.line ? ':' + f.line : ''}\`` : ''
              const fix = f.suggested_fix ? `\n\n**Suggested fix:** ${f.suggested_fix}` : ''
              return `### ${i + 1}. [${f.severity}] ${f.title}\n${loc ? loc + '\n\n' : ''}${f.detail}${fix}`
            })
            .join('\n\n')
        : '_No findings reported._'
      const notes = out.notes ? `${out.notes}\n\n` : ''
      return `## Reviewer: ${r.name}\n\n${notes}${body}`
    })
    .join('\n\n---\n\n')
}

let plan = await agent(synthesisPrompt, {
  label: 'synthesize:opus',
  phase: 'Synthesize',
  model: 'opus',
  effort: 'xhigh',
  schema: PLAN_SCHEMA,
})

// Guard: if synthesis came back empty/degenerate, retry once — most such failures
// (a dropped tool-call argument, a transient error) clear on a second attempt.
if (isDegeneratePlan(plan)) {
  log('Synthesis returned an empty/degenerate plan — retrying once.')
  plan = await agent(
    `${synthesisPrompt}\n\nNOTE: a previous attempt returned an empty result. Put the entire plan in the "markdown" field as plain GitHub-flavored markdown text; do not leave it blank.`,
    { label: 'synthesize:opus:retry', phase: 'Synthesize', model: 'opus', effort: 'xhigh', schema: PLAN_SCHEMA },
  )
}

// Fallback: still degenerate → surface the raw reviewer findings verbatim so
// nothing is lost. The caller/skill renders plan.markdown either way.
let synthesisFailed = false
if (isDegeneratePlan(plan)) {
  synthesisFailed = true
  log('Synthesis still empty after retry — falling back to raw reviewer findings so nothing is lost.')
  plan = {
    summary: `Synthesis failed to produce a consolidated plan; showing the ${ok.length} raw reviewer outputs verbatim (not deduped or verified).`,
    markdown: `> ⚠️ The synthesis step failed to return a plan, so these are the **raw, unverified** reviewer findings. Dedup/verify them by hand.\n\n${rawFallbackMarkdown(ok)}`,
  }
}

return { reviewers: ok.map((r) => r.name), synthesisFailed, plan }
