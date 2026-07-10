# Action Policy 認可監査 — 実行計画

## Context

Action
Policy が「大量に存在するだけ」なのか「危険な操作・データ取得経路に実際に効いているのか」を、route →
controller/service → model/query → policy/rule/scope → test まで接続して判定する監査レポートを作る。
**実装変更は行わない。** 成果物は日本語の監査レポート(`memos/`
に日付付きで保存、リポジトリ言語ポリシーのlocalization 例外ではないため本文見出し・構造は英語/日本語混在を避け、ユーザー慣行に従い日本語で書く—
feedback_japanese_docs / feedback_save_plan_reports_to_memos 準拠)。

## 調査で確定済みの事実(Phase 1 完了)

### 前提の訂正

- **Hono・React Router は存在しない**。フロントは Inertia.js + React
  19 のスタブ (`src/pages/base/app/groups/index.tsx`
  1 枚のみ、API 呼び出し・permission フラグ 0)。バックエンドは Rails 単体、バイパス経路なし。→ レポートの Hono/React セクションは「不在の確認根拠 + 認可は全面サーバサイド」の短い節に縮約(ユーザー承認済み)。

### Action Policy の使われ方

- action_policy 0.7.6、initializer なし。
- policy 381 ファイル、単一 `ApplicationPolicy < ActionPolicy::Base` (context:
  `authorize :actor, optional: true` / `authorize :user, optional: true`)。
- DSL 使用状況: relation_scope 10 / alias_rule は base のみ(edit?→update?, new?→create?) /
  scope_for・params_filter・pre_check・default_rule・cache すべて **0**。
- 呼び出し: `authorize!` 162(80 controller)、`allowed_to?` 18、 **ActionPolicy の `authorized_scope`
  使用 0**(grep hit 2 件は OAuth scope の別物)。→ relation_scope 定義 10 件は到達不能の可能性大。
- `verify_authorized` フック 0 — Layer 2 呼び忘れの機械的検出なし。

### 二層認可モデル(docs/architecture/controller-lifecycle.md)

- Layer 1: `enforce_access_policy!`(authentication_base.rb:1774)が action ごとの
  `AUTHENTICATION_MODE`(:deny_all デフォルト/:bare/:open/:private/:guest)を
  `Authentication::AccessPolicy` 経由で判定。未宣言は MissingPolicyError で fail-closed。
- Layer 2: action 内の明示 `authorize!` / `allowed_to?`(record-level)。
- rescue_from ActionPolicy::Unauthorized は全 surface ApplicationController(~13 箇所)+ API base
  controller で標準化。handler は authorization_audit.rb(chronicle 監査記録あり)。
- preference_core.rb:310,342,552,615,640 は Unauthorized を PreferenceOperationError に変換 (403 が汎用エラー化しうる — 監査観点)。

### ギャップ候補(レポートで検証・確定させる)

1. **org staff controller 群が :private 止まりで record-level policy なし**:
   base/org/{audit,iam,system,configurations,billing,support,dashboards}\_controller.rb、base/org/organizations/memberships_controller.rb(CRUD 全 action)。ユーザー判断: スタブでも policy は必須。app/com/org 全 surface で同等に必要 →
   **P1 指摘として記載**。base/app/organizations/memberships_controller.rb も同様。
2. **association scoping を policy 代替にしている session/identity 系**:
   base/_/identity/sessions_controller.rb, revocations_,
   rotations 等 (`current_client.client_tokens` スコープで所有権担保、policy object なし)。
3. **authorized_scope 全面不使用** — index/list 系の scope 認可が存在しない。
4. **verify_authorized 不在** — Layer 2 の網羅性保証がない。
5. base/org/identity/telephones_controller.rb:30,47 の `params(:id)` (method 呼び出し形) 表記 —
   typo 疑い、動作確認。
6. sign-up flow の `Visitor.find_by(...).destroy!` / `where(id:).find_each(&:destroy!)`
   (auth/com/sign/up/emails_controller.rb:279-287)— session 由来 id とはいえ削除経路として要精査。

### テスト

- test/policies 52 ファイル、51 に deny ケース。直接 predicate assert 方式で `assert_authorized_to`
  系 matcher は 0。
- controller test 362 中 93 に deny/guest 系。統合テストに auth flow 系多数。
- test/unit/security/action_policy_usage_test.rb が全 surface の ActionPolicy::Controller include +
  context 配線をピン留め(既存の regression guard)。

### ドメイン

- SNS 要素は avatar graph(avatar_follow/block/mute/group/membership)+ moderation
  (member_avatar_suspension/oversight/visibility)。post/DM/comment は存在しない。
- actor: visitor(com)/client(app)/operator(org staff)/member。routes は 9 ファイル (base
  575 行が最大)、host 制約でリテラル列挙。

## 実行ステップ(レポート作成、コード変更なし)

成果物: `memos/2026-07-03-action-policy-audit.md`(日本語)。以下の順で作る。

### Step 1: Endpoint × Authorization Matrix(完全全数 — ユーザー指定)

- `bin/rails routes` の出力(または route ファイル 9 本の静的解析)から全 route →
  controller#action を機械抽出。
- 各 action について script(grep/ruby ワンライナー)で以下を照合し CSV/表に落とす:
  AUTHENTICATION_MODE(controller 継承含む)、authorize!/allowed_to? の有無と対象 policy、association
  scoping の有無、操作種別(read/list/create/update/delete/admin)、risk 分類。
- 手作業は critical/high 行の検証に集中。全行掲載(low は表の中で明示的に low と分類)。
- controller 747・route directive
  ~1,200 なので、抽出はスクリプトで自動化し、レポートには表全体を載せる(長大になる旨は承認済み)。

### Step 2: Policy 到達可能性マップ(381 policy 全数)

- policy 名 → convention lookup 対象(record class / with: 明示 / dynamic
  `to: :"#{action_name}?"`)をクロス照合するスクリプトを組む。
- 判定: active / maybe active(convention 到達可能)/ dead / risky。単純 grep で dead 断定しない —
  `with:` 明示 249 hit と record 型からの推定を併用。
- relation_scope 10 件は authorized_scope 呼び出し 0 のため全件 dead 疑い — 個別確認。

### Step 3: 認可漏れ候補・policy 品質・テストギャップの精査

- ギャップ候補 1〜6 を file:line・呼び出し経路付きで検証し severity 付け。
- 代表 policy(AccountPolicy, OrganizationPolicy, AvatarPolicy, Avatar{Follow,Block,Mute}Policy,
  Authentication::AccessPolicy, SignIn::CyclePolicy, preference 系)を読み、rule と controller
  action の対応、nil user/guest 扱い、owner/operator 条件、過剰許可を評価。
- deny テストの欠落を matrix の critical/high 行と突き合わせ(blocked/suspended/other-user/
  cross-surface の各ケース)。

### Step 4: レポート組み立て(依頼の 10 セクション構成)

1. 調査前の確認質問 → 解消済みの回答 + 残る仮説として記載
2. 利用状況サマリ表(数値は確定済み)
3. 到達可能性マップ(Step 2)
4. Endpoint × Authorization Matrix 全数(Step 1)
5. 認可漏れ候補(severity 順、修正案はコード変更なしの提案のみ)
6. Policy 品質レビュー
7. テストギャップ表
8. 未使用 policy/rule 候補(confidence 付き)
9. 改善ロードマップ P0〜P4(org/app staff・membership controller への record-level
   policy 義務化を P1、verify_authorized 相当の regression
   guard 追加提案、authorized_scope 導入提案を含む)
10. 追加 docs 提案(docs/authorization-map.md 等 — 提案のみ、作成しない)

### 検証方法

- 数値は grep/スクリプト出力を根拠に再現可能な形でレポートに残す(コマンドは記載、生ログは載せない)。
- 到達可能性判定のうち「dead」判定は、`bin/rails runner`
  等での動的確認はせず、静的根拠(record 型・with: 明示・route 不在)を明記し confidence を付ける。
- コード・テスト・DB には一切変更を加えない。読み取り専用。

## 触るファイル

- 新規: `memos/2026-07-03-action-policy-audit.md`(レポート本体)
- 作業用スクリプト・中間 CSV は scratchpad に置き、コミットしない。
