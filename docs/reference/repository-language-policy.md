# Repository Language Policy

Repository-authored prose must be written in English.

This keeps harness instructions, architecture decisions, plans, operational documentation,
implementation handoff notes, and exploratory memos readable by all future agents and maintainers.

## Scope

The English-only rule applies to:

- `AGENTS.md`
- `.agents/harnesses/`
- `adr/`
- `docs/`
- `plans/`
- `notes/`
- `memos/`
- code comments and test names
- implementation summaries that are intended to be committed

## Exceptions

Non-English text is allowed only when the file explicitly needs it:

- localization documentation
- translation keys, fixtures, examples, or locale payloads
- customer-visible copy for a non-English locale
- quoted external material where the original language is relevant
- test data that verifies Unicode, locale handling, or multilingual behavior

When using an exception, make the reason clear from the surrounding section, filename, or test
context.

## Agent Workflow

When writing or updating repository prose:

1. Write new material in English.
2. If touched material contains Japanese or another non-English language, translate that touched
   material to English unless it falls under an exception.
3. Keep user conversation language separate from repository language. Chat replies may follow the
   user's language; committed repository content must remain English.
4. Before finishing documentation, ADR, plan, note, memo, harness, or comment work, scan touched
   files for non-English prose.

Useful review command for Japanese text:

```bash
rg -n "[ぁ-んァ-ン一-龯]" AGENTS.md .agents/harnesses adr docs plans notes memos
```

Any hit must either be translated to English or clearly belong to an exception.
