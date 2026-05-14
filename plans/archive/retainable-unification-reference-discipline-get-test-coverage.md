# 詳細設計: 参照テーブル・GET 200 アサーション・Retainable 統一

## Status

**COMPLETED** (2026-05-08)

実装本体は完了。テスト緑化と E2E 確認のみ別途継続。

達成事項:

- ✅ `Retainable` concern 導入、40 モデルに直接 `include`、12 モデルに concern 経由で推移的適用
- ✅ `ReferenceRecord` concern 導入、95 ファイルで採用
- ✅ 旧カラム (`deletable_at` / `shreddable_at` / `revoked_at` / `refresh_expires_at` /
  `compromised_at` / `expired_at` /
  `scheduled_purge_at`) すべての app コード参照を 0 化、DB スキーマからも drop 済
- ✅ `lapses_at` / `purge_at` 2 軸命名で統一、`Float::INFINITY` sentinel 採用
- ✅ Solid Queue `RetentionPurgeJob` 稼働、`config/recurring.yml` 登録済
- ✅ Verification::Base の 401 バグ (sentinel との不整合) 解消
- ✅ TokenStatusManagement#revoke! の created_at 境界対策 (`[now, created_at].compact.max`) 実装
- ✅ ADR `adr/reference-table-discipline.md` および `adr/retainable-concern-and-retention-purge.md`
  確定

## Related

- **Supersedes**: `plans/archive/gh586-lifecycle-columns-and-partitioning.md`（lifecycle
  column 設計の最終形を本プランで確定）
- **Spin-off**: GitHub issue [#789](https://github.com/seahal/umaxica-apps-global/issues/789)
  (`published_at` rename — 本プラン対象外、別 issue で継続)
- **References**: `adr/secure-jump-link-redirector.md`（`deletable_at`
  の retention 役割を定義、本プランで `purge_at` に rename + `lapses_at` 導入で深化）
- **ADR**: `adr/reference-table-discipline.md`, `adr/retainable-concern-and-retention-purge.md`

## Context

3 系統の設計負債を一括で詰める。

1. **参照テーブルの規律不足** — 68 個の lookup table のうち多くは `record_timestamps = false`
   で日付無しだが、NOTHING 定数の値が 0 / 1 / 11 とバラバラで「未指定 =
   0」という規約が暗黙的にしか運用されていない。`avatar_role_permissions` のような join 系には
   `created_at`/`updated_at` が残存。ADR 化されていない。
2. **正常系 200 の検証欠落** — GET ルート約 287 本に対し、`assert_response :success`
   系の明示的検証は概算 70–75% のテストにしか入っていない。レンダリング内容だけ assert していて 5xx 化を検知できない箇所が散在。
3. **retention / 物理削除カラムの不統一** — 24 モデルが既存カラム `deletable_at` を NOT NULL +
   `Float::INFINITY` sentinel で運用、User/Customer/Avatar/Member/Operator/Staff の 6 モデルは別途
   `shreddable_at` も保持（重複）、JumpLinkable は別 sentinel `Time.utc(9999,...)`
   を使用。3 つの concern (`token_deletable_sync` / `occurrence` /
   `jump_linkable`) が重複機能を持ち、「アクセス不可時刻」概念（後述の `lapses_at`）は未導入。Solid
   Queue の recurring purge は risk occurrences しかカバーしていない。

ゴール:

- 参照テーブル規約を ADR 化、Nothing=0 を全 reference
  model に揃える、関連テーブル (join 含む) からも日付剥奪
- 全 GET ルート想定の controller test に `assert_response :success`（または明示的 redirect）を補強
- `Retainable` concern を導入し、24 モデル + 既存 3 concern を一括で統合、Solid
  Queue の汎用 retention purge job を追加

採用した設計判断（ユーザ回答）:

- 時刻カラムは **NOT NULL + `Float::INFINITY` sentinel** に統一（spec の `IS NULL OR ...`
  は概念で、実装は `> Time.current` 単体）
- ロールアウトは **一括移行 (1 PR)**
- 関連テーブルの日付削除は **join 系含めて厳格適用**
- 200 アサーションは **各 controller test に明示的 `assert_response`**
- **カラム命名**: アクセス不可時刻 (= 論理削除) = `lapses_at`／物理削除候補時刻 =
  `purge_at`。`shreddable_at` は誤綴りではなく正書法だが意味重複のため `purge_at`
  に統合。`lapses_at` は仕様の `inaccessible_at` から変更（自動詞 + `_at` で `expires_at` と同型）。
- **意味論**: `lapses_at` 経過 = 論理削除（クエリでフィルタ、UI 不可視）／`purge_at`
  経過 = 物理削除可能（Solid Queue 回収対象）。通常は
  `lapses_at <= purge_at`（論理削除→物理削除の順）。
- **scope は定義しない**: concern は instance method (`accessible?` / `lapsed?` /
  `purgeable?`) のみ提供。クエリは呼び出し側で raw `where(...)` を書く。理由: 既存モデルの `.active`
  / `.deletable` 等と混乱、scope のチェーンによる予期せぬ条件結合を防ぐため。

---

## Theme 1: 参照テーブル規約

### 設計方針

**規約 (ADR 化対象)**:

1. 参照テーブルは PK のみを持つ。`record_timestamps = false` を全モデルに必須化。
2. 全参照モデルは `NOTHING = 0` を sentinel として持ち、reference data の最初の行は
   `id = 0`、論理的に「未指定 / 不明 / 未設定」を意味する。
3. 参照テーブルへの FK は `default: 0` を持ち、未設定状態を NOTHING 行で表現する（NULLable
   FK は使わない）。
4. 参照テーブル間の join 系テーブル（例:
   `avatar_role_permissions`）も日付カラムを持たない。ライフサイクルは参照データそのものとして扱う。

### 変更対象

- 新規 ADR `adr/reference-table-discipline.md` を追加（規約・Nothing=0・FK default
  0・日付不在の justification）
- `app/models/concerns/` に `reference_record.rb` を追加し、参照モデルの共通動作を集約:
  ```ruby
  module ReferenceRecord
    extend ActiveSupport::Concern
    included do
      self.record_timestamps = false
    end
    class_methods do
      def nothing_id; const_get(:NOTHING); end
      def ensure_defaults!; insert_missing_fixed_ids!(self::DEFAULTS); end
    end
  end
  ```
- 既存 68 reference model のうち、`NOTHING` が 0 でないもの（`NOTHING = 1`、`NOTHING = 11` 等）を
  **既存データとの互換性確認のうえ** 0 に揃える。互換性が崩れる場合は ADR で例外扱いを明記。
- `avatar_role_permissions` 他、参照テーブル間 join から `created_at` / `updated_at`
  を剥奪（migration）。
- `db/seeds.rb` の `ensure_reference_rows()` 呼び出し側で各モデルの `ensure_defaults!`
  を統一的に駆動。

### 重要ファイル

- 新規: `adr/reference-table-discipline.md`
- 新規: `app/models/concerns/reference_record.rb`
- 既存改修: `app/models/application_record.rb` (`insert_missing_fixed_ids!` は既存活用)
- 既存改修: `db/seeds.rb`
- Migration: `db/avatar_migrate/` 配下の join 系から日付カラム drop（avatar_role_permissions 起点）
- 各 reference model 68 件: `include ReferenceRecord` + `NOTHING = 0` 統一

### 留意点

- `NOTHING = 1` / `11`
  を 0 に変える際は、すでに本番に流れている FK 値の再マッピングが必要なケースがある。既存データに対しては
  **ID を変えない** 方針（reference
  data の id は immutable な enum 的扱い）にし、Nothing 行が 0 でない既存モデルは「規約から外れた legacy」として ADR の Exception 節に明記する選択肢も併記。最終決定は migration 設計時に。

---

## Theme 2: GET ルートの 200 アサーション補強

### 設計方針

各 controller test を巡回し、`get` を呼んでいる箇所のうち `assert_response`
系が無い箇所に明示的アサーションを追加する。リダイレクトが期待される箇所は
`assert_response :redirect` にする。

### スコープ見積

- 対象テストファイル: 141（`test/controllers/{apex,sign,jump}/`）
- 修正対象メソッド: 概算 50–100
- 既存パターン: `host!` でホスト設定、`test_helper.rb` の `ActionDispatch::IntegrationTest` を継承

### 進め方

1. `bin/rails routes` で GET ルート全件を抽出 → 一覧化（test 補完の checklist として）
2. `test/controllers/` 配下を grep で `^\s+get\s` を抽出し、後続行に `assert_response`
   が無いものをリストアップ
3. surface (apex/sign/jump) ごとにファイル単位で巡回し、`assert_response :success` または
   `:redirect` を補強
4. 補強と同時に、各テストの host! 設定が ENV 解決後に正しいことを確認（既存
   `test/support/auto_headers.rb` の helper 経由）

### 補強しないテスト

- 認可失敗・404・401 等のテストは既存の `assert_response :unauthorized` 等を維持（変更しない）
- 例外的に redirect が正解な GET（jump リダイレクタ等）は `:redirect` で固定
- 認証必須エンドポイントでログイン無しを試すテストは `:redirect` (sign-in へ) または `:unauthorized`
  を維持

### 重要ファイル

- 改修対象: `test/controllers/apex/**/*_test.rb` (29 ファイル)
- 改修対象: `test/controllers/sign/**/*_test.rb` (141 ファイル) — 主スコープ
- 改修対象: `test/controllers/jump/**/*_test.rb` (5 ファイル)
- 既存ヘルパ活用: `test/support/auto_headers.rb`、`test/test_helper.rb`

### 留意点

- 一括 sed 系の機械置換は危険（リダイレクト系を success に上書きしてしまう）。手動巡回必須。
- 補強と同時に「テストが通る = 200 が返る」ではなく、`assert_response :success`
  が「期待通りの応答」を捕まえる testdouble になることを意識。fixture 不足で偶発的に 500 になっているテストが浮上する可能性あり。

---

## Theme 3: Retainable concern 統一

### 設計方針 (核心)

**全モデルで NOT NULL + `Float::INFINITY` sentinel に統一**。`Retainable`
concern が単一の正解として 24 モデル + 既存 3 concern の機能を吸収する。

### Concern API

```ruby
# app/models/concerns/retainable.rb
module Retainable
  extend ActiveSupport::Concern

  SENTINEL = ::Float::INFINITY

  included do
    attribute :lapses_at, :datetime, default: -> { SENTINEL }
    attribute :purge_at,    :datetime, default: -> { SENTINEL }

    validates :lapses_at, presence: true
    validates :purge_at,    presence: true
    validate  :lapses_at_not_after_purge_at
    validate  :retention_times_not_before_created_at, on: :update

  end

  # NOTE: ActiveRecord scope はあえて定義しない（既存 `.active` / `.deletable` 等の
  #   暗黙挙動と混乱するため）。クエリは raw `where('lapses_at > ?', Time.current)` で書く。

  def accessible?; lapses_at > Time.current; end
  def lapsed?;     lapses_at <= Time.current; end
  def purgeable?;  purge_at  <= Time.current; end

  def schedule_retention!(lapses_at:, purge_at:)
    raise ArgumentError, 'lapses_at must be in the future' if lapses_at <= Time.current
    raise ArgumentError, 'purge_at must be in the future'  if purge_at  <= Time.current
    raise ArgumentError, 'lapses_at must be <= purge_at'   if lapses_at > purge_at
    update!(lapses_at: lapses_at, purge_at: purge_at)
  end

  private

  def lapses_at_not_after_purge_at
    return if lapses_at.blank? || purge_at.blank?
    errors.add(:lapses_at, 'must be <= purge_at') if lapses_at > purge_at
  end

  def retention_times_not_before_created_at
    return if created_at.blank?
    errors.add(:lapses_at, 'must be >= created_at') if lapses_at < created_at
    errors.add(:purge_at,    'must be >= created_at') if purge_at    < created_at
  end
end
```

**設計の含意**:

- spec の `accessible: lapses_at IS NULL OR lapses_at > Time.current` は、sentinel =
  INFINITY のもとで `> Time.current` 単体と意味的に等価（INFINITY >
  now は常に真）。これは ADR で明示する。
- `>= created_at` 検証は `on: :update` のみ（create 時は created_at が nil で参照不能）。
- `schedule_retention!` は ArgumentError を投げる（spec の「例外を出してください」を満たす）。
- 通常 validation には `>= Time.current` を入れない（過去 purge_at を持つレコードが purge
  job 対象になる）。

### カラム統合マップ (C/D 統合方針)

実装読解の結果、TTL / 失効 / retention 系の散在カラムを以下のとおり振り分けます。

#### `lapses_at` に統合

| 旧カラム                          | 対象モデル                                                                                                                                         | 統合根拠                                                                                                                         |
| --------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `revoked_at`                      | verifications (3), authorization_codes (3), tokens (3), jump_links (3), occurrences (9), reauth_sessions (3), preferences (3), single_use_token 系 | `update!(revoked_at: now)` で「以降使用不可」を表現、`lapses_at` と完全同義                                                      |
| `expires_at` (credential variant) | user/staff/customer の verifications, authorization_codes, reauth_sessions, secrets, organization_invitations, post_version                        | `TTL.from_now` で発行時セット、行レベル outer bound                                                                              |
| `refresh_expires_at`              | user_token, customer_token, staff_token                                                                                                            | OAuth refresh ウィンドウ終了 = 行が完全死、`lapses_at` の outer bound として最適                                                 |
| `compromised_at`                  | single_use_token 系                                                                                                                                | `revoked_at` と同等扱い（`where(revoked_at: nil, compromised_at: nil)` パターン）。forensic 区別が必要なら occurrence ログで保持 |

#### `purge_at` に統合

| 旧カラム                               | 対象モデル                                                                                                                            | 統合根拠                                                                |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- | --- | --------------------------------------------------------- |
| `deletable_at`                         | 24+ モデル (前述)                                                                                                                     | 既決                                                                    |
| `shreddable_at`                        | User/Customer/Avatar/Member/Operator/Staff (6)                                                                                        | 既決                                                                    |
| `scheduled_purge_at`                   | User, Customer                                                                                                                        | `withdrawals_controller.rb:140` で `deletable_at                        |     | = scheduled_purge_at` と同値運用、view も同 column を参照 |
| `expires_at` (audit/chronicle variant) | app/com/org*contact_chronicle, *\_document*audit, *\_preference*chronicle, *\_timeline*audit, staff/user_chronicle, *\_activity (13+) | `default: now + 7.years` の retention 期限、純粋に「7年後削除可能」の意 |

#### 削除 (dead column)

| 旧カラム     | 対象モデル                 | 削除根拠                                                                                                                                                                                                                                                                  |
| ------------ | -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `expired_at` | user_token, customer_token | `app/lib/sign/risk/enforcer.rb:32`, `verification/base.rb:185`, `dbsc_helpers.rb:82`, `token_status_management.rb:88` で `column_names.include?("expired_at") ? :expired_at : :revoked_at` の fallback chain でしか参照されず、機能は `revoked_at` と完全等価。過渡期遺物 |

#### 据え置き (sub-state column、行寿命と独立)

| カラム                                               | 対象モデル                                                                             | 据え置き根拠                                                                                                                 |
| ---------------------------------------------------- | -------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `token_expires_at`                                   | contacts (app/com/org), user_social_google, user_social_apple                          | 行に埋め込まれた token の TTL、期限切れ後も行存続・再発行可能。`alias_attribute :expires_at, :token_expires_at` (社外 OAuth) |
| `verifier_expires_at` / `otp_expires_at` (alias)     | contact_email/telephone, identity_email/telephone, user/customer_email, contact_topics | OTP / verifier の TTL、再発行で更新される                                                                                    |
| `expires_at` (token のみ: user/staff/customer_token) | tokens (3)                                                                             | access token TTL（短期 ~1h）、`refresh_expires_at` (=`lapses_at`) が outer bound、これは内側の access 軸として残す           |
| `consumed_at`                                        | authorization_codes                                                                    | 「コードが使用された」事実の記録、retention とは別軸                                                                         |
| `used_at`                                            | single_use_token 系                                                                    | 同上                                                                                                                         |

### Migration 戦略

**Phase A — 新カラム `lapses_at` の追加**:

1. 新規 migration を DB 別に発行（principals/guests/operators/chronicle/settings/redirector/avatar）:
   ```ruby
   add_column :users, :lapses_at, :datetime, null: false, default: -> { "'infinity'" }
   ```
2. 同タイミングで `purge_at` を持たないモデルにも `purge_at`
   を追加（chronicle 系 audit テーブルなど）。
3. PostgreSQL の `timestamp 'infinity'` を使い `Float::INFINITY` に対応（Rails の attribute
   API が型変換）。

**Phase B — 既存物理削除カラムの統合**:

1. **`deletable_at` → `purge_at` rename** (24 モデル):
   ```ruby
   rename_column :users, :deletable_at, :purge_at
   # 同様に customers, staffs, app/org/com_preferences, *_tokens, *_verifications,
   # *_authorization_codes, *_reauth_sessions, *_occurrences, *_jump_links
   ```
2. **`shreddable_at` 統合** (User/Customer/Avatar/Member/Operator/Staff の 6 モデル):
   - User/Customer は `deletable_at` と `shreddable_at` を併用していた → `deletable_at`
     を rename した後、`shreddable_at` の値を `LEAST(purge_at, shreddable_at)` で backfill して
     `shreddable_at` を drop
   - Avatar/Member/Operator/Staff は `shreddable_at` のみ → `rename_column shreddable_at → purge_at`
3. **`scheduled_purge_at` 統合** (User, Customer):
   - `deletable_at` rename 済の `purge_at` に `scheduled_purge_at` の値を backfill
     (`LEAST(purge_at, scheduled_purge_at)` を採用)
   - `scheduled_purge_at` を drop
   - 関連 view
     (`app/views/sign/app/configurations/edit.html.erb`、`sign/com/configurations/edit.html.erb`) で
     `current_user.scheduled_purge_at` 参照を `purge_at` に書き換え
   - `withdrawals_controller.rb`（app/com 両方）の `scheduled_purge_at` 代入を `purge_at`
     代入に書き換え（`||= deactivated_at + 31.days`）
4. **`expires_at` (audit/chronicle variant) → `purge_at` rename** (chronicle 系 13+ テーブル):
   ```ruby
   rename_column :app_contact_chronicles, :expires_at, :purge_at
   # *_chronicle, *_document_audit, *_preference_chronicle, *_timeline_audit, *_activity
   ```
   defalut の `now + 7.years` 表現はそのまま維持（rename だけ）。
5. **JumpLinkable の sentinel 統一**:
   ```ruby
   update_all(purge_at: 'infinity') # WHERE purge_at = '9999-12-31...'
   ```

**Phase C — 失効系カラムの `lapses_at` 統合**:

1. **`revoked_at` の値を `lapses_at` に backfill して drop** (24+ モデル):
   ```ruby
   # 既に lapses_at='infinity' default で生まれている → revoked_at が past であれば LEAST が revoked_at
   execute(<<~SQL)
     UPDATE user_tokens SET lapses_at = LEAST(lapses_at, revoked_at) WHERE revoked_at IS NOT NULL;
   SQL
   remove_column :user_tokens, :revoked_at
   # 同様に *_verifications, *_authorization_codes, *_reauth_sessions, *_occurrences,
   # *_jump_links, *_preferences, *_secrets, single_use_token 系
   ```
2. **`expires_at` (credential variant) の値を `lapses_at` に backfill して drop**:
   ```ruby
   execute(<<~SQL)
     UPDATE user_verifications SET lapses_at = LEAST(lapses_at, expires_at) WHERE expires_at IS NOT NULL;
   SQL
   remove_column :user_verifications, :expires_at
   # 同様に *_authorization_codes, *_reauth_sessions, *_secrets, organization_invitations, post_versions
   # NOTE: tokens (user/staff/customer_token) の expires_at は据え置き
   ```
3. **`refresh_expires_at` の値を `lapses_at` に backfill して drop** (tokens 3 モデル):
   ```ruby
   execute(<<~SQL)
     UPDATE user_tokens SET lapses_at = LEAST(lapses_at, refresh_expires_at);
   SQL
   remove_column :user_tokens, :refresh_expires_at
   ```
4. **`compromised_at` の `lapses_at` 統合** (single_use_token 系):
   ```ruby
   execute(<<~SQL)
     UPDATE single_use_tokens SET lapses_at = LEAST(lapses_at, compromised_at) WHERE compromised_at IS NOT NULL;
   SQL
   remove_column :single_use_tokens, :compromised_at
   # forensic 区別は occurrence ログで保持
   ```
5. **`expired_at` の drop** (user_token, customer_token):
   ```ruby
   # データは revoked_at と等価なので Phase C-1 で既に lapses_at に吸収されている
   remove_column :user_tokens, :expired_at
   remove_column :customer_tokens, :expired_at
   ```

**Phase D — 新 CHECK 制約 + concern 統合**:

1. CHECK 制約を `NOT VALID` で追加 → online で `VALIDATE`:
   ```sql
   ALTER TABLE users ADD CONSTRAINT chk_users_retention_order
     CHECK (lapses_at <= purge_at) NOT VALID;
   ALTER TABLE users VALIDATE CONSTRAINT chk_users_retention_order;
   ```
2. 既存 concern の整理:
   - `app/models/concerns/token_deletable_sync.rb` 削除（機能は `Retainable` +
     token 側 callback に分散）
   - `app/models/concerns/refresh_tokenable.rb` の `refresh_expires_at` 参照を `lapses_at`
     に書き換え、`ensure_refresh_expires_at` を `ensure_lapses_at` にリネーム
   - `app/models/concerns/token_status_management.rb` の
     `expired_at`/`revoked_at`/`refresh_expires_at` 参照を全て `lapses_at` に書き換え、fallback
     chain (`column_names.include?("expired_at") ? :expired_at : :revoked_at`) は不要になるので削除
   - `app/models/concerns/occurrence.rb` / `occurrence_status.rb` の `revoked_at` defaults を
     `lapses_at` に置換
   - `app/models/concerns/jump_linkable.rb` の `FAR_FUTURE` / `revoked_at` / `deletable_at` を全て
     `Retainable` の `lapses_at`/`purge_at` に置換
   - `app/models/concerns/single_use_token.rb` の `revoked_at`/`compromised_at` 参照を `lapses_at`
     に統合
   - `app/models/concerns/secret.rb` の `expires_at` 参照を `lapses_at` に書き換え
3. 24+ モデルすべてに `include Retainable` を追加。

**Phase E — アプリコードの `lapses_at` 化** (Retainable 適用後):

| ファイル                                                                 | 変更内容                                                                                                                                                                    |
| ------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `app/models/{user,staff,customer}_verification.rb`                       | `validates :expires_at` → `validates :lapses_at`、`scope :active` 削除、`active?` を `accessible?` に統合、`issue_for_token!(expires_at:)` → `issue_for_token!(lapses_at:)` |
| `app/models/{user,staff}_authorization_code.rb`                          | 同様。`scope :valid` を呼び出し側で raw `where('lapses_at > ?', now).where(consumed_at: nil)` に展開                                                                        |
| `app/models/{user,staff,customer}_reauth_session.rb`                     | `validates :expires_at` → `lapses_at`、`expired?` → `lapsed?`                                                                                                               |
| `app/models/{user,staff,customer}_secret.rb`                             | `is_expired?` のロジックを `lapsed?` に統合、`Float::INFINITY` チェックは concern に委譲                                                                                    |
| `app/models/organization_invitation.rb`                                  | `expires_at` → `lapses_at`、`scope :active` / `:expired` 削除（呼び出し側が raw where で書く）                                                                              |
| `app/models/post_version.rb`                                             | `validates :expires_at` → `lapses_at`                                                                                                                                       |
| `app/models/concerns/email.rb` / `telephone.rb`                          | `otp_expires_at` (sub-state) は据え置きなので変更不要                                                                                                                       |
| `app/services/auth/current_resource_resolver.rb`                         | `expired_at`/`revoked_at` の二段分岐を削除し `where('lapses_at > ?', Time.current)` 単体に                                                                                  |
| `app/services/oidc/single_logout_service.rb`                             | `update!(revoked_at: now, status: "revoked", ...)` → `update!(lapses_at: now, status: "revoked", ...)`                                                                      |
| `app/services/oidc/token_exchange_service.rb`                            | `refresh_expires_at: REFRESH_TOKEN_TTL.from_now` → `lapses_at: REFRESH_TOKEN_TTL.from_now`                                                                                  |
| `app/services/sign/refresh_token_service.rb`                             | `attrs[:expired_at]` / `attrs[:revoked_at]` → `attrs[:lapses_at]`                                                                                                           |
| `app/lib/sign/risk/enforcer.rb`                                          | `expiry_column` の fallback chain (line 32, 50) を削除し `lapses_at` 直接参照に                                                                                             |
| `app/controllers/concerns/restricted_session_guard.rb`                   | `session.refresh_expires_at` / `session.expired_at` 参照を `session.lapses_at` に統合                                                                                       |
| `app/controllers/concerns/verification/base.rb`                          | `expiry_column` 分岐 (line 185) を削除                                                                                                                                      |
| `app/controllers/concerns/authentication/base/refresh_token_handlers.rb` | 同上                                                                                                                                                                        |
| `app/controllers/concerns/authentication/base/dbsc_helpers.rb`           | 同上                                                                                                                                                                        |
| `app/controllers/sign/{app,com}/configuration/withdrawals_controller.rb` | `scheduled_purge_at` 参照を `purge_at` に統合（line 56, 139, 140, 149）                                                                                                     |
| `app/views/sign/app/configurations/edit.html.erb`                        | `current_user.scheduled_purge_at` → `current_user.purge_at`、INFINITY 判定を追加（表示時は `purge_at != Float::INFINITY` の場合のみ）                                       |
| `app/views/sign/{app,org}/configuration/sessions/index.html.erb`         | `session.refresh_expires_at` → `session.lapses_at`                                                                                                                          |

### Solid Queue retention job

**置き換え対象**: `config/recurring.yml` の `purge_expired_risk_occurrences` の raw
SQL は anti-pattern。

**新設計**:

```ruby
# app/jobs/retention_purge_job.rb
class RetentionPurgeJob < ApplicationJob
  queue_as :retention

  RETAINABLE_MODELS = [
    User, Customer, Staff, AppPreference, OrgPreference, ComPreference,
    UserToken, OperatorToken, CustomerToken,
    UserVerification, OperatorVerification, CustomerVerification,
    UserAuthorizationCode, OperatorAuthorizationCode, CustomerAuthorizationCode,
    UserReauthSession, OperatorReauthSession, CustomerReauthSession,
    AreaOccurrence, UserOccurrence, OperatorOccurrence, ZipOccurrence,
    DomainOccurrence, IpOccurrence, EmailOccurrence, JwtOccurrence, TelephoneOccurrence,
    AppJumpLink, ComJumpLink, OrgJumpLink
  ].freeze

  def perform(batch_size: 500)
    now = Time.current
    RETAINABLE_MODELS.each do |klass|
      klass.where('purge_at <= ?', now).in_batches(of: batch_size).delete_all
    end
  end
end
```

```yaml
# config/recurring.yml
retention_purge:
  class: RetentionPurgeJob
  schedule: every 15 minutes
```

旧 `purge_expired_risk_occurrences` エントリは削除（risk occurrence も `Retainable`
経由で同じジョブが拾う）。

**設計上の注意**:

- `delete_all` を使う（callback skip）。`destroy_all` だと N+1 / dependent
  destroy が走るため大量データで詰む。dependent
  destroy が必要なモデルは個別に override で対応する（現状不要）。
- DB ごとにモデルが分かれている場合（principals / guests / operators / chronicle / settings /
  redirector）、Solid Queue の単一プロセスから複数 connection を踏むことになる → 各 model の
  `connects_to` 設定が effective であることを動作確認。
- model リストは concern 側で `Retainable.included_models`
  のような registry を持たせる選択肢もあるが、明示リストの方が監査しやすい（recommended）。

### Tests (Minitest)

**新規**:

- `test/models/concerns/retainable_test.rb`: instance
  method（accessible?/lapsed?/purgeable?）、validation、`schedule_retention!`
  の正常系・例外系、`>= created_at` 検証、time-zero edge cases、raw `where('lapses_at > ?', now)`
  経由のクエリ
- `test/jobs/retention_purge_job_test.rb`: 各モデルが `purge_at <= now`
  のレコードだけ delete されること、INFINITY のレコードは残ること、batch 境界
- `test/migration/retention_consolidation_backfill_test.rb`: Phase B/C の `LEAST(...)`
  backfill が正しく動くこと、特に User/Customer の
  `deletable_at`+`shreddable_at`+`scheduled_purge_at`
  三重統合、`revoked_at`+`expires_at`+`refresh_expires_at` の token 三重統合、chronicle 系
  `expires_at` の `purge_at` rename を検証

**既存改修**:

- 全モデル test の `deletable_at` 参照を `purge_at` に書き換え（24+ モデル）
- 全モデル test の `revoked_at` 参照を `lapses_at` に書き換え（occurrences, jump_links, tokens,
  verifications, auth_codes, sessions, single_use_tokens, preferences, secrets）
- 全モデル test の `expires_at` 参照を:
  - credential 系 (`*_verification`, `*_authorization_code`, `*_reauth_session`, `*_secret`,
    `organization_invitation`, `post_version`) → `lapses_at`
  - audit/chronicle 系 → `purge_at`
  - **token 系 (`user_token`, `staff_token`, `customer_token`) は据え置き**
- token test の `refresh_expires_at` / `expired_at` 参照を `lapses_at` に統合
- User/Customer/Avatar/Member/Operator/Staff test の `shreddable_at` 参照を `purge_at` に
- User/Customer test の `scheduled_purge_at` 参照を `purge_at` に
- single_use_token test の `compromised_at` 参照を `lapses_at` に
- 24+ モデルの test に `include Retainable` 後の挙動確認（最低限 `accessible?` / `purgeable?`
  の smoke test）
- contact / OAuth social の sub-state column (`token_expires_at`, `verifier_expires_at`,
  `otp_expires_at`) は据え置きなのでテスト変更不要

### 重要ファイル

**新規**:

- `app/models/concerns/retainable.rb`
- `app/jobs/retention_purge_job.rb`
- `adr/retainable-concern-and-retention-purge.md` (sentinel 採用、`lapses_at`/`purge_at`
  命名、scope 不採用、sub-state column 据え置き理由を ADR 化)

**削除**:

- `app/models/concerns/token_deletable_sync.rb` (Phase D で機能分散後)

**改修 (concern)**:

- `app/models/concerns/refresh_tokenable.rb`: `refresh_expires_at` → `lapses_at`
- `app/models/concerns/token_status_management.rb`: `expired_at`/`revoked_at`/`refresh_expires_at`
  の fallback chain を削除、`lapses_at` 単一参照に
- `app/models/concerns/occurrence.rb`, `occurrence_status.rb`: `revoked_at` defaults を `lapses_at`
  経由に
- `app/models/concerns/jump_linkable.rb`: `FAR_FUTURE` / `revoked_at` / `deletable_at`
  削除、`Retainable` include
- `app/models/concerns/single_use_token.rb`: `revoked_at` / `compromised_at` を `lapses_at` に統合
- `app/models/concerns/secret.rb`: `expires_at` → `lapses_at`
- 24+ モデル本体への `include Retainable` 追加と schema annotation 再生成

**改修 (model)**:

- `app/models/{user,staff,customer}_verification.rb`
- `app/models/{user,staff}_authorization_code.rb`
- `app/models/{user,staff,customer}_reauth_session.rb`
- `app/models/{user,staff,customer}_secret.rb`
- `app/models/{user,staff,customer}_token.rb`
- `app/models/{user,customer}.rb` (User の line 159 scope は rename で自然解決)
- `app/models/{staff,operator,avatar,member}.rb`
- `app/models/{app,com,org}_jump_link.rb`
- `app/models/{app,com,org}_preference.rb`
- `app/models/*_occurrence.rb` (全 9 種)
- `app/models/post.rb`, `app/models/post_version.rb`
- `app/models/organization_invitation.rb`
- chronicle 系: `app/models/{app,com,org}_contact_chronicle.rb`, `*_preference_chronicle.rb`,
  `staff/user_chronicle.rb`, `*_activity.rb` 等

**改修 (service / lib / controller / view)**:

- `app/services/auth/current_resource_resolver.rb`
- `app/services/oidc/single_logout_service.rb`, `oidc/token_exchange_service.rb`
- `app/services/sign/refresh_token_service.rb`
- `app/lib/sign/risk/enforcer.rb`
- `app/controllers/concerns/restricted_session_guard.rb`
- `app/controllers/concerns/verification/base.rb`
- `app/controllers/concerns/authentication/base/refresh_token_handlers.rb`
- `app/controllers/concerns/authentication/base/dbsc_helpers.rb`
- `app/controllers/sign/{app,com}/configuration/withdrawals_controller.rb`
- `app/views/sign/{app,com}/configurations/edit.html.erb`
- `app/views/sign/{app,org}/configuration/sessions/index.html.erb`

**改修 (config)**:

- `config/recurring.yml`: `retention_purge` を追加、`purge_expired_risk_occurrences` を削除

**Migration 群** (各 DB ごとに Phase A → B → C → D の 4 段で発行、または 1 つに圧縮):

| DB                                                                  | Migration ファイル                                                | 主処理                                                                                                                                                                                              |
| ------------------------------------------------------------------- | ----------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| principals                                                          | `add_lapses_at_and_consolidate_retention_on_principals.rb`        | User/Customer: `+lapses_at` / `deletable_at→purge_at` / `shreddable_at` 統合 / `scheduled_purge_at` 統合 / `revoked_at`+`expires_at` (関連) 統合                                                    |
| guests                                                              | `add_lapses_at_and_consolidate_retention_on_guests.rb`            | contacts 系（sub-state は据え置き）                                                                                                                                                                 |
| operators                                                           | `add_lapses_at_and_consolidate_retention_on_operators.rb`         | Staff: `+lapses_at` / `deletable_at→purge_at` / `shreddable_at` 統合                                                                                                                                |
| chronicle (audit)                                                   | `rename_expires_at_to_purge_at_and_add_lapses_at_on_chronicle.rb` | audit/chronicle 全 13+ テーブル: `expires_at`(7yr) → `purge_at` rename / `+lapses_at`                                                                                                               |
| occurrences                                                         | `consolidate_retention_on_occurrences.rb`                         | 9 種 \*\_occurrence: `+lapses_at` / `deletable_at→purge_at` / `revoked_at→lapses_at` 統合                                                                                                           |
| settings                                                            | `consolidate_retention_on_preferences.rb`                         | preferences (3): `+lapses_at` / `deletable_at→purge_at` / `expires_at`+`revoked_at` 統合                                                                                                            |
| redirector                                                          | `consolidate_retention_on_jump_links.rb`                          | jump_links (3): `9999` sentinel → `infinity` / `+lapses_at` / `deletable_at→purge_at` / `revoked_at→lapses_at`                                                                                      |
| avatar                                                              | `consolidate_retention_on_avatars.rb`                             | Avatar/Member: `+lapses_at` / `shreddable_at→purge_at`                                                                                                                                              |
| token                                                               | `consolidate_retention_on_tokens.rb`                              | user/staff/customer_token: `+lapses_at` / `deletable_at→purge_at` / `refresh_expires_at→lapses_at` 統合 / `expired_at` drop / `revoked_at→lapses_at` 統合（NOTE: token の `expires_at` は据え置き） |
| mark / symbol (verifications, auth_codes, reauth_sessions, secrets) | `consolidate_retention_on_credentials.rb`                         | `+lapses_at` / `deletable_at→purge_at` / `expires_at→lapses_at` / `revoked_at→lapses_at`                                                                                                            |

---

## Verification

### 単体テスト

```bash
bin/rails test test/models/concerns/retainable_test.rb
bin/rails test test/jobs/retention_purge_job_test.rb
bin/rails test test/models/concerns/reference_record_test.rb  # Theme 1
```

### controller test 全件

```bash
bin/rails test test/controllers/
```

(Theme 2 の補強後、約 287 GET ルートに対応するテストが緑であること)

### Migration の dry-run + rollback

```bash
bin/rails db:migrate
bin/rails db:rollback STEP=N  # N は今回追加する migration 数
bin/rails db:migrate
```

各 DB (principals/guests/operators/chronicle/settings/redirector) で個別に確認:

```bash
bin/rails db:migrate:status
```

### Solid Queue 実機検証

```bash
bin/rails runner '
  u = User.create!(...)
  u.update!(purge_at: 1.minute.ago)  # validation を通す経路で
  RetentionPurgeJob.perform_now
  raise "purge failed" if User.exists?(u.id)
'
```

recurring schedule:

```bash
bin/rails solid_queue:start
# ログで `retention_purge` が 15 分間隔で発火することを確認
```

### C/D 統合の整合性検証

```bash
bin/rails runner '
  # 旧カラムが完全に削除されていること
  removed = {
    UserToken => %w[revoked_at expired_at refresh_expires_at deletable_at],
    UserVerification => %w[revoked_at expires_at deletable_at],
    UserAuthorizationCode => %w[revoked_at expires_at deletable_at],
    AppJumpLink => %w[revoked_at deletable_at],
    User => %w[deletable_at shreddable_at scheduled_purge_at],
    AppContactChronicle => %w[expires_at]
  }
  removed.each do |klass, cols|
    bad = cols.select { |c| klass.column_names.include?(c) }
    raise "#{klass}: 旧カラム残存 #{bad.inspect}" if bad.any?
  end

  # token sub-state は残っていること
  raise "UserToken expires_at が消えた" unless UserToken.column_names.include?("expires_at")
  raise "AppContact token_expires_at が消えた" unless AppContact.column_names.include?("token_expires_at")
  raise "AppContactEmail verifier_expires_at が消えた" unless AppContactEmail.column_names.include?("verifier_expires_at")

  # 新カラムが lapses_at + purge_at で揃っていること
  [User, UserToken, UserVerification, UserAuthorizationCode, AppJumpLink,
   AreaOccurrence, AppPreference, AppContactChronicle].each do |klass|
    %w[lapses_at purge_at].each do |c|
      raise "#{klass}: #{c} が無い" unless klass.column_names.include?(c)
    end
  end
  puts "C/D 統合の整合性 OK"
'
```

### 既存 sentinel データ整合性

```bash
bin/rails runner '
  models = [User, Customer, Staff, AppJumpLink, OrgJumpLink, ComJumpLink]
  models.each do |m|
    bad = m.where("purge_at < ?", "9999-01-01")  # NOT NULL なので IS NULL は不要
    puts "#{m.name}: #{bad.count} 件"  # 0 期待
  end
'
```

### 全体回帰

```bash
bin/rails test
vp test  # JS 側に影響無いはずだが念のため
```

---

## オープン事項

1. **Reference テーブルの `NOTHING = 1` / `11` の扱い**
   — 既存 FK 値の再マッピングが必要なら本 PR スコープ外として ADR の Exception 節に逃がす。最終判断は migration 設計フェーズで。
2. **Token の `expires_at` (access TTL) を据え置く判断** — `lapses_at` (refresh outer
   bound) との 2 段構造を維持。OAuth/OIDC セマンティクスを保持するため。ADR で「token 内側 TTL は sub-state として
   `expires_at` を残す」と明文化。
3. **Solid Queue の DB 横断トランザクション** — 8+
   DB に分散したモデルを 1 ジョブで巡回する際の失敗時 retry 戦略。1 モデル単位で失敗を捕まえてログだけ残し、他モデルは続行する error
   swallowing パターンが必要かも（recommended）。
4. **`compromised_at` の forensic 区別喪失** — single_use_token 系で `compromised_at` を `lapses_at`
   に統合すると、「侵害された /
   revoke された / 自然 expire した」の区別が DB 上から消える。代替として、Single use
   token 侵害時には対応する `*_occurrence` レコード (security
   event ログ) を発行する方針を ADR に明記。
5. **`published_at` の rename** — 過去分詞 + 未来時刻違和感の問題。本 PR 範囲外、issue
   [#789](https://github.com/seahal/umaxica-apps-global/issues/789)
   に分離済み。本会話では再議論しない。
6. **Migration 順序 (Phase A→B→C→D を 1 PR に圧縮するか分割するか)**
   — 本番デプロイのダウンタイムを最小化するなら Phase 別に複数 PR
   / 複数リリースが安全。ただし「一括移行」決定済みなので、staging 環境で全 Phase を一気に流す検証を先行させる。
