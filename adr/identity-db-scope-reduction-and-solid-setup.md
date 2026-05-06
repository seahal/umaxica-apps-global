# identity の DB 責務縮小と SolidCache/SolidQueue 整備

SolidCache / SolidQueue direction is now governed by `four-app-solid-cache-and-solid-queue.md`.

**Status:** Plan (2026-04-23)

## Context

`identity/` Rails app の `config/database.yml` と `db/*_schema.rb`
には、認証エンジン（Signature/sign）の責務を超える 8 つの DB 接続が残っている（avatar, notification,
publication, behavior, commerce, billing, message, search）。これらは：

- **avatar / notification / publication**: migrations_paths がすでに `engines/zenith/` および
  `engines/distributor/` を指しており、接続定義だけが identity に残存している
- **behavior / commerce / billing / message / search**: モデル本体は
  `engines/foundation/app/models/` に存在（`BehaviorRecord` 抽象クラス等）。identity の `app/`
  配下からは一切参照されていない（`connects_to` ゼロを確認済み）
- `identity/db/` 配下の 8 ファイルは 883 バイトの空 stub。マイグレーションソースは workspace root の
  `/db/*_migrate/` またはエンジン配下にある

このため `bin/rails db:migrate:reset`
が identity の責務外の DB まで対象にしてしまい、エラー時のノイズ・所要時間・疎通失敗の切り分けが困難になっている。

同時に、identity は将来独立した Rails アプリとして SolidCache/SolidQueue を自身のキャッシュ/ジョブ基盤として動かしたいが、現状は：

- `Gemfile` に gem あり、`database.yml` に `cache:` / `queue:` 接続ありだが、
- `config/cache.yml`, `config/queue.yml` が無い
- `config/environments/*.rb` で `cache_store` / `queue_adapter` が未設定
- identity ローカルには `db/caches_migrate/`, `db/queues_migrate/`
  ディレクトリが無い（workspace 共有の `../db/caches_migrate` などを参照）

参考として `/home/jit/workspace/lib/` に完全動作する SolidCache/SolidQueue 設定が存在する。

**意図する結果:**

1. identity が所有すべき DB だけを `database.yml` と `db/` に残す
2. 移管対象の 8 DB は `identity/config/database.yml` と `identity/db/*_schema.rb`
   から削除する。Foundation/Zenith/Distributor の各 app は独自の `config/database.yml`
   で引き続きそれらを所有するため、データ側には影響しない
3. SolidCache/SolidQueue が identity 単体で `db:migrate`
   できる状態にする（ワーカープロセス起動は別タスク）

## Scope（identity が保持する DB）

- **保持**: `principal` / `token` / `operator` / `occurrence` / `setting` / `guest` / `activity` /
  `cache` / `queue` / `storage` / `cable`
- **削除**: `avatar` / `notification` / `publication` / `behavior` / `commerce` / `billing` /
  `message` / `search`（各 `_replica` 含む）

## Changes

### 1. `identity/config/database.yml` の剪定

`development:` セクションから以下 8 ペア（16 ブロック）を削除：

- `avatar` / `avatar_replica`（L213–223）
- `notification` / `notification_replica`（L114–124）
- `publication` / `publication_replica`（L81–91）
- `behavior` / `behavior_replica`（L180–190）
- `commerce` / `commerce_replica`（L59–69）
- `billing` / `billing_replica`（L92–102）
- `message` / `message_replica`（L103–113）
- `search` / `search_replica`（L48–58）

`test: primary: migrations_paths:` 配列から以下を削除（L229–248）：

- `../db/behavior_migrate`
- `../db/billing_migrate`
- `../db/commerces_migrate`
- `../db/messages_migrate`
- `../db/searches_migrate`
- `../engines/distributor/db/publications_migrate`
- `../engines/zenith/db/avatars_migrate`
- `../engines/zenith/db/notifications_migrate`

**保留**: `../db/defaults_migrate`, `../db/documents_migrate`, `../db/finders_migrate`
が test 側にだけ現れる。development に対応する接続が無いので identity では実質未使用と思われるが、tests 実行時の前提になっている可能性があるため今回はそのまま残し、別タスクで所属を再検討する。

### 2. `identity/db/` の orphan schema 削除

以下 8 ファイルを削除：

- `identity/db/avatar_schema.rb`
- `identity/db/notification_schema.rb`
- `identity/db/publication_schema.rb`
- `identity/db/behavior_schema.rb`
- `identity/db/commerce_schema.rb`
- `identity/db/billing_schema.rb`
- `identity/db/message_schema.rb`
- `identity/db/search_schema.rb`

### 3. `identity/config/cache.yml` を新規作成

`/home/jit/workspace/lib/config/cache.yml` をそのまま写経する。抜粋：

```yaml
development:
  encrypt: true
  store_options:
    max_age: <%= 1.week.to_i %>
    max_size: <%= 256.megabytes %>
    namespace: <%= Rails.env %>
# production / test セクションも lib/ に合わせる
```

実装時は `lib/config/cache.yml` の全文をコピーする。

### 4. `identity/config/queue.yml` を新規作成

`/home/jit/workspace/lib/config/queue.yml` をそのまま写経する。抜粋：

```yaml
default: &default
  dispatchers:
    - polling_interval: 1
      batch_size: 500
  workers:
    - queues: "*"
      threads: 3
      processes: <%= ENV.fetch("JOB_CONCURRENCY", 1) %>
      polling_interval: 0.1
development:
  <<: *default
production:
  <<: *default
```

実装時は `lib/config/queue.yml` の全文をコピーする。

### 5. `identity/config/environments/*.rb` の cache/queue 配線

`lib/config/environments/production.rb` の該当箇所（L76–80）をリファレンスに配線する：

- **development.rb**: `config.cache_store = :memory_store` を `:solid_cache_store`
  に変更。`config.active_job.queue_adapter = :solid_queue` と
  `config.solid_queue.connects_to = { database: { writing: :queue } }` を追記
- **production.rb**: 同上の 3 行を追記。lib は production で `null_store`
  を選んでいるが、identity は単体アプリとして動かすため `:solid_cache_store`
  を既定とする。lib と方針が違う点はコミットメッセージ / レビューで明記する
- **test.rb**: `:null_store` のまま変更しない

### 6. マイグレーション配置（要判断）

`identity/config/database.yml` の `cache:` / `queue:` エントリは現状
`migrations_paths: ../db/caches_migrate` / `../db/queues_migrate`（workspace 共有）を参照している。

選択肢：

- **A**: そのまま workspace 共有を参照する。identity 側にコピーを置かない。最小変更。
- **B**: `identity/db/caches_migrate/` と `identity/db/queues_migrate/`
  を作成し、`lib/db/caches_migrate/` / `lib/db/queues_migrate/`
  のマイグレーションをコピーし、`migrations_paths`
  を identity 内に切り替える。identity が将来完全に独立したリポジトリ構成になっても動く。

実装着手時にどちらか確定させる。**デフォルト推奨は A**（変更を最小化するため）。

## Critical Files

- `/home/jit/workspace/identity/config/database.yml`（編集）
- `/home/jit/workspace/identity/db/*_schema.rb`（8 ファイル削除）
- `/home/jit/workspace/identity/config/cache.yml`（新規）
- `/home/jit/workspace/identity/config/queue.yml`（新規）
- `/home/jit/workspace/identity/config/environments/development.rb`（編集）
- `/home/jit/workspace/identity/config/environments/production.rb`（編集）

## Reference Files（コピー元・照合元）

- `/home/jit/workspace/lib/config/cache.yml`
- `/home/jit/workspace/lib/config/queue.yml`
- `/home/jit/workspace/lib/config/environments/production.rb`（L76–80）
- `/home/jit/workspace/lib/db/caches_migrate/`
- `/home/jit/workspace/lib/db/queues_migrate/`
- `/home/jit/workspace/foundation/config/database.yml`（behavior/commerce/billing/message/search の接続先として既存）
- `/home/jit/workspace/engines/foundation/app/models/*behavior*.rb`（behavior モデルの所有者確認用）

## Out of Scope（別タスク）

- Foundation / Zenith / Distributor 各 app の `database.yml`
  剪定（それぞれ同様に責務外 DB を抱えているが、今回は identity のみ）
- SolidQueue ワーカープロセス起動（`bin/dev` / `Procfile.dev` への追加）
- `defaults_migrate` / `documents_migrate` / `finders_migrate` の所属再検討
- `guest` / `activity` が本当に identity 所有かの精査（今回は暫定的に残す）

## Verification

### 静的検証

1. `grep -E "(avatar|notification|publication|behavior|commerce|billing|message|search):" /home/jit/workspace/identity/config/database.yml`
   → 0 件であること
2. `ls /home/jit/workspace/identity/db/*_schema.rb` → 削除対象 8 ファイルが無いこと
3. `test -f /home/jit/workspace/identity/config/cache.yml && test -f /home/jit/workspace/identity/config/queue.yml`
   → 存在すること

### コマンド検証

identity app ディレクトリで：

```bash
cd /home/jit/workspace/identity
bundle exec rails runner 'p ActiveRecord::Base.configurations.configs_for(env_name: "development").map(&:name)'
# => 剪定対象の接続名が含まれないこと。保持対象のみが出ること

bundle exec rails db:migrate:reset
# => 剪定前よりエラーが減り、identity 所有 DB のみが drop/create/migrate されること

bundle exec rails runner 'Rails.cache.write("k", "v"); p Rails.cache.read("k")'
# => "v" が出ること（SolidCache が有効）

bundle exec rails runner 'p Rails.application.config.active_job.queue_adapter'
# => :solid_queue

bundle exec rubocop config/ db/
bundle exec erb_lint .
```

### 回帰確認

```bash
cd /home/jit/workspace/identity
bundle exec rails test
```

削除した接続を参照するテストが現状ゼロであることは `connects_to`
探索で確認済み。ただし test セクションの `migrations_paths`
から 8 パスを抜くので、`test_identity_db`
にそれらの表が存在しなくなる。identity のテストが Foundation 等のテーブルを参照していた場合に落ちる可能性があるので、`bundle exec rails test`
実行結果を注視する。

## Risks

- **test セクションの migrations_paths 縮小**: 現状で identity のテストが Foundation 系テーブルを経由しているとは確認していない。fixture 読み込みや生 SQL が残っていないか
  `bundle exec rails test` で最終確認する
- **SolidCache を development で有効化**: `cache` DB への疎通が必須になる。Docker
  compose 未起動環境で `rails c` が失敗しやすくなる。lib の production が `null_store`
  を選んでいる点と方針が違う旨をコミットメッセージに明記する
- **Foundation/Zenith/Distributor 各 app の database.yml はそのまま残る**:
  identity から抜いた接続が他 app で生きているので DB データ自体は失われない。ただし各 app を将来剪定する際に同じ作業が繰り返しになる（別タスク）
