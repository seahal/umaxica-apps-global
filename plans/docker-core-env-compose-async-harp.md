# Plan: docker/core/env を compose yaml と Rails credentials に収容する

## Context

`docker/core/env` は現在 `compose.yaml` の `env_file:` ディレクティブで `core`
サービスに注入されている単一のフラットファイル（156行）。

問題点：

- 環境変数が一箇所にまとまっているが、その内訳は「Compose インフラ構成（ホスト名・URL）」「JWT公開鍵セット」「ビルド設定」と性質がバラバラ
- `env_file:`
  は Docker/Compose の外からは不透明（compose.yaml を見ただけではコンテナが何を受け取るか分からない）
- 野良ファイルであり、変数の追加・削除が compose.yaml の `environment:` と二重管理になっている（実際
  `POSTGRESQL_USER` 等はすでに `environment:` に重複している）

目標：

- **開発に必須な変数** → `compose.yaml` の `core.environment:` ブロックにインライン化
- **プロダクションで secrets backend / Rails credentials に入るべき変数** →
  `config/credentials/development.yml.enc` へ移動
- `docker/core/env` を削除してファイル自体をパージ

## 変数の分類

### A. compose.yaml `environment:` へ移動（インフラ構成・非シークレット）

以下はすべて Compose サービス名やローカル URL など開発環境固有の値で、シークレットではない。

**Rails / サーバー設定**

- `COLORTERM`, `BRAND_NAME`, `RUBY_PATH`, `BUNDLE_PATH`
- `PORT`, `BINDING`, `OPEN_TELEMETRY`, `NODE_ENV`

**Redis / Valkey**

- `VALKEY_URL`, `RATE_LIMIT_REDIS_URL`, `REDIS_NORMAL_URL`

**PostgreSQL ルーティング**（すでに compose.yaml に `${POSTGRESQL_USER:-root}`
等があるため重複分は削除）

- `POSTGRESQL_PORT`, `POSTGRESQL_HOST`
- `POSTGRESQL_*_PUB` / `POSTGRESQL_*_SUB` 全ペア（22データベース分）

**URL ルーティング**

- `PUBLIC_*_URL`（12変数）
- `PRIVATE_*_URL`（17変数）

**その他**

- `OTEL_EXPORTER_OTLP_ENDPOINT`
- `AWS_SES_REGION`
- `VITE_RUBY_PACKAGE_MANAGER`, `VITE_RUBY_HOST`, `VITE_RUBY_PORT`, `VITE_GIT_HOOKS`

### B. `config/credentials/development.yml.enc` へ移動（鍵素材）

JWT 公開鍵セットはローカル開発用の ES384 鍵素材。大きな値で管理が難しく、credentials に収めることで
`.env` や compose.yaml から切り離せる。

```
JWT_SIGN_APP_ACTIVE_KID / JWT_SIGN_APP_PUBLIC_KEYSET
JWT_SIGN_COM_ACTIVE_KID / JWT_SIGN_COM_PUBLIC_KEYSET
JWT_SIGN_ORG_ACTIVE_KID / JWT_SIGN_ORG_PUBLIC_KEYSET
JWT_ACME_APP_ACTIVE_KID / JWT_ACME_APP_PUBLIC_KEYSET
JWT_ACME_COM_ACTIVE_KID / JWT_ACME_COM_PUBLIC_KEYSET
JWT_ACME_ORG_ACTIVE_KID / JWT_ACME_ORG_PUBLIC_KEYSET
JWT_CORE_APP_ACTIVE_KID / JWT_CORE_APP_PUBLIC_KEYSET
JWT_CORE_COM_ACTIVE_KID / JWT_CORE_COM_PUBLIC_KEYSET
JWT_CORE_ORG_ACTIVE_KID / JWT_CORE_ORG_PUBLIC_KEYSET
```

credentials の構造例（`rails credentials:edit --environment development`）：

```yaml
JWT_SIGN_APP_ACTIVE_KID: sign-app-es384-dev-a
JWT_SIGN_APP_PUBLIC_KEYSET: '[{"kty":"EC",...}]'
# ... 残り8ペア
```

**前提確認が必要**: アプリ側がこれらを `ENV.fetch("JWT_*")` で読んでいるか
`Rails.app.creds.option(:JWT_*)` で読んでいるかを事前に確認する。`ENV.fetch`
のままであれば credentials への移動と同時にアプリ側の読み取りを `Rails.app.creds.option`
に変更する必要がある。

### C. 既に compose.yaml に存在するため削除のみ

- `POSTGRESQL_USER` → `${POSTGRESQL_USER:-root}` として既存
- `POSTGRESQL_PASSWORD` → `${POSTGRESQL_PASSWORD:-development_password}` として既存
- `VITE_RUBY_HOST` / `VITE_RUBY_PORT` → `.devcontainer/compose.override.yml` に既存

## 実装手順

### Step 1: JWT 読み取りコードを確認

```bash
grep -rn "JWT_SIGN\|JWT_ACME\|JWT_CORE" app/ config/ --include="*.rb" | head -40
```

- `ENV.fetch` なら `Rails.app.creds.option` への変更も同時実施
- すでに `Rails.app.creds` 経由なら compose.yaml から削除するだけ

### Step 2: compose.yaml を更新

`core` サービスから `env_file: docker/core/env` 行を削除し、`environment:`
ブロックに分類 A の変数をすべてインライン展開する。

既存の `environment:`
ブロック（4変数）に追記する形で統合する。YAML の可読性のためにコメントでカテゴリを区切る。

### Step 3: development credentials を更新

```bash
bin/rails credentials:edit --environment development
```

分類 B の JWT 変数を追記する。アプリ側の読み取りが `ENV.fetch` の場合は同時にコード変更。

### Step 4: docker/core/env を削除

```bash
rm docker/core/env
```

### Step 5: .gitignore / .dockerignore に漏れがないか確認

`docker/core/env` がどこかで参照されていないかを確認：

```bash
grep -rn "docker/core/env" .
```

## 注意事項

- `no-silent-fallback` ルール：移動後も `ENV.fetch("NAME")`
  は引数1個のままにする（デフォルト値を足さない）。credentials 側は
  `Rails.app.creds.option(:KEY, default: nil)`
  パターンで optional に扱う場合のみデフォルトを許容する。
- `POSTGRESQL_PASSWORD` はすでに compose.yaml で `${POSTGRESQL_PASSWORD:-development_password}`
  として扱われており、ホスト `.env` から注入する設計のまま変えない。
- `REDIS_NORMAL_URL` は `Rails.app.creds.option(:REDIS_NORMAL_URL, default: ...)`
  で読まれているため、credentials に移すことも可能だが、Compose サービス名依存（`redis://valkey:...`）なので compose.yaml 側に残すのが自然。

## 検証

1. `docker compose config` で `core` サービスの環境変数が正しく展開されることを確認
2. `docker compose up core` でコンテナが起動し Rails が立ち上がることを確認
3. `bin/rails credentials:show --environment development` で JWT 鍵が読めることを確認
4. `bin/rails test` でテストスイートが通ることを確認
5. `grep -rn "docker/core/env" .` で参照が残っていないことを確認
