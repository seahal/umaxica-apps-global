# データベース運用ワークフロー

このアプリは約 25 個の PostgreSQL データベースを持つマルチ DB 構成です。スキーマ変更時の事故を避けるため、開発・テスト環境でのデータベース運用は次のルールに従ってください。

## 原則

1. **テーブルリネームを含むマイグレーションが進行中のブランチでは、増分の `bin/rails db:migrate`
   を使わない。** 代わりに `bin/rails db:migrate:reset` を使い、毎回マイグレーションから作り直す。
2. **`rename_table_if_present` 形式の「サイレントスキップ」ヘルパーを書かない。** 代わりに
   `rename_table_strict`（`MigrationHelpers::SafeTableRename` で提供）を使う。
3. **コミット前に `bin/rails db:verify_no_schema_drift` を実行する。**
   クリーン DB に対してマイグレーションを流した結果と、コミットされた schema_dump が一致することを確認する。

## なぜ `db:migrate` を避けるのか

`db:migrate`
は「過去の全マイグレーションが正しく適用済み」という前提で増分マイグレーションを実行します。マルチ DB 環境（25
DB）でテーブルリネームを複数行っているブランチでは、次のような事故が頻発します。

- ブランチを切り替えたあと、一部の DB は新しい schema_dump を持っているが、他の DB は古いまま →
  `db:migrate` で「テーブルがない」エラーで失敗。
- 失敗を回避するため `rename_table_if_present`
  式のサイレントスキップを入れる → 半分だけリネームされた状態で `schema_migrations` に成功記録 →
  schema_dump も中間状態でダンプされてコミットされる → 他環境に伝播。
- fixtures は最新のテーブル名を前提にしているので、半分リネームされた DB ではロードできず、テストが全滅する。

`bin/rails db:migrate:reset` は毎回 drop → create → migrate を実行するので、中間状態が累積しません。

## コマンド

```bash
bin/rails db:migrate:reset
RAILS_ENV=test bin/rails db:migrate:reset

bin/rails db:verify_no_schema_drift
# クリーン test DB に対してマイグレーションを流し、
# コミット済みの db/*_structure.sql と差分がなければ成功。
# 差分があれば「schema drift 発生」と報告して終了コード 1。
```

## Stop the server before running db:reset

The `app_setting` DB initialises preference reference rows via `insert_missing_fixed_ids!` on
demand. If the server is running when `db:reset` executes, an incoming request can arrive while the
DB is being dropped and recreated. The connection pool checkout blocks until the socket times out
(~10 s), producing a `Rack::Timeout::RequestTimeoutException` → 500 error.

```bash
# Correct procedure
# 1. Stop Puma / Foreman / docker compose
# 2. Reset the DB
bin/rails db:migrate:reset
# 3. Restart the server — the startup initializer pre-seeds all preference reference tables
```

`config/initializers/preference_reference_defaults.rb` seeds all preference reference tables during
`after_initialize`, so the very first request after restart hits an already-populated DB.

## テーブルリネームの書き方

```ruby
class RenameUsersToClients < ActiveRecord::Migration[8.2]
  def up
    rename_table_strict :users, :clients
  end

  def down
    rename_table_strict :clients, :users
  end
end
```

`rename_table_strict` の挙動:

| 旧テーブル | 新テーブル | 動作                                       |
| ---------- | ---------- | ------------------------------------------ |
| あり       | なし       | リネーム実行                               |
| なし       | あり       | スキップ（再実行時のイディオム）           |
| あり       | あり       | **raise** — 半リネーム状態。手動で resolve |
| なし       | なし       | **raise** — schema が期待状態と不一致      |

旧来の `rename_table_if_present`
は新旧どちらかが存在しないと無言でスキップしていたため、半リネーム状態を見逃して schema
drift を生んでいました。 `rename_table_strict`
は手動 resolve が必要なケースを必ず raise で知らせます。

## 推奨：CI に schema drift チェックを追加

`.github/workflows/integration.yml` の `database-consistency`
ジョブの末尾に次のステップを追加してください。

```yaml
- name: Verify no schema drift
  run: bin/rails db:verify_no_schema_drift
```

これにより、ブランチがコミットしている schema_dump と「クリーン DB にマイグレーションを流した結果」が一致しなければ CI で失敗します。
