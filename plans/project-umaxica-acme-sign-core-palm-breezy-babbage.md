# Objective: Grill — Token Binding / Abuse / Ops Hardening

> NOTE: 本ファイルは plan mode の作業ファイルとして書いている。最終成果物としては
> `plans/objective-grill-token-binding-abuse-ops-hardening.md` に同じ内容を保存する (plan
> mode 中はそのパスへ直接書けないため、承認後にリネーム/コピーする)。
>
> 監査日: 2026-06-14 / 対象: Acme(IdP/AS) · Sign(credential/refresh/step-up/ceremony) · Core(Web
> RP/BFF + Rails API) · Palm(native bearer
> API)。本監査は read-only。実装・migration・config・routing・test は一切変更していない。

## Context（なぜこの監査をするか）

前回の "OpenAI-style account security review v2" は Advanced Account Security / Lockdown /
Enterprise controls の観点を整理し、`mfa_level` の浅さ、credential-change
revocation の矛盾、recovery secret の即時 access 問題、capability policy、enterprise
reservation を洗い出した。

本監査はそこから漏れやすい 8 領域 — (1) DPoP/DBSC/device binding、(2) auth endpoint rate limit、(3)
JWT/JWKS/signing key lifecycle、(4) security notification matrix、(5) operator negative
authorization、(6) org membership/deprovision/token revocation、(7) chronicle tamper evidence、(8)
recovery secret issuance policy
— を、実コード・ADR・docs/security・tests の根拠付きで監査することを目的とする。結論には必ず file:line を添える。確証が取れないものは UNKNOWN として残す。矛盾は片方を正にせず conflict として明示する。

検証深度の注記: 本監査では中核 5 経路を監査者が直接読んで line 確認した (DPoP resolver、refresh
rotation、recovery consume、chronicle model、chronicle ADR)。それ以外の file:line は read-only
survey による報告で、`[survey]` と付記する。 `[verified]` は監査者が当該行を直接読んだもの。

---

## 1. Executive Summary

**全体判定:
YELLOW**（複数の RED 項目を内包する YELLOW。中核の crypto/binding/rotation は堅牢だが、recovery 方針・notification・audit
tamper-evidence・membership revocation に account-takeover/forensic レベルのギャップがある。）

### 最大リスク 5 件

1. **RED — Recovery secret consume が通常 session を直接発行する。** recovery secret
   credential は通常の secret credential
   sign-in として扱われ (`app/controllers/sign/app/in/secret_credentials_controller.rb:267, 330-331`
   `[verified]`)、 `process_standard_login` → `establish_signed_in_session!` (`:208-211`
   `[verified]`) で通常 session を発行する。consume 時に既存 session / refresh
   family を revoke せず、passkey/TOTP の再登録・再確認も要求しない。recovery 専用処理は audit
   chronicle 1 行のみ (`audit_recovery_code_used!` `:397-411`
   `[verified]`)。→ 本監査の方針(recovery は restricted recovery
   state への one-time 証票)と真っ向から矛盾。

2. **RED — User-visible security notification が事実上存在しない。**
   sign-in/new-device/credential-change/recovery issue/consume いずれの security
   event でも user 宛 notification を送る経路が見つからない。`Email::App::AlertMailer#notice`
   (`app/mailers/email/app/alert_mailer.rb`) は存在するが auth/credential flow から呼ばれていない
   `[survey]`。email 変更時に旧 email へ通知する経路も NOT FOUND。→ attacker による silent
   takeover を検知/通知できない。

3. **YELLOW(RED寄り) — DPoP/DBSC binding は per-token opt-in で、unbound token は素の bearer。**
   `dpop_valid?` は `token_jkt.blank? && !scheme_dpop && @dpop_proof.blank?`
   のとき無条件 true を返す (`app/controllers/concerns/authentication_current_resource_resolver.rb:110`
   `[verified]`)。つまり binding 無しで発行された access/refresh token は DPoP
   proof 無しで使える。さらに binding mismatch は plain 401 (`failure(:dpop_binding_mismatch)` `:65`
   `[verified]`) 止まりで、refresh family revoke も anomaly escalation もしない。→ stolen unbound
   token はそのまま使える。どの threat model で unbound を許容するかが未文書。

4. **YELLOW — Chronicle に tamper-evidence が無い(ADR が明示的に後回し)。** `ClientChronicle` は
   `readonly?` override も DB immutability 制約も持たず、`discarded_at` / `purged_at`
   を持つ可変行 (`app/models/client_chronicle.rb:13-17, 43-114` `[verified]`)。
   `previous_hash`/chain/digest/signature/event_uuid は NOT FOUND。ADR
   `adr/chronicle-audit-implementation-guidance.md:83-86` `[verified]` が "Digest-chain fields,
   sequence assignment, validation behavior, and tamper verification workflows belong in a later
   implementation plan" と明記しており、未実装は意図的。→ compromised operator/app
   bug による audit 改竄を構造的に検知できない。

5. **YELLOW — Org membership 変更時の client/visitor token revocation が欠落、operator も race。**
   operator suspension/termination は `target.staff_tokens.not_revoked.find_each(&:revoke!)`
   で revoke する (`app/services/org_operator_lifecycle_execute.rb:110` `[survey]`) が、client
   workspace membership (`client_memberships.left_at`) 変更時の token/session/grant revocation
   handler は NOT FOUND。operator 側も `update!` と `revoke_target_sessions!`
   が別操作で transaction 境界が無く deprovision↔refresh race の窓がある `[survey]`。org 権限は JWT
   claim に入っていない様子(access token required claims は `iss aud typ exp sub sid act jti acr`
   `[survey]`)なので stale-claim 問題は小さいが、重要 write が role 変更後に DB
   authorization を再確認するかは UNKNOWN。

### 今すぐ確認すべき UNKNOWN 5 件

- **U1**: recovery secret credential の consume は本当に MFA を必ず挟むのか、それとも
  `process_standard_login` 直行で full session になり得るのか。`finalize_mfa_login!` /
  `establish_signed_in_session!`
  の MFA 分岐を line 確認する必要あり (`secret_credentials_controller.rb:180-228` 周辺)。
- **U2**: credential change(passkey/TOTP/secret 追加・削除、email/tel 変更)時に既存 session/refresh
  family を revoke するか。前回 review で「ADR と finding が矛盾」と整理済み。本監査でも revocation 経路を確定できていない(conflict として §C1 参照)。
- **U3**: `/oauth/authorize` に baseline(300/min) 以外の rate
  limit があるか。survey は「NONE」と報告したが authorizations_controller 群を line 確認していない。
- **U4**: access token の discard(`discarded_at`)が実際に request
  path で参照され即時失効するか。resolver は `currently_usable_at`
  scope を使う (`authentication_current_resource_resolver.rb:130-135`
  `[verified]`)が、その scope 定義の内容(discarded_at/expiry 条件)を確認していない。
- **U5**: DBSC verification が Core browser
  session の refresh で実際に enforce されるか (`dbsc_verification_service.rb` は存在するが call
  chain の起点を line 確認していない)。なお docs は `app/services/dbsc/` を指すが実体は flat な
  `app/services/dbsc_*.rb` (doc/code drift, §C2)。

### 実装前に ADR 化すべきもの

- A. **Recovery secret = restricted recovery/bootstrap 証票**
  の正式定義(issue 条件・step-up 必須・consume 後の session/refresh 全 revoke・再登録要求・atomicity・rate
  limit)。
- B. **Token binding policy**: どの surface/token を mandatory
  binding、どれを opt-in 許容とするかの threat model 明文化(Palm bearer は DPoP
  mandatory 化候補、Core は DBSC)。
- C. **Security notification matrix**: forced notification の最小集合と high-assurance
  (`mfa_level`) での強制ルール、旧 email への通知。
- D. **Chronicle integrity plan**:
  digest-chain/sequence/`readonly?`/DB 制約の実装計画 (ADR が後回し宣言済みなので「次の implementation
  plan」を起こす)。
- E. **Org/membership revocation contract**: membership removal/downgrade/deprovision/owner transfer
  × {session, refresh family, access token, external grant, device session} の revoke
  matrix、将来 SSO/SCIM の revoke hook 予約点。

### 過剰なので defer すべきもの

- 全 access token への JTI-based revocation
  list(blockchain 的 per-token 失効)。現状の session-record + idle/absolute TTL + family
  revoke で十分機能している。短命化方針と併せ defer。
- Chronicle の暗号署名・external WORM sink。まずは `readonly?`+sequence+digest-chain で十分。
- Enterprise SSO/SCIM の本実装。今回は revoke hook 予約点の文書化のみで足りる。
- DPoP nonce challenge の常時強制。replay は JTI store(TTL 300s)で抑止できており、high-value
  endpoint に限定して reserve でよい。

---

## 2. Scope Boundary

### 前回 review (v2) で扱ったもの

- `mfa_level`(NOTHING/WEAK/MEDIUM/FULL)の浅さ・未ルーティング・無監査。
- credential-change revocation の ADR↔finding 矛盾(未確定として持ち越し)。
- recovery secret が one-time だが軽量経路で即時 access を与える問題。
- capability policy、enterprise reservation、lockdown controls。

### 今回 review で追加で扱うもの(本書)

- DPoP/DBSC/device binding の enforcement 実体。
- auth endpoint rate limit / abuse control の endpoint×key×threshold。
- JWT/JWKS/signing key lifecycle(alg allowlist、kid、rotation、claims、key custody)。
- security notification matrix(event×channel)。
- operator/support negative authorization(できてはいけないこと)。
- org membership/deprovision/token revocation。
- chronicle/audit tamper evidence。
- recovery secret issuance policy(issue 条件と consume semantics)。

### 今回扱わないもの

- `mfa_level` の routing/監査の再設計(前回スコープ。本書は notification 連動のみ言及)。
- 商品購入/課金 audit、product analytics。
- OpenAI/Google との完全一致。Umaxica に必要な差分としてのみ評価する。
- 本実装・migration・config・routing・test の変更(本監査は read-only)。

---

## 3. PASS / PARTIAL / FAIL / UNKNOWN Table

凡例:
PASS=必要 control が実在し enforce、PARTIAL=部分的/条件付き、FAIL=必要 control が欠落、UNKNOWN=本監査で確証できず。`[verified]`=監査者が当該行を直接確認、`[survey]`=探索 agent 報告。

### Area 1 — DPoP / DBSC / Device Binding

| control                                              | status           | evidence (file:line)                                                                       | risk | recommendation                           |
| ---------------------------------------------------- | ---------------- | ------------------------------------------------------------------------------------------ | ---- | ---------------------------------------- |
| DPoP proof 検証(typ/alg/jwk/sig/htm/htu/iat/ath/jti) | PASS             | `app/services/dpop_proof_validator.rb:32-81` `[survey]`                                    | low  | keep                                     |
| DPoP 秘密鍵 `d` 混入の拒否                           | PASS             | `dpop_proof_validator.rb:43` `[survey]`                                                    | low  | keep                                     |
| DPoP JTI replay 防止(RDB, TTL 300s)                  | PARTIAL          | `dpop_request_verifier.rb:32-38`; refresh/login のみ stateful, API は stateless `[survey]` | med  | high-value API も stateful 検討          |
| Access token 使用時 DPoP 必須                        | FAIL(opt-in)     | `authentication_current_resource_resolver.rb:110` `[verified]` 無 binding は true          | high | Palm bearer を mandatory 化 ADR          |
| Token binding と request proof の一致検証            | PASS(binding 時) | `dpop_request_verifier.rb:45-47`(jkt match); resolver `:65,170-178` `[verified]`           | med  | keep                                     |
| binding mismatch 時の escalation                     | FAIL             | `:65` plain 401, family revoke 無し `[verified]`                                           | high | mismatch を anomaly+family revoke 候補に |
| DBSC proof 検証(typ/alg/aud/iat/jti, RSA>=2048)      | PASS             | `app/services/dbsc_proof_validator.rb:6-11,32-82` `[survey]`                               | low  | keep                                     |
| DBSC session binding(session_id/public_key/sig)      | PARTIAL          | `dbsc_verification_service.rb:15-37` `[survey]`; call 起点 line 未確認(U5)                 | med  | enforce 経路を verify                    |
| DBSC doc/code 整合                                   | PARTIAL          | docs は `app/services/dbsc/`、実体は flat `dbsc_*.rb` `[survey]`(§C2)                      | low  | doc 修正                                 |
| Palm(bearer) と Core(cookie) の binding 分離         | PARTIAL          | `docs/architecture/dpop.md:125-126,159-162` `[survey]` 両者 optional                       | med  | surface 別 policy 明文化                 |

### Area 2 — Rate Limit / Abuse Control

| control                                            | status        | evidence                                                                              | risk | recommendation                   |
| -------------------------------------------------- | ------------- | ------------------------------------------------------------------------------------- | ---- | -------------------------------- |
| Rails 8.1 native `rate_limit` 採用(rack-attack 無) | PASS          | `app/controllers/concerns/rate_limit.rb:1-29` `[survey]`                              | —    | keep(memory: rack-attack 不採用) |
| `/oauth/token` limit                               | PASS(IP)      | `acme/{com,org,app}/oauth/tokens_controller.rb:16` 10/min by IP `[survey]`            | med  | account/client_id key 追加検討   |
| `/oauth/authorize` limit                           | UNKNOWN/FAIL? | survey「baseline 300/min のみ」`[survey]`(U3)                                         | med  | line 確認後 dedicated limit      |
| OTP issue(cooldown) vs verify(lockout) 分離        | PASS          | `sign_otp_ceremony.rb:38,73-74,145`; `common_otp_policy.rb:5` `[survey]`              | low  | keep                             |
| OTP resend cooldown                                | PASS          | `sign_email_otp_verification_support.rb:126-135`; `step_up_cooldowns.rb:6` `[survey]` | low  | keep                             |
| passkey verify burst/sustained                     | PASS(IP)      | `sign/com/in/passkeys_controller.rb:33-78` 5/min,20/15min `[survey]`                  | low  | keep                             |
| passkey challenge issue limit                      | FAIL/UNKNOWN  | `sign_verification_passkey_actions.rb:12` 明示 limit NOT FOUND `[survey]`             | med  | challenge flooding 対策追加      |
| password verify burst/sustained                    | PASS(IP)      | `sign/com/in/secret_credentials_controller.rb:20-42` `[survey]`                       | low  | keep                             |
| recovery secret consume の max-fail/lockout        | FAIL          | recovery consume の rate limit NOT FOUND `[survey]`                                   | high | brute-force 対策必須             |
| refresh rotation の reuse 検知                     | PASS          | `acme_refresh_token_service.rb:65-67,99-122` `[verified]` family revoke               | low  | keep                             |
| rate-limit 超過 response の enumeration            | PARTIAL       | `rate_limit.rb:19` `X-RateLimit-Rule` 露出(rule 名のみ, identifier 無) `[survey]`     | low  | header 抑制検討                  |
| rate-limit event の audit                          | PASS          | `chronicle_recorder.rb:45` `/\Arate_limit\./` security pattern `[survey]`             | low  | keep                             |

### Area 3 — JWT / JWKS / Signing Key Lifecycle

| control                                                 | status      | evidence                                                                                             | risk | recommendation                       |
| ------------------------------------------------------- | ----------- | ---------------------------------------------------------------------------------------------------- | ---- | ------------------------------------ |
| alg allowlist(ES384 中心, decode は `algorithms: [..]`) | PASS        | `security_jwt_auth_access_token_codec.rb:300,314`; `..preference..:137,160` `[survey]`               | low  | keep                                 |
| `none`/alg confusion 拒否                               | PASS        | `..auth..:314`; `..preference..:160,172-175`(ALG_NONE anomaly) `[survey]`                            | low  | keep                                 |
| kid 必須・unknown kid 安全拒否                          | PASS        | `..auth..:115-122,317`; registry global uniqueness `jit_security_jwt_registry.rb:235-248` `[survey]` | low  | keep                                 |
| JWKS cache-control                                      | PASS        | `authentication_jwks_rendering.rb:8` `expires_in(1.hour, public: true)` `[survey]`                   | low  | keep                                 |
| key state/rotation(active/grace/retired/revoked)        | PASS        | `jit_security_jwt_registry.rb:124,208-219,227-232` `[survey]`                                        | low  | retention window と TTL 整合を文書化 |
| emergency rotation/global invalidation                  | PARTIAL     | `AUTH_JWT_REVOKED_KIDS` CSV + reload `[survey]`; per-token 失効は無                                  | med  | runbook 化(§Phase5)                  |
| 必須 claims(iss/aud/exp/iat/sub/sid/act/jti/acr)        | PASS        | `..auth..:301-308` `[survey]`                                                                        | low  | keep                                 |
| `token_valid_after_at` 相当                             | FAIL/設計差 | NOT FOUND; idle+absolute TTL+session status で代替 `[survey]`                                        | med  | 短命化方針で許容可、要文書           |
| access token discard 即時反映                           | UNKNOWN     | resolver は `currently_usable_at` scope 経由 `:130-135` `[verified]`; scope 定義未確認(U4)           | med  | scope を line 確認                   |
| 秘密鍵が code/fixture/log に非混入                      | PASS        | ENV/credentials 由来; test は runtime 生成 `test/support/preference_jwt_helper.rb:7` `[survey]`      | low  | keep                                 |
| test/prod key 分離                                      | PARTIAL     | env 管理依存, code 強制無 `[survey]`                                                                 | low  | 運用ガード文書化                     |

### Area 4 — Security Notification Matrix

| control                                                         | status  | evidence                                                                                                                         | risk | recommendation                |
| --------------------------------------------------------------- | ------- | -------------------------------------------------------------------------------------------------------------------------------- | ---- | ----------------------------- |
| chronicle(internal audit) の event 網羅                         | PASS    | `client_chronicle_event.rb:14-87`(LOGGED*IN/LOGIN_FAILED/PASSKEY*\_/RECOVERY\_\_/TOTP*\*/EMAIL*\*/SESSION_REVOKED 等) `[survey]` | low  | keep                          |
| user-visible notification(sign-in/new-device/credential change) | FAIL    | 送信経路 NOT FOUND; `AlertMailer#notice` 未呼出 `[survey]`                                                                       | high | 最小 forced set 実装(§Phase6) |
| email 変更時の旧 email 通知                                     | FAIL    | NOT FOUND `[survey]`                                                                                                             | high | 必須化                        |
| recovery issue/consume の連絡先通知                             | FAIL    | NOT FOUND `[survey]`                                                                                                             | high | 必須化                        |
| high-assurance(`mfa_level`)での通知強制                         | FAIL    | mfa_level↔notification 連動 NOT FOUND `[survey]`                                                                                 | med  | ADR 化                        |
| notification body の secret/token/raw-IP 非漏洩                 | UNKNOWN | 送信自体が無いため評価不能 `[survey]`                                                                                            | —    | 実装時に保証                  |
| notification↔chronicle event 対応                               | PARTIAL | chronicle は有るが notification が無い `[survey]`                                                                                | med  | 1:1 mapping を設計            |

### Area 5 — Operator / Support Negative Authorization

| 禁止行為                                         | status     | evidence                                                                                                                                           | risk | recommendation                             |
| ------------------------------------------------ | ---------- | -------------------------------------------------------------------------------------------------------------------------------------------------- | ---- | ------------------------------------------ |
| 他人 passkey の追加/削除不可                     | PASS       | `operator_passkey_policy.rb:14-42`(owner? / scope staff_id) + test `:51-58` `[survey]`                                                             | low  | keep                                       |
| 他人 TOTP の追加/削除不可(正式 reset 除く)       | PASS       | `operator_time_based_totp_credential_policy.rb`(空=default deny) `[survey]`                                                                        | low  | 明示 test 追加                             |
| recovery secret の閲覧/任意再発行不可            | UNKNOWN    | operator 向け recovery 閲覧/再発行 endpoint NOT FOUND `[survey]`                                                                                   | med  | 不在を test で固定                         |
| mfa_level の勝手な解除不可                       | PASS       | `sign/org/settings/mfa/challenges_controller.rb:28-32,47`(self のみ) `[survey]`                                                                    | low  | keep                                       |
| 他人 email/tel の勝手変更不可                    | PASS(推定) | admin endpoint NOT FOUND, policy gate `[survey]`                                                                                                   | med  | negative test 追加                         |
| 他人 session/refresh family の発行不可           | PASS(推定) | 発行は auth flow のみ, admin endpoint NOT FOUND `[survey]`                                                                                         | med  | negative test 追加                         |
| step-up 状態の偽造不可                           | PASS(推定) | operator 向け step-up 生成 endpoint NOT FOUND `[survey]`                                                                                           | med  | negative test 追加                         |
| org owner の単独移管不可                         | PASS       | `operator_lifecycle_request_policy.rb:25-27,42-44`(approved? & different_operator?) + `org_operator_lifecycle_execute.rb` 別 actor 必須 `[survey]` | low  | keep                                       |
| audit/chronicle の削除/改竄不可                  | PARTIAL    | delete endpoint 無だが model に immutability guard 無(§Area7) `[survey]`                                                                           | high | DB/`readonly?` で担保                      |
| recovery waiting period の短縮不可 / break-glass | FAIL(不在) | break-glass/two-person/waiting NOT FOUND `[survey]`                                                                                                | med  | break-glass を別経路で設計 or 明示的非対応 |

### Area 6 — Org Membership / Deprovision / Token Revocation

| control                                                   | status             | evidence                                                                                           | risk | recommendation                             |
| --------------------------------------------------------- | ------------------ | -------------------------------------------------------------------------------------------------- | ---- | ------------------------------------------ |
| operator suspend/terminate 時の token revoke              | PASS               | `org_operator_lifecycle_execute.rb:110` `staff_tokens.not_revoked.find_each(&:revoke!)` `[survey]` | low  | keep                                       |
| client workspace membership 除外時の token/session revoke | FAIL               | `client_memberships.left_at` 連動 revoke handler NOT FOUND `[survey]`                              | high | cascade revoke 実装                        |
| org 権限の JWT claim 非混入(stale claim 回避)             | PASS(設計)         | access token claims に org scope 無 `[survey]`                                                     | low  | keep                                       |
| role 変更後の重要 write の DB 再確認                      | UNKNOWN            | 体系的確認できず `[survey]`(U2 関連)                                                               | med  | important write の re-check 確認           |
| org-scoped refresh family                                 | FAIL(account-wide) | `operator_token.rb:40` family_id は org 非スコープ `[survey]`                                      | med  | org scope 追加は将来 SSO/SCIM と合わせ検討 |
| owner transfer の step-up/cooling-off/notify/audit        | PARTIAL            | step-up 有 `operator_lifecycle_requests_controller.rb:32`; cooling-off/notify NOT FOUND `[survey]` | med  | cooling-off+notify 追加                    |
| deprovision↔refresh race                                  | PARTIAL            | `update!`→`revoke_target_sessions!` 非 transaction `[survey]`                                      | med  | transaction 境界化                         |
| device session の membership 連動 revoke                  | FAIL               | handler NOT FOUND `[survey]`                                                                       | med  | revoke target に追加                       |
| SSO/SCIM revoke hook 予約                                 | FAIL(不在)         | NOT FOUND `[survey]`                                                                               | low  | hook 予約点を文書化                        |

### Area 7 — Chronicle / Audit Tamper Evidence

| control                                            | status       | evidence                                                                                                             | risk | recommendation                       |
| -------------------------------------------------- | ------------ | -------------------------------------------------------------------------------------------------------------------- | ---- | ------------------------------------ |
| append-only 方針(ADR)                              | PASS(方針)   | `adr/chronicle-audit-implementation-guidance.md:74-81` `[verified]`                                                  | —    | keep                                 |
| app code からの update/delete 不可(DB/`readonly?`) | FAIL         | `client_chronicle.rb:43-114` immutability guard 無、`discarded_at`/`purged_at` 可変 `[verified]`                     | high | `readonly?`+DB 制約                  |
| event_uuid / request_id                            | PARTIAL      | 上位 `chronicles` には有, `client_chronicles` に無 `[survey]`                                                        | med  | detail table にも付与                |
| actor/subject/occurred_at                          | PASS         | `client_chronicle.rb:9-24` `[verified]`                                                                              | low  | keep                                 |
| previous_hash/chain/digest/signature               | FAIL(意図的) | ADR `:83-86` 後回し宣言 `[verified]`                                                                                 | high | digest-chain plan 起票               |
| sensitive value redaction                          | PASS         | `chronicle_recorder.rb:5-19,50-65`(forbidden pattern + sanitize) `[survey]`; `encrypts :previous_value` `[verified]` | low  | keep                                 |
| retention/purge policy                             | PARTIAL      | `chronicle_recorder.rb:21-35` action 別 retention `[survey]`; 過剰削除リスク                                         | med  | security event の最小 retention 固定 |
| user-visible history と internal audit 分離        | PASS         | `acme_app_settings_activity_log.rb:4-6` subset filter `[survey]`                                                     | low  | keep                                 |
| clock/duplicate/out-of-order 対応                  | FAIL         | sequence/digest 無 `[survey]`                                                                                        | med  | sequence 導入                        |

### Area 8 — Recovery Secret Issuance & Consume

| control                                                          | status  | evidence                                                                                                                                                    | risk | recommendation               |
| ---------------------------------------------------------------- | ------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- | ---- | ---------------------------- |
| 単一 active recovery secret(再発行時に旧失効)                    | PASS    | `client_secret_credentials_issue_recovery.rb:68-74` `[survey]`                                                                                              | low  | keep                         |
| issue 時の step-up 必須                                          | FAIL    | service に step-up gate NOT FOUND `[survey]`                                                                                                                | high | issue を step-up gated に    |
| high-assurance(mfa_level)で FIDO step-up 必須                    | FAIL    | mfa_level 連動 NOT FOUND `[survey]`                                                                                                                         | high | ADR 化                       |
| raw secret one-time 表示・再表示不可                             | PARTIAL | `Result.raw_secret_credential` 返却 `:8`; controller 依存 `[survey]`                                                                                        | med  | 再表示不可を保証             |
| 状態フィールド(consumed_at/revoked_at/failure_count/safe_prefix) | PARTIAL | `max_uses:1, max_failures:5` `:40-41`; safe_prefix/revoked_at/failure_count は NOT FOUND `[survey]`                                                         | med  | フィールド整備               |
| raw secret の log/chronicle/email/job 非漏洩                     | PASS    | `chronicle_recorder.rb:7` forbidden pattern に `recovery_code` `[survey]`                                                                                   | low  | keep                         |
| issue 時の連絡先通知                                             | FAIL    | NOT FOUND `[survey]`                                                                                                                                        | high | 必須化                       |
| delete/revoke 時の step-up 必須                                  | UNKNOWN | 確認できず `[survey]`                                                                                                                                       | med  | gate 確認/追加               |
| rotation/expiry policy                                           | FAIL    | app 側 recovery に expiry NOT FOUND `[survey]`                                                                                                              | med  | expiry/rotation 定義         |
| **consume が通常 session を直接発行しない**                      | FAIL    | recovery を通常 sign-in 扱い `secret_credentials_controller.rb:267,330-331`→`process_standard_login`→`establish_signed_in_session!` `:208-211` `[verified]` | high | restricted recovery state へ |
| consume 後に既存 session/refresh family を全 revoke              | FAIL    | revoke 経路 NOT FOUND(audit 1 行のみ `:397-411`) `[verified]`                                                                                               | high | 全 revoke 必須               |
| consume 後に passkey/TOTP 再登録/再確認要求                      | FAIL    | NOT FOUND `[verified]`                                                                                                                                      | high | bootstrap 要求               |
| consume の DB-level atomicity                                    | PARTIAL | issue は `transaction`、consume は controller で明示 transaction 無 `[survey]`                                                                              | med  | atomic consume               |
| failed consume の rate limit/lockout/audit                       | FAIL    | NOT FOUND `[survey]`                                                                                                                                        | high | brute-force 対策             |

---

## 4. Attack Scenario Evaluation

- **token theft(unbound access token)**: 防御不十分。unbound
  token は DPoP 無しで使える (`resolver:110`
  `[verified]`)。binding を発行していなければ盗難 bearer がそのまま通る。→ Palm bearer の mandatory
  binding と、token への `cnf.jkt` 既定付与が要。
- **token theft(DPoP-bound token, 鍵無し)**: 防御十分。`cnf.jkt` 付き token は DPoP
  scheme と proof 必須、proof 署名は埋込 JWK で検証され thumbprint 一致を要求(`resolver:54,65,170-178`,
  `dpop_proof_validator.rb:32-81`)。private key 無しでは proof を作れない。
- **refresh theft(device 鍵無し)**: binding がある token は proof 不一致で拒否。ただし unbound
  refresh は素通り(opt-in)。binding mismatch でも family revoke せず 401 のみ `[verified]`。
- **refresh theft(device_id だけコピー)**:
  dpop_jkt/public_key の一致まで要求するため device_id 単独では不足(`token_dpop_binding_current?:170-178`
  `[verified]`)。binding 有効時のみ。
- **DPoP replay**: refresh/login 経路は JTI store(TTL 300s)で抑止。API 経路は stateless で iat±60s
  leeway 内の replay 余地が残る(PARTIAL)。high-value API は stateful 化推奨。
- **refresh reuse / family compromise**: 防御十分。reuse 検知で family 全 discard + risk emit
  (`acme_refresh_token_service.rb:99-122` `[verified]`)。ただし revoke は rotation と別
  `connected_to` block で非 atomic。
- **OTP brute force**: issue=cooldown / verify=attempt
  lockout で分離(`sign_otp_ceremony.rb`)。passkey challenge issue と recovery consume は rate
  limit 欠落(FAIL)。
- **recovery secret abuse**: 重大。logged-in attacker が recovery を作る(issue
  step-up 無)→ 別経路で consume → 通常 session、しかも既存 session/refresh を revoke しない
  `[verified]`。本監査方針(restricted state)から最も乖離。
- **compromised support/insider**: passkey/TOTP/mfa_level/owner 移管などの negative
  authz は概ね denied(policy + 別 actor 必須)。ただし audit 改竄に対する DB-level
  immutability 欠如と break-glass 不在が穴。
- **org deprovision race**: operator は revoke するが非 transaction の窓。client
  membership は revoke handler 自体が無い(FAIL)。
- **signing key compromise**: revoked_kids CSV +
  reload で失効可だが per-token 失効と runbook が未整備(PARTIAL)。
- **audit
  tampering**: 構造的に検知不能(digest-chain/sequence/`readonly?`/DB 制約いずれも無、ADR が後回し明言
  `[verified]`)。

---

## 5. Minimal Remediation Plan

実装方針は read-only 監査の範囲外だが、最小の段階計画を提示する。各 Phase は独立に着手可能。

- **Phase 0 — Documentation / ADR**
  - Recovery secret = restricted recovery/bootstrap 証票の ADR(§A)。
  - Token binding threat model ADR(surface 別 mandatory/opt-in)(§B)。
  - Security notification matrix ADR(§C)。
  - Chronicle integrity implementation plan を `plans/` に起票(ADR が後回し宣言済み, §D)。
  - Org/membership revocation contract ADR(§E)。
  - U2(credential-change revocation 矛盾)を notes/ で conflict として記録。
- **Phase 1 — Negative authorization tests**(挙動を固定する read-mostly な安全網)
  - operator が他人 email/tel/session/refresh/step-up/recovery を作れない・見れないことの policy/service
    test(§Area5 の PASS(推定)/UNKNOWN を test で固定)。
- **Phase 2 — Recovery secret issuance + consume hardening**
  - issue を step-up gated 化、high-assurance で FIDO 必須、連絡先通知。
  - consume を restricted recovery session に限定、既存 session/refresh
    family を全 revoke、passkey/TOTP 再登録要求、atomic consume、failed consume の rate
    limit/audit。
- **Phase 3 — DPoP/DBSC enforcement confirmation**
  - Palm bearer の mandatory binding、binding mismatch を anomaly+family revoke に格上げ。
  - DBSC enforce 起点(U5)と access-token discard scope(U4)の line 確認。
- **Phase 4 — Rate limit / abuse control**
  - `/authorize`(U3)、passkey challenge issue、recovery consume に限定子付き limit。
  - identifier/account key の追加(distributed low-rate 対策)。
- **Phase 5 — JWT/JWKS lifecycle**
  - emergency rotation runbook、grace/retention window と TTL の整合文書化。
- **Phase 6 — Notification matrix**
  - forced 最小集合(new-device、credential change、email 変更で旧 email、recovery
    issue/consume、all-sessions-revoked、refresh-reuse-detected)を実装、chronicle と 1:1 mapping。
- **Phase 7 — Org lifecycle revocation**
  - client membership/deprovision/role-downgrade の cascade revoke、owner
    transfer の cooling-off+notify、deprovision の transaction 境界化、SSO/SCIM revoke hook 予約。
- **Phase 8 — Chronicle tamper evidence**
  - `readonly?` + DB 制約で update/delete 封鎖、sequence + digest-chain、detail
    table への event_uuid/request_id、security event の最小 retention 固定。

優先度: Phase 0→2→1 を先行(account-takeover 直結)。Phase 3/6/7/8 を中位。Phase 4/5 を後続。

---

## 6. Concrete Test Plan

- **unit**
  - `dpop_proof_validator`: 秘密鍵 `d` 混入/htm・htu mismatch/iat skew/ath mismatch を reject。
  - JWT codec: `none`/alg confusion/unknown kid/expired を anomaly 化し nil 返却。
  - recovery issue: 再発行で旧 active を revoke、単一 active 不変条件。
- **integration**
  - unbound access token が DPoP 無しで通る現状を characterization test で固定 →
    mandatory 化後に反転する形で binding policy を検証。
  - refresh reuse → family 全 discard、後続 refresh 拒否。
  - recovery consume → (目標)restricted session のみ・既存 session/refresh 全 revoke。
- **policy/authorization**
  - operator が他人 passkey/TOTP/email/tel/session/refresh/step-up/recovery を操作不可。
  - owner transfer が単独実行不可(approved? & different_operator?)。
- **security invariant**
  - chronicle row が app code から update/delete されない(`readonly?`/DB 制約後)。
  - rate-limit 超過 response が identifier を enumerate しない。
- **race/concurrency**
  - recovery consume の同時実行で二重 session 発行されない(atomic)。
  - org deprovision↔refresh の並走で stale token が write できない。
- **audit/notification**
  - 各 security event で chronicle と forced notification が 1:1 で発火。
  - email 変更時に旧 email へ通知。
  - raw recovery secret/token が chronicle context・log・mail body に出ない。

---

## 7. Final Recommendation

- **implement now(account-takeover 直結)**
  - Recovery consume を restricted recovery
    state 化 + 既存 session/refresh 全 revoke + 再登録要求(§Phase2)。
  - Recovery issue の step-up gate + 連絡先通知(§Phase2)。
  - 最小 forced notification(new-device / credential change / 旧 email / recovery / family revoke)
    (§Phase6 の最小集合)。
  - client membership removal の cascade token/session revoke(§Phase7)。
- **verify now(UNKNOWN を確定)**
  - U1 recovery consume の MFA 分岐、U2 credential-change revocation の真偽(conflict 確定)、U3
    `/authorize` limit、U4 access-token discard scope、U5 DBSC enforce 起点。
- **defer**
  - org-scoped refresh family、SSO/SCIM 本実装(hook 予約のみ)、DPoP nonce 常時強制、
    `token_valid_after_at` 導入(短命化で代替)。
- **reject as overkill(現時点)**
  - 全 access token への JTI revocation list、chronicle 暗号署名/external WORM sink。まず
    `readonly?`+DB 制約+sequence+digest-chain で足りる。

---

## C. Conflicts / Drifts(矛盾の明示)

- **C1 (credential-change
  revocation)**: 前回 review で「ADR と finding が矛盾」と整理された credential 変更時の session/refresh
  revocation は、本監査でも revocation 経路を確定できなかった (UNKNOWN/U2)。片方を正にせず conflict として残す。verify
  now 対象。
- **C2 (DBSC doc/code drift)**: `docs/architecture/dbsc.md` は `app/services/dbsc/`
  を指すが、実体は flat な `app/services/dbsc_*.rb`。doc 修正が必要 `[survey]`。
- **C3 (binding 方針の暗黙性)**: docs は DPoP/DBSC を「optional」と記すが、どの threat
  model で unbound を許容するかが未文書。resolver の opt-in 実装(`:110`)と合わせ、明示的 policy が必要。
