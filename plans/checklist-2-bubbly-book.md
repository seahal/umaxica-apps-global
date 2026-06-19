# Checklist 2 — Social 監査レポート＋是正プラン

## Context

`Checklist 2 — Social`（Google/Apple の social signup/login、existing account
resolution、link/unlink、provider
denial/cancel を対象とする 52 項目 P0/P1/P2 セキュリティチェックリスト）に対し、現行の social 認証実装を突き合わせて
**監査レポート（各項目 PASS / GAP / 要検証 + 根拠 file 参照）** を作り、GAP に対する
**是正実装プラン** を立てる。範囲は全優先度（P0+P1+P2）。

調査の結果、設計（ADR/docs）は大半の項目を既に意図しているが、実装側に **provider ID
token のローカル署名検証境界が無い**
という P0 級の核心 GAP が存在することが確認できた（`omniauth-google-oauth2` は ID
token を署名検証せずに decode する）。本プランはこの監査を正式レポートとして `memos/`
に確定保存し、GAP を優先度順に是正することを目的とする。

### 監査対象の主な実装

- `app/controllers/concerns/social_auth.rb` — intent 管理 / state 生成 / step-up / user 整合性
- `app/controllers/concerns/social_callback_guard.rb` — state 検証（CSPRNG / provider bind /
  single-use / TTL）
- `app/models/client_oauth_callback_state.rb` + `SocialAuthCallbackStateStore` — DB 側 single-use
  consume
- `app/models/client_google_identity.rb` / `client_apple_identity.rb` /
  `concerns/social_identifiable.rb` — identity key `(uid, provider)` UNIQUE
- `app/controllers/sign/app/auth/omniauth_callbacks_controller.rb` — callback 処理 / session 発行
- `app/controllers/sign/app/social/authentications_controller.rb` — link/unlink エントリ
- `app/services/social_auth_link_handler.rb` / `social_auth_login_handler.rb` / `SocialAuthService`
- `config/initializers/omniauth.rb` — provider 設定（Google `scope: openid` / Apple code flow）
- 権威 ADR/docs: `adr/acme-sign-core-base-port-boundary.md`,
  `docs/security/social-callback-boundary.md`, `docs/security/social-login-provider-scope.md`,
  `docs/security/authentication-assurance-levels.md`,
  `adr/security-audit-findings-2026-06-13.md`（FINDING-03 = `email_verified=false` 拒否）
- 既存の関連 backlog: `plans/backlog/social-login-provider-gem-oidc-hardening.md`,
  `docs/auth-ceremony/OPEN-QUESTIONS.md`（GQ-01〜GQ-07）

凡例: ✅PASS / ⚠️要検証(部分実装・コードで最終確認が必要) / ❌GAP / ➖設計上対象外

---

## 監査結果テーブル

### Protocol Validation

| ID    | P   | 判定 | 根拠 / 備考                                                                                                                                                                                                                  |
| ----- | --- | ---- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| S-001 | P0  | ✅   | identity は `(uid, provider)` で一意。email は鍵に使わない。`social_identifiable.rb`, 両 identity モデル                                                                                                                     |
| S-002 | P0  | ❌   | **核心 GAP**。`omniauth-google-oauth2` は ID token を **署名検証せず** decode し `extra.id_info.sub` を渡す。ローカルに JWKS 署名検証境界が無い。Apple も部分的。`plans/backlog/social-login-provider-gem-oidc-hardening.md` |
| S-003 | P0  | ⚠️   | finalize 失敗時に link/session/token を残さない方針は ceremony grant + transaction で担保されるが、callback 失敗各経路を要確認                                                                                               |
| S-004 | P0  | ⚠️   | Turnstile は現状 **unlink のみ**。social signup の durable 作成前に server-side Turnstile を要求するかは未確定（要設計判断）                                                                                                 |
| S-005 | P0  | ✅   | `SecureRandom.hex(24)`、session+DB(`ClientOauthCallbackState`)、provider bind、5分 TTL、`consume!` single-use、`secure_compare`                                                                                              |
| S-006 | P0  | ❌   | **GAP**。Google は `scope: openid`（OIDC）だがローカル nonce binding 無し。Apple nonce は provider 任せ。`social-login-provider-gem-oidc-hardening.md`                                                                       |
| S-007 | P0  | ⚠️   | social は OmniAuth gem 経由。PKCE がローカルで required/transaction bind されているか要確認（OIDC RP 経路は S256 実装あり）                                                                                                  |
| S-008 | P0  | ✅   | `callback_path` 固定 + provider 登録の exact match。wildcard 設定無しを最終確認                                                                                                                                              |
| S-009 | P0  | ✅   | state に provider を保存し `provider_mismatch` 検出。Google state を Apple へ流用不可。`social_callback_guard.rb`                                                                                                            |

### Provider Callback Is Not Local Success

| ID    | P   | 判定 | 根拠 / 備考                                                                                                       |
| ----- | --- | ---- | ----------------------------------------------------------------------------------------------------------------- |
| S-010 | P0  | ✅   | Sign=evidence / Acme=commit の ceremony 境界。`docs/security/social-callback-boundary.md`                         |
| S-011 | P0  | ✅   | unknown social → signup checkpoint（guard/confirmation/birthdate 経路）まで durable 留保。`config/routes/sign.rb` |
| S-012 | P0  | ✅   | established account は ceremony grant 必須、grantless login は reject                                             |
| S-013 | P0  | ✅   | ceremony result は one-shot、transaction_id / step-up token に bind                                               |

### New / Existing / Conflict Matrix

| ID    | P   | 判定 | 根拠 / 備考                                                                                                          |
| ----- | --- | ---- | -------------------------------------------------------------------------------------------------------------------- |
| S-014 | P0  | ✅   | `find_by_uid_with_lock` で `(uid,provider)` を決定的解決                                                             |
| S-015 | P0  | ✅   | unknown subject → signup 方針が ADR `sign-up-authentication-handoff-and-social-rt.md` で明示                         |
| S-016 | P0  | ✅   | fail-closed。email 一致でも自動 merge/link しない（GQ-01 は OPEN だが現行 behavior は本項目に合致）                  |
| S-017 | P0  | ✅   | FINDING-03 修正済。`SocialAuthVerifiedProviderAssertion` が `email_verified=false` を拒否。加えて email は鍵に未使用 |
| S-018 | P0  | ⚠️   | provider_boundary / auto_link 等のテストはあるが、disabled/withdrawn/invited account ケースの網羅を要確認            |
| S-019 | P0  | ✅   | principal は uid 追跡。provider email 変更で別 account に移らない                                                    |
| S-020 | P1  | ❌   | provider subject 再割当て / tenant 違い / issuer alias の扱いが明文化されていない（policy GAP）                      |
| S-021 | P1  | ✅   | email 無し時も uid で成立（設計上 email 不要）。docs に明記推奨                                                      |

### Anonymous Login vs Logged-in Attach

| ID    | P   | 判定 | 根拠 / 備考                                                                           |
| ----- | --- | ---- | ------------------------------------------------------------------------------------- |
| S-022 | P0  | ✅   | `VALID_INTENTS=%w(login link step_up)` を server session 保持。Referer/params 非依存  |
| S-023 | P0  | ✅   | link intent は logged-in user + step-up 必須                                          |
| S-024 | P0  | ✅   | current_resource bind、別 user id を params 指定不可                                  |
| S-025 | P0  | ✅   | `social_link` scope の fresh step-up（10分 TTL）                                      |
| S-026 | P0  | ✅   | callback で user 整合性検証（`social_auth.rb:525-534`）、不一致は `UnauthorizedError` |
| S-027 | P1  | ⚠️   | account/org switch 中の attach 誤 context を要確認                                    |

### Cancel / Failure / Denial

| ID    | P   | 判定 | 根拠 / 備考                                                                                        |
| ----- | --- | ---- | -------------------------------------------------------------------------------------------------- |
| S-028 | P0  | ✅   | cancel/denial で `clear_social_state!` / `clear_social_auth_intent!`。失敗経路を最終確認           |
| S-029 | P0  | ⚠️   | logged-in attach cancel で authenticated session を維持し attach state のみ purge することを要確認 |
| S-030 | P0  | ✅   | `consume!`/used フラグで retry 不可。retry は新 transaction                                        |
| S-031 | P1  | ⚠️   | provider timeout/network の unknown outcome reconcile（二重 link/session 防止）を要確認            |
| S-032 | P1  | ⚠️   | failure は内部 `/auth/failure` で安全だが、最終 redirect の `rt` return-target allowlist を要確認  |

### Concurrency / Replay / Idempotency

| ID    | P   | 判定 | 根拠 / 備考                                                                                           |
| ----- | --- | ---- | ----------------------------------------------------------------------------------------------------- |
| S-033 | P0  | ✅   | single-use state + DB unique + user lock で commit 最大1回                                            |
| S-034 | P0  | ✅   | `(uid,provider)` UNIQUE + conditional `(user_id)` UNIQUE                                              |
| S-035 | P0  | ✅   | fail-closed + lock で email/social signup 競合の takeover/誤 merge を防止                             |
| S-036 | P0  | ⚠️   | cancel vs commit、link vs unlink の winner 決定性を lock 前提で要確認                                 |
| S-037 | P1  | ✅   | unique violation を 409 conflict に変換、別 actor へ fallback しない（`social_auth_link_handler.rb`） |
| S-038 | P1  | ⚠️   | `state_reused` は検出するが security event として記録されるか要確認                                   |

### Link / Unlink Safety

| ID    | P   | 判定 | 根拠 / 備考                                                                                                                                                       |
| ----- | --- | ---- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| S-039 | P0  | ⚠️   | docs は `social_unlink` scope の fresh step-up を要求。実装の unlink は Turnstile 経路で、**fresh step-up 必須が満たされているか要確認**（docs と実装の整合確認） |
| S-040 | P0  | ✅   | `LastIdentityError` で最後の認証手段を消す unlink を拒否                                                                                                          |
| S-041 | P0  | ⚠️   | unlink 時の provider token / session impact 定義を要確認                                                                                                          |
| S-042 | P1  | ❌   | link 後の既存 session rotate/revoke risk policy が未実装/未文書化                                                                                                 |
| S-043 | P1  | ❌   | provider 側 revoke/deauthorize webhook の署名検証・idempotency・owner resolution が未実装                                                                         |

### Session / Token / Secret Handling

| ID    | P   | 判定 | 根拠 / 備考                                                                                                                    |
| ----- | --- | ---- | ------------------------------------------------------------------------------------------------------------------------------ |
| S-044 | P0  | ⚠️   | login 成功時の pre-auth session 破棄 + 新 session ID/UserToken 発行（fixation 対策）を `establish_signed_in_session!` で要確認 |
| S-045 | P0  | ⚠️   | `token`/`refresh_token` を DB 保持（`access_type: offline`）。at-rest 暗号化・min scope・rotation/revocation を要確認          |
| S-046 | P1  | ⚠️   | state は session 保持で URL 非露出。token/code を log に残さないことを最終確認                                                 |
| S-047 | P1  | ✅   | oauth endpoint は `no-store`。callback response の cache 抑制も確認                                                            |
| S-048 | P1  | ✅   | `OmniAuthNonAppSocialGuard` の host 制御 + org/com blocked テストあり                                                          |

### Enumeration / Abuse / Audit

| ID    | P   | 判定 | 根拠 / 備考                                                                                                                        |
| ----- | --- | ---- | ---------------------------------------------------------------------------------------------------------------------------------- |
| S-049 | P1  | ⚠️   | unknown/disabled/existing の過剰開示有無を要確認                                                                                   |
| S-050 | P1  | ❌   | social continue/callback に rate limit/anomaly detection が無い（native `rate_limit` concern 未適用）                              |
| S-051 | P2  | ⚠️   | unlink audit はあり。login/link audit の provider/intent/ceremony/actor/result/failure-reason 完全性を要確認（token 非記録は維持） |
| S-052 | P2  | ❌   | login/link/unlink の security notification 方針と false positive 対応が未整備                                                      |

### サマリ（52 項目）

- ✅ PASS: 25
- ⚠️ 要検証（部分実装・コードで最終確認）: 19
- ❌ GAP（要是正）: 8 — S-002, S-006, S-020, S-042, S-043, S-050, S-052（+ S-004 は設計判断待ち）
- ➖ N/A: 0

最大リスクは **S-002 / S-006**（provider ID token のローカル署名検証・nonce 境界の欠如）。

---

## 是正プラン

優先度順。各テーマで「実装 → テスト」をセットにする。`adr`/`docs`/`plans` の英語ポリシーに従う。

### 1. [P0] Provider ID token ローカル検証境界（S-002, S-006, S-007, S-017 freshness）

`plans/backlog/social-login-provider-gem-oidc-hardening.md` を実装トラックに昇格。gem の
`extra.id_info` を信頼せず、callback で **commit/session 発行の前に**
ローカル検証を通す境界を追加する。

- 新規 service（例: `SocialAuthVerifiedProviderAssertion` を拡張、または
  `OidcProviderIdTokenVerifier`）で:
  - Google: JWKS（`https://www.googleapis.com/oauth2/v3/certs`）で
    **署名検証**、`iss`/`aud`/`exp`/`nbf`/`iat`、`alg: none` 拒否
  - Apple:
    JWKS（`https://appleid.apple.com/auth/keys`）で署名検証、**nonce を必須化**（redirect 前に発行した nonce と照合）
  - 両 provider に `iat`（+ 可能なら `auth_time`）の **freshness（最大許容 age）** を適用（AAL1
    social の age 上限を決定）
- Google OIDC 経路に **nonce を発行・session bind・ID token で検証**（`authorize_params`
  に nonce 追加 + `social_callback_guard` 同様の store）
- PKCE が social でローカル enforce/transaction bind されているか確認し、不足なら付与（S-007）
- Apple JWKS は Rails 所有の TTL cache + kid-miss refresh（`json-jwt` 既定の no-cache を回避）
- 検証失敗時は link/session 発行手前で reject し、`state` を consume 済みにして retry 不可に

対象: `app/services/`（検証 service）、`config/initializers/omniauth.rb`（Google nonce/params）、
`app/controllers/sign/app/auth/omniauth_callbacks_controller.rb`（検証呼び出し位置）

### 2. [P1] social エンドポイントの rate limit / anomaly（S-050）

native `rate_limit`（`app/controllers/concerns/rate_limit.rb`）を
`POST /social/auth/:provider/continue` と callback に適用。subject/email を用いた bot
signup・probing を抑制。`feedback_prefer_rails_native` に従い gem は使わない。

対象: `sign/app/social/authentications_controller.rb`、`omniauth_callbacks_controller.rb`

### 3. [P0/P1] Unlink の fresh step-up 整合（S-039, S-041）

`docs/security/authentication-assurance-levels.md` は unlink に `social_unlink` scope の AAL2
step-up を要求。実装の unlink が Turnstile のみで step-up を満たしていない場合、**fresh
step-up を必須化**する（Turnstile は補助）。unlink 時の provider token revoke / session
impact も定義・実装。

対象: `sign/app/social/authentications_controller.rb`、`SocialAuthService.unlink`

### 4. [P0] Provider token at-rest 保護 / rotation（S-045）

`token`/`refresh_token` カラムを Rails `encrypts` で at-rest 暗号化、min
scope を確認、rotation/revocation 経路を定義。必要が無ければ refresh_token 保持自体を見直す。

対象: `app/models/client_google_identity.rb`,
`client_apple_identity.rb`、関連 migration（暗号化は schema 変更を伴わない `encrypts` 宣言で可）

### 5. [P1] Post-link session rotation + provider deauthorize webhook（S-042, S-043）

- link 成功後の session rotate/revoke risk
  policy を ADR 化し実装（`adr/session-token-hardening-baseline.md` 整合）
- Google/Apple の revoke/deauthorize 通知に署名検証・idempotency・owner resolution を持つ webhook
  handler を追加（採否は ADR 判断）

### 6. [P1/P2] Policy/文書化 GAP（S-020, S-021, S-032, S-004, S-049, S-052）

- S-020: subject 再割当て/issuer alias の扱いを `docs/security/social-callback-boundary.md` に明文化
- S-004: social signup の durable 作成前 Turnstile 要否を決定し docs 反映
- S-032: cancel/failure の最終 redirect `rt` allowlist を確認・明文化
- S-049: unknown/disabled/existing の開示差分をレビューし均一化
- S-052: login/link/unlink の security notification 方針（false positive 対応含む）を策定

### 7. [P0/P1] テスト拡充（要検証項目の確定）

監査で ⚠️ とした項目を、コード確認の上で不足分のテストを追加して確定:

- forged Google `extra.id_info.sub` / wrong-sig / `alg:none` / wrong iss/aud / expired / stale
  iat の拒否（S-002）
- Apple missing/mismatch/reused nonce / wrong-sig の拒否（S-006）
- disabled/withdrawn/invited account の social ケース（S-018）
- attach cancel が authenticated session を保持（S-029）
- provider timeout の二重 link/session 無し（S-031）
- link/unlink/cancel/commit 競合の決定性（S-036）
- `state_reused` の security event 記録（S-038）
- login 成功時 session fixation 防止（S-044）

---

## 検証方法

```bash
# 既存 social テストの回帰
bin/rails test test/integration/social_callback_guard_test.rb \
               test/integration/social_auth_login_test.rb \
               test/integration/social_auth_step_up_test.rb \
               test/integration/social_auth_unlink_test.rb \
               test/integration/omniauth_callbacks_test.rb \
               test/integration/apple_auth_test.rb

# 是正テーマごとの新規テスト（forged token / nonce / rate limit / unlink step-up）追加後に該当ファイル単体実行
# 影響が surface/auth 全体に及ぶため最後に広域実行
bin/rails test
```

provider 検証境界は外部 JWKS への実ネットワーク呼び出しを避け、固定鍵で署名した fixture JWT を使う。

---

## 成果物の保存先

- 本ファイルは plan 用ワーク。確定後、監査レポート本体（この 52 項目テーブル + 根拠）を
  `feedback_save_plan_reports_to_memos` に従い `memos/2026-06-19-checklist-2-social-audit.md`
  へ日本語 flat ファイルとして保存する。
- 是正のうち ADR 判断を要する項目（S-004 Turnstile-before-durable、S-042 session rotation、S-043
  webhook、S-020 subject alias policy）は `adr/` に起票、実装トラックは
  `plans/backlog/social-login-provider-gem-oidc-hardening.md` を更新。
- secret/token は memos/notes/docs に記録しない（AGENTS.md ポリシー）。
