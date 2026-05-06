# Observability Boundary

## Status

Pending

## Purpose

This note records the current separation between:

- operational telemetry
- audit and security events
- product analytics

The goal is to prevent these concerns from being mixed into one system.

## Current Decision

The application should not use one event pipeline for every purpose.

Instead, it should separate at least these three layers:

1. OTEL and technical telemetry
2. audit and security events
3. product analytics

## Layer 1: OTEL And Technical Telemetry

Primary purpose:

- reliability
- performance debugging
- incident investigation

Typical contents:

- request timing
- SQL timing
- background job timing
- external API latency
- exceptions
- service dependency failures

Primary audience:

- engineering
- SRE
- incident responders

OTEL should remain focused on technical observability.

## Layer 2: Audit And Security Events

Primary purpose:

- accountability
- abuse investigation
- security review
- compliance support

Typical contents:

- login success and failure
- session revoke
- passkey registration
- MFA or verification changes
- sensitive configuration changes
- staff actions on user-facing records

Primary audience:

- security
- operations
- compliance

Audit events are not the same as product analytics.

## Layer 3: Product Analytics

Primary purpose:

- understand user flow
- understand activation and retention
- understand product adoption

Typical contents:

- signup started
- signup completed
- onboarding completed
- feature used
- first value reached

Primary audience:

- product
- growth
- business

Product analytics must remain separate from audit events and OTEL.

## Why Separation Matters

If the layers are mixed together:

- retention rules become unclear
- access control becomes unclear
- privacy review becomes harder
- dashboards become noisy
- event naming becomes unstable

Each layer exists for a different operational reason and should keep a different schema, retention
policy, and access path.

## Current Repository Fit

The repository already shows:

- OTEL usage for technical observability
- structured event logging patterns
- authentication and preference systems that can produce audit-worthy events
- cookie consent primitives that can later gate optional analytics

This means the repository can support separation, but the product analytics layer is not yet fully
defined.

## Minimum Rule For Implementation

For now:

- OTEL remains technical only
- audit and security events cover required service and security actions
- product analytics stays pending until consent-aware rules are finalized

## Event Placement Rule

Use this rule when adding a new event:

- if it answers "is the system healthy?" -> OTEL / technical telemetry
- if it answers "who did what?" -> audit or security events
- if it answers "how do users move through the product?" -> product analytics

If an event seems to fit more than one layer, split it into separate events rather than forcing one
event to serve multiple purposes.

## Pending Work

1. Define the minimal audit event list for authentication and sensitive settings.
2. Define the minimal product event list for consent-aware analytics.
3. Define data retention and access rules per layer.
4. Link optional analytics startup to the consent model.
