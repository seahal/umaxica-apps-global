# Logout Sequence

## Authority

Logout is acme/www session mutation.

`acme/www` owns current-session logout, all-session logout, session revoke, session-management UI,
refresh-token family mutation, device binding cleanup, step-up freshness cleanup, and logout audit.

`sign/id`, `core`, and `base` are relying parties. They may initiate logout and show local
ceremony/completion UI, but they must not revoke authoritative acme session state.

Logical authority moves now; physical storage may remain where it is. Existing sign-side tables,
models, services, controllers, or namespaces do not imply sign-side authority.

## User-Facing Ceremony

The browser ceremony is surface-local and uses the same shape on every browser surface:

- `GET /sign/out/new`
- `GET /sign/out/edit`
- `POST /sign/out`
- `GET /sign/out/complete`

`GET /sign/out/new` is a redirect-only entry point. `GET /sign/out/edit` is the confirmation page.
`POST /sign/out` is the local logout action or RP launcher, depending on surface authority.
`GET /sign/out/complete` is the friendly completion page and is safe to reload.

`/sign/out/edit?sot=` is retired from the normal browser flow. Completion is session-bound, not URL
token-bound.

## Acme Local Logout

Acme app/com/org surfaces own direct session mutation. Local logout:

1. resolves the current acme session;
2. revokes the current session and current token family with the existing logout primitive;
3. clears acme auth cookies and request-local actor state;
4. records logout audit through the existing authority path;
5. stores a one-time completion marker in the fresh session;
6. redirects to the same surface's `/sign/out/complete`.

Acme local logout must not self-redirect to `/oidc/logout` or mint `id_token_hint` for itself.

## RP Logout Launch

Sign/Core/Base browser surfaces are RPs. Their `POST /sign/out` actions:

1. capture the material needed for logout before any reset;
2. clear or reset the local RP session;
3. store an opaque state token in the fresh Rails session;
4. redirect to the corresponding Acme surface's `GET /oidc/logout`;
5. complete on the RP surface's `/sign/out/complete` after the Acme end-session flow returns.

The RP completion marker is session-bound and one-time. The browser may revisit completion safely,
but the server must not re-assert a fresh logout from stale state.

## Acme OIDC End-Session

`GET /oidc/logout` and `POST /oidc/logout` remain Acme-only protocol endpoints. They validate the
OIDC request, stage exact registered redirect URIs, and use the shared `/sign/out/edit` confirmation
when user confirmation is needed.

`post_logout_redirect_uri` must be an exact registry match. Invalid or unregistered values must
never be redirected to.

## Palm Contract

Palm remains a future native/app-link client. The future completion target is:

`https://<palm-host>/sign/out/complete`

This is documented only; runtime Palm logout is not implemented here.

## Related

- `docs/identity/authority-boundary.md`
- `docs/security/logout-session-management.md`
- `docs/security/session-token-authority.md`
- `docs/security/redirect-vs-ceremony-result.md`
