# Retention 語彙 drift の cleanup

**Status: PROPOSAL — NOT STARTED. 受諾された ADR の遵守タスクであり、まだ着手前。**

`plans/active/` に昇格させる前に、Phase 1 を別 PR で取り出して着手予定。

## 動機

`adr/retainable-concern-and-retention-purge.md` および `adr/retention-lifecycle-column-boundary.md`
で retention 列は `discarded_at` + `purged_at` の 2 列に限定すると決まっている。しかし `clients`
テーブルだけが旧名 `deletable_at` を残し、サービス層もそのための防御コードを保持している。

実害:

- `clients` に retention 用列が 3 つ並ぶ (`deletable_at`, `discarded_at`,
  `purged_at`)。読み手が真の物理削除条件を誤解する
- `SignUp::Cancellation` / `SignUp::ArtifactCleanup` の `has_attribute?(:deletable_at)` 分岐が dead
  branch として残り、コード理解のノイズになる
- 新規 retainable テーブル追加時に「`deletable_at` も付けるべきか」と判断を迷う原因になる

## 現状調査結果

```
$ rg 'deletable_at' db/*_schema.rb app/
db/app_principal_schema.rb:540: t.datetime "deletable_at", default: ::Float::INFINITY, null: false
db/app_principal_schema.rb:547: t.index ["deletable_at"], name: "index_clients_on_deletable_at"
app/models/client.rb (annotate コメント内のみ)
app/services/sign_up/artifact_cleanup.rb:209
app/services/sign_up/cancellation.rb:77
```

- 生きた書き手: `SignUp::Cancellation`, `SignUp::ArtifactCleanup` の 2 箇所のみ
- 生きた読み手: なし (`RetentionPurgeJob` は `purged_at` のみ参照)
- 過去の migration: `db/app_principals_migrate/20260226100000_add_deletable_at_to_users.rb`
  で導入、`scheduled_purge_at → deletable_at` の rename を含む。`clients` への
  `deletable_at → purged_at` rename migration は **未実施**

他テーブルでの `deletable_at` 残存はゼロ (`operators`, `visitors`, 各 contact テーブルは
`discarded_at` + `purged_at` のみ)。

## 段階計画

### Phase 1: サービス層の dead branch 削除 (リスク低)

対象:

- `app/services/sign_up/cancellation.rb:77`
  - `attrs[:deletable_at] = purged_at if record.has_attribute?(:deletable_at)` の行を削除
- `app/services/sign_up/artifact_cleanup.rb:209`
  - 同上

挙動への影響:

- `clients.deletable_at` への書き込みが止まる。読み手はゼロのため副作用なし
- `RetentionPurgeJob` は `purged_at` のみ参照しており、物理削除挙動は変わらない
- `clients.deletable_at` の値は cancel/cleanup 経路で更新されなくなるが、既存値はそのまま残る (Phase
  2 で列ごと削除)

test:

- `test/services/sign_up/cancellation_test.rb`、 `test/services/sign_up/artifact_cleanup_test.rb` で
  `deletable_at` を assert している箇所があれば削除
- `bin/rails test test/services/sign_up/` を通す
- `bin/rails test test/models/client_test.rb` を通す

ロールバック:

- 単純な revert で戻せる。データ移行を伴わない

### Phase 2: `clients.deletable_at` の物理削除 (リスク中)

前提:

- Phase 1 が本番に出てから最低 1 リリース経過 (生きた書き手がゼロであることを確認)
- `bin/rails db:verify_no_schema_drift` で committed schema_dump とランタイム状態の一致を確認

migration:

```ruby
class DropDeletableAtFromClients < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    if index_exists?(:clients, :deletable_at, name: "index_clients_on_deletable_at")
      remove_index :clients,
                   name: "index_clients_on_deletable_at",
                   algorithm: :concurrently
    end

    safety_assured do
      remove_column :clients, :deletable_at
    end
  end

  def down
    safety_assured do
      add_column :clients, :deletable_at, :datetime,
                 default: ::Float::INFINITY, null: false
    end

    # purged_at と意味的に同じだった列なので backfill
    execute(<<~SQL.squish)
      UPDATE clients SET deletable_at = purged_at
    SQL

    add_index :clients, :deletable_at,
              name: "index_clients_on_deletable_at",
              algorithm: :concurrently
  end
end
```

PostgreSQL 11+ では `remove_column` は metadata 操作のみ (full table
rewrite なし) のため軽い。ただし `clients` は最大テーブルのため:

- index 削除は `algorithm: :concurrently` で online 実行
- `safety_assured do` ブロックで `strong_migrations` の警告を意図的に承認
- migration 前後で `bin/db-reset-all` ではなく、本番相当のサンプルデータで local 検証

test:

- `bin/rails test test/models/client_test.rb`
- `bin/rails db:verify_no_schema_drift`
- `db/app_principal_schema.rb` の diff を PR で目視レビュー (committed
  schema_dump が migration 後の状態と一致すること)

ロールバック:

- 上記 down migration で `deletable_at` を再作成し、`purged_at` の値で backfill する
- index 再作成も `algorithm: :concurrently`

### Phase 3: `RefreshTokenable` の doc 整備 (リスク無)

対象:

- `app/models/concerns/refresh_tokenable.rb` の `default_lapses_at` および関連メソッド

作業:

- `lapses_at` がドメイン語の alias method であり、DB 列は `discarded_at` であることを doc
  comment で明記
- `adr/retention-lifecycle-column-boundary.md` 第 3 項への参照を comment に追加

挙動への影響: なし

### Phase 4: 新規 retainable テーブル template の整備 (任意)

対象:

- `lib/generators/` 配下に retainable migration template があれば、ADR の規定 (default Infinity, NOT
  NULL, check constraint, partial index) を反映する
- 既存 template が無い場合は本 plan では新規作成しない。`AGENTS.md` の migration
  policy に項目を追記するだけに留める

## 着手順

1. Phase 1 を別 PR で実施 (この PR を本 plan の最初の deliverable とする)
2. Phase 3 を Phase 1 と同 PR に含めて差し支えない (どちらも touch 量小)
3. Phase 1 マージ → 本番リリース後 1 週間以上の観察期間
4. Phase 2 を別 PR で実施。merge 前に本番相当のサンプル DB で migration を通し、rollback 手順を確認
5. Phase 4 は別 backlog 化を検討 (本 plan では scope 外でもよい)

## 未決事項

- Phase 2 の migration を `app_principals_migrate/`
  に置く時点で、未マージの他 migration との rebase 順序を要調整 (`git log db/app_principals_migrate/`
  で最新タイムスタンプを確認)
- `bin/rails db:verify_no_schema_drift`
  のコマンド存在を確認 (AGENTS.md 言及あり、未確認の場合は migration policy 担当者に確認)

## 参照

- `adr/retainable-concern-and-retention-purge.md` — 元の決定
- `adr/retention-lifecycle-column-boundary.md` — 本 plan の根拠 ADR
- `app/models/concerns/retainable.rb` — 正本実装
- `app/jobs/retention_purge_job.rb` — 物理削除 worker
- `app/services/sign_up/cancellation.rb`, `app/services/sign_up/artifact_cleanup.rb` — Phase 1 対象
- `db/app_principal_schema.rb` の `clients` テーブル定義 — Phase 2 対象
