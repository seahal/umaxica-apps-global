# Ruby Static Analysis: Reek, Flog, Flay

## Status

Accepted on 2026-05-17.

## Context

This codebase receives a large volume of AI-assisted Ruby changes. The recurring failure modes of
that code are not syntax or style (RuboCop already covers style, Brakeman covers known security
patterns). They are:

- sloppy responsibility splitting — methods and classes that do too many unrelated things;
- over-complex methods concentrated in the highest-risk paths (authorization, withdrawal,
  session/token revocation, billing);
- copy-paste duplication that diverges silently later.

The `reek`, `flog`, and `flay` gems are already vendored (`Gemfile:227-229`) and `.reek.yml` already
carries surface-aware tuning, but no decision record states that they are part of the review
discipline, and `config/ci.rb` (run by `bin/ci`) does **not** invoke them. Their status was
effectively "available but not adopted".

## Decision

The three tools are adopted as a Ruby design-quality discipline, each with a defined purpose:

1. **Reek** — `bundle exec reek app lib`. Read it for **design smells**. Its primary value here is
   catching the sloppy responsibility splitting typical of AI-generated code (FeatureEnvy,
   TooManyStatements, DataClump, control-couple methods). `.reek.yml` is the source of truth for
   per-surface tuning; tighten it there rather than scattering `# :reek:` disables.
2. **Flog** — `bundle exec flog app lib`. Read it for **methods that are too complex**. Prioritize
   the highest-risk paths: authorization, withdrawal, session/token revocation, and billing. A high
   flog score on those paths is a blocker for review, not a note.
3. **Flay** — `bundle exec flay app lib`. Read it for **duplication**, but treat the whole tool as
   **reference only — neither a "must" nor a "should"**. Flay also flags duplication that is
   intentional and correct (parallel-by-design code, deliberately repeated structure, test setup);
   it cannot distinguish intentional repetition from accidental copy-paste. So flay output is an
   input to judgement, never a gate: consolidate when it reveals genuine accidental copy-paste,
   ignore it when the repetition is deliberate. It is not a basis for blocking review on its own.

These are review-discipline tools, not auto-fixers. They inform human/agent judgement; they do not
get blanket-suppressed to make output go away.

## Evidence

- `Gemfile:227-229` — `flog`, `flay`, `reek` are vendored in the dev/test group.
- `.reek.yml` — existing per-directory smell tuning (controllers, helpers, mailers, models) and
  `exclude_paths` for legacy/vendor.
- `config/ci.rb` — current CI steps; reek/flog/flay are **not** among them.

## Consequences

- The adopted invocations are exactly `bundle exec reek app lib`, `bundle exec flog app lib`,
  `bundle exec flay app lib`. Run them on Ruby changes that touch responsibility boundaries or the
  high-risk paths above.
- CI does not yet enforce these. Until a CI step is added to `config/ci.rb`, the discipline is
  review-time and local; wiring a non-blocking (or path-scoped blocking) CI step is a tracked
  follow-up, not part of this decision.
- Flay is reference-only by decision: it is neither a "must" nor a "should" gate, because it also
  detects intentional duplication and cannot tell it apart from accidental copy-paste. Do not file
  or act on flay findings (test-only or otherwise) as defects without a judgement that the
  duplication is genuinely accidental.
- Per-finding suppressions must be justified and prefer `.reek.yml` tuning over inline disables.

## Related

- `docs/reference/ruby-static-analysis.md` — how to run and read the tools.
- `.harnes/policies/forbidden_patterns.md` — blanket-suppression prohibitions.
- `adr/frontend-architecture-toolchain.md` — sibling toolchain decision.
