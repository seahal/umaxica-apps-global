# model concern `included do` 棚卸し + Telephone 小改善

## Context（背景）

このアプリの `app/models/concerns/` には `included do` を持つ concern が 49 件ある。 `validates` /
`scope` / `before_validation` / `encrypts` を `included do` に書くこと自体は Rails
idiomatic であり、controller concern の hidden `before_action` のような security
harness 劣化とは性質が違う。**全面禁止はしない。**

ただし model 層でも、`include`
しただけで多数の責務（正規化・digest・暗号化・OTP・policy・validation）が暗黙登録され、必要カラムが読めない concern がある。これらは可読性・局所性・責務境界・テスト容易性を悪化させるため、改善候補として棚卸しする。

今回の目的は「安全に棚卸しし、設計メモを残し、現状をテストで固定したうえで 1 件だけ小さく改善する」こと。大規模改修・挙動変更・auth/StepUp/OIDC/token/session 周辺の変更はしない。

結論の立て方：

- controller concern の hidden `before_action` は security harness 劣化になりやすい。
- model concern の `included do` は Rails idiomatic なので許容する。
- ただし責務過多・暗黙要求・順序依存が強い model concern は改善対象にする。
- 今回は棚卸し + 現状固定 + Telephone 1 件の小改善に留める。

## 棚卸し結果（分類 A / B / C）

調査コマンド：`rg "included do" app/models app/models/concerns` ほか。

### 分類A: Rails idiomatic / 原則許容（今回は触らない）

- `public_id.rb` — 単一責務。`generate_public_id` +
  presence/length/uniqueness のみ。名前と登録内容が一致。23 モデルが include。**模範例。改善不要。**
- `account.rb` / `identity.rb` / `collective.rb` — `validates :status_id` 等、少数で明快。
- `retainable.rb` / `reference_record.rb` / `social_identifiable.rb` — 単一目的・小さい。
- `has_birthdate.rb` / `version.rb` — `encrypts` + 関連 validation が密結合で目的が明確。

### 分類B: 要注意 / 今後整理候補（今回はメモのみ）

- `email.rb` — 正規化 + blind-index digest + `encrypts` + OTP defaults(`after_initialize`) + policy
  acceptance + pass_code + OTP lock/cooldown 約 220 行。複数責務混在。※ 既に `Requires/Registers`
  ヘッダ・読める callback 名・大きな concern test
  (`test/models/concerns/email_test.rb`) があり、pattern 2/3/4 は概ね適用済み。
- `single_use_token.rb` — `included do` は `scope :active/:unconsumed` のみで軽いが、token rotation
  / consume / DBSC / preference 移送など class
  method が多く責務が広い。auth/token 隣接のため今回は不可侵。
- `refresh_tokenable.rb` — `before_validation` 4 連（family_id / generation / device_session /
  lapses_at）+ device session bind。順序依存あり。token 隣接で不可侵。
- `sign_flow.rb` — state machine + step + TTL + nonce + legacy state sync + Retainable。
  `before_validation` 3 連 + `validate` 6 連。最も重い。auth flow 隣接で不可侵。
- ceremony transactionable 系（`email_ceremony_transactionable.rb` ほか）— scope 多数 +
  surface/operation 整合 validate。パターン化されているが暗黙カラムが多い。

### 分類C: 改善優先

- `telephone.rb` — `email.rb` のほぼ複製だが **`Requires/Registers` ヘッダが無い**。正規化 +
  digest + `encrypts` + OTP defaults(`after_initialize`) + validation + OTP
  lock が混在。暗黙要求カラム（`number`/`number_digest`/`otp_*`）が読めない。concern test
  (`test/models/concerns/telephone_test.rb`) は OTP は厚いが **E164 正規化 / `set_number_digests` /
  `find_by_number`(blind-index) / `with_number` scope を固定していない**。→ **今回の改善対象。**
- `email.rb` + `telephone.rb` の OTP lock 重複（約 80 行）— DRY 候補だが、unlocked
  sentinel が Email=`"infinity"` / Telephone=`"-infinity"` で非対称、`save!` vs
  `save!(validate: false)`、 `otp_last_sent_at`
  の有無も差異あり。**安全な抽出にならないため今回は見送り（next-steps）。**

## 今回の実装（1 件だけ・挙動変更なし）

対象：`app/models/concerns/telephone.rb` と `test/models/concerns/telephone_test.rb`。

### 1. `telephone.rb` に `Requires/Registers` ヘッダコメント追加（pattern 2）

`email.rb:7-25` と同形式で、`module Telephone`
直下（既存の定数定義の前、`include TelephoneNormalization`
付近）にコメントを追加するのみ。**コードは一切変更しない。**

```ruby
# Requires:
# - number
# - number_digest
# - otp_counter
# - otp_private_key
# - otp_attempts_count
#
# Optional:
# - number_bidx
# - otp_last_sent_at  (無い場合 created_at にフォールバック)
#
# Registers:
# - before_validation :normalize_number_from_raw
# - before_validation :set_number_digests
# - scope :with_number
# - after_initialize OTP defaults
# - encrypts :number
# - validate :validate_telephone_number
# - validates :confirm_policy / :confirm_using_mfa / :pass_code
```

callback 名は既に副作用が読める（`normalize_number_from_raw` / `set_number_digests`）ため pattern
3 の改名は不要。

### 2. `telephone_test.rb` に現状固定テスト追加（pattern 4/5）

既存テストは OTP を厚く covers するが、address/number 取り扱いの concern 統合が未固定。以下を
**現状の挙動どおりに** pin する（新規テストのみ追加、既存は変更しない）。include 先は実在モデル
`OperatorTelephone`（既存 setup を踏襲、DB カラム必要なため anonymous model は使わない）。

- `normalize_number_from_raw`: `raw_number=` に非 E164 を渡すと validation 前に E164 化される（例
  `"+1 (234) 567-890"` 系の正規化結果が `number` に入る）。`raw_number` が空なら no-op。
- `set_number_digests`: 保存後に `number_digest`（と `respond_to?` なら `number_bidx`）が
  `IdentifierBlindIndex.bidx_for_telephone` の値で埋まる。
- `find_by_number` / `with_number`: blind-index 経由で既存レコードを引ける／未知番号は `nil` /
  `none`。
- `confirm_using_mfa` acceptance: `email.rb` には無い Telephone 固有の validation を 1 本固定。

注意：normalize 値の期待は `TelephoneNormalization.normalize_to_e164`
の実出力に合わせて確定させる（推測しない）。`telephone_normalization_test.rb`
で実値を確認してから assert を書く。

### やらないこと（不可侵）

- `included do` の削除・`validates`/`scope` の class method 化・`ActiveSupport::Concern` 廃止。
- callback の一括削除・順序変更・validation 意味の変更。
- 暗号化 / digest の生成順序変更・DB schema 変更。
- Service Object 新設。
- auth / 認可 / Step-Up / OIDC / token refresh / cookie / session 周辺。
- `email.rb` / `single_use_token.rb` などへの並行改修（今回は Telephone 1 件のみ）。

## 設計メモ（成果物）

`memos/`
に日付付きフラットファイルで日本語の設計メモを残す（例：`memos/2026-06-15-model-concern-included-do.md`）。内容：

- 上記 A/B/C 棚卸し結果。
- 「model concern の `included do`
  は許容、ただし責務過多・暗黙要求・順序依存は改善対象」という方針。
- OtpLockable 抽出を見送った理由（sentinel 非対称・save! 差異）を記録。

## 検証

```bash
# narrowest first
bin/rails test test/models/concerns/telephone_test.rb
# 広め（concern の include 先確認）
bin/rails test test/models/concerns/email_test.rb test/models/operator_telephone_test.rb
bundle exec rubocop app/models/concerns/telephone.rb test/models/concerns/telephone_test.rb
```

時間が厳しい場合は `telephone_test.rb`
単体実行を最低ラインとする。実行できなかったテストは最終報告で明示する。

## 次回やるべきこと（next-steps）

1. `email.rb` + `telephone.rb` の OTP lock 重複を `OtpLockable` へ抽出する設計検討。
   **前提**：unlocked sentinel（`"infinity"`/`"-infinity"`）と `save!`
   差異を先に統一可否判断。auth 隣接のため独立タスク・要レビュー。
2. `test/models/concerns/email_test.rb`
   の chain-of-thought コメント残骸（おおよそ L381-412）を整理（AGENTS.md のコメント方針・no
   chain-of-thought 違反）。テスト挙動は変えない。
3. 重い分類B（`sign_flow.rb` / `refresh_tokenable.rb`）への `Requires/Registers`
   ヘッダ付与（ドキュメントのみ、auth 隣接なので慎重に）。
