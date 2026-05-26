# Redirect Targets

Redirect targets are split into three separate lanes. These names are public contract names and
controller/service code should use them consistently.

- `pt` means path target. It is for local path returns such as post-login, post-update, cancel, and
  retry destinations. It accepts only path plus query.
- `nt` means navigation target. It is for internal flow and screen transitions. It accepts registry
  keys, not caller-supplied URLs or arbitrary paths.
- `xt` means external target. It is for handoff to another origin. It accepts only named or
  explicitly allowlisted external destinations.

Do not use `it` as an abbreviation for internal target. The internal flow abstraction is `nt`
because it is a navigation target.

## Path Targets

`pt` is path-plus-query only. The path target resolver rejects:

- schemes and hosts, including `https://evil.example` and `http://evil.example`;
- protocol-relative URLs such as `//evil.example`;
- backslashes, including `/\evil.example` and `\evil.example`;
- control characters, CRLF, NUL, and encoded control characters;
- encoded slash or backslash host escapes such as `%2f` and `%5c`;
- userinfo;
- fragments;
- blank or nil values;
- executable schemes such as `javascript:` and `data:`.

Allowed examples:

- `/dashboard`
- `/dashboard?tab=security`
- `/configuration/security`
- `/sign/out/complete?x=1`

Rejected `pt` values produce a `Redirects::TargetResult` with `failure_reason` and, when a value was
present, `unsafe_value_digest`. Dangerous values must not be silently converted to the default path.

## Navigation Targets

`nt` resolves through `Redirects::NavigationTargetResolver`.

The registry owns the mapping from key to path helper. A controller or flow may pass a scope so only
the keys valid for that flow can resolve. Raw paths and absolute URLs are invalid `nt` input even if
they point at the same application.

Current baseline registry keys include:

- `checkpoint`
- `selector`
- `dashboard`
- `configuration_security`
- `signed_out`
- `home`

Registry entries must resolve to `pt`-valid paths. A registry entry that resolves to an external URL
is invalid and must fail closed.

## External Targets

`xt` resolves through `Redirects::ExternalTargetResolver`.

External redirects are allowed only after explicit allowlist or registry resolution. `xt` rejects
userinfo, fragments, control characters, unallowlisted origins, and HTTP downgrades except for
development/test localhost-style origins. Path joins must stay inside the selected origin, so a path
such as `//evil.example` is invalid.

When merging query parameters for an external redirect, do not relay redirect-like parameters from
the caller. The resolver strips dangerous keys including:

- `redirect_uri`
- `return_to`
- `redirect_to`
- `rt`
- `pt`
- `nt`
- `xt`
- `next`
- `continue`
- `url`

`allow_other_host: true` may appear only inside the `xt` facade in `Common::Redirect`. Direct use in
controllers, concerns, or services is forbidden.

## Priority

Internal redirect priority is explicit:

1. controller-declared `nt`;
2. signed/session `nt`;
3. signed `pt`;
4. raw `pt` when it validates as a path target;
5. explicit default path.

`xt` is not part of the internal priority chain. Actions that hand off to another origin must call
the external target resolver directly and must not let an external target override `pt` or `nt`.

Security-dangerous upper-priority values fail closed. Benign missing values may continue to the next
priority entry and eventually to the explicit default path.

## Controller Use

Controllers should use the facade methods from `Common::Redirect`:

- `redirect_to_pt(default: dashboard_path)`
- `redirect_to_nt(:selector)`
- `redirect_to_xt(:rp_app, path: "/signed-out")`
- `redirect_to_xt_url(url, allowed_urls: [...])`
- `resolve_redirect_target(priority: [...], default: dashboard_path)`

Do not redirect directly to a raw request parameter.

## Legacy Names

Legacy names such as `rt`, `return_to`, `redirect_to`, `redirect_uri`, `next`, and `continue` are not
the public internal-return contract. Existing OIDC protocol fields named `redirect_uri` remain
protocol inputs, but they must resolve through the OIDC client registry and external-target
boundary before any cross-host redirect.

Remaining `rt` and `return_to` uses in sign-in, sign-up, step-up, logout, social, and jump flows are
migration debt. They must either move to `pt`, `nt`, or `xt`, or be isolated with an owning-flow
reason until that flow is rebuilt.

## Audit

Use:

```bash
bin/audit_redirects
```

The audit reports direct parameter redirects, direct `allow_other_host: true`, legacy `rt` /
`return_to` reads, and old safe-return helper names. The security test suite also enforces that
production `allow_other_host: true` is limited to the `xt` facade.
