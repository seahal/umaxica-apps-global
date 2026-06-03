# Dictionary

This directory contains the DDD ubiquitous language for the application domain.

Use this directory to record terms that should have one shared meaning across product discussion,
implementation, tests, and documentation.

## Files

- `access-terms.md` - authentication, verification, session lifecycle, and access terminology.
- `alphabet.md` - alphabetical index from A to Z.
- `glossary.md` - existing domain-specific terms, abbreviations, and naming rules.
- `identity-account-organization-avatar.md` - core SNS-domain terms: Identity, Account,
  Organization, Avatar, Handle, public_id.

## Entry Format

Use this format when adding or refining a term:

```markdown
### Term

- Definition: The shared domain meaning of the term.
- Context: Where this term is used, such as `app`, `org`, `com`, or a bounded context.
- Notes: Important constraints, alternative names, or implementation references.
- Status: `draft`, `accepted`, or `deprecated`.
```

## Rules

- Prefer domain language over framework or database terminology.
- Do not mix terms across the `app`, `org`, and `com` surfaces unless a shared abstraction already
  exists.
- Mark uncertain definitions as `draft` instead of presenting them as settled.
- Promote stable, accepted terms here when they affect product behavior or implementation.
