# セキュリティ監査計画: 認証・認可・セッション・トークン・マルチテナント境界

## Context

本計画は、Umaxica
Rails アプリケーションの認証認可セキュリティ監査を実施するためのものである。監査官としてコードベースを一読した上で、実装の具体的なリスクを特定し、実装者に証拠を要求しながらリスクを掘り下げる。

本監査の目的は「防御・検証・是正」であり、外部攻撃・課金・犯罪行為は一切含まない。診断セクション L（Hono/React
Router）は本プロジェクトに実装がないため対象外。セクション M（Cloud/Operations）は外部テストなし・クレデンシャル外部流出なしの制約下で実施。

---

## コードベース読み取りサマリー

### 確認済みの強み

| 領域                     | 実装                                                    | ファイル                                                                   |
| ------------------------ | ------------------------------------------------------- | -------------------------------------------------------------------------- |
| セッション Cookie        | `__Host-session`, SameSite=lax, HttpOnly, AES-256-GCM   | `config/initializers/session_store.rb`, `lib/jit_session_cookie_config.rb` |
| 認証 Cookie              | `__Host-access/refresh/dbsc`, SameSite=strict, HttpOnly | `app/controllers/concerns/authentication_cookie_service.rb`                |
| JWT 署名アルゴリズム     | ES384 (ECDSA P-384)                                     | `lib/jit_security_jwt_jwk.rb`                                              |
| JWT 必須クレーム         | iss, aud, typ, exp, sub, sid, act, jti, acr             | `app/services/security_jwt_auth_access_token_codec.rb`                     |
| Refresh Token 保存       | SHA3-384 ダイジェストのみ、平文なし                     | `app/models/concerns/refresh_token_shared.rb`                              |
| Refresh Token 再利用検知 | ファミリー全体失効 + SignRiskEmitter                    | `app/services/acme_refresh_token_service.rb`                               |
| DPoP                     | htm/htu/iat/jti/ath/jwk 完全検証                        | `app/services/dpop_proof_validator.rb`                                     |
| DBSC                     | ES256/RS256, RSA 2048bit 最低、challenge TTL 5分        | `app/services/dbsc_proof_validator.rb`                                     |
| Session Fixation 対策    | login/logout で `reset_session`                         | `app/controllers/concerns/authentication_base.rb`                          |
| アクセスポリシー強制     | `enforce_access_policy!` は skip 不可                   | `app/controllers/concerns/authentication_base.rb:766-791`                  |
| デフォルト認証モード     | `:deny_all` (未設定 action は全拒否)                    | `app/controllers/application_controller.rb`                                |
| IDOR 対策                | `current_user.resources.find()` パターン統一            | `app/controllers/acme/*/settings/*_controller.rb`                          |
| CSP                      | enforce モード、nonce 付き、unsafe-inline なし          | `config/initializers/content_security_policy.rb`                           |
| HSTS                     | 365日, subdomains, preload=false (ADR有り)              | `config/environments/production.rb`                                        |
| パラメータフィルタ       | token, jwt, cookie, secret 等 網羅                      | `config/initializers/filter_parameter_logging.rb`                          |
| ActionPolicy             | deny-all default, relation_scope → `.none`              | `app/policies/application_policy.rb`                                       |

### コードレビューで発見した要注意箇所（初回質問の根拠）

| ID   | 箇所                                                                                     | リスク仮説                                                     | 重大度予測 |
| ---- | ---------------------------------------------------------------------------------------- | -------------------------------------------------------------- | ---------- |
| R-01 | `operator_lifecycle_requests_controller.rb:106` `organization_id` を params から受け取る | 権限昇格：別 org の lifecycle request を作成できる可能性       | Critical   |
| R-02 | `after_action :verify_authorized` なし                                                   | authorize! を書き忘れた action が認可なしで通過                | High       |
| R-03 | `protect_from_forgery using: :header_or_legacy_token`                                    | "legacy_token" の意味・実装が不明                              | High       |
| R-04 | Session cookie SameSite=lax（意図的との注記あり）                                        | cross-site flow で session cookie が送られる範囲の明確化が必要 | Medium     |
| R-05 | DPoP は optional（stateless path では JTI 記録なし）                                     | stateless な API path では DPoP proof の replay が可能か       | Medium     |
| R-06 | WebAuthn: rpId が per-request で動的決定                                                 | Host header 偽装による rpId confusion の可能性                 | High       |
| R-07 | `has_secure_password algorithm: :argon2` のパラメータ不明                                | ライブラリデフォルト値が弱い可能性                             | Medium     |
| R-08 | アカウントリンク: `email_verified` チェック不明                                          | 未検証メールアドレスによるアカウント乗っ取り                   | High       |
| R-09 | JWKS endpoint 公開 (`/keys.json`)                                                        | kid 列挙・grace/retired 鍵の公開範囲                           | Low-Medium |
| R-10 | 環境間の JWT issuer/audience 分離の証拠未確認                                            | staging JWT を production で受理するリスク                     | High       |

---

## 初回 12 質問（コードベース読み取りを踏まえた版）

以下の質問が実装者に投げる初回質問である。コードで確認できた事実を前提に、「コードで保証されている」か「運用・設定・テストで保証されている」かを峻別する。

### Q1: 責務分界

Rails の `AuthenticationBase` が認証判定を担うことはコードで確認した。しかし Cloudflare / CDN /
WAF などエッジ層が別途 JWT/Cookie を検証している場合、その判定と Rails の判定が食い違ったときどちらが優先されるか。エッジ層は何を見ており、何を信頼しているか。

### Q2: ブラウザ保存物の完全インベントリ

`__Host-access`, `__Host-refresh`, `__Host-dbsc`, `__Host-session` の 4
Cookie はコードで確認した。DPoP 実装もある。DPoP の秘密鍵はブラウザのどこに保存されるか（`localStorage`,
`IndexedDB`, Web Crypto API
`non-extractable CryptoKey`）。DPoP 非対応ブラウザの fallback は何か。それ以外に `localStorage` /
`sessionStorage` / `IndexedDB` に認証関連データを保存しているか。

### Q3: TTL / rotation / revocation

以下の 4 イベントそれぞれで、「次のリクエストが成功する前に」失効する token/session を列挙せよ。「おそらく失効する」は不合格。

- (a) ユーザーがパスワードを変更した
- (b) ユーザーの role が downgrade された
- (c) ユーザーが organization から削除された
- (d) アカウントが suspended になった

### Q4: JWT alg allowlist

`ALGORITHM = "ES384"` は確認した。`decode()` 時に `alg=none` を拒否するコードはどこか。`alg=HS256` +
ECDSA 公開鍵を HMAC secret として confusion
attack を試みたときに拒否するコードはどこか。`SecurityJwtAuthAccessTokenCodec#decode`
から JWT ライブラリ呼び出しまでの正確なコードパスを示せ。

### Q5: OIDC アカウントリンクの信頼モデル

`social_auth_link_handler.rb` はロックを取得してから identity を探す実装を確認した。Google ID
token の `email_verified=false` のケースを拒否しているか。Google アカウント側で
`attacker@victim.com`
を作成した場合に victim のアカウントにリンクできるか。Google と Apple の間で同じメールアドレスによる identity
confusion を防いでいるか。何のクレームを identity の正規キーとして使っているか（email か uid か）。

### Q6: WebAuthn rpId の決定方法

`webauthn.rb` で rpId が per-request で動的決定されると読んだ。rpId は何から決まるか。HTTP `Host`
ヘッダーから派生するなら、`Host: evil.staging.umaxica.com` を送った場合の rpId は何になるか。trusted
origins の allowlist は起動時に固定されているが、rpId も同様か。

### Q7: TOTP replay 防止

`rotp` によって TOTP を実装しているのを確認した。ユーザーが code `123456`
を使って認証成功した後、同じ 30 秒 window 内に同じ code が別の session/デバイス/IP から使われたとき、それを拒否するか。「使用済みコード」はどのテーブル・キャッシュに記録し、TTL は何秒か。

### Q8: Argon2id パラメータ

`has_secure_password algorithm: :argon2` を確認した。`memory_cost`, `time_cost`, `parallelism`
の実際の値は何か。`argon2`
gem のデフォルト値を使っているか、明示的に上書きしているか。本番サーバーでのハッシュ計算時間の測定値を示せ。

### Q9: operator_lifecycle_requests_controller の organization_id

`app/controllers/sign/org/settings/operator_lifecycle_requests_controller.rb:106` で
`organization_id` を params から受け取っている。`OrgOperatorLifecycleRequestCreate` サービスは
`current_operator` が該当 `organization_id`
の org に実際に所属しているかを検証しているか。検証しているなら、その正確なコード行を示せ。Policy で弾くか、Service で弾くか、両方か。

### Q10: ActionPolicy 認可漏れ検知

`after_action :verify_authorized` が存在しないことを確認した。新しい action を追加して `authorize!`
を書き忘れた場合、どの仕組みがそれを検知するか。Rubocop ルール、CI チェック、テスト規約のどれかがあるか。ない場合、過去に「認可なしで通過する action」が本番に入った事例はあるか。

### Q11: Cookie SameSite split と CSRF の根拠

Session cookie が SameSite=lax、auth
cookie が SameSite=strict であることを確認した。lax が必要な具体的フロー（OIDC callback、magic
link 等）を列挙せよ。`protect_from_forgery using: :header_or_legacy_token`
の "legacy_token" とは何か。どのエンドポイントで CSRF 検証が skip されるか（`skip_forgery_protection`
/ `skip_before_action :verify_authenticity_token` を grep した結果を示せ）。

### Q12: 環境間クレデンシャル分離

`AUTH_JWT_ISSUER`
が staging と production で異なる値を持つことを ENV 変数で管理していると想定する。staging の private
key で署名した JWT を production の JWKS で verify したときに拒否される保証はどこにあるか。staging/production の OAuth
client_id、redirect_uri、cookie domain、CORS
origin が混在しないことをどのテスト・設定管理で保証しているか。

---

## 危険度順の監査予定セクション（初回回答後に絞り込む）

1. **セクション J: multi-tenant / IDOR / BOLA** — R-01 (org_id from params) が Critical 候補
2. **セクション K: Rails 固有** — R-02 (verify_authorized なし)、R-03 (legacy_token)
3. **セクション A: OAuth 2.1 / OIDC** — R-08 (account linking / email_verified)
4. **セクション C: JWT / JWKS** — R-04/R-10 (alg confusion, env isolation)
5. **セクション G: WebAuthn / Passkey** — R-06 (rpId 動的決定)
6. **セクション D: DPoP** — R-05 (stateless path の JTI 記録)
7. **セクション B: access/refresh token** — TTL・revocation チェーン
8. **セクション H: TOTP** — R-07 (replay 防止)
9. **セクション I: password** — R-08 (Argon2id params)
10. **セクション E: DBSC / device_id** — device_id が認証要素化していないか
11. **セクション F: Cookie / CSRF / CORS** — R-03/R-04
12. **セクション M: Cloud/Ops** — 環境分離・audit log

---

## Q1〜Q12 調査結果 — コードベース読み取りによる監査レポート

---

### FINDING-01 [Critical] — organization_id を params から受け取り、org 帰属を検証しない

**Finding ID:** FINDING-01 **Title:** OrgOperatorLifecycleRequest 作成時に `organization_id`
の認可チェックが存在しない **Category:** Authorization / IDOR / Multi-tenant boundary **Attack
hypothesis:** 認証済みの Operator が、自分が所属しない別 org の `organization_id`
を params に含めて lifecycle request（招待・除名・昇格等）を作成できる。Policy は
`operator?`（Operator であること）のみを確認しており、org 帰属は確認しない。

**コード証拠:**

- `app/controllers/sign/org/settings/operator_lifecycle_requests_controller.rb:106` —
  `organization_id` を Strong Parameters で受け取る
- `app/controllers/sign/org/settings/operator_lifecycle_requests_controller.rb:34` —
  `authorize!(OperatorLifecycleRequest)` を呼ぶが…
- `app/policies/operator_lifecycle_request_policy.rb:13-15` — `create?` は `operator?`
  のみを返す（org 帰属なし）
- `app/services/org_operator_lifecycle_request_create.rb:37` —
  `organization_id: attributes[:organization_id].presence` を検証なしで渡す

**How to test safely (ローカル):**

1. Operator A (org_1 所属) でログイン
2. `organization_id` を org_2 の id に変えて lifecycle request の POST を送る
3. 400/403 が返るか、または org_2 に対する招待・除名が作成されるかを確認

**Expected secure behavior:** 403 Forbidden。Policy または Service 内で
`actor.organizations.exists?(organization_id)` を検証する。

**Current answer quality:** Fail **Severity:** Critical **Likely impact:**
攻撃者は別テナントに対して組織操作（管理者招待・自分を昇格・他ユーザー除名）を実行できる。マルチテナント境界の完全な突破。
**Fix recommendation:** Policy の `create?` を
`operator? && user.organizations.exists?(record_organization_id)` に強化するか、Service 内で
`actor.organizations.find!(attributes[:organization_id])` を使い、見つからなければ raise する。
**Regression test to add:**
`test "operator cannot create lifecycle request for foreign organization"` **Owner hint:** Rails /
DB

---

### FINDING-02 [High] — パスワード変更時に既存 token / session が失効しない

**Finding ID:** FINDING-02 **Title:** password change 後も旧 access token・refresh
token・session が有効なまま残る **Category:** Session / Token revocation **Attack hypothesis:**
攻撃者が access token または refresh
token を窃取していた場合、被害者がパスワードを変更しても旧トークンでアクセス継続できる。`session_version`
のインクリメントや `logout_all_sessions` の呼び出しがパスワード変更フローに存在しない。

**コード証拠:**

- `app/controllers/concerns/authentication_logout_all_sessions.rb:44-47` — `session_version`
  increment は logout_all_sessions のみ
- パスワード変更 service にて `logout_all_sessions` を呼ぶ箇所なし
- `app/services/security_token_lifetimes.rb:10` — access token TTL は 1 時間、refresh
  token は最大 14 日

**How to test safely:**

1. ログインして access token と refresh token を控える
2. パスワードを変更する
3. 旧 access token でリソースリクエスト → 成功するか確認
4. 旧 refresh token で token refresh → 成功するか確認

**Expected secure behavior:** パスワード変更後、すべての refresh token が即時失効。access
token は最大 TTL（1 時間）で自然失効するか、`session_version` インクリメントにより JWT 検証で弾く。

**Current answer quality:** Fail **Severity:** High **Likely impact:**
資格情報窃取後、被害者がパスワードリセットしても攻撃者は最大 1 時間（access token
TTL）または最大 14 日（refresh token TTL）アクセスを継続できる。 **Fix recommendation:**
パスワード変更成功時に `logout_all_sessions_for!(current_user, except_current: true)`
を呼び、`session_version` をインクリメントする。現在のセッションのみ残すことは UX 上許容される。
**Regression test to add:** `test "existing tokens are revoked after password change"` **Owner
hint:** Rails

---

### FINDING-03 [High] — social login account linking で email_verified を強制しない

**Finding ID:** FINDING-03 **Title:** Google/Apple アカウントリンク時に `email_verified=false`
を拒否しない **Category:** OAuth / OIDC / Account takeover **Attack hypothesis:** `email_verified`
はクレームとして収集されるが、`false`
時のリンク拒否ロジックが存在しない。現在は uid+provider が identity キーであるため直接的リスクは低いが、将来のプロバイダ追加または email マッチングコードパスの追加時にアカウント乗っ取りリスクが顕在化する。

**コード証拠:**

- `app/services/identity_social_ceremony_result_issuer.rb:108-114` — `email_verified` を抽出する
- `app/services/social_auth_link_handler.rb:28` — `find_by(uid:, provider:)`
  で uid+provider キーを使用（email_verified のガードなし）
- `app/services/social_auth_verified_provider_assertion.rb` — email_verified の強制なし

**緩和要因:** identity の主キーは `uid + provider`（email ではない）。Google uid
(sub) は攻撃者が偽装困難。DB 制約 `uniqueness: { scope: :provider }` あり。

**Current answer quality:** Weak **Severity:** High（潜在的）/
Medium（現状の uid 設計により部分緩和） **Likely impact:**
将来の email マッチングコードパス追加時に未検証メールによるアカウント乗っ取り **Fix
recommendation:** `email_verified=false` を明示的に raise するガードを `social_auth_link_handler.rb`
または `identity_social_ceremony_result_issuer.rb` に追加する。 **Regression test to add:**
`test "linking with email_verified=false is rejected"` **Owner hint:** Rails

---

### FINDING-04 [High] — ActionPolicy で authorize! を書き忘れた action が無音で通過する

**Finding ID:** FINDING-04 **Title:** `after_action :verify_authorized`
が存在せず、認可漏れ action が自動検知されない **Category:** Authorization gap / structural **Attack
hypothesis:** 開発者が新しい action に `authorize!` を書き忘れた場合、`enforce_access_policy!`
は認証（認証済みユーザーか）を確認するが、認可（このリソースへのアクセス権があるか）は確認しない。認証と認可を混同した実装が無音で通過する。

**コード証拠:**

- `grep -r "after_action.*verify_authorized" app/controllers` — ヒットなし
- `test/unit/security/action_policy_usage_test.rb:34-49` — `enforce_access_policy!`
  の before_action 存在を検証するが `authorize!` の呼び出しは検証しない
- `app/controllers/concerns/authentication_base.rb:765-785` — `enforce_access_policy!`
  の skip を禁止（認証チェックのみ）

**Current answer quality:** Weak **Severity:** High **Likely impact:**
将来追加される action で認可が抜け落ちた場合、認証済みユーザーならば誰でもアクセス可能な endpoint が生まれる。
**Fix recommendation:**

```ruby
# Surface ApplicationController に追加
after_action :verify_authorized
```

または ActionPolicy の audit mode / `action_policy.test_mode` を CI で活用する。 **Regression test
to add:** `test "all authenticated controller actions call authorize!"` **Owner hint:** Rails

---

### FINDING-05 [High] — role downgrade 後に既存 token が即時失効しない

**Finding ID:** FINDING-05 **Title:** Operator の role downgrade 後、旧 access
token で旧権限 API が叩ける可能性 **Category:** Token revocation / Authorization **Attack
hypothesis:** Operator が `admin` → `viewer` に降格された後も旧 access
token（最長 1 時間有効）が権限判定に使われる場合、旧権限 API にアクセスできる。SUSPEND/TERMINATE 時は
`revoke_target_sessions!` が呼ばれるが role downgrade 単体では呼ばれない。

**コード証拠:**

- `app/services/org_operator_lifecycle_execute.rb:110` — SUSPEND/TERMINATE 時のみ
  `revoke_target_sessions!` を呼ぶ
- role の `change_role` 等の後に revoke を呼ぶコードなし
- JWT の access token に role クレームが含まれるかどうかを要確認（含まれる場合は特に影響大）

**Current answer quality:** Unknown（JWT に role クレームが含まれるかどうかで影響が変わる）
**Severity:** High（JWT に role が埋め込まれている場合） **Likely impact:** role
downgrade が最大 1 時間有効にならない **Fix recommendation:** role 変更時も `session_version`
インクリメントまたは token 失効させる。またはすべての認可判定を JWT クレームではなく DB の現在 role に基づいて行う。
**Regression test to add:** `test "downgraded operator cannot access admin API with old token"`
**Owner hint:** Rails / DB

---

### FINDING-06 [Medium] — TOTP の同一 window 内 replay 防止が間接的

**Finding ID:** FINDING-06 **Title:** TOTP の replay 防止が `last_otp_at`
タイムスタンプ方式で、DB ロックなし **Category:** TOTP / MFA **Attack hypothesis:** `last_otp_at`
更新が race
condition にさらされた場合（並列リクエスト）、同一 window のコードが複数回使われる可能性がある。

**コード証拠:**

- `app/controllers/sign/app/in/challenge/totps_controller.rb:106` —
  `totp_record&.update!(last_otp_at: ...)` — `with_lock` なし
- `app/models/client_totp_credential.rb:12` — `last_otp_at` フィールド

**Current answer quality:** Weak **Severity:** Medium **Fix recommendation:**
`totp_record.with_lock { verify_and_update }` パターンに変更して DB ロックで排他制御する。
**Regression test to add:** `test "same TOTP code cannot be used twice in same window"` **Owner
hint:** Rails / DB

---

### FINDING-07 [Medium] — Argon2id パラメータが gem デフォルト（明示的調整・計測なし）

**Finding ID:** FINDING-07 **Title:**
Argon2id のパラメータが RFC_9106_LOW_MEMORY デフォルトで、本番での計測値が不明 **Category:**
Password hashing **コード証拠:**

- `app/models/concerns/secret_credential.rb:22` —
  `has_secure_password algorithm: :argon2, validations: false`
- `vendor/bundle/.../argon2-2.3.3/lib/argon2/profiles.rb:30-34` — RFC_9106_LOW_MEMORY:
  `t_cost:3, m_cost:16(64MiB), p_cost:4`
- 明示的なパラメータ上書きなし

**評価:** RFC 9106
LOW_MEMORY は OWASP 推奨を上回るが、本番サーバーでの計測値が不明。300ms 超の場合 DoS リスク。
**Current answer quality:** Weak **Severity:** Medium **Fix recommendation:** 本番サーバーで
`Argon2::Password.create("test")` の実行時間を計測し、100–300ms 以内を確認。パラメータを
`config/initializers/` で明示的に固定する。 **Owner hint:** Rails / Infra

---

### FINDING-08 [Low] — WebAuthn rpId が env var 未設定時 `request.host` にフォールバック

**Finding ID:** FINDING-08 **Title:** `WEBAUTHN_APP_RP_ID` 等の env var 未設定時、rpId が HTTP
Host ヘッダー由来になる **Category:** WebAuthn **コード証拠:**

- `app/controllers/concerns/sign_webauthn.rb:27` —
  `configured_webauthn_value("RP_ID") || request.host`

**緩和:** `validate_webauthn_origin!`
が TRUSTED_ORIGINS 外の origin を拒否 (`sign_webauthn.rb:46-70`)。TRUSTED_ORIGINS は起動時に必須検証される。

**Current answer quality:** Weak **Severity:** Low **Fix recommendation:** `WEBAUTHN_APP_RP_ID`
が未設定の場合、起動時に raise する。 **Owner hint:** Rails / Infra

---

### FINDING-09 [Info] — DPoP がブラウザ（Web フロントエンド）では実装されていない

**Finding ID:** FINDING-09 **Title:** ブラウザ JS に DPoP 鍵生成がなく、Web セッションは plain
Bearer として機能する **Category:** Token binding / Defense-in-depth **コード証拠:**
`app/javascript/` 内に `crypto.subtle.generateKey` / DPoP 関連コードなし

**評価:**
意図的設計と思われる（Web は DBSC で代替）。ただし DBSC 非対応ブラウザでの Web セッションの token
theft blast radius を文書化すべき。 **Severity:** Info **Owner hint:** Rails / Product

---

### FINDING-10 [Info] — Staging 環境ファイルが存在せず本番 config との分離が運用依存

**Finding ID:** FINDING-10 **Title:** `config/environments/staging.rb` がなく、staging は ENV
var のみで production と分離 **Category:** Environment isolation **コード証拠:**
`config/environments/` — development.rb, production.rb, test.rb のみ

**評価:** JWT issuer 検証 (`verify_iss: true`) により、正しく ENV var が設定されていれば cross-env
token は拒否される。ENV var 設定ミスが唯一の保護。 **Severity:** Info **Fix recommendation:**
`AUTH_JWT_ISSUER` の staging/production 差異を IaC で管理・CI で検証する。 **Owner hint:** Infra

---

## Q1〜Q12 一覧サマリー

| Q   | 項目                                          | 判定     | 重大度       | Finding ID     |
| --- | --------------------------------------------- | -------- | ------------ | -------------- |
| Q1  | 責務分界（エッジ認証なし）                    | Pass     | —            | —              |
| Q2  | ブラウザ保存物（DPoP はネイティブのみ）       | Weak     | Info         | FINDING-09     |
| Q3a | パスワード変更時の revocation                 | **Fail** | **High**     | **FINDING-02** |
| Q3b | role downgrade 時の revocation                | **Fail** | **High**     | **FINDING-05** |
| Q3c | org 除名（TERMINATE/SUSPEND 時）の revocation | Pass     | —            | —              |
| Q3d | アカウント suspend 時の revocation            | Pass     | —            | —              |
| Q4  | JWT alg allowlist（三重防衛）                 | Pass     | —            | —              |
| Q5  | OIDC account linking / email_verified         | Weak     | High         | FINDING-03     |
| Q6  | WebAuthn rpId（env var フォールバック）       | Weak     | Low          | FINDING-08     |
| Q7  | TOTP replay（ROTP + last_otp_at、ロックなし） | Weak     | Medium       | FINDING-06     |
| Q8  | Argon2id パラメータ（デフォルト、未計測）     | Weak     | Medium       | FINDING-07     |
| Q9  | **organization_id 認可チェックなし**          | **Fail** | **Critical** | **FINDING-01** |
| Q10 | verify_authorized なし（authorize! 漏れ無音） | Weak     | High         | FINDING-04     |
| Q11 | SameSite split / CSRF（正当な設計）           | Pass     | —            | —              |
| Q12 | 環境分離（issuer 検証あり、staging.rb なし）  | Weak     | Info         | FINDING-10     |

---

## Top 10 リスク（悪用可能性 × 影響度）

| 順位 | Finding                                      | 重大度   | 悪用難易度                           | 影響                                       |
| ---- | -------------------------------------------- | -------- | ------------------------------------ | ------------------------------------------ |
| 1    | FINDING-01: org_id from params 無認可        | Critical | 低（認証済み Operator なら即実行可） | クロステナント組織操作                     |
| 2    | FINDING-02: パスワード変更後も旧 token 有効  | High     | 中（token 窃取が前提）               | 最大 14 日の持続的アクセス                 |
| 3    | FINDING-04: verify_authorized なし           | High     | 中（実装者の書き忘れに依存）         | 将来の認可漏れ action が無音で通過         |
| 4    | FINDING-05: role downgrade 後も旧 token 有効 | High     | 中（token 窃取 + タイミング依存）    | 降格後の管理者権限継続                     |
| 5    | FINDING-03: email_verified 未強制            | High     | 高（現状 uid 設計で部分緩和）        | 将来のソーシャル account 乗っ取りリスク    |
| 6    | FINDING-06: TOTP replay 防止が間接的         | Medium   | 中（race condition）                 | MFA バイパス                               |
| 7    | FINDING-07: Argon2id パラメータ未計測        | Medium   | 低（本番スペック次第）               | DoS またはブルートフォース                 |
| 8    | FINDING-08: WebAuthn rpId フォールバック     | Low      | 高（env var 設定時は実害なし）       | rpId confusion（env 未設定時のみ）         |
| 9    | FINDING-09: Web ブラウザ DPoP なし           | Info     | —                                    | DBSC なし端末での token theft blast radius |
| 10   | FINDING-10: staging.rb なし                  | Info     | —                                    | ENV 設定ミスによる環境混在リスク           |

---

## 「今すぐ止血」リスト

1. **FINDING-01**: `OperatorLifecycleRequestPolicy#create?`
   に org 帰属チェックを追加。`operator? && user.organizations.exists?(record_organization_id)`
   に強化。
2. **FINDING-02**: パスワード変更成功後に
   `logout_all_sessions_for!(current_user, except_current: true)` を呼ぶ。

## 「設計を変えるべき」リスト

1. **FINDING-04**: 全 Surface ApplicationController に `after_action :verify_authorized`
   を追加し、`authorize!` の書き忘れを即時検知する仕組みを作る。
2. **FINDING-05**: 権限変化（role 変更）時の revocation フローを確立。SUSPEND/TERMINATE だけでなく role
   downgrade も revoke を呼ぶ設計にする。

## 「テストを足せば確認できる」リスト

1. **FINDING-01**: 別テナントの org_id で POST して 403 を確認するインテグレーションテスト
2. **FINDING-02**: パスワード変更後に旧 refresh token で token
   refresh が 401 になることを確認するテスト
3. **FINDING-03**: `email_verified=false`
   の auth_hash でリンクが拒否されることを確認するサービス単体テスト
4. **FINDING-06**: 同一 TOTP コードを同 window 内で 2 回使い、2 回目が失敗することを確認するテスト
5. **FINDING-05**: role downgrade 後に旧 access token で admin API が 403 になることを確認するテスト

## 「証拠不足 — 次に確認すべきコード/設定」リスト

1. **FINDING-05**: JWT access token payload に `role` / `permission` クレームが含まれるか →
   `app/services/security_jwt_auth_access_token_codec.rb` の encode payload を確認
2. **FINDING-06**: TOTP verify 時に `with_lock` が使われているかどうか →
   `app/controllers/sign/app/in/challenge/totps_controller.rb` の完全コードを確認
3. **FINDING-08**: `WEBAUTHN_APP_RP_ID` 等の env var が production deploy に設定されているか → IaC /
   Helm values を確認
4. **FINDING-09**: DBSC 非対応ブラウザの fallback session の TTL と権限範囲 → `app/services/dbsc_*`
   の fallback フロー確認
5. **Q3b**: org membership 削除（SUSPEND/TERMINATE 以外の経路）があるかどうか →
   `org_operator_lifecycle_execute.rb` の全 action を確認

---

## 深掘り Grill 結果

### GRILL-01 [Critical → Critical+] — FINDING-01 の根本原因判明

**発見: Policy のサブクラスが base class の組織帰属チェックを上書きしている**

```ruby
# app/policies/application_policy.rb:161-163 (base class)
def operator?
  user&.has_role?("operator", organization: organization)  # org 帰属チェックあり ✓
end

# app/policies/operator_lifecycle_request_policy.rb:31-33 (subclass — OVERRIDES)
def operator?
  user.is_a?(Operator)  # 型チェックのみ — org チェックを完全に除去 ✗
end
```

さらに:

- Controller は `authorize!(OperatorLifecycleRequest)` に**クラス**を渡す（インスタンスではない）
- クラスには `organization_id` 属性がないため `ApplicationPolicy#organization` が `nil` を返す
- 結果として org コンテキストなしで policy が評価される

**ライフサイクル全体が脆弱:**

- `create?` → `operator?` (type check のみ)
- `approve?` → `operator? && pending_request? && different_operator?`
- `reject?` → `approve?`
- `execute?` → `operator? && record.approved? && different_operator?`

**攻撃パス確定:**

1. Org A の Operator が Org B の organization_id を payload に含めて
   `POST /sign/org/settings/operator_lifecycle_requests`
2. Policy: `operator?` → `user.is_a?(Operator)` → **True** → 通過
3. Service: `organization_id: attributes[:organization_id].presence` → **B の ID がそのまま保存**
4. 別の Operator C (Org C 所属) が `approve!` → `operator?` → True → **承認通過**
5. `execute!` → Org B の Operator が除名・停止・昇格される

**影響拡大:** create → approve → execute の3フェーズすべてが同じ欠陥 `operator?`
override を使用。**テナント境界の完全な突破**。

---

### GRILL-02 [High → High+] — FINDING-02 の session_version が実装されていない

**発見: `session_version` は「幽霊機能」— インクリメントしても Client モデルに列が存在しない可能性**

```ruby
# app/controllers/concerns/authentication_logout_all_sessions.rb:43-47
if resource.respond_to?(:session_version)
  resource.session_version = resource.session_version.to_i + 1
  resource.save!(validate: false)
end
```

テストが確認:

- `Client` モデルは `session_version` に `respond_to?` しない可能性がある
- `session_version` は JWT payload に含まれない (`authorization_token_claims.rb:7-35` 参照)
- `logout_all_sessions_for!`
  を呼んでも session_version が列として存在しなければ JWT バリデーションで弾けない

**パスワード変更フローの全ブランチで revocation なし:**

- `acme/app/settings/secret_credentials_controller.rb:29-54` (enrollment) —
  `logout_all_sessions_for!` 呼び出しなし
- `acme/app/settings/secret_credentials_controller.rb:61-79` (update) — なし
- `acme/app/settings/secret_credentials_controller.rb:81-91` (destroy) — なし
- サービス層 (`client_secret_credentials_create.rb`, `_update.rb`, `_destroy.rb`) — なし

**最大攻撃ウィンドウ:** | シナリオ | 継続期間 | |---------|---------| | access
token のみ窃取（refresh なし） | 最大 1 時間 | | refresh token も窃取 | 最大 14 日（session TTL） |
| ユーザーが logout しない限り | **無期限** |

---

### GRILL-03 [High] — FINDING-05 は緩和済み / FINDING-04 の実態を精査

**FINDING-05 (role downgrade) — 緩和済み:**

- JWT access token に `role` / `permission` クレームは含まれない
- `scp` は actor type 由来の静的スコープのみ (`domain:operator`, `read:org` 等)
- `authorize!` は毎リクエストで DB の現在 role を見る (`load_current_resource()` via
  `authentication_base.rb:1495-1555`)
- **role downgrade は次のリクエストで即時有効** → FINDING-05 の重大度を High → Medium に下方修正

**FINDING-04 (authorize! カバレッジ) — 実態:**

- ACME controllers: 206 action 中 48 に `authorize!` (23.3%)、SIGN: 300 action 中 11 (3.7%)
- **ただし**:
  - `BareController` 継承の public endpoint は認可不要で正当
  - `before_action :authorize_*!` パターンが 30+ 箇所で使用されており、count に含まれていない
  - `current_user.resources.find()` パターンで自己スコープされた index/show は `authorize!` が不要
- **実際の懸念**: `Resource.find(params[:id])` スタイル（ユーザースコープなし）で `authorize!`
  も before_action もない action が存在するかどうか

→
FINDING-04 は構造的 High のまま維持。ただし「raw 数値が大きい」ではなく「検知仕組みがない」が本質。

---

## 最終判定表（深掘り後更新）

| Finding    | 当初重大度 | 深掘り後      | 変化理由                                                                             |
| ---------- | ---------- | ------------- | ------------------------------------------------------------------------------------ |
| FINDING-01 | Critical   | **Critical+** | Policy override が全ライフサイクルに波及。create だけでなく approve/execute も無保護 |
| FINDING-02 | High       | **High+**     | session_version が幽霊機能の可能性。パスワード変更全フローで revocation ゼロ         |
| FINDING-04 | High       | High          | 構造的欠陥。raw 数値は過大だが仕組みのなさは本物                                     |
| FINDING-05 | High       | **Medium**    | JWT に role なし、live DB check で即時有効 → 緩和済み                                |

## 現在のステータス

**フェーズ: 深掘り Grill 完了**

今すぐ対応すべき修正:

1. FINDING-01: `OperatorLifecycleRequestPolicy#operator?` のサブクラス override を削除し、base
   class の `has_role?` を使用する
2. FINDING-02: secret credential の create/update/destroy 後に `logout_all_sessions_for!`
   を呼ぶ。`session_version` が Client モデルに存在するかどうかを確認し、なければ列を追加する
