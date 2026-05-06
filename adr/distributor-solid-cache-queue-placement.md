# ADR: Solid Cache / Solid Queue の配置とアプリ専用 DB 化

Status: superseded by `four-app-solid-cache-and-solid-queue.md`

Superseded on: 2026-04-23

**Status:** Historical plan (2026-04-23)

**Scope:** distributor / foundation / identity / zenith の 4 アプリ (Solid
Queue 実利用は lib も関連)

## Context

Solid Cache / Solid Queue は現状:

- **マイグレーションはリポジトリ root 共有**: `db/caches_migrate/`, `db/queues_migrate/`
- **DB 名はアプリ別に分岐済み** (例: `development_distributor_cache_db`,
  `development_foundation_queue_db`)
- **schema snapshot** のみ `<app>/db/cache_schema.rb`, `<app>/db/queue_schema.rb`
  として各アプリ配下に存在
- Solid Cache 側はまだ `:solid_cache_store`
  を使っておらず (memory_store/null_store が主)、DB だけが用意されている段階
- Solid Queue は `lib/config/application.rb` で `config.active_job.queue_adapter = :solid_queue` /
  `connects_to = { database: { writing: :queue, reading: :queue_replica } }` として接続名 `queue`
  を参照

この構成には以下の歪みがある:

1. マイグレーションが root 共有なのに DB はアプリ別なので、「このマイグレーションはどのアプリの DB に流すのか」の所在が曖昧
2. `cache` / `queue` という接続名が汎用的で、Solid Cache / Solid
   Queue 固有のリソースだと一目で分からない
3. distributor の場合は特にキャッシュ/ジョブのワーカーがアプリ専有であるべきだが、命名が曖昧なままでは将来スコープが崩れやすい

目標: Solid Cache / Solid
Queue の配置をアプリ固有に整理し、名前も Solid プリフィックスで統一して、マイグレーションもアプリ配下に持ち込む。

## Final Design

### 1. DB 名のリネーム

各アプリで以下の変更:

| 旧 DB 名                           | 新 DB 名                                 |
| ---------------------------------- | ---------------------------------------- |
| `development_distributor_cache_db` | `development_distributor_solid_cache_db` |
| `development_distributor_queue_db` | `development_distributor_solid_queue_db` |
| `development_foundation_cache_db`  | `development_foundation_solid_cache_db`  |
| `development_foundation_queue_db`  | `development_foundation_solid_queue_db`  |
| `development_identity_cache_db`    | `development_identity_solid_cache_db`    |
| `development_identity_queue_db`    | `development_identity_solid_queue_db`    |
| `development_zenith_cache_db`      | `development_zenith_solid_cache_db`      |
| `development_zenith_queue_db`      | `development_zenith_solid_queue_db`      |

test / production 環境についても同じ変更パターン。

### 2. database.yml 接続名と ENV のリネーム

- 接続名: `cache` → `solid_cache`, `cache_replica` → `solid_cache_replica`, `queue` → `solid_queue`,
  `queue_replica` → `solid_queue_replica`
- ENV: `POSTGRESQL_CACHE_PUB/SUB` → `POSTGRESQL_SOLID_CACHE_PUB/SUB`, `POSTGRESQL_QUEUE_PUB/SUB` →
  `POSTGRESQL_SOLID_QUEUE_PUB/SUB`
- migrations_paths: `../db/caches_migrate` → `./db/solid_caches_migrate`
  (アプリ配下の相対パス), 同様に queue

distributor の例 (他アプリも同形式):

```yaml
development:
  solid_cache:
    <<: *default
    database: development_distributor_solid_cache_db
    host: <%= ENV["POSTGRESQL_SOLID_CACHE_PUB"] || default_host %>
    migrations_paths: db/solid_caches_migrate
  solid_cache_replica:
    <<: *default
    replica: true
    database: development_distributor_solid_cache_db
    host: <%= ENV["POSTGRESQL_SOLID_CACHE_SUB"] || default_host %>
    migrations_paths: db/solid_caches_migrate
  solid_queue:
    <<: *default
    database: development_distributor_solid_queue_db
    host: <%= ENV["POSTGRESQL_SOLID_QUEUE_PUB"] || default_host %>
    migrations_paths: db/solid_queues_migrate
  solid_queue_replica:
    <<: *default
    replica: true
    database: development_distributor_solid_queue_db
    host: <%= ENV["POSTGRESQL_SOLID_QUEUE_SUB"] || default_host %>
    migrations_paths: db/solid_queues_migrate
```

### 3. マイグレーションの配置

各アプリ (`distributor`, `foundation`, `identity`, `zenith`) の配下に移す:

- `distributor/db/solid_caches_migrate/20260312100000_create_solid_cache_entries.rb`
- `distributor/db/solid_queues_migrate/20251220094000_create_solid_queue_schema.rb`
- `distributor/db/solid_queues_migrate/20260309000001_convert_timestamps_to_timestamptz.rb`

foundation / identity / zenith にも同一ファイルを配置 (コピー)。

root の `db/caches_migrate/` と `db/queues_migrate/` は削除。

### 4. schema snapshot のリネーム

各アプリで:

- `<app>/db/cache_schema.rb` → `<app>/db/solid_cache_schema.rb`
- `<app>/db/queue_schema.rb` → `<app>/db/solid_queue_schema.rb`

中身は `bin/rails db:schema:dump` を走らせて再生成してもよい。

### 5. Solid Queue / Solid Cache 設定更新

**`lib/config/application.rb`:**

```diff
- config.solid_queue.connects_to = { database: { writing: :queue, reading: :queue_replica } }
+ config.solid_queue.connects_to = { database: { writing: :solid_queue, reading: :solid_queue_replica } }
```

**`lib/config/environments/production.rb`:**

```diff
- config.solid_queue.connects_to = { database: { writing: :queue } }
+ config.solid_queue.connects_to = { database: { writing: :solid_queue } }
```

同様の定義が他アプリ側に存在する場合も同様に置換。

**Solid Cache 側** は現状 Rails の `cache_store`
として使われていないので、設定変更だけで配線はされない。必要になった時点で別 ADR で
`config.cache_store = :solid_cache_store` + `connects_to` を追加する (このときに `solid_cache`
接続を参照)。

### 6. Solid Queue / Solid Cache の config.yml

- `lib/config/queue.yml`, `lib/config/cache.yml` は内容 (max_age など) の変更は不要
- ただし **各アプリ配下にコピーを置くか、lib の共有を参照し続けるか** は要判断 (下記 Open Items)

### 7. 影響範囲チェック

- `distributor/config/puma.rb`, `foundation/config/puma.rb`, `identity/config/puma.rb`,
  `zenith/config/puma.rb`: `plugin :solid_queue`
  はそのまま (接続名は application.rb 側で決まるので変更不要)
- `lib/config/cache.yml` / `lib/config/queue.yml`: 変更不要
- Docker compose / seed スクリプトで DB 名を直書きしている箇所が無いか確認

## Critical Files

新規 (各アプリごと):

- `<app>/db/solid_caches_migrate/20260312100000_create_solid_cache_entries.rb` (コピー)
- `<app>/db/solid_queues_migrate/20251220094000_create_solid_queue_schema.rb` (コピー)
- `<app>/db/solid_queues_migrate/20260309000001_convert_timestamps_to_timestamptz.rb` (コピー)
- `<app>/db/solid_cache_schema.rb` (旧 `cache_schema.rb` のリネーム)
- `<app>/db/solid_queue_schema.rb` (旧 `queue_schema.rb` のリネーム)

編集:

- `distributor/config/database.yml` (接続名 cache/queue →
  solid_cache/solid_queue、DB 名・ENV・migrations_paths を全面更新)
- `foundation/config/database.yml`
- `identity/config/database.yml`
- `zenith/config/database.yml`
- `lib/config/database.yml` (queue 接続名/ENV を solid_queue 系に置換。Solid
  Cache は lib では使っていなければ削除)
- `lib/config/application.rb` (`solid_queue.connects_to` の接続名)
- `lib/config/environments/production.rb` (同)
- `AGENTS.md` の Multi-Database
  Architecture 表 (queue/cache 行を solid_queue/solid_cache に差し替え)

削除:

- `db/caches_migrate/` (root)
- `db/queues_migrate/` (root)
- `<app>/db/cache_schema.rb` (旧名)
- `<app>/db/queue_schema.rb` (旧名)

## Verification

各アプリ (distributor / foundation / identity / zenith) で:

```bash
# DB 作り直し (新しい DB 名で作成されること)
docker compose up -d
bin/rails db:drop
bin/rails db:create
bin/rails db:migrate

# 期待するテーブルが solid_cache DB / solid_queue DB に入ること
psql $POSTGRESQL_SOLID_CACHE_PUB -d <app>_solid_cache_db -c "\\dt"
psql $POSTGRESQL_SOLID_QUEUE_PUB -d <app>_solid_queue_db -c "\\dt"

# Lint & テスト
bundle exec rubocop
bundle exec erb_lint .
vp check
bundle exec rails test
```

機能確認:

- 任意の ActiveJob をキューイングし、`solid_queue` 接続の `solid_queue_jobs`
  テーブルにレコードが入ることを確認
- SolidQueue ワーカー (`SOLID_QUEUE_IN_PUMA=1` で起動) がジョブを取り出して処理することを確認
- `/health` が新しい接続名 `solid_cache` / `solid_queue` を表示し、旧 `cache` / `queue`
  が残存していないことを確認

## Open Items (実装前に要判断)

1. **config/queue.yml, config/cache.yml の配置**: 現在 `lib/config/`
   に共有で置かれている。各アプリ専有に切り替える場合、`<app>/config/queue.yml` にコピーして Solid
   Queue の起動オプションをアプリ別に持てるようにする選択肢もある。→ 推奨: 現状維持 (lib 共有)。必要になった時点で個別化。
2. **マイグレーションのコピー vs シンボリックリンク**: 各アプリに同内容のマイグレーションをコピーで置くと、今後 Solid
   Cache/Queue の gem アップデートで新マイグレーションが必要になった時に 4 箇所同期させる手間が発生する。→ 選択肢 A: コピー (単純、アプリ独立性が高い)
   → 選択肢 B: `lib/db/solid_caches_migrate/`
   に置いて各アプリの database.yml から相対パス参照 → 推奨: 今回は A (コピー)。Solid
   Cache/Queue の schema 変更頻度は低いため、アプリ独立性を優先。
3. **DB データ引き継ぎ**: 開発環境のキャッシュ/キュー中身は捨てて問題なし。本番は未デプロイ。
4. **identity/foundation/zenith の実利用状況**: puma.rb に `plugin :solid_queue`
   はあるが実ジョブが流れているか (schedule/recurring 設定の有無) を確認し、影響度を把握する。

## Out of Scope

- Solid Cache を Rails の `cache_store` として有効化する作業 (別 ADR)
- Solid Queue recurring/scheduler の設定変更
- chronicle DB 統合 (`adr/chronicle-audit-db-consolidation.md` で別途)
- 本番データの移行 (現状未デプロイのため不要)
