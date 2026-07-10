# Cloudflare Tunnel ingress を公開向けに整合させる計画

## Context（なぜこの変更か）

`id.umaxica.app` 等を Cloudflare Tunnel 経由で外部公開する整備の続編。

フェーズ 1（前回のコミット）で以下を完了済み:

- 廃止された `post.*` origin を `base.{tld}.localhost` / `palm.app.localhost`
  に修正（Cloudflare 側）
- `config/routes/*.rb` の `constraints host:` を `[ENV[...], "<surface>.<tld>.localhost"]`
  の 2 要素に統一
- `compose.yaml` の frontend.aliases に `base.{app,com,org}.localhost` と `palm.app.localhost`
  を追加
- `docker/core/env` の `BASE_*` を `base.jp.umaxica.{app,com,org}`（ピリオド形）に更新

ユーザーが Cloudflare ダッシュボードを更新した結果、現在の公開ホスト → origin マッピングは:

| 公開ホスト                      | origin                             | 状態            |
| ------------------------------- | ---------------------------------- | --------------- |
| `id.umaxica.{app,com,org}`      | `http://id.{tld}.localhost:3000`   | OK              |
| `www.umaxica.{app,com,org}`     | `http://www.{tld}.localhost:3000`  | OK              |
| `www-jp.umaxica.{app,com,org}`  | `http://core.{tld}.localhost:3000` | OK              |
| `base-jp.umaxica.{app,com,org}` | `http://base.{tld}.localhost:3000` | ❌ ENV と不一致 |
| `palm-jp.umaxica.app`           | `http://palm.app.localhost:3000`   | ❌ ENV と不一致 |

**ユーザーは公開ホスト名のハイフン形（`base-jp.*`/`palm-jp.*`）を維持する判断**を行った。これは
`www-jp.*` と表記を統一する一貫した方針で、ピリオド形改名（前回プランの推奨）よりも合理的。

しかしフェーズ 1 で `docker/core/env` の `BASE_*` および `config/application.rb` の
`PALM_SERVICE_URL` 既定値はピリオド形のままになっており、

- Cloudflare が `Host: base-jp.umaxica.app` を保持して origin に送る
- Rails routes は `ENV["BASE_SERVICE_URL"]=base.jp.umaxica.app`（ピリオド）または
  `base.app.localhost` のみ受理
- → どちらにも一致せず 404

という不整合が `base-jp.*` と `palm-jp.*` で発生する。この食い違いを解消する。

## 命名規約の確定

公開ホスト名の `jp` 修飾は **すべてハイフン形** で統一する:

| サーフェス  | 公開ホスト名                    |
| ----------- | ------------------------------- |
| Sign        | `id.umaxica.{app,com,org}`      |
| Acme        | `www.umaxica.{app,com,org}`     |
| Core BFF    | `www-jp.umaxica.{app,com,org}`  |
| Base 管制   | `base-jp.umaxica.{app,com,org}` |
| Palm Native | `palm-jp.umaxica.app`           |

ローカル受理ホスト（`<surface>.<tld>.localhost`）はフェーズ 1 で確定済み（変更なし）。

## 変更内容

### 1. `docker/core/env` の `BASE_*` をハイフン形に戻す

```diff
-BASE_CORPORATE_URL=base.jp.umaxica.com
-BASE_SERVICE_URL=base.jp.umaxica.app
-BASE_STAFF_URL=base.jp.umaxica.org
+BASE_CORPORATE_URL=base-jp.umaxica.com
+BASE_SERVICE_URL=base-jp.umaxica.app
+BASE_STAFF_URL=base-jp.umaxica.org
```

`PALM_*` も同様にハイフン形に揃える:

```diff
-PALM_CORPORATE_URL=palm.jp.umaxica.com
-PALM_SERVICE_URL=palm.jp.umaxica.app
-PALM_STAFF_URL=palm.jp.umaxica.org
+PALM_CORPORATE_URL=palm-jp.umaxica.com
+PALM_SERVICE_URL=palm-jp.umaxica.app
+PALM_STAFF_URL=palm-jp.umaxica.org
```

### 2. `config/application.rb` の `PALM_SERVICE_URL` 既定値をハイフン形に

唯一既定値がピリオド形（`palm.jp.umaxica.app`）になっており、ローカル名・公開名のどちらのパターンとも整合しない。ハイフン形に揃える:

```diff
-      "PALM_SERVICE_URL" => "palm.jp.umaxica.app",
+      "PALM_SERVICE_URL" => "palm-jp.umaxica.app",
```

他の `*_SERVICE_URL` の既定値はローカル開発向けの `<surface>.<tld>.localhost`
形のままである（`base.app.localhost`, `core.app.localhost`
等）。Palm だけ既定値が公開ホストになっているのは元コードの異常値だが、PALM のテストがこの既定値に依存しているため、今回は形式だけハイフンに揃え、後続プランで他サーフェスと同じ
`palm.app.localhost` に統一する余地を残す。

### 3. テストのハードコード参照を追従

#### 3-1. `test/integration/routes/palm_route_contract_test.rb`

`palm.jp.umaxica.app` を直接受理パスとして検証する重複テストを削除（フェーズ 1 で
`base_route_contract_test.rb` から PUBLIC_BASE_HOSTS を削除したのと同じ整理）:

```diff
-  test "palm public host alias routes to app surface" do
-    recognized = Rails.application.routes.recognize_path(
-      "http://palm.jp.umaxica.app/",
-      method: :get,
-    )
-
-    assert_equal "palm/app/roots", recognized[:controller]
-    assert_equal "index", recognized[:action]
-  end
```

`PALM_HOST` は `ENV.fetch("PALM_SERVICE_URL", "palm.app.localhost")`
のままで OK（fallback が新既定値と整合）。

#### 3-2. テストの ENV.fetch fallback 参照を更新

以下のファイルで `ENV.fetch("PALM_SERVICE_URL", "palm.jp.umaxica.app")` の fallback 部分を
`"palm-jp.umaxica.app"` に置換:

- `test/controllers/palm/app/oauth_boundary_test.rb`（2 箇所）
- `test/controllers/palm/app/oauth/callbacks_controller_test.rb`（2 箇所）
- `test/controllers/palm/app/api/v0/profiles_controller_test.rb`（1 箇所）

#### 3-3. テストのハードコード host を更新

- `test/services/palm_access_token_authenticator_test.rb:6` の `HOST = "palm.jp.umaxica.app"` を
  `HOST = "palm-jp.umaxica.app"` に
- `test/services/oidc/token_exchange_service_test.rb` の `palm.jp.umaxica.app`
  直接参照（1096/1097/1119 行）を `palm-jp.umaxica.app` に

実用上、ENV[PALM_SERVICE_URL] が application.rb 既定値で `palm-jp.umaxica.app`
になるため、fallback に到達するのはテスト ENV が明示的に異なる値を持つ稀ケース。それでも将来の混乱を避けるため一律置換する。

### 4. `compose.yaml` の alias（任意）

`palm.jp.umaxica.app`（ピリオド形）が alias に残っているが、cloudflared origin は
`http://palm.app.localhost:3000` を指すので未使用。整合性のため `palm-jp.umaxica.app`
へのリネームを推奨するが、必須ではない。

```diff
-          - palm.jp.umaxica.app
+          - palm-jp.umaxica.app
```

base 系は `base-jp.umaxica.{app,com,org}`
形では元から alias 登録なし（origin として使わないので不要）。追加は不要。

## 影響を受けるファイル

必須:

- `docker/core/env`（6 行）
- `config/application.rb`（1 行）
- `test/integration/routes/palm_route_contract_test.rb`（重複テスト削除）

推奨（テスト追従）:

- `test/controllers/palm/app/oauth_boundary_test.rb`
- `test/controllers/palm/app/oauth/callbacks_controller_test.rb`
- `test/controllers/palm/app/api/v0/profiles_controller_test.rb`
- `test/services/palm_access_token_authenticator_test.rb`
- `test/services/oidc/token_exchange_service_test.rb`

任意（cosmetic）:

- `compose.yaml`（palm alias リネーム）

## 非対応スコープ

- `application.rb` 既定値の `PALM_SERVICE_URL`
  をローカル形（`palm.app.localhost`）に統一するリファクタ。テスト ENV の挙動と相互依存しているため別タスクで。
- `www-jp`
  を含むハイフン形 → ピリオド形への将来移行。今回の判断（ハイフンで統一）が定着すれば移行不要。
- Cloudflare ダッシュボード側の追加変更（今回は不要、現状維持）。

## 検証

1. **ENV と routes 一致**: コンテナ内で確認

   ```sh
   docker compose exec core bin/rails runner '
     ["base-jp.umaxica.app", "base-jp.umaxica.com", "base-jp.umaxica.org",
      "palm-jp.umaxica.app"].each do |h|
       r = Rails.application.routes.recognize_path("http://#{h}/", method: :get)
       puts "#{h} -> #{r[:controller]}##{r[:action]}"
     end'
   ```

   それぞれ `base/{app,com,org}/roots#index` および `palm/app/roots#index` を返すこと。

2. **cloudflared から origin への疎通**: `Host` ヘッダを公開ホスト名で送って 200/302:

   ```sh
   docker compose exec cloudflare-tunnel \
     wget -S -O- --header='Host: base-jp.umaxica.app' \
     http://base.app.localhost:3000/health
   ```

3. **本番ホスト疎通**: 公開ホストに直接 curl:

   ```sh
   for h in base-jp.umaxica.app base-jp.umaxica.com base-jp.umaxica.org \
            palm-jp.umaxica.app; do
     printf '%-30s %s\n' "$h" "$(curl -sS -o /dev/null -w '%{http_code}' "https://$h/health")"
   done
   ```

   200/302 を期待。

4. **テスト**:
   `bin/rails test test/integration/routes/ test/controllers/palm/ test/services/palm_access_token_authenticator_test.rb`
   で回帰なし。

## ロールバック

すべて ENV 値とテスト fallback の文字列置換なので、`git revert`
で個別にリバート可能。Cloudflare ダッシュボードは今回触らないのでロールバック不要。
