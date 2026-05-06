# Analytics Consent Runtime Gate

## Issue

GitHub #663

## Related

- #658 — Define the future performant-gated product event set
- #659 — Define the minimum pre-consent event allowlist

## Problem

The repository has a cookie consent model with `consented`, `functional`, `performant`, and
`targetable` flags, but no runtime mechanism connects these flags to analytics startup. Optional
analytics code could execute before the user grants the matching consent category.

## Goals

1. Add a runtime gate that checks consent flags before optional analytics can execute.
2. Connect the `performant` flag to product analytics startup.
3. Connect the `targetable` flag to marketing and targeting tracking startup.
4. Keep operational telemetry (OTEL, security events) unaffected.

## Existing Components

| Component                  | Location                                                    | Role                                                         |
| -------------------------- | ----------------------------------------------------------- | ------------------------------------------------------------ |
| Cookie consent flags       | `app/models/current/preference.rb`                          | Stores `consented`, `functional`, `performant`, `targetable` |
| Cookie banner controller   | `app/javascript/controllers/cookie_banner_controller.js`    | Captures user consent choice                                 |
| Cookie toggle controller   | `app/javascript/controllers/cookie_toggle_controller.js`    | Per-category toggle UI                                       |
| Web cookie actions         | `app/controllers/concerns/preference/web_cookie_actions.rb` | Server-side consent persistence                              |
| Analytics consent boundary | `docs/legal/analytics-consent-boundary.md`                  | Policy definition                                            |
| Telemetry separation       | `docs/security/observability-boundary.md`                   | Layer separation rules                                       |

## Implementation Approach

### Phase 1: Server-side gate

- Add a consent check helper (for example in a concern or `Current`) that returns the granted
  consent categories for the current request.
- Guard any future server-side analytics event emission behind a check for the required category.
- Ensure OTEL and audit events bypass this gate entirely.

### Phase 2: Client-side gate

- Add a JavaScript gate that reads the current consent state before loading any optional analytics
  script or module.
- The cookie banner and toggle controllers already persist consent to cookies. The gate reads these
  values.
- If `performant` is not granted, product analytics modules must not initialize.
- If `targetable` is not granted, marketing and ad modules must not initialize.

### Phase 3: Testing

- Unit test: consent gate returns correct categories for each flag combination.
- Integration test: analytics code does not execute when consent is absent.
- Regression test: OTEL and security events fire regardless of consent state.

### Phase 4: Documentation

- Update `docs/legal/analytics-consent-boundary.md` to reference the gate implementation.
- Mark Pending Work #3 as resolved.

## Open Questions

- Should the gate be a Stimulus controller, a plain JS module, or both?
- Should the server-side gate live in `Current` or in a dedicated concern?
- How should the gate behave during the brief window between page load and consent resolution?

## Acceptance Criteria

- [x] Optional analytics cannot execute before matching consent is granted
- [x] Operational telemetry is unaffected
- [x] Gate is testable in unit and integration tests
- [x] Behavior is documented

## Implementation Status

**Completed.** The runtime gate is implemented in `app/javascript/analytics_consent_gate.js`:

- `installAnalyticsConsentGate()` checks consent flags before analytics initialization
- `onConsentChange` callback handles consent state changes
- OTEL and security events bypass the gate (unaffected)
- Unit tests in `test/javascript/analytics_consent_gate.test.js`
- Integrated into `app/javascript/application.js`
