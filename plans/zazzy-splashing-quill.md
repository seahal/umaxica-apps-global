# Plan: Apex-scope JS-readable preference mirror cookies

## Context

`ct`、`tz`、`cu`、`df`、`tf`、`mo`、`dn`、`ps`、`language` など、httponly でない preference
mirror クッキーが `www.umaxica.{app,com,org}`
以外のサブドメイン（`side-jp.umaxica.app`、`jpx.umaxica.app` 等）から参照できない問題。

**`CoreCookieOptions.for` のデフォルト:** `domain: true`（apex-scoped）。  
`domain: false` を明示した場合のみ Domain 属性なし（host-only）になる。

**クッキー種別ごとの書き込みパス:**

| クッキー               | 書き込みパス                                                                                     | 現状          | 期待値        |
| ---------------------- | ------------------------------------------------------------------------------------------------ | ------------- | ------------- |
| `preference_access`    | `preference_auth_cookie_options` → `preference_cookie_options(httponly: true)` → `domain: false` | host-only ✓   | host-only ✓   |
| `preference_refresh`   | `set_refresh_token_cookie` → `preference_auth_cookie_options` → 同上                             | host-only ✓   | host-only ✓   |
| `ct` / `tz` / `cu` 等  | `write_preference_cookie` → `preference_cookie_options(httponly: false)` → `domain: false`       | host-only ✗   | apex-scoped   |
| `preference_consented` | `preference_consented_buffer` → `CoreCookieOptions.for(...)` 直呼び（`domain:` 省略）            | apex-scoped ✓ | apex-scoped ✓ |

**ADR の仕様（`adr/cookie-domain-scope-by-surface.md`）:**

- Credential クッキー（`preference_access`、`preference_refresh`）→ host-only ✓
- JS-readable mirror クッキー（`ct`、`language` 等）→ **apex-scoped** が意図された動作

**ギャップ:** `preference_cookie_options` が `domain: false`
を明示しているため、credential（正しく host-only）と mirror（誤って host-only）の両方に適用されている。

**`CoreCookieDomain.for` の動作:**

- `www.umaxica.app` → `.umaxica.app`（`best_effort_apex`）
- `www.umaxica.com` → `.umaxica.com`
- `www.umaxica.org` → `.umaxica.org`
- `app.localhost` → `.localhost`
- credentials に `COOKIE_DOMAIN_APP` 等が設定されていれば優先使用

## Changes

### 1. `app/controllers/concerns/preference_base.rb`

`preference_cookie_options` に `domain:` キーワード引数を追加（デフォルト `false`
で既存の credential クッキー呼び出しを維持）。

```ruby
def preference_cookie_options(expires_at:, httponly:, domain: false)
  ::CoreCookieOptions.for(
    surface: ::CoreSurface.current(request),
    request: request,
    expires: expires_at,
    httponly: httponly,
    secure: ::JitSessionCookieConfig.force_secure?,
    same_site: :strict,
    path: "/",
    domain: domain,
  )
end
```

`preference_auth_cookie_options` は変更不要 — `preference_cookie_options(httponly: true)` を呼ぶが
`domain:` を渡さないため新デフォルト `false` → host-only 継続。  
`set_preference_dbsc_cookie!` も `preference_cookie_options(httponly: true)`
直呼びなので同様に不変。

### 2. `app/controllers/concerns/preference_cookie_writer.rb`

`write_preference_cookie` が `domain: true` を渡すよう変更。

```ruby
def write_preference_cookie(key, value)
  cookies[key] = preference_cookie_options(
    expires_at: PreferenceBase::REFRESH_TOKEN_TTL.from_now,
    httponly: false,
    domain: true,  # apex-scoped for cross-subdomain JS reads per ADR
  ).merge(value: value)
end
```

### 3. `docs/security/cookie-domain-scope.md`

「JS-Readable Preference Mirrors」セクションに apex-scoped である旨を明記。

```markdown
These cookies are apex-scoped (e.g. `.umaxica.app`) so that all subdomains within a surface can read
them for theme bootstrapping, Hono compatibility, and edge rendering.
```

### 4. `plans/backlog/preference-jwt-js-visible-projection-decision.md`

domain スコープの問題が本プランで対処済みであることを記録。残課題（どの値を JS-visible にするか、Hono
`language` 契約確認等）は継続。

## Files NOT changed

- `preference_consented_buffer.rb` — 既に `CoreCookieOptions.for(...)` 直呼び（apex-scoped）✓
- `preference_auth_cookie_options` — credential クッキー、host-only 継続 ✓
- `preference_access_token_issuer.rb` の `issue_access_token_from` が呼ぶ
  `write_public_option_cookies` → `write_preference_cookie` 経由なので本変更で対応される

## Tests

### `test/controllers/concerns/preference/core_test.rb`

`write_preference_cookie` が domain 属性付きのクッキーを書くことを検証するテストを追加。ハーネスの
`written_cookies` に domain を含めるか、`cookies` モックで確認する。

### `test/security/invariants/cookie_security_invariant_test.rb`

既存テストを確認し、mirror クッキーの domain 属性チェックがあれば合わせて更新。credential クッキーの「domain なし」アサーションは変更しない。

## Verification

1. `bin/rails test test/controllers/concerns/preference/core_test.rb`
2. `bin/rails test test/security/invariants/cookie_security_invariant_test.rb`
3. 実際に `www.umaxica.app` にアクセスして DevTools でクッキーを確認：
   - `ct`、`tz`、`cu` 等に `Domain: .umaxica.app` が付いていること
   - `preference_access` には Domain 属性がないこと（host-only）
