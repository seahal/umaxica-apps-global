# GH-560: Investigate Phantom &query= Parameter in Preference URLs

GitHub: #560

## Summary

When visiting `https://sign.umaxica.org/preference/email?ri=jp`, an empty `&query=` parameter is
automatically appended to the URL.

## Investigation Result

The Rails application does not add `&query=` to URLs. Investigation confirmed:

- Integration tests show no `query` parameter in redirect Location headers or rendered page links.
- `default_url_options` only merges `ri`, `lx`, `ct`, `tz`.
- No controller, view, JavaScript, middleware, or route injects `query`.

**Conclusion:** The parameter originates from outside the application.

## Remaining Steps

- [ ] Check Cloudflare Tunnel/WAF rules for Transform Rules or Page Rules appending `query=`.
- [ ] Browser DevTools: verify whether `query=` appears in the initial request or after redirect.
- [ ] Incognito/private window test with all extensions disabled.
- [ ] Direct access via `sign.org.localhost` in development (bypass Cloudflare Tunnel).
- [ ] Check Cloudflare access logs for edge vs origin presence of the parameter.

## Implementation Status (2026-04-07)

**Status: APP-SIDE INVESTIGATION COMPLETE**

Rails application confirmed as not the source of `&query=`. Remaining investigation is external
(Cloudflare Tunnel/WAF rules, browser extensions).

## Improvement Points (2026-04-07 Review)

- The app-side investigation is already sufficient to rule out Rails as the source. Convert the
  remaining steps into an operations checklist with owner and environment.
- Add a closure rule for the issue: either document the external root cause or record a bounded "not
  reproducible in app" conclusion with evidence.
