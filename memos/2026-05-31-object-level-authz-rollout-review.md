# object-level 認可ロールアウト（PR-11〜19）再評価メモ（2026-05-31）

> exploratory メモ。source of truth ではない。安定・実行可能になったら `notes/` か `plans/`
> へ昇格する。元はプランモードの一時ファイル（`~/.claude/plans/`）として作成し、ユーザー依頼により以後この
> `memos/` 配下へ保存する運用に変更したもの。

## コンテキスト

configuration 面の機微な読み書きエンドポイントへ object-level
ActionPolicy 認可（`authorize!`/`authorized_scope`）を段階導入した PR-11〜PR-19 について、最初から通して「実装が適切か」を再評価した記録。検証は静的解析 + テスト実行（ポリシー単体）。

## 評価結論

**認可実装そのものは適切。ポリシー単体テストはグリーン。**
ただし configuration 結合テストは別作業（post/publisher テーブル rename の in-flight）由来の schema
drift により現時点で実行不能。これは認可作業とは無関係。

## 静的監査（7観点、すべて問題なし）

1. **カバレッジ**: 508 controller 中 63 が `authorize!` 保持。configuration 配下の未カバーは公開
   `*/openid_configurations_controller`（`:bare`、認可不要で正しく除外）と、authorize! 済みコントローラに include される共有 concern のみ。
2. **ポリシールール定義**: 呼び出している全ルールが対応ポリシーに定義済み（deny-all 既定の取りこぼし無し）。`new?→create?`
   `edit?→update?` は `ApplicationPolicy` の alias_rule。
3. **所有者判定**: `owner?` は Client=`user_id` / Operator=`staff_id` / Visitor=`visitor_id`。org の
   `staff_emails`/`staff_telephones` は `class_name: "OperatorEmail/OperatorTelephone"` 関連で
   `Operator*Policy`→`staff_id` に整合。全 controller が `current_<actor>.<assoc>.find_by!`
   の owner-scoped ロード後に authorize → 非所有者は authorize 前に 404（挙動保存）。
4. **到達順序**: body 内 authorize! はアクション先頭。`rescue ActiveRecord::RecordInvalid` /
   `rescue SocialAuth::BaseError` は `ActionPolicy::Unauthorized`
   を捕捉しない。StandardError を rescue する index 系（activities）は before_action ゲート。connections は set→authorize 順。
5. **禁止パターン非混入**: `permit!`/`skip_*`/`rescue nil`/`VERIFY_NONE` ゼロ。
6. **サーフェス非混在**: app/com/org 間の actor 混入ゼロ。
7. **テスト存在**: 全対象ポリシーに owner/非owner 否定アサーション付き単体テスト。org は `staff_*`
   命名（`staff_token_policy_test`→OperatorTokenPolicy 等）。

## テスト実行結果（実測）

- **ポリシー単体 `bin/rails test test/policies` → 425 runs, 1002 assertions, 0 failures, 0
  errors。グリーン。**
- **configuration 結合テスト 46 ファイル: 実行不能。** 全件がフィクスチャ挿入段階で
  `PG::UndefinedTable: relation "app_post_review_statuses" does not exist` により 0
  assertions のまま error（テスト本体未到達）。

## 結合テストが回らない原因（認可作業と無関係）

- working tree に post/publisher テーブル rename
  migration が in-flight（`db/app_publishers_migrate/20260530143000_rename_app_publisher_post_tables_to_model_conventions.rb`
  ほか、05-30 付）。`post_review_statuses → app_post_review_statuses` 等へ改名。
- schema_dump（`*_structure.sql`）が 27 ファイル全て git M（未確定）で、
  `app_publisher_structure.sql` に新名 `app_post_review_statuses` が含まれていない。一方モデル
  `app_post_review_status.rb` とフィクスチャ `app_post_review_statuses.yml`
  は新名で存在 → コード/フィクスチャが dump より先行。
- そのため `bin/db-reset-all test`（dump からロード）が該当テーブル欠落の DB を作り、全 controller
  test がフィクスチャロード失敗。
- AGENTS.md の「rename in-flight 時は
  `migrate → schema_dump 再生成 → db:verify_no_schema_drift`」が post/publisher 側で未完了。認可作業を post/preference 作業と絡めない方針（巻き込み回避）のため、本評価では dump 再生成・他作業の migration 適用は未実施。

## 残アクション

1. configuration 結合テストのグリーン確認は、post/publisher
   rename の schema_dump 再生成後に実施（post 作業の担当範囲）。dump 整合後は
   `bin/db-reset-all test` → 各結合テストを個別実行（ポリシー単体と結合を 1 コマンドに混ぜない）。
2. configuration 面以外（OIDC
   authorize/token、sign-in/up 等）は authn/公開系が主体で object-level 認可対象が薄い。精査するなら別スコープ。
