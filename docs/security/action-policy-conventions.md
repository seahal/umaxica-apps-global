# Action Policy Conventions

This Rails monolith uses server-side Action Policy as the authorization boundary. The current audit
should evaluate route-to-controller-to-policy-to-test wiring, not the raw count of policy files.

## Audit Summary

- Hono and React Router are not present in this repository, so there is no separate JavaScript
  backend or client loader/action path that bypasses Rails authorization.
- Identity, credential, account, organization, and avatar graph mutations already use effective
  server-side policy checks in the dangerous paths.
- Empty shell policies are deny-all placeholders through `ApplicationPolicy`; they are not a cleanup
  target for this remediation.
- Published routes that are still implementation stubs must still wire policy checks before product
  behavior is added.

## Required Controller Rules

- `:private` `create`, `update`, and `destroy` actions must call `authorize!` unless they are
  explicitly documented as an exception in the security regression test.
- Route-published stubs must place the policy call before the stub response.
- UI visibility, hidden buttons, disabled controls, and future frontend permission flags are not
  authorization. The Rails controller boundary must still authorize the action.
- Manual policy instantiation is prohibited by default because it bypasses normal Action Policy
  context and instrumentation. If a manual instance is unavoidable, document the reason in the
  controller and add a regression-test exception.
- Association scoping can be an acceptable exception for session, revocation, ceremony, or protocol
  controllers, but the controller, test allowlist, or docs must state the reason.

## Current Remediation

Organization membership CRUD now resolves the parent organization on the relevant surface and then
authorizes either the organization or the membership record through `OrganizationMembershipPolicy`.
Member records are resolved through the parent organization association, so a membership id from a
different organization is not reachable through the route.

Org staff stub areas now use `OrgStaffPolicy` at the controller boundary. Until the operator role
model is finalized, the policy denies by default and only permits an operator whose installed actor
context delegates the existing manager/view role predicates.

The regression guard lives in `test/unit/security/action_policy_usage_test.rb`. Its allowlist is a
temporary inventory of known private mutation exceptions with comments explaining why each group is
not using a record-level controller policy yet.
