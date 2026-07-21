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
   A request for a non-English report does not override this rule unless the user explicitly asks
   to change the repository language policy itself.
4. Before finishing documentation, ADR, plan, note, memo, harness, or comment work, scan touched
   files for non-English prose.

Run the repository language checker before finishing:

```bash
bin/repository-language-check
```

The checker examines repository knowledge prose as well as source comments and test names. It does
not treat localized string literals, locale payloads, or translation assertions as repository
prose.

For a necessary non-English example or quotation, place a narrow exception immediately before the
affected line:

```markdown
<!-- repository-language: allow-next-line reason=localized-gloss -->
```

Longer necessary examples may use matching `allow-begin` and `allow-end` annotations. Every opening
annotation requires a short reason. Unbalanced, nested, or unexplained annotations are errors.
