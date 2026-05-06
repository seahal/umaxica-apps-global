# Analytics Consent Boundary

## Status

Completed

## Purpose

This note records the current boundary between:

- strictly necessary service and security processing
- product analytics
- marketing and targeting tracking

The goal is to avoid mixing operational telemetry with optional analytics work before the consent
model is fully implemented.

## Current Repository Signals

The repository contains a complete cookie consent model and UI, plus a runtime gate:

- cookie banner UI
- cookie settings UI
- web cookie consent endpoints
- persisted consent flags for:
  - `consented`
  - `functional`
  - `performant`
  - `targetable`
- **Analytics consent runtime gate** (`app/javascript/analytics_consent_gate.js`)

Relevant implementation references:

- `app/javascript/analytics_consent_gate.js` — Runtime gate that checks consent before analytics
  execution
- `app/javascript/controllers/cookie_banner_controller.js`
- `app/javascript/controllers/cookie_toggle_controller.js`
- `app/controllers/concerns/preference/web_cookie_actions.rb`
- `app/models/current/preference.rb`

### Runtime Gate Implementation

The `installAnalyticsConsentGate()` function (see `app/javascript/analytics_consent_gate.js`)
provides:

- Consent state checking before analytics script initialization
- Callback mechanism for consent changes (`onConsentChange`)
- Protection against pre-consent analytics execution
- OTEL and security events remain unaffected (bypass the gate)

## Current Decision

Until the consent-aware analytics implementation is complete:

- operational telemetry may continue for service reliability and security
- product analytics must remain separate from OTEL
- product analytics should not run before the correct consent category is granted
- marketing or ad-related tracking should not run before the correct consent category is granted

## Working Category Model

### Necessary

This category covers processing that is required to provide, secure, or debug the service.

Examples:

- session and authentication handling
- rate limiting
- anti-bot verification
- critical service error logging
- contact form delivery status

### Functional

This category should remain limited to user-requested convenience behavior.

Examples:

- saved interface preferences
- non-essential UX convenience settings

### Performant

This category is the correct home for product analytics and performance analytics that are not
strictly necessary.

Examples:

- product funnel events
- page and screen flow analysis
- usage analytics
- retention and activation analytics

### Targetable

This category is the correct home for targeting, advertising, and similar tracking.

Examples:

- ad tech
- campaign profiling
- remarketing support

## Minimum Safe Rule For Now

Before consent for optional analytics is confirmed, only collect events that are required for:

- security
- fraud or abuse prevention
- service delivery
- incident response

Do not treat product analytics as necessary by default.

## Allowed Before Optional Consent

The following event types are acceptable as a conservative starting point:

- authentication success and failure
- OTP request and failure
- passkey verification success and failure
- OAuth callback success and failure
- rate limit triggers
- Turnstile verification failures
- contact submission success and failure
- critical external API failures
- unhandled exceptions

These events should be treated as operational or security events, not as growth analytics.

## Hold Until Performant Consent

The following event types should remain disabled until the appropriate optional consent is granted:

- page view analytics
- clickstream analysis
- signup funnel analytics
- onboarding funnel analytics
- feature usage analytics
- retention analytics
- campaign attribution analytics

## Hold Until Targetable Consent

The following should remain disabled until targeting consent is granted:

- advertising pixels
- remarketing identifiers
- audience building
- ad network conversion tracking

## Pending Work

1. Define the exact mapping from implementation features to consent categories.
2. Decide whether product analytics uses only `performant` or a refined category model.
3. ~~Add a runtime gate so optional analytics cannot start before consent is available.~~ ✅
   Completed via `analytics_consent_gate.js`
4. Add documentation that matches the final behavior in the privacy and cookie notices.

## Open Questions

1. Should first-party product analytics always require `performant`, even when implemented without a
   third-party SDK?
2. Should the quick-accept banner action enable only `functional` and `performant`, or all optional
   categories except `targetable`?
3. Should optional analytics be disabled by region until the consent model is complete?
