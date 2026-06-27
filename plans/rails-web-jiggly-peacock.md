# サブシステムリネーム設計レビュー

提案: `sign→auth`, `acme→base`, `base→side`, `info→info`

---

## 判定：**却下**（3件すべてに即死・長期破壊リスクが存在する）

---

## 最も危険な問題 TOP 3

### 危険度 S：`sign → auth` — 起動時クラッシュ確定

`Sign::App::Auth::OmniauthCallbacksController`、`Sign::Com::Auth::LogoutsController`、`Sign::Org::Auth::LogoutsController`
が実在する（`app/controllers/sign/app/auth/`、`sign/com/auth/`、`sign/org/auth/` の3ディレクトリ）。

リネーム後のファイルパスは `app/controllers/auth/app/auth/omniauth_callbacks_controller.rb`
になり、Zeitwerk は `Auth::App::Auth::OmniauthCallbacksController`
を要求する。Ruby の定数探索において内側の `Auth` モジュールが外側を隠蔽し、初回オートロードで
`NameError` またはミスロードが発生する。 **Phase 0 として `sign/*/auth/`
サブディレクトリを先に別名に移動しない限り `sign → auth` は着手不可。**

### 危険度 S：`acme → base` — 発行済み JWT の `iss` クレームを永続破壊

`JitSecurityJwtRegistry::SURFACE_ISSUER_ORIGINS` により:

```
ACME_APP => "https://www.umaxica.app"
ACME_COM => "https://www.umaxica.com"
ACME_ORG => "https://www.umaxica.org"
```

これらの値は `OidcIssuer.for_resource_type` 経由で JWT の `iss`
クレームに埋め込まれ、すでに発行済みである。RFC 7519 §4.1.1 および RFC 8414
§2 は issuer 値の変更を禁じている。ホスト名を変えた瞬間、全 RP のトークン検証が即座に失敗する。

さらに `identity_*_ceremony_contract.rb` の `acme_issuer_id` が生成する `"surface:ACME_APP"`
等の文字列が `client_identities.issuer`、`visitor_identities.issuer`、`security_consumed_jti.issuer`
カラムに DB 保存済みである。コードが `"surface:BASE_APP"`
を生成し始めると既存レコードとの突合が失敗し、JTI 二重消費チェックが壊れる（セキュリティ劣化）。
**データマイグレーションなしでの `acme → base` は不可。**

### 危険度 A：`base → side` — インフラ全体の同期変更が必要

`JitSecurityJwtRegistry::SURFACE_NAMESPACES` と `SURFACE_ISSUER_ORIGINS` に
`BASE_APP`/`BASE_COM`/`BASE_ORG` がある。 `oidc_client_stores_static_client_store.rb` の
`build_redirect_uris`/`build_post_logout_redirect_uris` が
`BASE_SERVICE_URL`/`BASE_STAFF_URL`/`BASE_CORPORATE_URL`
をハードコード参照している。コード変更と Kubernetes/Terraform の環境変数変更が同タイミングで届かないと起動時にリダイレクト URI が空になり OAuth フロー全体が
`redirect_uri_mismatch` で停止する。

---

## Per-rename 辛口評価

### `sign → auth`：**却下（前提条件未充足）**

- `auth` は既に `Sign` 内部のサブモジュール名として実在する。トップレベルを `Auth` にすると
  `Auth::App::Auth::*` という二重構造が発生し、起動時クラッシュが確定する。
- `config/sign_route_mapper.rb`（`SignRouteMapper` モジュール、5 マクロ）と
  `config/routes/sign.rb`（537行）の変更量が膨大。
- i18n の `sign:` トップキーを `auth:` に変えると、4 ロケールファイル × 3000〜3700行の `t()`
  呼び出し全件と同期変更が必要。翻訳キー欠損は Rails が `"translation missing: ..."`
  を返すだけでエラーにならないためテストで検出しにくい。
- `SIGN_APP`/`SIGN_COM`/`SIGN_ORG`
  の JWT 鍵名前空間文字列を変えると鍵ストアとの参照が切れ、署名検証が全件失敗する。

### `acme → base`：**却下（issuer 永続性問題が解決不可能に近い）**

- 発行済みトークンの `iss`
  は変えられない。二重 issuer 運用（旧 URL の互換レイヤー）が最低でも全トークン有効期限分（14日 + バッファ）必要。
- `surface:ACME_APP` という文字列が DB に焼き込まれており、`UPDATE`
  マイグレーションなしでは既存ユーザーのソーシャルログイン連携と JTI 管理が同時に壊れる。
- `acme/app/auth/` が現在 `Base::App::Auth` と衝突するため（現 `base/` に `auth/`
  サブディレクトリが存在する）、`acme → base` の前に `base → side`
  が完了している必要がある。依存関係が複雑化している。
- 「`BASE` が identity/account/organization 基盤の名前」という点は実態を示しているが、OIDC の issuer
  authority であることを隠蔽する。長期的には誤解を生む。

### `base → side`：**条件付き検討可（単体ならリスク最小）**

- `base` サービスはホスト名ベースルーティングのためユーザー向け URL に `base`
  文字列は露出しない。ユーザー混乱問題は実際には存在しない。
- `side`
  という名前に設計上の耐久性がない。「サイド」は何のサイドなのかが不明。新規参入エンジニアには意味不明。
- インフラ同期さえ取れれば技術的実現性は最も高い。ただし名前の改善度が低い。

### `info → info`：**承認（変更なし）**

---

## 影響チェックリスト

### コントローラ（896ファイル）

- [ ] `app/controllers/sign/`（推定 280ファイル）— `module Sign` 宣言全件書き換え
- [ ] `app/controllers/acme/`（推定 200ファイル）— `module Acme` 宣言全件書き換え
- [ ] `app/controllers/base/`（推定 30ファイル）— `module Base` 宣言全件書き換え
- [ ] `app/controllers/concerns/sign_*.rb`（13ファイル以上）— ファイル名・モジュール名変更
- [ ] `app/controllers/concerns/acme_*.rb` — 同上

### ルーティング

- [ ] `config/routes/sign.rb`（537行）→ `auth.rb`
- [ ] `config/routes/acme.rb`（633行）→ `base.rb`
- [ ] `config/routes/base.rb`（156行）→ `side.rb`
- [ ] `config/sign_route_mapper.rb` → `auth_route_mapper.rb`（モジュール名 + 5マクロ名変更）
- [ ] `config/routes.rb`（`require_relative` パスと `draw` 呼び出し変更）

### i18n（4ファイル × 3000〜3700行）

- [ ] `sign:` トップキー → `auth:` + 全ビューの `t("sign.*.*.xxx")` 呼び出し
- [ ] `acme:` トップキー → `base:` + 同上
- [ ] `base:` トップキー → `side:` + 同上
- [ ] **ユーザー向け表示名は内部名前空間と分離すること**（`t("auth.sessions.new.title")`
      の値が「Auth」ではなく「ログイン」になっているか確認）
- [ ] i18n missing key CI チェックの追加（`i18n-tasks` 等）

### config / 環境変数 / インフラ

- [ ] `SIGN_SERVICE_URL`, `SIGN_STAFF_URL`, `SIGN_CORPORATE_URL`
- [ ] `ACME_SERVICE_URL`, `ACME_STAFF_URL`, `ACME_CORPORATE_URL`
- [ ] `BASE_SERVICE_URL`, `BASE_STAFF_URL`, `BASE_CORPORATE_URL`
- [ ] `WEBAUTHN_APP_RP_ID`, `WEBAUTHN_COM_RP_ID`,
      `WEBAUTHN_ORG_RP_ID`（ホスト名変更なければ値は不変。変数名のみ変更）
- [ ] `JitSecurityJwtRegistry::SURFACE_NAMESPACES` の定数キー
- [ ] `JitSecurityJwtRegistry::SURFACE_ISSUER_ORIGINS` の定数キー（URL 値は変えない）
- [ ] `OidcIssuer` の `boot_config` キー参照（`acme_service` → `base_service` 等）
- [ ] `oidc_client_stores_static_client_store.rb` の環境変数参照
- [ ] CSP initializer の `acme`/`sign` ホスト参照
- [ ] CORS origin 設定

### テスト（261ファイル）

- [ ] `test/integration/routes/sign_route_contract_test.rb`
- [ ] `test/integration/routes/acme_route_contract_test.rb`
- [ ] `test/integration/routes/base_route_contract_test.rb`
- [ ] `test/integration/routes/oidc_discovery_route_stability_test.rb`（issuer URL に依存）
- [ ] 全 `Sign::`, `Acme::`, `::Base::` 参照 261件
- [ ] passkey フロー E2E（RP ID 変更がない前提で回帰確認）
- [ ] OAuth callback フロー
- [ ] OIDC discovery エンドポイント URL の安定性テスト
- [ ] 旧 URL 互換 redirect テスト

### OAuth/OIDC / 認証系

- [ ] **issuer URL は変えない**（コードの名前空間だけ変える）
- [ ] `.well-known/openid-configuration` の `issuer` フィールドが旧値のまま返ることを確認
- [ ] JWKS エンドポイント URL が不変であることを確認
- [ ] `surface:ACME_APP` issuer ID の DB データマイグレーション計画（`acme → base` の場合）
- [ ] 全 RP への変更通知と再設定期間の設定
- [ ] passkey RP ID 不変確認
- [ ] TOTP / step-up / recovery code の導線を回帰テスト

---

## 推奨 Rails リファクタ方針

### 絶対原則

1. **issuer URL（ホスト名）は変えない。コード内名前空間だけを変える。** 外部公開 issuer
   URL・`.well-known` エンドポイント URL・JWKS URL は移行中も不変。 `SURFACE_ISSUER_ORIGINS`
   の URL 値はそのまま維持し、定数キー名だけを新名前に変える。

2. **旧環境変数と新環境変数を移行完了まで並存させる。**
   コードが新名を使うようになった後も、Kubernetes の旧変数名を即座に削除しない。デプロイローリング中に旧コードが参照する可能性がある。

3. **i18n キーと表示文言を分離する。** 内部名前空間が `auth`
   になっても、`t("auth.sessions.new.title")`
   の値は「ログイン」にする。ユーザー向け画面に「Auth」「Base」「Side」という内部名が表示されてはならない。

4. **各リネームは独立したプルリクエストとして実施する。**
   4つを同時に実施するとレビュー不可能な変更規模になる。

### Phase 0（前提条件）：`sign/*/auth/` サブモジュールの事前移動

`sign → auth` 着手前に必須。

```
app/controllers/sign/app/auth/omniauth_callbacks_controller.rb
  → app/controllers/sign/app/social_callbacks/omniauth_callbacks_controller.rb
app/controllers/sign/com/auth/logouts_controller.rb
  → app/controllers/sign/com/session/logouts_controller.rb
app/controllers/sign/org/auth/logouts_controller.rb
  → app/controllers/sign/org/session/logouts_controller.rb
```

対応するルートの `module :auth` スコープも同時に更新。テストグリーンを確認してからマージ。

### Phase 1（最小リスク）：`base → ctrl`（または `base → side`）

コードのみ変更（ホスト名・issuer URL は不変）。

```ruby
# JitSecurityJwtRegistry
SURFACE_NAMESPACES = {
  ctrl_app: "CTRL_APP",  # 旧: base_app: "BASE_APP"
  ...
}
```

環境変数はインフラ側に `CTRL_SERVICE_URL` を追加し、旧 `BASE_SERVICE_URL` は移行完了まで並存。

### Phase 2：`sign → auth`（Phase 0 完了後）

`config/sign_route_mapper.rb` → `config/auth_route_mapper.rb` `SignRouteMapper` → `AuthRouteMapper`
マクロ名 `sign_routes` → `auth_routes`（`config/routes/auth.rb` 全体で呼び出し変更）

JWT 鍵名前空間は移行期間中 `SIGN_APP` と `AUTH_APP` を並存させ、新規発行を `AUTH_APP` で行いつつ旧
`SIGN_APP` で検証できる期間を設ける（発行済みトークン最大有効期限 + バッファ）。

### Phase 3：`acme → base`（Phase 1 完了後、issuer 移行計画と連動）

3a. 旧 issuer URL の互換検証レイヤーを追加（旧 `iss`
を持つトークンも検証通過させる）3b. コード側リネーム + DB の `surface:ACME_*` → `surface:BASE_*`
UPDATE マイグレーション 3c. 全 RP 移行確認後、互換レイヤーを除去

### Phase 4：JWT 鍵名前空間の旧名廃止

移行前に発行された全トークンが期限切れになった後（最大有効期限 14日 + バッファ）に旧名前空間キーを削除。

### Phase 5：旧環境変数・インフラ設定の廃止

モニタリングで旧変数参照がゼロであることを確認してから Kubernetes/Terraform から削除。

---

## 代替 4 文字ネーミング案

### 案 A：`gate` / `idop` / `ctrl` / `info`（推奨）

| 旧     | 新     | 根拠                                                                                           |
| ------ | ------ | ---------------------------------------------------------------------------------------------- |
| `sign` | `gate` | credential gateway = ゲートウェイ。`Gate::App::Auth` で内側 `auth` サブモジュールと衝突なし    |
| `acme` | `idop` | Identity Operator（ID発行局）。OIDC AS としての役割を名前に含む。Ruby/gem 名前空間に存在しない |
| `base` | `ctrl` | control-plane の略。意図が明確                                                                 |
| `info` | `info` | 変更なし                                                                                       |

### 案 B：`cred` / `iden` / `ctrl` / `info`

| 旧     | 新     | 根拠                                          |
| ------ | ------ | --------------------------------------------- |
| `sign` | `cred` | credential の略。`Cred::App::Auth` で衝突なし |
| `acme` | `iden` | identity + authorization server の略          |
| `base` | `ctrl` | 同上                                          |
| `info` | `info` | 変更なし                                      |

### 案 C：`sign` / `acme` / `ctrl` / `info`（最小変更・最推奨）

| 旧     | 新     | 根拠                                                                                          |
| ------ | ------ | --------------------------------------------------------------------------------------------- |
| `sign` | `sign` | 変更なし。「sign in/out」として意味明快。衝突解消なしでのリネームはコストが便益を大幅に上回る |
| `acme` | `acme` | 変更なし。issuer 破壊リスクに見合う便益がない                                                 |
| `base` | `ctrl` | この1件だけ改善。OIDC 的影響が軽微で名前の改善効果が最も明確                                  |
| `info` | `info` | 変更なし                                                                                      |

**現実解として案 C を強く推奨する。** `base → ctrl`
の1件だけを最初に実施し、運用安定性を確認してから次のリネームの是非を判断する。

---

## 検証方法

```bash
# 全ルート契約テスト
bin/rails test test/integration/routes/

# OIDC discovery 安定性テスト
bin/rails test test/integration/routes/oidc_discovery_route_stability_test.rb

# 全ロケールキー欠損チェック（i18n-tasks がある場合）
bundle exec i18n-tasks missing

# passkey フロー回帰
bin/rails test test/system/passkey/

# 全体
bin/rails test
```

---

## 関連ファイル

- `lib/jit_security_jwt_registry.rb` — JWT 鍵名前空間・issuer origin の定義元
- `app/values/oidc_issuer.rb` — issuer URL の組み立てロジック
- `config/sign_route_mapper.rb` — sign 用ルートマクロ定義
- `app/values/oidc_client_stores_static_client_store.rb` — redirect URI 組み立て・環境変数参照
- `app/controllers/sign/app/auth/omniauth_callbacks_controller.rb` — Phase 0 の移動対象
- `app/controllers/sign/com/auth/logouts_controller.rb` — Phase 0 の移動対象
- `app/controllers/sign/org/auth/logouts_controller.rb` — Phase 0 の移動対象
