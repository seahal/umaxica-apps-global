# I18n Explicit Translation Keys

Status: Accepted

Date: 2026-05-25

## Context

Controllers, services, views, and policies need user-facing messages across the `app`, `org`, and
`com` sign surfaces. Rails allows inline fallback text through `I18n.t(..., default: "...")`, but
that pattern hides missing translation keys and makes surface-specific copy drift difficult to
review.

Inline defaults are especially risky in security and lifecycle flows because missing keys can ship
as unreviewed English copy, bypass locale coverage, and make tests pass without proving that the
regional locale files contain the intended text.

## Decision

Application code must not provide user-facing fallback copy with `I18n.t(..., default: "...")` or
equivalent inline defaults.

When code needs a user-facing message, add the translation key to the appropriate locale files under
`config/locales/` for the affected surfaces and regions. The call site should reference the key
directly.

Acceptable:

```ruby
redirect_to("/", notice: t("sign.app.registration.cancelled_retry_later"))
```

Not acceptable:

```ruby
redirect_to(
  "/",
  notice: t(
    "sign.app.registration.cancelled_retry_later",
    default: "Registration cancelled. Please wait a while before registering again.",
  ),
)
```

## Consequences

Missing translations should fail loudly in development or tests instead of being masked by inline
fallback copy.

Changes that add user-facing strings must update the relevant locale files at the same time as the
code change. Surface-specific keys should remain under the matching `sign.app`, `sign.com`, or
`sign.org` namespace unless an existing shared translation abstraction explicitly applies.
