# Checklist 4 — Cross-cutting Security 監査レポート＋是正プラン

## Context

`Checklist 4 — Cross-cutting Security`（Email / Social /
Telephone の全 ceremony に共通する横断セキュリティ contract。83 項目 P0/P1/P2）に対し、現行実装・テスト・ADR・docs・plans を突き合わせ、
**各項目を PASS / 要検証 / GAP + 根拠 file 参照で判定した監査レポート**と、GAP/要検証に対する
**是正プラン**をまとめる。`plans/checklist-2-bubbly-book.md`（Social 監査）の後継であり、同じ書式・凡例を踏襲する。

調査の結論：**Acme 側の token/session authority コアは堅牢**（中央集約された発行点、login 前の
`reset_session`、refresh rotation + reuse 検出 + family revoke、PKCE-S256 必須、Chronicle durable
audit + outbox fallback）。横断 contract の弱点は **(1) failure path の negative
test を共通契約として持っていない、(2) Turnstile のローカル single-use / hostname-action
binding 未実装、(3) 失敗 signup 由来の疑わしい UserToken を検出・段階的 cleanup する data-repair 経路が無い、(4)
side-effect matrix が未文書化、(5) Sign 側 `log_in` 経由の token 発行が Acme-only
authority 原則と境界上ぶれている**
の 5 点に集約される。多くの是正は既存 plan（後掲）に owner が居り、本プランは横断 contract 化と net-new
GAP を確定させる。

### 監査対象の主な実装

- Acme 発行点: `app/controllers/concerns/authentication_base.rb`（`log_in` / `reset_session`(L352) /
  `create_login_token_record` / audit）、`app/services/oidc_token_exchange_service.rb`
  （`consume_and_issue_tokens!` / PKCE / nonce / DPoP）
- Refresh: `app/models/concerns/refresh_tokenable.rb`（`rotate_refresh!` / `rotated_at` replay /
  family_id）、`app/services/acme_refresh_token_service.rb`（reuse 検出 + family revoke +
  `SignRiskEmitter`）
- Logout/Revocation: `app/controllers/concerns/authentication_logout_current_session.rb` /
  `authentication_logoutable.rb` /
  `sign_oidc_logout.rb`、`app/services/oidc_backchannel_logout_notifier.rb`
- Sign ceremony: `sign/app/sign/up/{emails,telephones}_controller.rb`、
  `sign/app/sign/up/check/{email,telephone}/{otps,cancellations}_controller.rb`、
  `app/controllers/concerns/{social_auth,sign_email_registrable,cloudflare_turnstile}.rb`、`SignOtpCeremony`
- Turnstile: `lib/jit_security_turnstile_verifier.rb`、`concerns/cloudflare_turnstile.rb`
- 権威 ADR/docs: `adr/acme-session-and-token-authority.md`,
  `adr/session-token-hardening-baseline.md`, `adr/logout-completion-boundary.md`,
  `adr/refresh-revoke-aal-downgrade-and-replay-hardening.md`,
  `adr/email-otp-race-condition-fixes.md`, `adr/sign-up-cycle-cancellation-retention.md`,
  `adr/security-audit-findings-2026-06-13.md`, `adr/application-logging-boundary.md`,
  `docs/security/{sign-up-sequence,sign-in-sequence,logout-sequence,refresh-token-rotation,session-reset-policy}.md`,
  `docs/auth-ceremony/CONTEXT.md`（contradiction C-4）
- 既存の関連 plan:
  `plans/active/{sign-up-state-machine,logout-state-machine}-implementation-plan.md`,
  `plans/backlog/{session-token-hardening-implementation,social-login-provider-gem-oidc-hardening, credential-abuse-rate-limit-policy,sign-up-failure-recovery-plan,gh633-emergency-revoke-all-sessions}.md`

凡例: ✅PASS / ⚠️要検証(設計あり・コード/テスト最終確認が必要) / ❌GAP / ➖対象外

---

## 監査結果テーブル

### Global Invariants And Commit Boundary

| ID    | P   | 判定 | 根拠 / 備考                                                                                                                                                                                                                                  |
| ----- | --- | ---- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| X-001 | P0  | ❌   | **核心 GAP**。成功 commit のテストはある（`test/services/identity/*_acme_transaction_test.rb`）が、`failed/cancelled/expired/blocked => UserToken delta = 0` を **全 ceremony 共通契約**として回す test が無い                               |
| X-002 | P0  | ⚠️   | 設計上 failure path は token/session/cookie を発行しない（発行は Acme 側 ceremony-gated）。だが X-001 と同じく failure path の negative test が共通化されていない                                                                            |
| X-003 | P0  | ⚠️   | durable commit は `*_ceremony_final_committer` のみ。失敗時 verified email/phone・linked social・active context を残さない設計だが、pending candidate(`ClientEmail/Telephone` UNVERIFIED)の即時 purge は cleanup に遅延                      |
| X-004 | P0  | ✅   | pending(principal DB の pending actor/contact、ticket)と durable(finalize commit)の分類は `docs/security/sign-up-sequence.md` + final committer で明示。ただし matrix 化は X-072 参照                                                        |
| X-005 | P0  | ⚠️   | UserToken 発行は `authentication_base#log_in` と `oidc_token_exchange_service` の 2 点に集約、controller/model callback 直叩きは無い。但し `log_in` は shared concern で **Sign の omniauth callback から呼ばれる** → X-077/X-078 の境界課題 |
| X-006 | P0  | ✅   | ceremony result は one-shot `consume!` + transaction_id bind。`*_acme_transaction_test.rb` が replay 拒否を検証                                                                                                                              |
| X-007 | P0  | ⚠️   | audit は outbox fallback で reconcile 可（`authentication_audit_writer.rb`）。token/session と durable mutation の after_commit partial-outcome reconcile は要確認                                                                           |
| X-008 | P1  | ⚠️   | audit は outbox あり。email/SMS/provider 外部副作用の idempotency/reconciliation は `adr/outbound-message-delivery-interface.md` 方針止まりで要検証                                                                                          |

### Session Fixation / Login CSRF

| ID    | P   | 判定 | 根拠 / 備考                                                                                                                                                                                                       |
| ----- | --- | ---- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| X-009 | P0  | ✅   | `authentication_base.rb:352` で token 作成 **前**に `reset_session`。`docs/security/session-reset-policy.md`                                                                                                      |
| X-010 | P0  | ✅   | `reset_session` で session id 回転。旧 id 再利用不可（明示的な別ブラウザ再利用 test 追加は X-075 で補強）                                                                                                         |
| X-011 | P0  | ✅   | `reset_session` で pre-auth CSRF/login state を wipe。post-auth へ無条件コピーは無し                                                                                                                              |
| X-012 | P0  | ⚠️   | form CSRF(Rails) + social state(CSPRNG/single-use/`secure_compare`) はあり。OAuth **token endpoint** の CSRF は `plans/backlog/restoration-a6-token-endpoint-csrf.md` / `gh627-csrf-strict-mode-test.md` で進行中 |
| X-013 | P0  | ⚠️   | rotation policy は `adr/session-token-hardening-baseline.md`（step-up/privilege/credential-change で re-issue）で定義。actor/account/org 切替の全経路実装は要検証                                                 |
| X-014 | P1  | ✅   | `adr/signed-return-targets-only.md`。session id/token を URL/fragment/Referer/history に載せない                                                                                                                  |
| X-015 | P1  | ⚠️   | absolute は token TTL で担保。idle/renewal timeout の server-side enforcement は `plans/backlog/session-token-hardening-implementation.md` で未了                                                                 |

### Cancellation Semantics

| ID    | P   | 判定 | 根拠 / 備考                                                                                                                                                                                                                                                          |
| ----- | --- | ---- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| X-016 | P0  | ✅   | anon cancel は `cancel_from_explicit_step`（`sign/app/sign/up/check/{email,telephone}/cancellations_controller.rb`）で sequence session を purge                                                                                                                     |
| X-017 | P0  | ⚠️   | OAuth state は `consume!` single-use。但し candidate(`ClientEmail/Telephone`)/OTP は cancel 時に session key 削除のみで、物理 purge は retention 遅延（`adr/sign-up-cycle-cancellation-retention.md`: `discarded_at`/`purged_at`）。OTP secret の即時 clear は要確認 |
| X-018 | P0  | ✅   | cancel は idempotent、`consume!`/CANCELLED status で back/retry/replay 成功不可（同 ADR）                                                                                                                                                                            |
| X-019 | P0  | ⚠️   | logged-in attach cancel が authenticated session を維持し attach state のみ purge する点は checklist-2 S-029 と同じく要コード確認                                                                                                                                    |
| X-020 | P0  | ⚠️   | attach cancel で identity/contact/UserToken を作成・変更しない点、要確認（S-029 連動）                                                                                                                                                                               |
| X-021 | P1  | ⚠️   | cancel vs finalize の winner と DB guard は lock 前提で要確認（S-036 連動）                                                                                                                                                                                          |

### Logout / Revocation / Refresh

| ID    | P   | 判定 | 根拠 / 備考                                                                                                                                           |
| ----- | --- | ---- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| X-022 | P0  | ✅   | `logout_current_session!` が token revoke + cookie clear + `reset_session`。`test/controllers/concerns/authentication/logoutable_test.rb`             |
| X-023 | P0  | ✅   | `rotate_refresh!` の `rotated_at` で rotation + 旧 token replay 検出。`test/services/sign/refresh_token_service_test.rb`                              |
| X-024 | P0  | ✅   | reuse 検出時 `handle_refresh_token_reuse` が family revoke + `SignRiskEmitter`。`test/security/invariants/refresh_token_reuse_invariant_test.rb`      |
| X-025 | P0  | ✅   | credential destroy の session revoke は FINDING-02 修正済。SUSPEND/TERMINATE で `revoke_target_sessions!`。global admin revoke-all は `gh633` backlog |
| X-026 | P1  | ✅   | `adr/logout-completion-boundary.md`：Acme=logout mutation / Sign=`/signed-out`。route・UI・audit を分離                                               |
| X-027 | P1  | ⚠️   | refresh rotation race は test 済（`refresh_token_concurrency_test.rb`）。**revoke/logout vs in-flight refresh/token issue** の race は未テスト        |

### TOCTOU / Concurrency / Idempotency

| ID    | P   | 判定 | 根拠 / 備考                                                                                                                        |
| ----- | --- | ---- | ---------------------------------------------------------------------------------------------------------------------------------- |
| X-028 | P0  | ✅   | email は `with_lock`（`adr/email-otp-race-condition-fixes.md`）、social は `find_by_uid_with_lock` + `(uid,provider)` UNIQUE       |
| X-029 | P0  | ✅   | proof/state/result の consume は `consume!`/`rotated_at` で `unused -> used` atomic                                                |
| X-030 | P0  | ⚠️   | single-use + lock で原則 max 1。但し concurrent **email signup**（同一 email 2 thread）の duplicate-POST race test が無い          |
| X-031 | P0  | ✅   | `(uid,provider)` UNIQUE + conditional `(user_id)` UNIQUE が別 user への link を DB 拒否（409 変換、`social_auth_link_handler.rb`） |
| X-032 | P0  | ⚠️   | race test は refresh rotation のみ。cancel/finalize・resend/verify・link/unlink・logout/refresh の race test が未整備              |
| X-033 | P0  | ⚠️   | audit writer は never-raise + outbox。rollback 後の after_commit/job/token/audit partial 残存の明示 test は無い                    |
| X-034 | P1  | ⚠️   | unique violation は 409 変換し別 actor へ fallback しない。deadlock/serialization の safe-retry は要確認                           |
| X-035 | P1  | ⚠️   | external timeout の unknown outcome を state machine へ持つ方針はあるが provider timeout reconcile 未実装（S-031 連動）            |
| X-036 | P1  | ⚠️   | state machine は active plan で定義。任意 event sequence に対する property/state-machine test は未整備                             |

### Turnstile

| ID    | P   | 判定 | 根拠 / 備考                                                                                                                                              |
| ----- | --- | ---- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| X-037 | P0  | ✅   | `lib/jit_security_turnstile_verifier.rb` が server-side Siteverify 必須                                                                                  |
| X-038 | P0  | ⚠️   | forged/missing/expired は Siteverify が拒否（fail-closed）。**replayed token のローカル single-use 検証は未実装**（`docs/auth-ceremony/CONTEXT.md` C-4） |
| X-039 | P0  | ❌   | **GAP**。Turnstile token のローカル一回使用マーキングが無く、duplicate submit / 別 ceremony 流用を防げない（Cloudflare 側検証のみ）                      |
| X-040 | P0  | ❌   | **GAP**。expected hostname / action / cdata(ceremony binding) のローカル検証が未実装（C-4 / OPEN-QUESTIONS GQ-06）                                       |
| X-041 | P0  | ⚠️   | email/telephone signup は `ensure_turnstile!` を durable 作成前に実施 ✅。social signup の Turnstile 適用は未確定（checklist-2 S-004）                   |
| X-042 | P0  | ✅   | secret missing / timeout / malformed は `JitSecurityTurnstileVerifier` が fail-closed                                                                    |
| X-043 | P1  | ⚠️   | Siteverify は単発呼び出し。retry 時の idempotency key 扱いは要確認                                                                                       |
| X-044 | P1  | ⚠️   | `adr/turnstile-environment-toggle.md` で env 分離。production bypass を CI/boot check で禁止しているかは要検証                                           |
| X-045 | P1  | ⚠️   | `sign_error_responses` で内部 reason と外部 response を分離する方針。bot への情報露出の最終確認が必要                                                    |
| X-046 | P1  | ✅   | Turnstile は bot 防御であり identity proof/AAL として扱わない（docs 明記）                                                                               |

### OTP / Challenge Common Rules

| ID    | P   | 判定 | 根拠 / 備考                                                                                                                             |
| ----- | --- | ---- | --------------------------------------------------------------------------------------------------------------------------------------- |
| X-047 | P0  | ✅   | `SignOtpCeremony` が subject/purpose/surface/channel/`session_nonce`(ticket public_id)/expiry に bind。`*_ceremony_contract_test.rb`    |
| X-048 | P0  | ✅   | proof single-use、verify 成功のみ次状態（status VERIFIED）へ                                                                            |
| X-049 | P0  | ⚠️   | resend は cooldown 制御だが、resend/new proof で failed-attempt counter を **リセットしない**保証は windowed-reset logic を要コード確認 |
| X-050 | P1  | ✅   | `otp_attempts_count` / `otp_last_sent_at` / `otp_expires_at` を server-side 保持（`ClientEmail`/`ClientTelephone`）                     |
| X-051 | P1  | ⚠️   | provider delivery telemetry と auth proof の分離は `outbound-message-delivery-interface` 方針止まりで要検証                             |

### Enumeration / Rate Limiting / Abuse

| ID    | P   | 判定 | 根拠 / 備考                                                                                                                                                                                |
| ----- | --- | ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| X-052 | P1  | ⚠️   | `sign_error_responses` で一様化方針。account/email/phone 存在を漏らさない点の最終確認が必要                                                                                                |
| X-053 | P1  | ⚠️   | `app/values/rate_limit_profiles.rb`（Rails native `rate_limit`）+ per-email submit limit。IP/email/phone/device/account 複合 key の網羅は `credential-abuse-rate-limit-policy.md` で要拡張 |
| X-054 | P1  | ⚠️   | cooldown + `new-email-trust-cooldown`(提案) はあるが victim-identifier lockout/notification flooding 防止の網羅は要検証                                                                    |
| X-055 | P1  | ⚠️   | retention ADR + `sign-up-physical-purge-worker` で candidate/token TTL/cleanup あり。quota は要検証                                                                                        |
| X-056 | P1  | ⚠️   | response timing/size/status 差による enumeration の評価は未実施                                                                                                                            |
| X-057 | P2  | ⚠️   | false-positive recovery は `mfa-reset-account-recovery`。operator override/audit は要整備                                                                                                  |

### Audit / Observability / Privacy

| ID    | P   | 判定 | 根拠 / 備考                                                                                                                                                                                                          |
| ----- | --- | ---- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| X-058 | P0  | ⚠️   | session create / rotate / revoke / replay は Chronicle + `SignRiskEmitter`（`session_issued`/`refresh_reuse_detected`）。**cancel / conflict** の security event 化は不足（cancel に audit 無し）                    |
| X-059 | P1  | ⚠️   | `audit_context` + token-family id で相関。request_id/trace_id/ceremony_id/actor_ref の全フィールド網羅は要検証                                                                                                       |
| X-060 | P1  | ✅   | `adr/application-logging-boundary.md`。refresh は SHA3-384 digest only、raw token/OTP/secret を log しない                                                                                                           |
| X-061 | P1  | ❌   | `SignRiskEmitter` で event emit はするが、failed-signup token delta / duplicate token / replay / unexpected link / Turnstile bypass の metrics/alert は未整備（`traces-and-metrics-routing-via-alloy` 経路に未接続） |
| X-062 | P1  | ⚠️   | ceremony contract error は型付き（binding 失敗種別）だが、運用者が scope/purpose/audience/expiry 失敗を判別できる audit reason 化は要確認                                                                            |
| X-063 | P2  | ⚠️   | retention/PII minimization は ADR 群あり。access control / incident export 方針は要整備                                                                                                                              |

### Data Repair / Migration

| ID    | P   | 判定 | 根拠 / 備考                                                                                                                                     |
| ----- | --- | ---- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| X-064 | P0  | ❌   | **GAP**。既存の疑わしい UserToken（失敗 signup 由来等）を検出する report-only query/task が無い                                                 |
| X-065 | P0  | ❌   | **GAP**。正当な multi-device/multi-session と失敗 signup 由来 token を区別する evidence criteria が未定義                                       |
| X-066 | P0  | ❌   | **GAP**。token cleanup の report→review→revoke→delete 段階方式が無い（`sign-up-physical-purge-worker` は candidate 向けで token repair 非対象） |
| X-067 | P1  | ⚠️   | orphan candidate/identity/unverified contact/expired proof は retention ADR + purge worker で一部 cover。inventory 化は要整備                   |
| X-068 | P1  | ⚠️   | legacy cookie/session/token family の compatibility window or 全再ログイン判断の ADR 化が未了                                                   |
| X-069 | P1  | ⚠️   | migration 中の old/new 両経路 double-token-issue freeze test が無い                                                                             |

### Docs / Tests / State Contract

| ID    | P   | 判定 | 根拠 / 備考                                                                                                                                                          |
| ----- | --- | ---- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| X-070 | P0  | ✅   | `docs/auth-ceremony/CONTEXT.md`（contradiction C-x）+ `EVIDENCE-LEDGER.md` + `OPEN-QUESTIONS.md` が ADR/code/test/DB の矛盾を一覧化                                  |
| X-071 | P1  | ✅   | `adr/README.md` が superseded/deprecated を明示分類。検索で current contract が優先される構造                                                                        |
| X-072 | P1  | ⚠️   | state machine は `docs/security/{sign-up,sign-in,logout}-sequence.md` で checked-in。**side-effect matrix**(ceremony×result→token/chronicle/account delta)は未文書化 |
| X-073 | P1  | ✅   | `SignUp::Result(status/step/response/errors/next_event)` / `Logout::Result`、flash 全廃（`no-flash-messages.mdc`）                                                   |
| X-074 | P1  | ✅   | `SignUp::Result.status` enum が field error/retryable/expired/cancelled/blocked/conflict/terminal を別状態で返す                                                     |
| X-075 | P1  | ⚠️   | ceremony contract + reuse invariant + concurrency test あり。fault-injection / 全 ceremony 横断 negative test は不足                                                 |
| X-076 | P2  | ⚠️   | 本チェックリスト + checklist-2 で owner/evidence/test/status の枠組みは成立中。per-item exception ADR 運用は未確立                                                   |

### Architecture Boundary

| ID    | P   | 判定 | 根拠 / 備考                                                                                                                                                                                                                                          |
| ----- | --- | ---- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| X-077 | P0  | ⚠️   | `adr/acme-session-and-token-authority.md` で Acme を唯一の IdP/AS と decide。但し `log_in`(shared concern)が Sign omniauth callback から呼ばれ token 発行する残存があり、`plans/backlog/sign-acme-boundary-remediation.md`(inactive)で要 remediation |
| X-078 | P0  | ⚠️   | Sign は ceremony result を扱う設計だが、上記 `log_in` 経路が token/session authority へ戻る境界ぶれ。boundary remediation で確定要                                                                                                                   |
| X-079 | P0  | ✅   | provider success と Acme session の間に audience/purpose/session-bound one-shot ceremony result 境界（grant/result `consume!`）。`*_ceremony_contract_test.rb`                                                                                       |
| X-080 | P1  | ⚠️   | RP session と Acme IdP session の区別は ADR + `cookie-domain-scope-by-surface` で方針化。logout/cookie route の混同防止の最終確認が必要                                                                                                              |
| X-081 | P1  | ⚠️   | Palm/native は public client/PKCE/bearer・no browser cookie（`acme-sign-core-base-port-boundary.md`）。実装側 contract 維持は要検証                                                                                                                  |
| X-082 | P1  | ⚠️   | `log_in` は actor context 確定後に発行、token は per-surface 分離。cross-surface user_id の意味混同防止は要確認                                                                                                                                      |
| X-083 | P2  | ⚠️   | `controller_inheritance_invariant_test.rb` + remediation plan の rg guardrail あり。Sign への session/token/preference authority 再侵入を検出する architectural test/lint は未整備                                                                   |

### 集計

| 判定      | 件数 | 主な該当                                                                   |
| --------- | ---- | -------------------------------------------------------------------------- |
| ✅ PASS   | 25   | 発行集約・reset_session・refresh rotation/reuse・logout・PKCE・OTP binding |
| ⚠️ 要検証 | 51   | 失敗 path negative test・cancel purge・race coverage・rate limit・boundary |
| ❌ GAP    | 7    | X-001 / X-039 / X-040 / X-061 / X-064 / X-065 / X-066                      |

---

## 是正プラン

GAP/要検証を優先度順に整理する。**既存 plan に owner がある項目は重複させず参照**し、本プランは net-new な共通 contract と data-repair 経路の確定を担う。

### Tier 0 — net-new P0 GAP（本プランで新規に起こす）

1. **X-001/X-002/X-003 失敗 path 共通 contract test**（最優先）。
   `test/security/invariants/ceremony_failure_token_delta_invariant_test.rb`（新規）を追加し、email/telephone/social の各
   `*_ceremony_contract` の全 rejection 経路（expired grant / invalid aud / wrong purpose /
   forbidden claim / bad signature / replayed result / cancelled）を parametrize して
   `assert_no_difference` で `ClientToken.count` / `VisitorToken.count` / session cookie / verified
   contact status の不変を assert。既存 `*_acme_transaction_test.rb`
   の成功側と対になる failure 側契約。

2. **X-039/X-040/X-038 Turnstile ローカル binding & single-use**。 `JitSecurityTurnstileVerifier`
   の検証結果に対し、(a) `hostname`/`action`/`cdata`(ceremony id) の expected 値照合、(b)
   token の一回使用マーキング（DB or short-TTL store、`ClientOauthCallbackState`
   の single-use パターンを流用）を追加。`docs/auth-ceremony/CONTEXT.md` C-4 / OPEN-QUESTIONS
   GQ-06 を close。あわせて X-041：social signup の durable 作成前 Turnstile を checklist-2
   S-004 と整合させて適用判断。test は `test/integration/turnstile_forms_test.rb`
   を binding/replay ケースに拡張。

3. **X-064/X-065/X-066 疑わしい UserToken の data-repair 経路**。
   - X-064: `lib/tasks` に report-only rake task（自動 delete 無し）を追加し、active
     session に紐づかない / 失敗 signup ticket 期間と相関する token を一覧出力。
   - X-065: evidence criteria を
     `docs/security/suspicious-token-criteria.md`（新規）に明文化（正当な multi-device/multi-session の除外条件、family_id・device
     session・login 時刻の突き合わせ）。
   - X-066: report→review→revoke→delete の段階運用を doc 化し、revoke は既存
     `revoke_target_sessions!` / family revoke を再利用。auto-delete は禁止。

### Tier 1 — P0 要検証（コード確認 → テスト追加で確定）

4. **X-005/X-077/X-078 Sign↔Acme
   token 発行境界**。`rg "log_in|create_login_token_record" app/controllers/sign`
   で Sign 側発行経路を棚卸しし、`plans/backlog/sign-acme-boundary-remediation.md`
   を再活性化するか、現状の shared `log_in`
   を Acme 権威に正規化する方針を ADR で確定。X-083 の architectural lint（Sign 配下の session/token
   authority 再侵入検出）をこの一環で追加。
5. **X-017/X-019/X-020 cancel の purge 不変**。anon cancel での candidate/OTP
   secret 即時 clear と、logged-in attach cancel での「auth session 維持・attach
   state のみ purge・identity/token 不変」をコード確認し、`cancellations_controller` の request
   test で固定（checklist-2 S-029 と統合）。
6. **X-030/X-032/X-027/X-033 race / TOCTOU test 拡充**。`refresh_token_concurrency_test.rb`
   の Queue+Thread barrier パターンを雛形に、concurrent email signup・cancel vs finalize・resend vs
   verify・logout/revoke vs in-flight refresh・rollback 後の after_commit partial の各 race
   test を追加。
7. **X-012 OAuth token endpoint CSRF**：`plans/backlog/restoration-a6-token-endpoint-csrf.md` /
   `gh627-csrf-strict-mode-test.md` の進捗に委譲（重複実装しない）。

### Tier 2 — P1 要検証（既存 plan へ委譲 / 文書整備）

8. **X-072 side-effect
   matrix**：`docs/security/ceremony-state-effects-matrix.md`（新規）で (ceremony_type,
   result_status) → (token delta, chronicle events, account/contact
   state) を一覧化。X-001 のテスト期待値の source-of-truth とする。
9. **X-058/X-061/X-062 audit/alert 整備**：cancel/conflict の security event 化、P0
   anomaly の metrics/alert を `traces-and-metrics-routing-via-alloy`
   経路へ接続。`audit-log-write-points-and-otel-mapping` backlog と統合。
10. **X-013/X-015
    session 強化**：`plans/backlog/session-token-hardening-implementation.md`（idle/renewal
    timeout、switch 時 rotation）へ委譲。
11. **X-053/X-054/X-055/X-056 rate
    limit/enumeration**：`plans/backlog/credential-abuse-rate-limit-policy.md`
    へ複合 key・flooding 防止・timing enumeration 評価を集約。
12. **X-049/X-051 OTP counter/telemetry**、**X-035/X-031 provider timeout reconcile**：
    `sign-up-failure-recovery-plan` / `social-login-provider-gem-oidc-hardening` へ委譲。

### 段階

- Stage 1（本プラン直結）: Tier 0 の 1〜3（失敗契約 test / Turnstile binding / token data-repair）。
- Stage 2: Tier 1 の 4〜6（境界正規化 + cancel 不変 + race test）。X-072
  matrix を先行して期待値の基準に。
- Stage 3: Tier 2 を各既存 backlog/plan へ委譲し、本チェックリストは status
  tracker として維持（X-076）。

---

## Verification

```bash
# 失敗契約テスト（Tier 0-1）
bin/rails test test/security/invariants/ceremony_failure_token_delta_invariant_test.rb
bin/rails test test/services/identity   # 成功側 acme_transaction との対比

# Turnstile binding/replay（Tier 0-2）
bin/rails test test/integration/turnstile_forms_test.rb

# race / TOCTOU（Tier 1-6）
bin/rails test test/models/refresh_token_concurrency_test.rb \
  test/security/invariants/refresh_token_reuse_invariant_test.rb

# Sign↔Acme 境界の負例（Tier 1-4）: Sign が Acme-owned state を mutate しないこと
rg -n "log_in|create_login_token_record|rotate_login_refresh_token" app/controllers/sign

# 疑わしい token report（Tier 0-3, report-only・delete しない）
bin/rails security:report_suspicious_user_tokens   # 新規 task

# 既存回帰
bin/rails test test/controllers/sign test/controllers/acme \
  test/controllers/concerns/authentication
```

エンドツーエンド確認: app の email/telephone/social の各 ceremony を **失敗（expired OTP / cancel /
provider deny / forged
Turnstile）**させ、Chronicle に成功 audit が出ず token 数が増えないことを確認。logout→`/signed-out`
の one-shot 性、refresh reuse での family revoke も合わせて手動確認する。migration を伴う場合のみ
`bin/rails db:verify_no_schema_drift`（本プランは test/doc 中心で原則不要）。

## Open items / risks

- X-077/X-078 の境界正規化は ADR 判断（`sign-acme-boundary-remediation`
  再活性化要否）が前提で、実装着手前に方針確定が必要。
- Turnstile の cdata/action binding は widget 発行側（view/JS）との同時変更が要るため、
  `turnstile-visible-placement-policy` / `turnstile-environment-toggle` と整合させること。
- token data-repair は **auto-delete 禁止**。report→review→revoke→delete の人手 gate を崩さない。
