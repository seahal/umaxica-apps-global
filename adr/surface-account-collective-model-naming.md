# Surface Account and Collective Model Naming

**Status:** Accepted (2026-05-20)

## Context

`Account` and `Collective` are shared domain interfaces, not surface-specific model names.

The runtime actor names are already accepted as `Client`, `Visitor`, and `Operator`. Those names
must remain the authentication, current-context, authorization, and token actor vocabulary.

The hierarchy cleanup also accepted `Collective` as the common interface for recursive nodes that
can contain child nodes and receive account placements. Concrete surface models may use
surface-specific names while implementing that common interface.

## Decision

Keep these shared concerns as the common contracts:

- `Account` for account / placement-like records that can be attached to a collective.
- `Collective` for recursive organization/team/unit/personal hierarchy nodes.

Use these surface-specific model names as the target vocabulary:

| Surface | Runtime actor | Account implementation | Collective implementation |
| ------- | ------------- | ---------------------- | ------------------------- |
| `app`   | `Client`      | `Persona`              | `Enterprise`              |
| `com`   | `Visitor`     | `Individual`           | `Company`                 |
| `org`   | `Operator`    | `Agent`                | `Bureau`                  |

The conceptual flows are:

```text
Client   -> Persona    -> Enterprise
Visitor  -> Individual -> Company
Operator -> Agent      -> Bureau
```

RP/IdP boundary records use `Identity` naming and remain separate from both runtime actors and
Account implementations:

```text
Client   -> ClientIdentity   -> Persona
Visitor  -> VisitorIdentity  -> Individual
Operator -> OperatorIdentity -> Agent
```

The concrete models should include the appropriate shared concern instead of being named after the
concern:

```ruby
class Persona
  include Account
end

class Enterprise
  include Collective
end
```

## Consequences

- `Collective` remains the interface / concern name, not the required concrete model name.
- `Enterprise`, `Company`, and `Bureau` are surface-specific collective implementations.
- `Persona`, `Individual`, and `Agent` are surface-specific account implementations.
- `Client`, `Visitor`, and `Operator` remain runtime actor names and must not be repurposed as the
  account implementation names.
- `ClientIdentity`, `VisitorIdentity`, and `OperatorIdentity` are RP/IdP identity-binding records,
  not Account implementations.
- `Staff`, `User`, and `Customer` must not be reintroduced as runtime actor compatibility names.
- Existing `Workspace`, `Organization`, `Department`, `Division`, `Member`, and
  `OperatorWorkspaceAccount` names are transitional until a deliberate rename plan is accepted.
- Database table, column, index, foreign-key, fixture, policy, and route renames require a separate
  rename matrix and migration plan.

## Related

- `adr/collective-hierarchy-model.md`
- `adr/actor-db-naming-policy.md`
- `adr/app-actor-client-naming.md`
- `adr/com-actor-visitor-naming.md`
- `adr/org-actor-operator-naming.md`
- `docs/architecture/actor-naming.md`
