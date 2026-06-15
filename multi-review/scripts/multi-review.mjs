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

const PLAN_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['summary', 'issues', 'dismissed'],
  properties: {
    summary: { type: 'string' },
    issues: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['id', 'title', 'severity', 'sources', 'files', 'verified', 'problem', 'fix_approach'],
        properties: {
          id: { type: 'integer' },
          title: { type: 'string' },
          severity: { type: 'string', enum: ['critical', 'high', 'medium', 'low', 'nit'] },
          sources: { type: 'array', items: { type: 'string' }, description: 'Which reviewers flagged this (e.g. claude, codex)' },
          files: { type: 'array', items: { type: 'string' }, description: 'file:line references' },
          verified: { type: 'boolean', description: 'Confirmed real by reading the actual code' },
          verification_note: { type: 'string' },
          problem: { type: 'string' },
          fix_approach: { type: 'string' },
        },
      },
    },
    dismissed: {
      type: 'array',
      description: 'Findings discarded as false positives / not real, with why',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['title', 'reason'],
        properties: {
          title: { type: 'string' },
          source: { type: 'string' },
          reason: { type: 'string' },
        },
      },
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
1. DEDUP: merge findings that describe the same underlying issue (even if worded differently). Record which reviewers flagged each (the "sources").
2. VERIFY: for every candidate issue, open the actual code with Read/Grep/Bash (gather the same diff the instruction above describes) and confirm it is genuinely a problem in the current changes. Set verified=true only when you have confirmed it against the real code; add a one-line verification_note saying what you checked.
3. DISMISS false positives: if a finding does not hold up against the code, put it in "dismissed" with the reason — do not silently drop it.
4. For each REAL issue write: a clear problem statement and a concrete fix_approach (how you would fix it — file/function and the change), ordered by severity (critical first).

Be concise and concrete. Reference file:line. Prefer fewer, verified, high-signal issues over a long unverified list.

${reviewBlocks}

Return the structured plan.`

const plan = await agent(synthesisPrompt, {
  label: 'synthesize:opus',
  phase: 'Synthesize',
  model: 'opus',
  schema: PLAN_SCHEMA,
})

return { reviewers: ok.map((r) => r.name), plan }
