# core-jp.umaxica.* を Cloudflare Tunnel 経由で core BFF に到達させる計画

## Context（なぜこの変更か）

Cloudflare Tunnel の公開ホスト `core-jp.umaxica.{app,com,org}` →
`core.{tld}.localhost:3000` は疎通しているが、Rails がルーティング 404
（デバッグページ）を返す。原因はホスト名の不一致:

- core ルートの制約（`config/routes/core.rb`）は
  `ENV["PUBLIC_CORE_*_URL"]`（現在 **jpx.umaxica.***）と `core.{tld}.localhost` のみ受理
- トンネルが届ける Host は **core-jp.umaxica.***
- `development.rb` の `public_tunnel_hosts` は既に core-jp を許可済みのため、
  Host Authorization は通過してルーティングだけが落ちる（観測どおり）

ユーザー決定: 公開ホスト名は **core-jp.umaxica.* に統一**
（side-jp / palm-jp のハイフン命名規約と一致。トンネル側は変更不要）。

## 変更内容

### 1. compose.yaml の PUBLIC_CORE_*_URL（必須・3 行）

```diff
-      PUBLIC_CORE_CORPORATE_URL: jpx.umaxica.com
-      PUBLIC_CORE_SERVICE_URL: jpx.umaxica.app
-      PUBLIC_CORE_STAFF_URL: jpx.umaxica.org
+      PUBLIC_CORE_CORPORATE_URL: core-jp.umaxica.com
+      PUBLIC_CORE_SERVICE_URL: core-jp.umaxica.app
+      PUBLIC_CORE_STAFF_URL: core-jp.umaxica.org
```

これで routes の constraint（`ENV["PUBLIC_CORE_*_URL"] || …`）と
development.rb の `env_hosts`（PUBLIC_CORE_* は `env_host_keys` に含まれる）が
自動的に core-jp を受理する。

### 2. compose.yaml の frontend alias 整理（任意）

`jpx.umaxica.{app,com,org}`（220-222 行）は origin として未使用になるので削除推奨。
`core-jp.umaxica.*` alias（217-219 行）は登録済みで変更不要。

### 3. スコープ外（後続タスクとしてメモ）

- `config/environments/production.rb` 158-160 行の `jpx.umaxica.*`:
  本番の公開名を core-jp に揃える際に追従（本番 DNS/デプロイと同期が必要なので別作業）
- `core_{app,com,org}_*_bridges` テーブルの `host` デフォルト
  （`jpx.umaxica.*`）と `audience`: core の OIDC ブリッジ検証に関わるため、
  命名統一の後続プランで扱う

## 適用手順

1. `compose.yaml` を編集（上記 1、任意で 2）
2. env は**コンテナ再作成でしか反映されない**ため、ホスト側で
   `podman compose up -d core` を実行（devcontainer 内からは不可。
   devcontainer ごと再起動でも可）
3. コンテナ再作成後、Rails（puma）を起動し直す

## 検証

1. コンテナ内で routes が新ホストを認識すること:

   ```sh
   bin/rails runner '
     %w(core-jp.umaxica.app core-jp.umaxica.com core-jp.umaxica.org).each do |h|
       r = Rails.application.routes.recognize_path("http://#{h}/", method: :get)
       puts "#{h} -> #{r[:controller]}##{r[:action]}"
     end'
   ```

   `core/{app,com,org}/roots#index`（core 系コントローラ）が返ること。

2. ブラウザで `https://core-jp.umaxica.{app,com,org}` にアクセスし、
   core BFF のページが表示されること。`log/development.log` に
   `Core::…Controller` の Processing 行が出ること。

3. 既存の www / auth 系ホストが回帰していないこと（ブラウザで再確認）。

4. ルート契約テスト: `bin/rails test test/integration/routes/`
