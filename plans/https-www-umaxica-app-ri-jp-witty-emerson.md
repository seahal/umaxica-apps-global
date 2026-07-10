# `/?ri=jp` 遅延・クッキーリセット後エラーの改修計画

## Context

`https://www.umaxica.app/?ri=jp` へのアクセスが遅く、クッキーをリセットすると 500 エラーになる。
`development.log` のログ調査で根本原因を特定した。

「急に出るようになった」理由は `1d5727815`（6/26
00:24）で 3 件の新規マイグレーションが追加され、db:reset が必要になったタイミングで潜在的なブロッキング問題が顕在化したため。

---

## 問題の整理

### 問題 A：クッキーなし初回リクエストで `app_setting` DB がブロック → タイムアウト

**現象**

- クッキーリセット後または db:reset 直後の最初のリクエストが 10 秒タイムアウト（`Rack::Timeout::RequestTimeoutException`）
- ログに `Completed 500 Internal Server Error in 9994ms` / `in 174029ms`

**原因スタック**

```
set_preferences_cookie
  → load_preference_record_from_refresh_token!(create_if_missing: true)
    → create_new_preference_record!
        → with_preference_connection(:writing)
            → preference_connection_owner.transaction {
                ensure_preference_reference_defaults!
                  → AppPreferenceStatus.ensure_defaults!
                    → insert_missing_fixed_ids!([0,1,2])   ← ここでブロック
```

**ブロックの正体** `insert_missing_fixed_ids!` の冒頭で `lease_connection.data_source_exists?`
を呼ぶ際、 `app_setting` DB が drop〜migrate 中（db:reset 中）だと TCP 接続確立がブロックされる。
`ActiveRecord`
計測時間はほぼ 0ms だが Wall 時間だけ 10 秒消費する（コネクションプール checkout 待ち）。

**もう 1 つのパス（コールバック）**

```
create_preference_options
  → create_preference_option_records (Array#each)
      → with_model_writing_connection(klass)          ← 11 種類 × 個別呼び出し
          → connected_to(role: :writing) { ... }      ← ここでブロック
```

---

### 問題 B：preference 新規作成が遅い（90 クエリ）

**現象** クッキーリセット後の初回リクエストが正常時でも 172〜229ms かかる。

**原因** `create_preference_options` が以下を直列で実行する：

1. `create_preference_cookie` — 1 件の cookie association
2. `ensure_preference_option_defaults` — 11 種類 × オプションクラスのデフォルト確認クエリ
3. `create_preference_option_records` — 11 種類 × `pluck/create/load` = 33 クエリ

加えて各 `with_model_writing_connection` が `connected_to(role: :writing)`
を 12 回個別に呼んでいる。Rails のマルチ DB スイッチが 12 回走るのはオーバーヘッドになる。

---

### 問題 C：`FIXED_ID_SEED_CACHE` が db:reset 後に空になる

**現象** db:reset 後の最初のリクエストで必ず `insert_missing_fixed_ids!`
が走る（キャッシュが空なので）。

**原因** `FIXED_ID_SEED_CACHE` はプロセスインメモリの
`Concurrent::Map`。サーバーを再起動すると空になる。DB が空の状態でリクエストが来ると必ずシード処理が走る。

---

### 問題 D（根本）：なぜ急に出るようになったか

| コミット                  | 変更                                                          | 影響                                                             |
| ------------------------- | ------------------------------------------------------------- | ---------------------------------------------------------------- |
| `1d5727815`（6/26 00:24） | `info` サーフェス追加 + マイグレーション 3 件                 | db:reset が必要になり、ブロッキングが顕在化                      |
| `1d5727815`               | OIDC callback に `prepend_before_action :clear_auth_cookies!` | auth クッキーのみ削除（preference クッキーは別名なので影響なし） |
| `da243330e`（6/25 18:10） | `oidc_pending_flows` をセッションに追加                       | セッションサイズ増加（副次的リスク）                             |

直接原因は **db:reset 中にサーバーが動いていた**こと。 `clear_auth_cookies!`
は auth クッキー（`auth_access`, `auth_refresh`,
`auth_dbsc`）のみ削除し、preference クッキー（`preference_refresh`,
`preference_access`）は別名なので影響しない。

---

## 解決方針

### 解決策 1：`insert_missing_fixed_ids!` をリクエストパスから外す

**対象ファイル**

- `app/models/application_record.rb`
- `app/controllers/concerns/preference_base.rb`（`ensure_preference_reference_defaults!`）
- `db/seeds.rb`（または専用の seed ファイル）

**方針**

- `ensure_preference_reference_defaults!` はサーバー起動時（initializer または
  `config/application.rb`）に一度だけ実行し、リクエストパスでは `FIXED_ID_SEED_CACHE`
  のキャッシュヒット前提で動くようにする。
- `insert_missing_fixed_ids!` に `statement_timeout`
  を設定し、接続が取れない場合は例外を rescue してログだけ出し、次のリクエストに引き渡す（fail-fast）。
- または `db/seeds.rb` に各 reference table の初期データ投入を追加し、db:reset 後は必ず `db:seed`
  も走る構成にする（`db:reset` = `db:schema:load + db:seed`）。

**具体的な変更**

```ruby
# config/initializers/preference_reference_defaults.rb（新規）
# サーバー起動時に一度だけ app_setting DB に fixed IDs を書き込む。
# DB が使えない場合はスキップして warn のみ（起動は止めない）。
Rails.application.config.after_initialize do
  next if Rails.env.test?

  [AppPreferenceStatus, AppPreferenceChronicleLevel, AppPreferenceChronicleEvent,
   AppPreferenceBindingMethod, AppPreferenceDbscStatus].each do |klass|
    klass.ensure_defaults! if klass.respond_to?(:ensure_defaults!)
  rescue => e
    Rails.logger.warn("preference_reference_defaults: skipped #{klass} — #{e.class}")
  end
end
```

```ruby
# application_record.rb — insert_missing_fixed_ids! に statement_timeout 追加
def self.insert_missing_fixed_ids!(ids)
  # ... 既存のガード ...
  with_statement_timeout(500) do   # 500ms で fail-fast
    # ... 既存の insert_all ロジック ...
  end
rescue ActiveRecord::QueryTimeout, ActiveRecord::StatementInvalid => e
  Rails.logger.warn("insert_missing_fixed_ids! skipped #{name}: #{e.class}")
end
```

---

### 解決策 2：preference 新規作成の `connected_to` をまとめる

**対象ファイル**

- `app/controllers/concerns/preference_base.rb`

**方針** `create_preference_options` 全体を 1 回の `with_preference_connection(:writing)`
で囲む。現在は `create_preference_cookie` と `create_preference_option_records` の各エントリが個別に
`with_model_writing_connection` を呼んでいるため 12 回の `connected_to`
スイッチが発生する。すべて同じ `app_setting` DB を使うので、外側で 1 回スイッチすれば済む。

```ruby
# 変更前
def create_preference_options(preference, params_hash = {})
  prefix = preference_prefix(preference)
  option_ids = preference_option_ids(prefix, params_hash)
  create_preference_cookie(prefix, preference)           # ← 内部で connected_to
  ensure_preference_option_defaults(prefix)
  create_preference_option_records(prefix, preference, option_ids)  # ← 11回 connected_to
end

# 変更後
def create_preference_options(preference, params_hash = {})
  prefix = preference_prefix(preference)
  option_ids = preference_option_ids(prefix, params_hash)
  with_preference_connection(:writing) do
    create_preference_cookie(prefix, preference)
    ensure_preference_option_defaults(prefix)
    create_preference_option_records(prefix, preference, option_ids)
  end
end

# create_preference_cookie / create_preference_option_records の内部 with_model_writing_connection は
# 外側の connected_to コンテキスト内では no-op になるので、削除しても同じ挙動になる。
# ただし他の呼び出し元から単独で呼ばれる場合を考慮し、内側のガードは残す。
```

---

### 解決策 3：db:reset 手順の明確化

**対象ファイル**

- `docs/operations/db-workflow.md`（既存ドキュメントに追記）

**方針**

- db:reset はサーバーを止めてから実行する手順を明文化する。
- `bin/rails db:migrate:reset` 後に `bin/rails db:seed` を必ず実行する。
- 開発環境の `Procfile.dev`（または `compose.yaml`）に health
  check を追加して DB が ready になるまでサーバーを起動しない構成を推奨する。

---

## 優先度

| 優先度 | 問題              | 解決策                                      | 影響範囲                                                        |
| ------ | ----------------- | ------------------------------------------- | --------------------------------------------------------------- |
| 高     | A（ブロッキング） | 解決策 1（fail-fast + initializer seeding） | `application_record.rb`, `preference_base.rb`, 新規 initializer |
| 中     | B（90 クエリ）    | 解決策 2（`connected_to` 集約）             | `preference_base.rb`                                            |
| 低     | C/D（運用手順）   | 解決策 3（docs 更新）                       | `docs/operations/db-workflow.md`                                |

## 検証方法

1. サーバーを起動したままブラウザのクッキーをすべて削除 → `/?ri=jp` を開く → 200 OK、かつ 100ms 以内
2. `bin/rails db:migrate:reset` 後（サーバーは起動中）に `/?ri=jp` を開く → タイムアウトせず応答する
3. `bin/rails test test/controllers/core/app/roots_controller_test.rb` が通る
4. `bin/rails test test/controllers/concerns/preference/base_test.rb` が通る
