# Grill Me: RP コールバックが Acme アクタートークンを発行してはならない

調査日: 2026-06-24

---

## 1. Executive Summary

**Confirmed**: `OidcTokenExchangeService#create_token_record!`
は OIDC トークンエンドポイント処理中に Acme アクターセッショントークン（`ClientToken`/`OperatorToken`/`VisitorToken`）を発行している。

これは想定された「グローバルリボケーション/セッションルート」モデルに違反する。

- 同一 `Client` に対してサインイン完了時とRP コールバック時で **別々の `ClientToken` 行**
  が生成される
- 両方とも同一セッション制限プールに計上される
- ブラウザセッションの `ClientToken` を無効化しても、RP 由来の `ClientToken` は有効のまま残る
- 逆もしかり

---

## 2. Current Behavior

### トークン発行の2つのパス

| パス                                 | エントリポイント                                     | 最終メソッド                                                | 作成されるモデル                           | セッション制限ゲートを通過するか      |
| ------------------------------------ | ---------------------------------------------------- | ----------------------------------------------------------- | ------------------------------------------ | ------------------------------------- |
| **ブラウザインタラクティブログイン** | `AuthenticationBase#log_in`                          | `create_login_token_record` (authentication_base.rb:1929)   | ClientToken / OperatorToken / VisitorToken | Yes（`with_actor_session_lock` 経由） |
| **OIDC トークンエンドポイント**      | `OidcTokenExchangeService#consume_and_issue_tokens!` | `create_token_record!` (oidc_token_exchange_service.rb:222) | ClientToken / OperatorToken / VisitorToken | No（直接 `.create!` を呼ぶ）          |

### サインアップ + OIDC フロー（numbered sequence）

```
1. ユーザーがメールサインアップ完了
   → sign_up_sequence_controller_support.rb: handoff_to_sign_in_flow!
   → establish_signed_in_session! (bootstrap_actor: true)
   → create_login_token_record
   → ClientToken A 作成（oidc_* フィールドは空）

2. RP がユーザーを Acme 認可エンドポイントへリダイレクト
   → ユーザーはすでにログイン済み（ClientToken A が cookie）
   → Acme が ClientAuthorizationCode を発行

3. RP バックエンドが Acme トークンエンドポイントを呼ぶ
   → AcmeOauthTokenEndpoint → OidcTokenExchangeService
   → authorization_code.consume!
   → OidcConnectionRecorder.call（OidcConnection 作成/更新）
   → create_token_record!
   → ClientToken B 作成（oidc_sid, oidc_jti, oidc_client_id, oidc_connection_id が設定される）
   → refresh token, access token, ID token を返す

4. ClientToken A（ブラウザセッション）と ClientToken B（RP セッション）が共存
   → どちらも ClientToken::MAX_TOTAL_SESSIONS_PER_USER = 3 にカウントされる
```

### OidcCallback（Acme が RP として外部 IdP を使う場合）

```
外部IdPコールバック
  → oidc_callback.rb: log_in(bootstrap_actor: true)
  → create_login_token_record
  → ClientToken C 作成（後で bind_oidc_logout_session が oidc_sid をセット）
```

これは **Acme が IdP** の場合（Path 2）とは別フロー。`OidcCallback`
は正しくブラウザセッション作成パスを使う。

### コード証拠

**`OidcTokenExchangeService#create_token_record!`** (oidc_token_exchange_service.rb:252-259):

```ruby
ClientToken.create!(
  user: resource,
  public_id: SecureRandom.alphanumeric(21),
  discarded_at: SecurityTokenLifetimes::CLIENT_REFRESH_TOKEN_TTL.from_now,
  user_token_status_id: ClientTokenStatus::ACTIVE,
  dpop_jkt: dpop_jkt,
  **oidc_attrs,   # oidc_connection_id, oidc_client_id, oidc_scope, oidc_sid, oidc_jti
)
```

既存の Acme アクターセッションへの参照なし。`resource` は Client モデルのみ。

**セッション制限カウント** (client_token.rb):

```ruby
MAX_SESSIONS_PER_USER = 2
MAX_TOTAL_SESSIONS_PER_USER = 3  # 2 active + 1 restricted

# active_status scope がカウント対象
# oidc_* フィールドの有無でフィルタリングしない
```

---

## 3. Intended Contract

ドキュメント・ADR から明示的な仕様は見つからなかった（No documentation found）。

**コードと構造から推定される想定コントラクト:**

- `ClientToken` は Acme アクターセッションのルート（ブラウザ/デバイスごとに1つ）
- OIDC フィールド（`oidc_sid`, `oidc_client_id` 等）は後付けでセットされるバインディングメタデータ
- RP との接続記録は `OidcConnection` テーブルが担う
- `ClientToken` 1行 = 1セッションルート

`OidcCallback` concern（外部 IdP からのコールバック）はこのコントラクトに従っている: `log_in` →
`create_login_token_record` → 既存ゲートを通る。

`OidcTokenExchangeService`（Acme が IdP として RP へトークン発行する場合）はこのコントラクトに違反している。

---

## 4. Contract Violations

### Violation 1: RP トークンエンドポイントがアクターセッショントークンを新規発行する

```
Violation: OidcTokenExchangeService#create_token_record! が ClientToken/OperatorToken/VisitorToken を
           新規作成する。これらは Acme アクターセッションのルートである。
Evidence:  oidc_token_exchange_service.rb:222-261
           ClientToken.create! を直接呼ぶ。既存セッションへの参照なし。
Why it matters: RP アクセスごとにアクタートークンが増殖し、セッション制限を圧迫する。
                ブラウザセッション無効化が RP セッションに伝播しない。
Likely fix: create_token_record! は OidcConnection とRP向けアーティファクトのみ作成し、
            既存の ClientToken（セッションルート）を参照する形に変更する。
```

### Violation 2: セッション制限が RP バウンドトークンをブラウザセッションと同列に扱う

```
Violation: ClientToken::MAX_TOTAL_SESSIONS_PER_USER = 3 は RP トークンも
           ブラウザセッションも区別しない。
Evidence:  client_token.rb: enforce_concurrent_session_limit
           active_status scope に oidc_client_id フィルタなし
Why it matters: ブラウザ2セッション + RP1つ でセッション制限に達し、
                ユーザーがログインできなくなる。
Likely fix: セッション制限カウントから OIDC バウンドトークンを除外するか、
            RP バウンドトークンを別モデルに分離する。
```

### Violation 3: リボケーションがグローバルに伝播しない

```
Violation: ClientToken A（ブラウザセッション）を revoke! しても
           ClientToken B（RP バウンド）は有効のまま。
Evidence:  token_status_management.rb: revoke! は自身の status と discarded_at のみ更新
           authentication_logout_current_session.rb: DeviceSession 経由で同デバイス
           の token のみカスケード。RP バウンドトークンへの参照なし。
Why it matters: ユーザーがセッションを削除しても RP へのアクセスが残存する。
                セキュリティ要件「1つのアクターセッションルートがすべての派生 RP アクセスを制御」に違反。
Likely fix: RP 向けアーティファクトが ClientToken 外部キーを持つことで、
            ClientToken 無効化時に CASCADE または アプリレベルで RP セッションを無効化できる。
```

### Violation 4: コールバックリトライの冪等性が不完全

```
Violation: authorization_code.consumed? チェックは同一コードの2回実行を防ぐが、
           新しい認可コードを使ったリトライは新規 ClientToken を作成する。
Evidence:  oidc_token_exchange_service.rb:113: consumed? チェックあり
           oidc_token_exchange_service.rb:155: OidcConnectionRecorder → create_token_record!
           OidcConnectionRecorder は upsert 的に動作する可能性があるが
           create_token_record! には既存トークン確認ロジックなし。
Why it matters: RP フレームワークがリトライした場合、同一ユーザー・同一 RP で
                複数の ClientToken が生成される。
Likely fix: create_token_record! 実行前に既存の oidc_connection 関連トークンを確認し、
            存在すれば再利用する。
```

---

## 5. Risk Analysis

| リスク                       | 深刻度 | 現状                                                  |
| ---------------------------- | ------ | ----------------------------------------------------- |
| 偽の同時セッション制限失敗   | 高     | MAX=3 のうち RP 分が消費される                        |
| グローバルリボケーション不能 | 高     | RP バウンドトークンが独立した認証ルートになる         |
| 重複トークン行               | 中     | リトライ時に発生しうる                                |
| コールバックリトライ非冪等   | 中     | 同一コード再利用は防止。新コードは防止しない          |
| トークン概念の混同           | 高     | ClientToken = アクターセッション AND RP セッション    |
| セキュリティ境界混同         | 高     | Acme 内部セッショントークン ≠ OIDC プロトコルトークン |

---

## 6. Recommended Fix Direction

### A（推奨優先）: RP コールバックは既存 Acme アクタートークンを参照し、RP スコープアーティファクトのみ作成する

`OidcTokenExchangeService` が `ClientToken`/`OperatorToken`/`VisitorToken` を新規作成する代わりに:

1. 認可コードに紐づく既存 Acme セッションを特定する
   - `ClientAuthorizationCode` → 作成時点でユーザーがログイン済みなので、セッション情報を埋め込む
2. `OidcConnection` レコードをその既存トークンに外部キーで紐付ける
3. OIDC プロトコル向けトークン（access_token, id_token, refresh_token）は `ClientToken`
   行ではなく別の RP アーティファクトモデルから発行する

### B: `create_token_record!` の責務を分離する

現在 `create_token_record!`
は「アクターセッショントークン作成」と「OIDC プロトコルトークン発行」を混同している。メソッドを分割:

- `find_or_bind_actor_token!` — 既存アクタートークンを検索・参照
- `issue_oidc_rp_artifacts!` — RP 向けアーティファクトのみ作成

### C: 認可コードに発行時のセッション情報を持たせる

`ClientAuthorizationCode` 作成時点で
`client_token_id`（外部キー）を記録し、トークンエンドポイントでそれを参照することで既存セッションルートを取得する。これが最も明確な設計変更。

### D: コントラクトを ADR/docs に明文化する（即時実施可能）

実装変更の前に、以下を定義する:

- `ClientToken` の責務は「Acme アクターセッションルート」である
- `ClientToken` は RP ごとに複数作成してはならない
- OIDC RP 向けセッション/接続は `OidcConnection` とその派生モデルに持つ

---

## 7. Tests To Add

```ruby
# サインアップで ClientToken が1つだけ作成される
test "signup creates exactly one ClientToken" do
  # email OTP → 生年月日 → finalize
  # ClientToken.where(user_id: client.id).count == 1
end

# RP コールバックが新規 Acme アクタートークンを作成しない
test "OIDC token endpoint does not create additional ClientToken when actor session exists" do
  # ログイン済み状態で authorize → code 取得 → token endpoint
  # ClientToken.where(user_id: client.id).count == 1  # 変化なし
end

# コールバックリトライで重複トークンが作成されない
test "OIDC token endpoint is idempotent for the same authorization session" do
  # 異なる code で2回 token endpoint を呼ぶ
  # ClientToken.where(user_id: client.id).count == 1  # 増えない
end

# Acme アクタートークン無効化で RP アクセスが失効する
test "revoking actor token invalidates all derived RP access" do
  # ClientToken を revoke → RP への以降のリクエストが 401
end

# セッション制限が RP コールバックリトライで消費されない
test "concurrent session limit is not consumed by RP callback retries" do
  # RP を N 回使っても session_limit ではじかれない
end

# ClientToken/OperatorToken/VisitorToken が同じコントラクトに従う
test "OperatorToken and VisitorToken follow the same actor-session-root contract" do
  # OperatorToken / VisitorToken でも同上
end
```

---

## 8. Token Glossary（概念整理）

| 用語                      | 型                                               | 役割                       | 混同リスク                            |
| ------------------------- | ------------------------------------------------ | -------------------------- | ------------------------------------- |
| Acme アクタートークン     | `ClientToken` / `OperatorToken` / `VisitorToken` | グローバルセッションルート | **これが問題の核心**                  |
| OIDC 認可コード           | `ClientAuthorizationCode`                        | 短命、1回限り使用          | create_token_record! の引き金         |
| OIDC アクセストークン     | JWT (encoded)                                    | RP が API 呼び出しに使う   | ClientToken とは別物                  |
| OIDC ID トークン          | JWT (encoded)                                    | RP がユーザー情報を取得    | ClientToken とは別物                  |
| OIDC リフレッシュトークン | digest (ClientToken.refresh_token_digest)        | アクセストークン再発行     | ClientToken に格納されている          |
| OidcConnection            | `OidcConnection`                                 | ユーザー × RP 接続記録     | RP スコープアーティファクトとして適切 |
| RP ローカルセッション     | RP 側で管理                                      | Acme とは独立              | Acme 管理外                           |

---

## 9. Critical Files

| ファイル                                                            | 役割                                      |
| ------------------------------------------------------------------- | ----------------------------------------- |
| `app/services/oidc_token_exchange_service.rb`                       | 問題の核心: create_token_record!          |
| `app/controllers/concerns/authentication_base.rb`                   | create_login_token_record（正規パス）     |
| `app/models/client_token.rb`                                        | セッション制限定義、OIDC フィールド       |
| `app/models/client_authorization_code.rb`                           | consumed? チェック                        |
| `app/controllers/concerns/oidc_callback.rb`                         | 外部 IdP コールバック（正しいパスを使う） |
| `app/models/concerns/token_status_management.rb`                    | revoke! の実装                            |
| `app/controllers/concerns/authentication_logout_current_session.rb` | リボケーションカスケード                  |

---

## 10. Verification

調査で用いた方法:

- `ClientToken.create`, `OperatorToken.create`, `VisitorToken.create` の全出現箇所 grep
- `OidcTokenExchangeService` ソース全体精読
- `AuthenticationBase#create_login_token_record` ソース精読
- `ClientToken` モデル（スキーマ、バリデーション、スコープ）精読
- `token_status_management.rb#revoke!` 精読
- `authentication_logout_current_session.rb` カスケード挙動精読
- `sign_up_sequence_controller_support.rb` サインアップ完了フロー精読

**未確認事項（証拠なし）:**

- `OidcConnectionRecorder.call` の内部実装（upsert か否か）
- `ClientAuthorizationCode` が発行時点のセッション情報を持つか否か
- RP フレームワーク（Doorkeeper 等）がリトライ時に新規 code を発行するか否か
- 実際のログ・本番データでの重複トークン発生頻度

これらは次の調査フェーズで確認が必要。
