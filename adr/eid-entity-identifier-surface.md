# EID Entity Identifier Surface

Accepted: 2026-09-08

## Context

UMAXICA needs a stable domain-level identifier that can uniquely identify resources and entities
without coupling external consumers to a database primary key or an implementation-specific storage
model. No existing resource model or persistence boundary currently owns that identifier lifecycle.
Choosing an identifier encoding or fabricating storage during a surface bootstrap would turn an
unreviewed implementation detail into a difficult-to-reverse public compatibility obligation.

## Decision

Adopt **EID = Entity Identifier** and establish `eid.umaxica.net` as the dedicated surface for
EID-related functionality.

An EID is an opaque domain-level identifier. It identifies exactly one entity or resource, must not
be reused for another, and has no consumer-visible semantics in its display formatting. It is not
defined as a UUID, ULID, GUID, DOI, URI, or database primary key.

The initial Rails surface is isolated under the `Eid::Net` namespace and a host constraint. It
provides a minimal homepage; the repository-standard health and revision endpoints; CSP reporting;
and `GET /api/v0/resources/:eid` as the resource-resolution boundary. The route follows the existing
versioned, plural-resource API convention. Until an authoritative EID store and resolver contract
are decided, transport-safe identifiers receive the standard `404` Problem Details response.

The resolver validates untrusted path input for transport safety and maximum size, returns no
internal identifier or target, disables response storage, and performs no redirect. The EID health
profile has no database readiness check until EID persistence exists.

## Consequences

Positive consequences:

- Public identifiers are decoupled from storage implementation and internal primary keys.
- UMAXICA gains a stable namespace and domain concept for resource identification.
- Resolution and future identifier functionality have a dedicated host and controller boundary.
- The bootstrap reuses existing health, revision, error, CSP, host-gating, and security-header
  conventions.

Costs and risks:

- Another public surface must be deployed, monitored, secured, and kept available.
- Identifier lifecycle and permanence become explicit compatibility obligations.
- Careless changes to identifier meaning or reuse rules may be impossible to reverse.
- A resolver returning only `404` is intentionally incomplete and must not be represented as an
  issuance or persistence service.
- Issuance, revocation or tombstones, canonical resolution, and persistence policy require later
  decisions.

## Deferred Decisions

The following are explicitly outside this decision:

- EID binary and text formats;
- UUID, UUIDv7, ULID, or another implementation mechanism;
- identifier issuance mechanism;
- database schema and authoritative storage owner;
- public issuance API;
- authentication and authorization requirements for issuance;
- tombstone and deletion behavior;
- canonical resolver response and redirect behavior;
- federation and cross-system namespaces;
- DOI, Handle, and ARK interoperability;
- persistence guarantees and retention period.

None of these may be inferred from the bootstrap route, its 255-byte transport limit, or the current
not-found response.

## Related

- `docs/architecture/eid-surface.md`
- `docs/reference/api-design-standards.md`
- `docs/reference/health-endpoints.md`
- `adr/internal-health-endpoint-edge-isolation.md`
