# Ruby Static Analysis

Adopted Ruby design-quality tools. Decision and rationale:
`adr/ruby-static-analysis-reek-flog-flay.md`.

These complement RuboCop (style) and Brakeman (security); they target _design_, not style.

## Commands

```bash
bundle exec reek app lib
bundle exec flog app lib
bundle exec flay app lib
```

## How To Read Each Tool

| Tool     | Read it for                  | Primary use here                                                                                                          | Scope rule                                                                                                                                    |
| -------- | ---------------------------- | ------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| **Reek** | Design smells                | Catching sloppy responsibility splitting in AI-assisted code (FeatureEnvy, TooManyStatements, DataClump, control couples) | Tune in `.reek.yml`, not via scattered inline `# :reek:` disables                                                                             |
| **Flog** | Methods that are too complex | High-risk paths first: authorization, withdrawal, session/token revocation, billing                                       | A high score on those paths blocks review                                                                                                     |
| **Flay** | Duplication                  | Spotting accidental copy-paste in application code                                                                        | **Reference only — not a "must" or "should".** Flay also flags intentional duplication and cannot tell it apart from accidental; never a gate |

## When To Run

Run on Ruby changes that touch responsibility boundaries, or any of the high-risk paths
(authorization, withdrawal, session/token revocation, billing). They are review-time tools, not
auto-fixers — do not blanket-suppress findings to silence output; prefer `.reek.yml` tuning with a
stated reason.

Flay is the exception: treat it as reference only, neither a "must" nor a "should". It also detects
intentional, correct duplication and cannot distinguish it from accidental copy-paste, so use its
output only as a hint for judgement — consolidate genuine accidental copy-paste, ignore deliberate
repetition — and never block on it.

## CI Status

`config/ci.rb` (run by `bin/ci`) does **not** currently run these tools. Until a CI step is added,
the discipline is local and review-time. See the ADR's Consequences section.

## Related

- `adr/ruby-static-analysis-reek-flog-flay.md`
- `.reek.yml` — per-surface smell tuning and exclude paths.
- `.agents/harnesses/rules/generic/absolute-rules.mdc`
