---
name: grill-with-docs
disable-model-invocation: true
description: Grilling session that challenges your plan against the existing domain model, sharpens terminology. Use when user wants to stress-test a plan against their project's language and documented decisions.
---

<what-to-do>

Interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

Ask the questions one at a time, waiting for feedback on each question before continuing.

If a question can be answered by exploring the codebase, explore the codebase instead.

</what-to-do>

<supporting-info>

## Domain awareness

During codebase exploration, also look for existing documentation:

### File structure

```
docs/
├── INDEX.md                      # Master TOC - ALWAYS read first
├── CONTEXT.md                    # Project-level ubiquitous language (glossary)
└── features/
    └── feature-name/
        ├── INDEX.md              # Feature TOC - read when working on feature
        ├── CONTEXT.md            # Optional: feature-specific terms only
        ├── DESIGN.md             # Required: what/why, requirements, user stories
        ├── TECHNICAL.md          # Required: how, implementation, data models
        └── [topic].md            # Optional: sub-components (scoring.md, etc.)
```

## During the session

Use the AskUserQuestion tool if available

### Challenge against the glossary

When the user uses a term that conflicts with the existing language in `CONTEXT.md`, call it out immediately. "Your glossary defines 'cancellation' as X, but you seem to mean Y — which is it?"

### Sharpen fuzzy language

When the user uses vague or overloaded terms, propose a precise canonical term. "You're saying 'account' — do you mean the Customer or the User? Those are different things."

### Discuss concrete scenarios

When domain relationships are being discussed, stress-test them with specific scenarios. Invent scenarios that probe edge cases and force the user to be precise about the boundaries between concepts.

### Cross-reference with code

When the user states how something works, check whether the code agrees. If you find a contradiction, surface it: "Your code cancels entire Orders, but you just said partial cancellation is possible — which is right?"

### Update CONTEXT.md inline

When a term is resolved, update `CONTEXT.md` right there. Don't batch these up — capture them as they happen. the project-documentation skill provides info about the context format

`CONTEXT.md` should be totally devoid of implementation details. Do not treat `CONTEXT.md` as a spec, a scratch pad, or a repository for implementation decisions. It is a glossary and nothing else.

</supporting-info>
