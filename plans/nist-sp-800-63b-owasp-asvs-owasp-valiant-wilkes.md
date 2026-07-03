# Step-up 認証レビュー: 現状把握フェーズ

レビュー担当: セキュリティアーキテクト視点(NIST SP 800-63B / OWASP ASVS / OWASP Cheat Sheets:
Authentication, Session Management, CSRF Prevention, Unvalidated Redirects and Forwards,
Logging)。本フェーズの目的は結論ではなく、証拠の収集と穴の特定である。Unknown は安全扱いしない。

---

## 0. 前提の修正(コードベース調査による)

質問の前に、提示された前提と実リポジトリの差分を確定させる。ここが食い違ったままだと以降の質問が無意味になる。

| 提示された前提                         | 実際                                                                                                                                                |
| -------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| Hono の API / edge / middleware がある | **存在しない**。`hono` は package.json / lockfile / ソースに 0 件                                                                                   |
| React Router frontend がある           | **存在しない**。Inertia.js + React 19(ページ 1 枚のみ)+ Stimulus/Turbo                                                                              |
| React Router loader / guard            | 存在しない。認可・認証はすべて Rails サーバーサイド                                                                                                 |
| app / com / org namespace              | 存在する。ただし実態は **realm(auth/base/core/side/palm/…)× surface(app/com/org)** の二軸マトリクス                                                 |
| cookie session を使っている可能性      | 確定: cookie session。prod は `__Host-session`, `SameSite=Lax`, `HttpOnly`, `Secure`, `expire_after: 14.days`(`lib/jit_session_cookie_config.rb`)   |
| step-up を実装している                 | 確定: `step_up` DSL(`verification_step_up_guard.rb`)+ AAL ベース(`step_up_requirement.rb`, DEFAULT_AAL=:aal2)+ ceremony サービス群 + Chronicle 監査 |

**質問 0(最優先)— 解決済み**: 依頼者確認により **本レビューは Rails 単体として進める**。Hono / React Router
の edge/SPA 層は本リポジトリに存在しないため、edge 層 enforcement・SPA guard 依存・cookie 転送の論点は成立
しないものとして扱う。以降の質問群で Hono/React Router を前提にした項目は、Rails + Inertia + Stimulus に読み
替える(client guard = Stimulus WebAuthn ceremony のみ、認可判断は持たない)。

## 1. 探索で確認済みの事実(提出不要なもの)

コードから直接確認できたため、以下は提出不要。

- **step-up 実装の中核**: `app/controllers/concerns/verification_base.rb`(`require_step_up!`,
  `step_up_satisfied?`, `enforce_verification_if_required`)、宣言 DSL
  `verification_step_up_guard.rb`(`step_up only:, scope:, required_aal:, bootstrap:`)、値オブジェクト
  `app/values/step_up_requirement.rb`
- **actor 別 step-up セッション**: `{visitor,operator,client}_step_up_session.rb`、ceremony
  transaction モデル、`identity_step_up_ceremony_*` サービス(grant issuer / replay store / freshness
  committer / purger)
- **mfa_level**: NOTHING=0 / WEAK=1 / MEDIUM=5 / FULL=9(visitor/operator/client 3 系統)
- **surface 別 ApplicationController**: 各 surface が `ActionController::Base`
  直系で、順序固定のパイプライン(`rate_limit` → context → actor → `enforce_verification_if_required`
  → `enforce_access_policy!`)。未宣言 action は `:deny_all` にフォールバック(fail-closed)
- **session fixation 対策**: login 時 `reset_session`(`authentication_base.rb:366`)、logout 時も
  `reset_session` + cookie clear(`authentication_logoutable.rb:40,55`)
- **redirect**: raw `return_to` ではなく署名付き `pt` トークン(15 分期限、flow/surface/session
  nonce 拘束)、`redirect_to(..., allow_other_host: false)`、拒否理由ログあり(`authentication_redirects.rb`)。外部遷移は
  `redirects_external_target_resolver.rb`(HTTPS 必須・origin allowlist・危険クエリ除去)。ADR:
  `adr/signed-return-targets-only.md`, `adr/redirect-target-lanes-pt-nt-xt.md`
- **CSRF**: 全面 `protect_from_forgery using: :header_or_legacy_token, with: :exception` +
  trusted_origins。例外は OAuth token / OIDC backchannel(`null_session`)と OIDC
  logout(`header_only`)
- **監査**: Chronicle(durable, redaction・retention policy つき)+
  `IdentityAudit.record!`。`auth.step_up.succeeded/failed`, `auth.aal.changed` の retention 分類あり
- **テスト**: `test/integration/step_up_authentication_test.rb`,
  `org_step_up_verification_enforcer_test.rb`, `app_withdrawal_step_up_enforcer_test.rb`,
  `step_up_intent_authority_test.rb`, cookie invariant テスト、CSRF route coverage テスト等が存在
- **ドキュメント**: `docs/security/step-up-mfa-status.md`(一部 Identity
  Authority 反転で陳腐化)、`authentication-assurance-levels.md`,
  `adr/step-up-authentication-redesign.md`, `session-reset-on-privilege-transition.md` ほか多数

## 2. 暫定所見(探索段階で既に見えている穴 — 反証があれば提出せよ)

回答フェーズで反証・補足がなければ、このまま Findings に昇格する。

| ID   | 暫定 Severity   | Area                 | 所見                                                                                                                                                                                                                                                                                                             | 根拠                                             | 参照規格                                                     |
| ---- | --------------- | -------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------ | ------------------------------------------------------------ |
| P-01 | **High**        | Session invalidation | **credential 変更後のセッション失効が無い**。email 変更(`base/app/identity/emails_controller.rb#update`)は `logout_all_sessions_for!` も `reset_session` も呼ばず、`step_up` 宣言も無い(registrations 側のみ宣言)。MFA level 変更(`mfa/challenges_controller.rb#update`)も失効なし                               | 調査エージェントのコード読解                     | NIST 800-63B §7.1(認証イベント後のセッション束縛)、ASVS V3.3 |
| P-02 | **High**        | Auth lifecycle       | app の password rotation が `head(:not_implemented)` のスタブ(`base/app/identity/secrets/rotations_controller.rb`)。MFA reset(`mfa/resets_controller.rb#create`)も実質 no-op redirect。「password change 後の失効」を検証する以前に機能が無い                                                                    | 同上                                             | 800-63B §5.1.1                                               |
| P-03 | **Medium**      | Step-up 粒度         | settings の MFA challenge は `mfa_level_id` を NOTHING/FULL の 2 値でしかトグルしない。WEAK/MEDIUM は到達不能値の疑い。policy matrix と実装の乖離                                                                                                                                                                | `base/app/identity/mfa/challenges_controller.rb` | ASVS V2.8                                                    |
| P-04 | **Medium**      | Logging              | `AuthenticationSecurityEventEmitter` は 14 イベントのタクソノミーを持つが、production の呼び出しは **1 箇所のみ**(`sign_telephone_registrable.rb:110`)。sign_in/sign_out/csrf.failure 等はほぼ未配線。durable 側は Chronicle に流れるが、タクソノミーが二重化・不統一                                            | 調査エージェント                                 | OWASP Logging CS                                             |
| P-05 | **Medium**      | CSRF                 | CSRF strict-mode テスト・token endpoint CSRF は backlog のまま未実装(`plans/backlog/gh627-csrf-strict-mode-test.md`, `restoration-a6-token-endpoint-csrf.md`)。さらに `base/app/application_controller.rb:89` の `protect_from_forgery` 直上に `# FIXME: Resolve the URL issues before deploying.` が残置        | 同上                                             | OWASP CSRF CS                                                |
| P-06 | **Medium**      | Session ops          | 緊急全セッション失効(`gh633-emergency-revoke-all-sessions.md`)・staff session purge(`gh635`)が backlog のみ。インシデント時の kill switch 不在                                                                                                                                                                   | 同上                                             | ASVS V3.3.4                                                  |
| P-07 | **Low/Unknown** | Redirect             | surface ApplicationController の `cross_host_redirect_allowed?` が `true` を返し、authority redirect で `allow_other_host` が広がる。署名 pt / allowlist resolver で緩和されているが、全経路がそれを通る証明が未提出                                                                                             | `sign_acme_authority_redirect.rb`                | OWASP Redirect CS                                            |
| P-08 | **Low**         | 設計整合             | `Sign::` / `Acme::` は redirect concern の正規表現とルートヘルパーにのみ存在し、`app/controllers/sign/*` は空。ADR(Sign=ceremony / Acme=authority)とコードの乖離。到達不能な分岐はレビュー・監査の盲点になる                                                                                                     | 調査エージェント                                 | —                                                            |
| P-09 | **Unknown**     | AAL                  | `step_up_requirement.rb` の `aal_supported?` が aal3 を明示的に除外。FULL(=9)相当の操作も aal2 止まり。これが意図した上限か、暫定かの判断材料が無い                                                                                                                                                              | `app/values/step_up_requirement.rb`              | 800-63B §4.3                                                 |
| P-10 | **Unknown**     | AuthZ                | 未追跡プラン `plans/rails-react-clever-lecun.md` が指摘: org staff コントローラ群が `:private` 止まりで record-level policy 無し、`authorized_scope` 使用 0、`verify_authorized` 0、`base/org/identity/telephones_controller.rb:30,47` に `params(:id)` typo 疑い。step-up が通っても authorization が薄い可能性 | 同プラン                                         | ASVS V4                                                      |

## 3. 提出してほしいもの(コードで確認済みのものは除外済み)

1. **production 実物の `Set-Cookie`
   ヘッダ**(login 直後・step-up 成功直後の 2 時点、値はマスク可)。`jit_session_cookie_config.rb`
   の設定と実配信の一致確認のため。特に `partitioned` と `__Host-` の実挙動
2. **step-up 成功・失敗・期限切れ・intent
   mismatch の実ログ**(Chronicle レコードと Rails.logger 双方、redaction 適用後)
3. **sensitive action の正式な policy matrix**(どの操作にどの scope /
   required_aal を要求するかの一覧表)。`step_up` DSL の grep 結果 ≠ 意図した一覧、の差分を取るため
4. **step-up freshness(max_age)の値と根拠**。`identity_step_up_ceremony_freshness_committer`
   が保持する有効期間、および NIST の reauth 間隔(AAL2: 12h / idle 30min)との対応
5. **step-up 成功時に session id を rotate しているかのコード箇所**(login 時の `reset_session`
   は確認済み。step-up 成功時が未確認)
6. **email 変更・MFA level 変更後にセッション/step-up
   grant を失効させる仕組みがあるなら**その箇所(無ければ P-01 が確定)
7. **`pt` トークンの検証テスト結果**: `//evil.example`, `/%2f%2fevil.example`, `/\evil.example`,
   `https://app.example.com.evil.example/` 等を pt 発行を経ずに直接投げた場合の実レスポンスとログ
8. **org context の検証経路**: org 切替時に DB membership を再検証している箇所。org A の step-up
   grant が org B の sensitive action に流用できない根拠(`step_up_scope_catalog.rb` の scope に org
   id が入るか)
9. **絶対タイムアウト / inactivity timeout** の設定値(`expire_after: 14.days`
   は確認済みだが、これは absolute か sliding か。inactivity 側の制御はどこか)
10. **p95/p99 レイテンシ**: `enforce_verification_if_required`
    が全リクエストで走るパイプラインでの step-up 状態 lookup の回数(Redis/DB)と測定値
11. **ログ retention の決定文書**(Chronicle の `RETENTION_POLICY_BY_ACTION`
    はあるが、日数と削除ジョブの実在)
12. **Hono / React Router が別リポジトリに実在する場合**: そのリポジトリ一式(質問 0)

## 4. 質問セット

## 2026-07-03 acceptance update

This section records the closure state for the step-up security remaining-risk slice. It is written
in English to follow the repository language policy for newly touched plan material.

| ID | Standard mapping | Status | Evidence | Remaining release risk |
| -- | ---------------- | ------ | -------- | ---------------------- |
| P-01 | NIST SP 800-63B session binding; OWASP Session Management | Closed for MFA disable, MFA reset, secret credential removal, and email verification on the Base app request paths. | `test/integration/step_up_authentication_test.rb` creates two sessions and verifies current-session retention, other-session revocation, step-up freshness removal, persisted step-up row expiry, and durable credential-transition audit through controller routes. | Full password change needs equivalent coverage when enabled. |
| P-02 | NIST SP 800-63B authenticator lifecycle | Closed as disabled, not implemented. | `Base::App::Identity::Secrets::RotationsController#create` returns `403 Forbidden`; request test asserts no transition/audit event is emitted. | Full password change is a release blocker for any release that exposes password rotation UI. |
| P-04 | OWASP Logging Cheat Sheet; ASVS V7 | Documented remaining risk for this release. | `CredentialSecurityTransition` writes durable Chronicle/IdentityAudit aggregate records and redaction tests cover secret-bearing metadata. `docs/security/session-reset-policy.md` fixes the non-credential taxonomy bridge as non-blocking remaining risk. | Full durable taxonomy bridge for `auth.csrf.rejected`, `auth.redirect.rejected`, `auth.authorization.denied`, `auth.step_up.intent_mismatch`, and `auth.step_up.required_missing` remains next-slice work. |
| P-05 | OWASP CSRF Prevention; ASVS V4.2 | Closed for release gate. | `test/integration/preference_web_csrf_test.rb` covers same-origin, same-site, untrusted-origin reject, exact trusted-origin pass, suffix/scheme/port confusion reject, missing `Sec-Fetch-Site` same-session legacy-token pass, no-token reject, cross-session token reject, invalid-token reject, and protocol exception paths under enabled forgery protection. `test/lib/jit/base_trusted_origins_test.rb` covers production-like minimal allowlists. | Broader route inventory remains covered separately; full `auth.csrf.rejected` durable taxonomy bridge is P-04 next-slice work. |
| P-07 | OWASP Unvalidated Redirects and Forwards | Closed for path-target resolver fuzz payloads and allow-other-host inventory. | `test/services/redirects_path_target_resolver_security_test.rb` rejects external, protocol-relative, encoded-host-escape, backslash, and dangerous nested redirect query keys without issuing pt. | Per-flow browser redirects still rely on existing controller-specific tests. |
| P-10 | OWASP ASVS V4 IDOR | Closed for org membership matrix. | `test/controllers/base/org/organizations/memberships_controller_test.rb` verifies org A staff cannot access org B membership collection, cannot swap org B membership id into org A URL, and cannot use old step-up freshness to authorize org B mutation. | Owner-transfer and role-specific workflows need equivalent request tests when those production routes are enabled. |

Release recommendation from this update: merge may proceed if the security-slice focused suites stay
green and password rotation UI is not exposed. Exposing password rotation without a full
current-password or step-up verified update flow is a release blocker. Full release still depends on
separating the known red full-suite baseline from this slice.

### A. Step-up の定義(NIST 800-63B §4.3, §7.1)

- A-1. `step_up_satisfied?` の判定材料は何か:
  step_up_session レコードの存在か、session 内の timestamp か、両方か。**cookie session 内に step-up
  state を持っているなら即時失効はどう実現するのか**
- A-2. step-up
  grant は「session 単位」か「actor 単位」か。同一ユーザーの別デバイス session に grant が波及しないか(`{visitor,operator,client}_step_up_session`
  のキー設計)。device / org / action intent単位で分離されているか
- A-3. step-up 成功後に session id を rotate するか(login の `reset_session:366`
  は確認済み。**step-up 成功パスの rotation が未確認**)。[Session Mgmt CS / ASVS V3.2.1]
- A-4. AAL3 が `aal_supported?` で除外されている根拠。AAL3 を要求すべき操作が本当に無いか。[800-63B
  §4.3]

### B. Sensitive action の定義(ASVS V2.2.5 / Authentication CS)

- B-1. step-up 必須アクションの正典はコードか docs か。`step_up` DSL 全 call site と
  `step_up_scope_catalog` / `docs/dictionary/access-terms.md` が一致するか(policy
  matrix の提出で確定)
- B-2. account deletion / password / email / phone / MFA enable-disable / recovery code / API token
  / data export / DM / org owner transfer / org role change / org invite / billing /
  admin の各々に step-up が要るか、コードで示す
- B-3. email 変更(`emails_controller#update`)が step-up 未宣言(registrations 側のみ宣言)なのは意図か

### C. Server-side enforcement(ASVS V1.4 / V4.1)

- C-1. `enforce_verification_if_required` → `enforce_access_policy!` の 2 段が全 surface
  ApplicationController に必ず並ぶことをどう保証するか(regression guard の有無)
- C-2. `AUTHENTICATION_MODE` 未宣言 =
  `:deny_all`(fail-closed)を検証するテストがあり、宣言漏れが CI で落ちるか
- C-3.
  curl/Postman で GET 表示だけでなく POST/PATCH/DELETE 実行も step-up で弾かれるか。GET/mutation 片方漏れの検出手段
- C-4. `BareController`(`:bare`)配下に sensitive endpoint が紛れない保証
- C-5. client(Stimulus WebAuthn
  ceremony)が認可判断を持たないことの確認 — 認可を client 側に置いた箇所が本当に 0 か

### D. Credential change 後の失効(NIST §5.1/§7.1 / Session Mgmt CS)— 最重要

- D-1. email 変更後に他 session / step-up を失効するか(`emails_controller#update`
  に失効呼び出しが見当たらない)
- D-2. MFA level 変更後に既存 step-up / session を失効するか(`mfa/challenges_controller#update`)
- D-3. password rotation が `head(:not_implemented)`。実装後の全 session 失効設計
- D-4. MFA reset が no-op redirect。reset 後の全 session 失効

### E. Cookie / session(Session Mgmt CS / ASVS V3.4)

- E-1. 本番相当 `Set-Cookie` の実測(`__Host-session` / Secure / HttpOnly / SameSite=Lax / Path=/ /
  Domain 無し / `partitioned`)
- E-2. `expire_after: 14.days` は absolute か。inactivity
  timeout の有無・値。AAL2(12h/30min)との整合
- E-3. logout の server-side 無効化が cookie 削除だけに依存していないか
- E-4. cookie session に step-up state を持つ場合の即時失効手段(session version / replay store)
- E-5. remember-me / DBSC(`:1250`)で step-up freshness を延命していないか
- E-6. session store(Redis/DB)障害時の fail は open か closed か。[no-silent-fallback]

### F. auth → base flow / redirect(Unvalidated Redirects CS / ASVS V5.1.5)

- F-1. `after_login_path:93` → `base_app_dashboard_url` の全体像
- F-2. 生 `return_to`/`next`/`redirect_uri` を受ける口が残っていないか(pt/nt/xt lane の使い分け)
- F-3. `redirect_to_pt_destination!`(`allow_other_host: false`)と authority
  redirect(`allow_other_host: cross_host_redirect_allowed?` = surface
  app で true)の境界。後者が allowlist を必ず通る保証
- F-4. step-up の intent ↔ return_to action の一致検証(`step_up_intent_authority_test.rb`
  の範囲)。intent に resource id を含むか

### G. Open redirect / intent テスト(Unvalidated Redirects CS)

以下 payload を pt 発行を経ず直接投げた場合の 期待 / 実結果 / ログ を提出: `https://evil.example`,
`//evil.example`, `https://app.example.com.evil.example/path`,
`https://evil.example/@app.example.com`, `/%2f%2fevil.example`, `/\evil.example`,
`/%5c%5cevil.example`, `/org/123/settings` vs `/org/999/settings`, `/auth/logout?return_to=…`,
`/auth/step_up?return_to=…`。各々: 外部 redirect 阻止 / fallback path / `path_target.rejected`
ログ / intent mismatch 拒否 / org 権限検証。

### H. CSRF(CSRF Prevention CS / ASVS V4.2)

- H-1. `:header_or_legacy_token` strategy 本体。legacy
  token 両受けで downgrade 抜けが無いか。`trusted_origins` の算出根拠
- H-2. **`base/app/application_controller.rb:89` の
  `# FIXME: Resolve the URL issues before deploying.`** の内容・デプロイ状況(Critical 候補)
- H-3. `:null_session`(oauth/backchannel)/ `:header_only`(oidc logout)緩和が safe な理由(M2M /
  Origin・Sec-Fetch-Site 検証)
- H-4. SameSite=Lax 依存過多でないか(GET で state 変更する口が無いか)
- H-5. 将来 cross-origin 前提が無いか(現状 JS 側 CORS / `credentials:'include'` は 0 件)

### I. Authorization との関係(ASVS V4.1 / IDOR)

- I-1. step-up 済みで authz を bypass しない(step-up → authz の順で両方通る)か
- I-2. org role change / owner transfer で step-up と owner/admin 権限の両方を検証するか
- I-3. `authorized_scope` 0 件・org staff が record-level policy 無しで `:private`
  止まり。IDOR を association scoping で担保する範囲
- I-4. `base/org/identity/telephones_controller.rb:30,47` の `params(:id)` typo 疑いの実在

### J. Logging / monitoring(OWASP Logging CS / ASVS V7)

- J-1. step-up
  created/success/failure/expired/required-missing/intent-mismatch が durable にどのイベント名で残るか
- J-2. emitter の taxonomy が call site
  1 箇所で、主要イベント(sign_in/out/csrf/logout/authz.failure)が Chronicle 経由で確実に残るか、記録されない穴があるか(検知の穴)
- J-3. open redirect reject / CSRF reject / sensitive action allowed-denied が監査に残るか
- J-4. OTP/password/raw cookie/CSRF token/recovery code の非出力を保証する redaction の網羅性
- J-5. request_id/trace_id/user_id/session_id
  hash/org_id/route/result/reason の付与、alert 定義、retention、PII 過剰出力

### K. Tests(ASVS V1.4)

- K-1. request spec で API 直叩き step-up 拒否テスト(frontend guard bypass 相当)
- K-2. expired / wrong intent / wrong org のカバレッジ
- K-3. logout 後 session reuse / password 変更後 invalidation / MFA disable 後 step-up invalidation
- K-4. cookie 属性テストが Secure/HttpOnly/SameSite/`__Host-`/Domain 無しを全 assert するか
- K-5. open redirect fuzz / CSRF strict-mode(backlog `gh627` 等で未実装)の現状カバレッジ

### L. Performance(可用性もレビュー対象)

- L-1. `enforce_verification_if_required`
  が全 action で走るか sensitive のみか。step-up 状態の重い query の有無
- L-2. freshness / replay store の lookup 回数(Redis/DB)、purge job コスト
- L-3. Inertia 遷移が /session 相当を連打しないか(client auth-status endpoint 0 件は確認済み)
- L-4. p95/p99 latency 実測(無ければ Unknown)

### M. Documentation(保証性)

- M-1. step-up policy matrix が doc に存在しコードと一致するか(`step_up_scope_catalog` ↔
  `access-terms.md`)
- M-2. session/cookie/redirect/surface 責務/logging/incident
  response の各 doc 現行性。`step-up-mfa-status.md` の superseded 是正状況
- M-3. NIST/OWASP 対応表の有無(`authentication-assurance-levels.md` ほか)

---

## 5. 出力フォーマット(回答受領後に確定)

証拠受領前の暫定。Unknown は安全扱いしない。

### Executive Summary(暫定)

- **現時点で「安全」とは言えない。** load-bearing な未確定が 3 つある: (a)
  credential 変更後の session/step-up 失効が実装上見当たらない(P-01)、(b) デプロイ前提の CSRF
  FIXME 残存(P-05)、(c) 主要 auth イベントの durable 記録が未配線の可能性(P-04)。
- 良い土台はある: fail-closed(`:deny_all`)、署名 pt token による内部限定 redirect、`__Host-`
  cookie、login 時 `reset_session`、Chronicle durable 監査、テスト所在の広さ。
- **最も危険な不明点**: P-01(email/MFA 変更後も奪取済み session が生存)。成立すれば Critical。

### Attack / Abuse Scenarios(防御観点・非破壊)

- S1(P-01/P-02): 攻撃者が session 保持中に被害者が email/MFA を変更しても攻撃者 session が失効せず、乗っ取りが継続。回復操作が無効化。
- S2(P-07): authority redirect の広い `allow_other_host`
  経路で allowlist を迂回できれば外部誘導が成立しうる(pt/allowlist が塞ぐはずだが要実証)。
- S3(P-04): 主要 auth イベントが durable に残らないと侵害を事後検知・追跡できない。
- S4(P-10): org staff の record-level authz 欠落 + `authorized_scope`
  不使用で org 間 IDOR が成立しうる。

### Fix Plan(暫定)

- **今すぐ**: P-05(CSRF FIXME 解消可否とデプロイ判断)、P-01/P-02 の失効実装可否の確定
- **次 sprint**: P-01/P-02(credential 変更 →
  session/step-up 失効)、P-04(auth イベント durable 配線)、P-10(org record-level policy +
  IDOR テスト)
- **ドキュメント**: M 群(policy matrix / NIST・OWASP 対応表 / superseded doc 是正)
- **テスト追加**: K 群(API 直叩き step-up 拒否、変更後失効、open redirect fuzz、CSRF
  strict-mode の backlog 昇格)
- **運用監視**: J 群(step-up failure / intent mismatch / redirect reject / CSRF
  reject の alert 定義と retention)

### Re-test Plan(修正後)

- P-01/P-02 修正後: email/MFA/password 変更 → 他 session が 401/再認証になる integration test
- P-05 修正後: CSRF strict-mode の request spec(全 mutation endpoint、`gh627` 昇格)
- P-07 検証後: G の payload 群を fuzz test 化し `path_target.rejected` ログを assert
- P-04 配線後: 各 auth イベントが Chronicle に記録される emitter/recorder テスト
- 実測: 本番相当 Set-Cookie 属性の invariant test 拡充、step-up 成功時 rotation の assert

---

## 7. 検証結果: P-01(確定)

**結論: Partial(ただし核心は Confirmed / High)。** 当初の「email 変更で失効しない」という表現は **Refuted**
だが、より正確な穴 —「authenticator の無効化・再設定が他 session と未消化 step-up grant を失効させない」— は
**Confirmed**。

### Evidence(実コード)

- **email `#update` はクレデンシャル変更ではない → 当初表現は Refuted**。
  `base/app/identity/emails_controller.rb#update`(l.28-41)が permit するのは
  `email_preference_params`(l.63-71)= `:promotional, :notifiable` のみ。**メールアドレス本体を変更しない**
  (マーケティング購読設定の編集)。よって「email 変更ハンドラに失効が無い」という P-01 の元の主張は当該
  エンドポイントには当たらない。
- **実際のアドレス追加/検証は step-up gated(良好)だが他 session を失効しない**。
  `base/app/identity/emails/registrations_controller.rb:23` に
  `step_up only: %i(new create edit update), bootstrap: true`(`verification_scope = "settings_email"`, l.57)。
  ただし super チェーン(`sign_settings_email_registration.rb` / `sign_email_registrable.rb` /
  `sign_email_registration_flow.rb`)に `reset_session` / `logout_all` / `revoke` / `session_version` は
  **0 件**(grep 確認)。
- **MFA level 変更が失効しない → Confirmed / High**。
  `base/app/identity/mfa/challenges_controller.rb#update`(l.28-32)は
  `current_client.update!(mfa_level_id: ..., mfa_level_enabled: ...)` + redirect のみ。step-up gated
  (`verification_scope = "settings_mfa"`, l.45)だが、更新後に session も step-up grant も失効しない。
  `requested_mfa_level_id`(l.47-52)は NOTHING/FULL のみ受理 = **MFA 無効化(FULL→NOTHING)が可能**で、
  無効化しても既存 session と DB 永続の `{visitor,operator,client}_step_up_session` grant が生き残る。
- **password rotation は未実装 → Confirmed(P-02)**。
  `base/app/identity/secrets/rotations_controller.rb:13` = `def create = head(:not_implemented)`。
- **MFA reset は no-op → Confirmed(P-02)**。
  `base/app/identity/mfa/resets_controller.rb:15-20` = `authorize!` → `redirect_to` のみ。
- **失効は「明示的な全 session revoke」エンドポイントにしか存在しない**。`logout_all_sessions_for!` /
  `AuthenticationSessionRevoker.revoke_all_for` の呼び出し元は `revocations/alls_controller.rb` と
  com/org `sessions_controller`(ユーザー操作)のみ。credential/authenticator 変更からは一切呼ばれない。
- **session fixation 対策(current session の rotate)は存在 → 当初 U3 懸念は解消**。ADR
  `adr/session-reset-on-privilege-transition.md` により `reset_session` は (1) sign-in、(2) **step-up 完了
  (`consume_step_up_session!`)**、(3) logout の 3 点に集約。step-up 成功時に current session id を rotate
  する。ただしこれは fixation(現 session)対策であり、**他 session の失効ではない**。同 ADR の Consequences は
  settings 系 registrations(secrets/totps/passkeys/emails)を「AAL promotion bypass」= `reset_session`
  非適用の non-goal と明記。なお同 ADR は 2026-06-02 に `identity-authority-boundary.md` で supersede 済み。

### Attack scenario(防御観点)

被害者の session を保持中の攻撃者(または account recovery を競っている攻撃者)がいる状況で、被害者が MFA を
無効化・再設定しても、攻撃者の既存 session と過去に取得済みの step-up grant が失効しない。authenticator を
変更・除去しても「他のログイン済み端末を締め出す」効果が得られず、NIST 800-63B §7.1 が想定する authenticator
イベント後の session 束縛が成立しない。password 変更に至っては未実装のため「変更による締め出し」自体が不能。

### Fix(実装方針・最小)

- MFA level 変更成功後(`mfa/challenges#update`)に、**current session を除く**他 session を失効させる。既存の
  `AuthenticationLogoutAllSessions`(`session_version` bump + token 走査)を再利用し、現 session token を除外
  する形の呼び出しを追加(または `revoke_all_for` 後に現 session を再確立)。email address 追加/検証の確定点も
  同様の方針を検討。
- password rotation(`secrets/rotations#create`)実装時は、成功後に全 session 失効 + current 再確立を仕様に含める。
- MFA reset は no-op を実装するまで「未実装」を UI/ドキュメントに明示(silent no-op を廃す)。

### Tests(追加すべき spec)

- integration: MFA を FULL→NOTHING 後、別 session(別 token)の後続リクエストが 401/再認証になること。
- integration: MFA 無効化後、無効化前に取得した step-up grant が sensitive action に通らないこと。
- request: email address 検証確定後の他 session 失効(仕様確定後)。
- password rotation 実装後: 変更成功 → 他 session 失効の integration spec。

### Regression guard(CI で再発検知)

- 「authenticator/credential 変更コントローラは失効 API を呼ぶ」不変条件テスト: `mfa`, `secrets`,
  `emails/registrations` 系 `#update`/`#create` が `AuthenticationLogoutAllSessions` 相当を経由することを
  controller unit で assert(未呼び出しなら fail)。
- `head(:not_implemented)` を返す本番ルートを検出し、意図的スタブの許可リスト外なら fail させる test。

---

## 8. 検証結果: P-05(確定)

**結論: Partial / Medium。CSRF 保護は有効かつ構造的に健全(bypass は Refuted / H-3 も Refuted)。ただし
`# FIXME: Resolve the URL issues before deploying.` は `trusted_origins` の正しさに関する未解決の deploy
gate として実在し、strict-mode 等のテストギャップも確定。**

### Evidence(実コード)

- **`:header_or_legacy_token` はフォーク Rails 由来のカスタム strategy**。定義はアプリ側になく、vendoring された
  git ソースの Rails(`vendor/bundle/ruby/4.0.0/bundler/gems/rails-bf13f50eb663/actionpack/lib/action_controller/metal/request_forgery_protection.rb`)。
  検証セマンティクス(l.620-659):GET/HEAD は無検証で許可 → それ以外は `valid_request_origin?` かつ
  `verified_with_legacy_token?`。後者は Sec-Fetch-Site が same-origin/same-site → pass、cross-site →
  `origin_trusted?`(allowlist)、**missing/none → `any_authenticity_token_valid?`(従来トークン)にフォールバック**。
- **downgrade bypass は成立しない → H-3 Refuted**。Sec-Fetch-Site を省いても token フォールバック側で有効な
  authenticity token が必須。ヘッダを落とすだけでは検証を回避できない。
- **全 browser サーフェスの mutation は CSRF 検証対象**。各 surface `ApplicationController` + `BareController` が
  `with: :exception`。例外は妥当な M2M のみ: `:null_session`(OAuth token/protocol、OIDC backchannel logout =
  JWT 認証・非ブラウザ)、`:header_only`(OIDC RP logout)。state-changing の GET は確認範囲で無し。
- **FIXME は最近の未解決 deploy gate**。`base/app/application_controller.rb:89`、`base/com:85`、`base/org:84` の
  3 サーフェスに存在。git blame = commit `3683d7aec`(2026-06-27, 本日から 6 日前)。直下の
  `trusted_origins: JitHostOriginEnv.trusted_origins(ENV.fetch("PUBLIC_*_..."))` を指しており、「URL issues」は
  この allowlist 算出の正しさに関わる。trusted_origins が広すぎれば cross-site の `origin_trusted?` が誤って
  通り CSRF bypass、狭すぎればクロスサーフェス正常系が壊れる。**env 値と作者意図が未提出のためコードだけでは
  確定不能**。ただし作者自身の "before deploying" マーカーにより deploy gate 扱いが妥当。
- **テストギャップ確定**。CSRF strict-mode(`gh627`)、token-endpoint CSRF(`restoration-a6`)、
  public-controller CSRF は backlog で未実装。`test/controllers/security/csrf_route_coverage_test.rb` は
  「どの controller が NULL_SESSION_STRATEGY か」の coverage guard のみで、request レベルの CSRF 挙動は未検証。

### Deploy blocker か

**作者の "before deploying" マーカーに従い「未解決の deploy gate」と扱う。** ただし CSRF 自体は無効化されて
おらず(`with: :exception` 稼働)、確定した live bypass ではない。判定に必要なのは (a) 各 `PUBLIC_*_SERVICE_URL`
の実値、(b) `JitHostOriginEnv.trusted_origins` の展開結果、(c) FIXME が指す「URL issues」の具体。これらが健全と
確認できれば FIXME 除去、そうでなければデプロイ前に是正。

### 修正 diff 方針

- `JitHostOriginEnv.trusted_origins` の展開結果を検証する unit test を追加し、想定 origin 集合と一致することを
  pin(FIXME が指す不確実性をテストで固定 → コメント除去の根拠にする)。
- cross-site の `origin_trusted?` 分岐が **意図した origin だけ**通すことを request spec で確認(信頼外 origin から
  の cross-site POST が 403 になること)。

### request spec 案

- same-origin POST(Sec-Fetch-Site: same-origin)→ 200/302(通る)。
- cross-site POST、Origin が trusted_origins 内 → 通る / 外 → `ActionController::InvalidCrossOriginRequest`(403)。
- Sec-Fetch-Site 欠落 + 有効 token → 通る、token 無し → 403(フォールバック健全性)。
- OAuth token(`:null_session`)/ OIDC RP logout(`:header_only`)が browser CSRF token 無しでも仕様どおり動作し、
  かつ他認証(client credential / JWT)で保護されること。

---

## 6. 進め方

本ファイルは現状把握フェーズの成果物(前提修正 + 確認済み事実 + 暫定所見 + 提出依頼 + 質問セット)。ここで結論は出さない。依頼者が §3 の証拠と §4 の回答を出したら、証拠ベースで各所見を Critical/High/Medium/Low/Unknown に確定し、Findings・Attack
Scenarios・Fix Plan・Re-test Plan を更新する。曖昧回答には追加証拠を要求する。
