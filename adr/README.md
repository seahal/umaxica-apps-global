# Architecture Decision Records

This directory stores accepted architecture and design decisions.

- Keep decision records focused on what was decided and why.
- Include tradeoffs when they matter to future readers.
- Update `docs/` separately when implementation changes become current behavior.
- Keep non-authoritative decision notes and implementation handoff notes in `notes/`, not under
  `adr/`.

Current database naming decisions:

- `adr/actor-db-naming-policy.md`
- `adr/surface-database-connection-naming.md`

Current audit / chronicle decisions:

- `adr/chronicle-audit-db-consolidation.md`
- `adr/chronicle-audit-implementation-guidance.md`

Current preference decisions:

- `adr/app-actor-client-naming.md`
- `adr/com-actor-visitor-naming.md`
- `adr/org-actor-operator-naming.md`
- `adr/preference-relogin-reconciliation-record-recency.md`
- `adr/preference-extended-option-reference-tables.md`

Current hierarchy / collective decisions:

- `adr/collective-hierarchy-model.md`
- `adr/surface-account-collective-model-naming.md`

Current request-context decisions:

- `adr/actor-current-facade.md`

Current controller-boundary decisions:

- `adr/static-and-guest-controller-boundaries.md`

Current sign configuration decisions:

- `adr/authentication-assurance-level-boundaries.md`
- `adr/sign-up-authentication-handoff-and-social-rt.md`
- `adr/sign-withdrawal-and-membership-surface-policy.md`
- `adr/mfa-reset-account-recovery.md`
- `adr/identifier-hmac-emergency-rotation.md`

Current session-reset decisions:

- `adr/session-reset-on-privilege-transition.md`
- `adr/logout-primitive-and-composition.md`
- `adr/device-session-dbsc-device-id-boundary.md`

Current cookie / session-transport decisions:

- `adr/cookie-domain-scope-by-surface.md`

Current tooling / code-quality decisions:

- `adr/ruby-static-analysis-reek-flog-flay.md`

Current outbound delivery decisions:

- `adr/outbound-message-delivery-interface.md`

Current repository / application boundary decisions:

- `adr/split-into-regional-and-global-repos.md`

Historical engine-era ADRs are retained for traceability only. They do not authorize reintroducing
`engines/`, wrapper apps under `apps/<name>`, `Jit::<EngineName>` namespaces, or `isolate_namespace`
boundaries in this repository.
