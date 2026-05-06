# Analysis Agent Brief Index

## Purpose

This directory is split so each topic can be discussed with a separate AI agent.

Each Markdown file is a standalone handoff brief. A human can open one file, start a fresh agent
conversation, and ask the agent to focus only on that brief.

## Recommended Agent Split

1. [Audit And Evidence Plan](./audit-and-evidence-plan.md)
   - Use for audit schema, event semantics, retention, and incident evidence quality.
2. [Jurisdiction Rollout Plan](./jurisdiction-rollout-plan.md)
   - Use for JP, US, and EU rollout order, capability gating, and launch sequence.

Architecture-direction and engine-boundary briefs previously lived here. They have been superseded
by the four-engine decision and moved to `plans/archive/` (`redesign-direction.md`,
`engine-boundary-plan.md`). For the current direction use
`adr/four-engine-restoration-and-base-contract.md`,
`adr/four-app-wrapper-runtime-and-root-retirement.md`, `plans/active/four-engine-reframe.md`, and
`plans/active/four-engine-enforcement-decisions.md`.

## How To Use With Separate Agents

For each topic:

1. Start a fresh agent conversation.
2. Share one file only.
3. Ask the agent to stay inside that file's scope.
4. Ask for:
   - weak points
   - missing decisions
   - better alternatives
   - migration risks
   - concrete next implementation steps

## Notes

- The remaining briefs are related, but each should remain independently discussable.
- If one agent finds a blocker that belongs to another topic, record it as a dependency instead of
  expanding scope.

## Session Recap

The current boundary model is:

- `Identity`
- `Zenith`
- `Foundation`
- `Distributor`

Current discussion focus for follow-up:

1. which engine owns which database group (see `plans/active/four-engine-enforcement-decisions.md`
   section 2)
2. how host labels map onto the four engines (`sign.*`, `acme`, `base.*`, `post.*`)
3. how runtime ownership is split between wrapper apps and engines
