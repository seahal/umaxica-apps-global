# ヘルスチェックエンドポイント

このアプリでは Rails 標準の `/up` を**ヘルスチェックに使いません**。代替として、将来的に `/health`
を専用エンドポイントとして用意する予定です。本書はその現状と方針を記録します。

## 原則

1. **`/up` をオーケストレータ（Kubernetes / Docker Compose / 監視 SaaS 等）の liveness / readiness
   probe に向けない。**
2. **新しいインフラ構成を組むときは、ヘルスチェックの URL を未定義のまま放置せず、`docs/operations/health-check.md`（本書）か関連 ADR を読んで現行方針を確認する。**
3. **`/health` 実装後は本書を更新し、`/up` セクションは「歴史的経緯」として残す。**

## なぜ `/up` を使わないのか

このアプリは `Authentication::Base` を `ApplicationController`
の階層へ組み込んでおり、`enforce_access_policy!` のデフォルト挙動が **`deny_all`**（明示的に
`declare_authentication_mode!` を呼んでいないコントローラはすべて拒否）です。Rails が提供する
`Rails::HealthController` はこのアプリの認証パイプラインに合わせた `declare_authentication_mode!`
を呼ばないため、内部 Rack 経由で `GET /up` を叩くと `403 Forbidden` を返します。

確認手順:

```ruby
# bin/rails runner
env = Rack::MockRequest.env_for("/up", method: "GET")
status, _, _ = Rails.application.call(env)
puts status # => 403
```

このため `/up` を probe
URL に設定するとサービスが常に unhealthy 扱いになり、オーケストレータが正常な Pod を再起動し続けるリスクがあります。

`/up` 自体に認証スキップを差し込む選択肢もありますが、それは「`/up`
だけ deny_all 原則の例外」を作ることであり、`AGENTS.md`
の非交渉ルール「認証パイプラインをスキップ・並び替えしない」と衝突します。よって `/up`
は使わず、専用エンドポイントを別系統で用意する方針です。

## `/health` の方針（実装予定）

| 項目               | 方針                                                                          |
| ------------------ | ----------------------------------------------------------------------------- |
| パス               | `/health`                                                                     |
| メソッド           | `GET`, `HEAD`                                                                 |
| 認証               | `declare_authentication_mode! :open` でパイプライン内に正規に登録する         |
| レスポンス（正常） | `200 OK` / 軽量な JSON（例: `{"status":"ok"}`）                               |
| レスポンス（異常） | `503 Service Unavailable`                                                     |
| 依存チェック       | DB ping、Redis ping は **含めない**。プロセス生存のみを返す liveness 用とする |
| readiness 用途     | 別パス（例: `/health/ready`）として後付けで検討。本書のスコープ外             |
| Cache-Control      | `no-store, private`                                                           |
| レート制限         | Rails 8.1 標準 `rate_limit` ではなく、ロードバランサ側で吸収する想定          |

実装の進捗・タスク管理は `plans/backlog/` 配下に切り出す（本書執筆時点では未起票）。

## 移行までの暫定運用

`/health` が用意されるまでは、オーケストレータ側のヘルスチェックは次のいずれかで代替します。

- TCP probe（ポートが開いているかだけを見る）
- ルートトップ（`GET /`）への probe で `2xx` または `3xx` を成功と扱う設定

`/up` を probe URL に設定している既存の compose / k8s
manifest が見つかった場合は、本書を参照しつつ修正してください。

## 関連

- `app/controllers/concerns/authentication/base.rb` — deny_all デフォルトポリシーの実装。
- `AGENTS.md` 非交渉ルール — 認証パイプラインのスキップ禁止。
