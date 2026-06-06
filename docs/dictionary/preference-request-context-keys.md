# Preference Request Context Keys

Preference request context keys are short transport names used in GET parameters, JS-readable
preference cookies, and preference payload projections. They carry UI and request-context
preferences only. They are not authentication, session, refresh, access, credential, ceremony, or
one-time token material.

Rails may write JS-readable preference cookies for browser, Hono, edge, or UI compatibility, but
Rails request code must read authoritative runtime preference state from `Actor.preferences`, not
from JS-readable cookies.

## Terms

### Client Theme Key

- Definition: `ct`, the stable transport key for the current client theme preference.
- Context: `app`, `org`, `com`; GET request context, JS-readable preference cookies, preference
  payload projections, and UI theme code.
- Notes: Accepted by `adr/theme-preference-cookie-and-param-contract.md`. Typical values are
  `li`, `dr`, and `sy`, with long-form compatibility values `light`, `dark`, and `system`.
- Status: `accepted`.

### Language Key

- Definition: `language`, the JS-readable preference cookie key for the current UI language.
- Context: `app`, `org`, `com`; browser, Hono, edge, and UI compatibility code.
- Notes: Keep this cookie key as `language` for Hono framework compatibility. GET request context
  may use `lx`; do not rename the cookie key to `lx` without a separate compatibility plan.
- Status: `accepted`.

### Timezone Key

- Definition: `tz`, the transport key for the current timezone preference.
- Context: `app`, `org`, `com`; GET request context, JS-readable preference cookies, preference
  payload projections, and display localization code.
- Notes: Carries a display and request-context timezone, not an authority boundary.
- Status: `accepted`.

### Currency Key

- Definition: `cu`, the transport key for the current display currency preference.
- Context: `app`, `org`, `com`; optional display preference overlays and preference payload
  projections.
- Notes: Carries display context only. It does not imply billing authority or payment state.
- Status: `accepted`.

### Date Format Key

- Definition: `df`, the transport key for the current date format preference.
- Context: `app`, `org`, `com`; optional display preference overlays and preference payload
  projections.
- Notes: Carries UI display format context only.
- Status: `accepted`.

### Time Format Key

- Definition: `tf`, the transport key for the current time format preference.
- Context: `app`, `org`, `com`; optional display preference overlays and preference payload
  projections.
- Notes: Typical values are `12` and `24`, with long-form compatibility values `hour_12` and
  `hour_24`.
- Status: `accepted`.

### Motion Key

- Definition: `mo`, the transport key for the current motion preference.
- Context: `app`, `org`, `com`; optional display preference overlays and preference payload
  projections.
- Notes: Typical values are `st` and `rd`, with long-form compatibility values `standard` and
  `reduced`.
- Status: `accepted`.

### Density Key

- Definition: `dn`, the transport key for the current UI density preference.
- Context: `app`, `org`, `com`; optional display preference overlays and preference payload
  projections.
- Notes: Typical values are `st` and `cp`, with long-form compatibility values `standard` and
  `compact`.
- Status: `accepted`.

### Page Size Key

- Definition: `ps`, the transport key for the current page size or items-per-page preference.
- Context: `app`, `org`, `com`; optional display preference overlays and preference payload
  projections.
- Notes: `ps` is the current code and test contract. Older references to `pp` or `ipp` are
  documentation drift unless a separate compatibility plan says otherwise.
- Status: `accepted`.

### Adult Content Gate Key

- Definition: `r18s`, the transport key for the current adult content gate preference.
- Context: `app`, `org`, `com`; optional display and content-gating preference projections.
- Notes: Carries a UI/request-context gate preference. It is not an identity, age-verification,
  credential, authorization, or compliance record.
- Status: `accepted`.
