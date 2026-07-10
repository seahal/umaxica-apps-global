# Rails テストスイート全面修復プラン（サブエージェント委任方式）

## Context

`bin/rails test` が大規模に壊れている（本セッションでの実測: **8,759 runs / 297 failures / 362
errors**、実行時間約13分。末尾には edge v0 token
refresh 系の 404（ルーティング未定義）が多数）。原因は単一バグではなく、以下の複合的な作業途中状態:

- **principal→zenith 物理DB統合**（2026-06-30）: マイグレーションパス統合、`operator_accounts`
  テーブル名衝突（解消済みだが余波あり）、`db/*_structure.sql` が全て 448
  byte のプレースホルダで再生成されていない、 `test_com_principal_db` 欠落。
- **routes 大規模書き換え**（`config/routes/auth.rb`, `base.rb`
  ほか）に伴うルーティングテスト群の破損。
- 進行中の withdrawal / OIDC redirect / MFA challenge / welcome-sequence 実装の中途状態。
- `app/auth/callbacks_controller.rb` → `app/oidc/callbacks_controller.rb` 移動。

ゴール: **実装のデグレ・脆弱性・性能低下を起こさずに**
テストを green にする。テストを弱める（skip、assert 削除、mock で本体を潰す）方向の修正は禁止。

## 方針

「テストを直す」のではなく「テストと実装の不一致を、正しい側に合わせて解消する」。判定基準:

1. 現在のコード・アクティブプラン（`plans/active/`）・ADR が意図する挙動 → テストを新挙動に更新。
2. テストが守っている挙動（認証・認可・CSRF・rate-limit・リダイレクト安全性）が実装から欠落 → 実装を修正。
3. 判断がつかないもの → 修正せずレポートに残し、ユーザーに委ねる。

## Phase 0: インフラ修復（直列・自分で実施）

サブエージェント並列実行の前提となる土台。壊れたままだと全 agent が同じ障害で空転する。

1. `bin/rails db:migrate:reset` 相当で全 test
   DB をマイグレーションから再構築（rename 進行中ブランチの規定手順。`docs/operations/db-workflow.md`
   参照）。 `test_com_principal_db` 欠落など DB 起因のエラーをここで根絶する。
2. `db/*_structure.sql` プレースホルダ問題: `schema_format` / `dump_schema_after_migration=false`
   の現状を確認し、fixtures ロードが schema
   dump に依存していないことを確認。依存していれば dump を再生成。
3. `bin/rails test` を再実行し、失敗一覧を `tmp/` にフルログとして保存。

## Phase 1: 失敗の分類（自分で実施）

フルログを解析し、失敗をクラスタに分類する（想定クラスタ、実ログで確定）:

- A. ルーティング系（`test/controllers/base/self_service_routes_test.rb`、org configuration
  routes、edge health routes）
- B. OIDC / callbacks コントローラ移動系
- C. MFA challenge / sign フロー系
- D. withdrawal / welcome-sequence リダイレクト系
- E. モデル・マイグレーション残骸系（zenith 統合の余波）
- F. その他

各クラスタについて「対応する active plan / ADR / note」を紐付けたタスク票を作る。

## Phase 2: サブエージェントへの並列委任（Workflow）

ユーザーが明示的に「ほかの AI
agent に代理させる」ことを要求しているため、Workflow ツールでクラスタごとに修復 agent を並列起動する。

各修復 agent への共通制約（プロンプトに埋め込む）:

- AGENTS.md の Non-Negotiable Rules 厳守。特に `skip_before_action` / `skip_authorization` /
  `permit!` / `rescue nil` / flash 禁止、認証・認可パイプラインの順序変更禁止。
- **テストを弱めない**: skip / assert 削除 / 検証対象の mock 化 /
  placeholder 化は禁止。テストの期待値変更は、対応する plan/ADR が新挙動を裏付ける場合のみ可。
- 性能: N+1 の導入、テスト通過のためだけの余分なクエリ・コールバック追加を禁止。
- 修正のたびに該当ファイルのテストを narrow に実行して確認。
- 判断不能・仕様不明のものは修正せず `needs-decision` として構造化出力で返す。

修復後、クラスタごとに **検証 agent**（adversarial
reviewer）を流し、「セキュリティ低下・実装デグレ・テスト弱体化がないか」を diff ベースでレビューさせる（pipeline:
fix → verify）。

## Phase 3: 統合検証（自分で実施）

1. `bin/rails test` フル再実行。
2. 残失敗があれば Phase 1–2 をイテレート（loop-until-dry）。
3. 最終 diff を `/security-review` 相当の観点で確認（認証・認可・CSRF・rate-limit の変更有無）。
4. `notes/implementation/` に修復内容と `needs-decision` 残件を英語で記録。

## 触る主なファイル（ログ確定後に精緻化）

- `config/routes/*.rb` と対応するルーティングテスト
- `app/controllers/`（oidc/callbacks、mfa、withdrawal、welcome 系）
- `test/controllers/`, `test/integration/`
- `db/` はマイグレーション再構築のみ。**新規の破壊的マイグレーションは書かない**

## 検証方法

- クラスタ単位: `bin/rails test test/path/...`
- 全体: `bin/rails test` が 0 failures / 0 errors
- 弱体化チェック: `git diff` 上で削除された assert / 追加された skip が無いこと
- security: 認証・認可・CSRF 関連の diff を目視 + 検証 agent レビュー

## 未確定事項

- 初回実行はサマリのみ保存されたため、Phase
  0 の再実行でフルログを取得してクラスタ構成を確定する（フル実行は1回約13分。イテレーション中はクラスタ単位の narrow 実行を優先し、フル実行は各ラウンド末尾のみ）。
- `needs-decision` に落ちた仕様判断はユーザーへ報告して終了する。
