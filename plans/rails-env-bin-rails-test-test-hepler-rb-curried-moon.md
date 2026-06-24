# テスト DB 修復プラン — `clients` テーブル不在エラー

## Context

`RAILS_ENV=test bin/rails test` を実行すると、ほぼ全テストで以下のエラーが発生する：

```
ActiveRecord::StatementInvalid: PG::UndefinedTable: ERROR: relation "clients" does not exist
```

`Client` モデルは `app_principal` データベースに接続しており、`clients`
テーブルが存在していることを前提としている。

## 根本原因

### 1. テーブルリネームマイグレーション未適用

`db/app_principals_migrate/20260520143000_rename_app_principal_tables_to_model_conventions.rb`
が追加されたが、テスト DB にはまだ適用されていない。

このマイグレーションは `users` →
`clients`（その他 50+ テーブル）の一括リネームを行う。テスト DB はリネーム前の `users`
テーブルを持っているか、または完全に空の状態にある。

### 2. `app_principal_structure.sql` が空

`config/database.yml` の `app_principal_replica` に `schema_dump: app_principal_structure.sql`
が設定されているが、`db/app_principal_structure.sql` の中身が空（PostgreSQL dump のヘッダのみ）。

`bin/rails db:test:prepare`
はこの空の SQL ファイルからテスト DB を構築するため、テーブルが一切存在しない状態になる。

### 3. AGENTS.md の指示との対応

AGENTS.md には以下の記載がある：

> While a rename migration is in flight on a branch, rebuild dev and test DBs with
> `bin/rails db:migrate:reset` instead of incremental `bin/rails db:migrate`.

リネームマイグレーションが存在する現状では、インクリメンタルな migrate ではなく `db:migrate:reset`
でゼロから再構築する必要がある。

## 修正手順

### Step 1: テスト DB を migrations から再構築

```bash
bin/rails db:migrate:reset RAILS_ENV=test
```

全データベース（`app_principal` を含む）を drop → create
→ 全マイグレーション適用 の順で再構築する。これにより `clients` テーブルが正しく作成される。

### Step 2: スキーマドリフトがないことを確認（任意・推奨）

```bash
bin/rails db:verify_no_schema_drift
```

### Step 3: テストを再実行

```bash
bin/rails test
```

## 注意事項

- `test_helper.rb` は変更不要・変更禁止。
- 開発環境でも同じリネームマイグレーションが未適用の場合、`bin/rails db:migrate:reset`
  （RAILS_ENV 指定なし）で dev DB も再構築する。
- `app_principal_structure.sql` が空のままだと、次回 `db:test:prepare`
  でまた空の DB になる。`db:migrate:reset` 後に `db:structure:dump` が自動で走るか、または手動で
  `bin/rails db:structure:dump RAILS_ENV=test` を実行して SQL ファイルを更新しておく。

## 検証

`bin/rails test` がエラーなく全テストを通過すること。 `clients` テーブルが存在することは
`bin/rails runner "puts Client.count" RAILS_ENV=test` でも確認できる。
