# model concern `included do` 棚卸しメモ

日付: 2026-06-15種別: exploratory field note（implementation handoff ではない）

## 背景・結論

`app/models/concerns/` には `included do` を持つ concern が 49 件ある。 `validates` / `scope` /
`before_validation` / `encrypts` を `included do` に書くこと自体は Rails
idiomatic であり、controller concern の hidden `before_action` / `skip_before_action` /
`rescue_from` のような security harness 劣化とは性質が異なる。

結論:

- controller concern の hidden `before_action` 隠蔽は security harness 劣化になりやすい。
- model concern の `included do` は Rails idiomatic なので **許容する（全面禁止しない）**。
- ただし model
  concern でも「include しただけで多数の責務が混入する」「名前から副作用が読めない」「複数ドメイン責務を 1
  concern に詰める」「順序依存が強い」ものは改善対象にする。
- 今回は安全に棚卸しし、テストで現状を固定し、1 件だけ小さく改善した。

## 棚卸し（分類 A / B / C）

### 分類A: Rails idiomatic / 原則許容

- `public_id.rb` — 単一責務（`generate_public_id` +
  presence/length/uniqueness）。23 モデルが include。名前と登録内容が一致。模範例。
- `account.rb` / `identity.rb` / `collective.rb` — `validates :status_id` 等、少数で明快。
- `retainable.rb` / `reference_record.rb` / `social_identifiable.rb` — 単一目的・小さい。
- `has_birthdate.rb` / `version.rb` — `encrypts` + 関連 validation が密結合で目的が明確。

### 分類B: 要注意 / 今後整理候補

- `email.rb` — 正規化 + blind-index digest + `encrypts` + OTP defaults(`after_initialize`) + policy
  acceptance + pass_code + OTP lock/cooldown 約 220 行。複数責務混在。ただし既に
  `Requires/Registers` ヘッダ・読める callback 名・大きな concern test
  (`test/models/concerns/email_test.rb`) があり pattern 2/3/4 は概ね適用済み。
- `single_use_token.rb` — `included do` は `scope :active/:unconsumed` のみで軽いが、token rotation
  / consume / DBSC / preference 移送など class method が多く責務が広い。auth/token 隣接。
- `refresh_tokenable.rb` — `before_validation` 4 連 + device session bind。順序依存。token 隣接。
- `sign_flow.rb` — state machine + step + TTL + nonce + legacy state sync + Retainable。
  `before_validation` 3 連 + `validate` 6 連。最も重い。auth flow 隣接。
- ceremony transactionable 系 — scope 多数 + surface/operation 整合 validate。暗黙カラムが多い。

### 分類C: 改善優先

- `telephone.rb` — `email.rb` のほぼ複製だが `Requires/Registers`
  ヘッダが無く、暗黙要求カラム (`number`/`number_digest`/`otp_*`) が読めなかった。concern
  test は OTP は厚いが E164 正規化 / `set_number_digests` / `find_by_number`(blind-index) /
  `with_number` scope を未固定だった。→ **今回改善。**

## 今回の実装（挙動変更なし・1 件）

- `app/models/concerns/telephone.rb`: `Requires/Registers` ヘッダコメントを追加（pattern
  2）。コードは未変更。`number_bidx` / `otp_last_sent_at`
  は OperatorTelephone に存在しないため「Optional」と明記（concern 側は `respond_to?` ガード済み）。
- `test/models/concerns/telephone_test.rb`: 現状固定テストを 6 件追加（pattern
  4/5）。E164 正規化、digest 付与、`find_by_number` / `with_number`、`confirm_using_mfa`
  acceptance を pin。

検証: `telephone_test.rb` 24 runs / 0 failures、`email_test.rb`+`operator_telephone_test.rb` 62 runs
/ 0 failures、rubocop 2 files no offenses。

## OtpLockable 抽出を見送った理由（重要）

`email.rb` と `telephone.rb` は OTP
lock/cooldown/attempt のロジック約 80 行がほぼ重複しており DRY 候補だが、以下の差異があるため「安全な小改善」にはならない。共通 concern 化は独立タスク・要レビューで行うこと（前提を先に統一可否判断する）。

- unlocked sentinel が **非対称**: Email = `"infinity"`、Telephone = `"-infinity"`。
- `increment_attempts!` の保存が **Email=`save!` / Telephone=`save!(validate: false)`** で異なる。
- `otp_last_sent_at` カラムの有無: Email は前提、Telephone は `respond_to?` で `created_at`
  にフォールバック。
- OTP は auth 隣接のため、挙動を 1 ビットでも動かすと verification flow に波及する。

## 次回やるべきこと

1. `OtpLockable` 抽出の設計検討（上記差異の統一可否を先に判断）。
2. `test/models/concerns/email_test.rb`
   の chain-of-thought コメント残骸（おおよそ L381-412）整理。AGENTS.md のコメント方針・no
   chain-of-thought 違反。テスト挙動は変えない。
3. 重い分類B（`sign_flow.rb` / `refresh_tokenable.rb`）への `Requires/Registers`
   ヘッダ付与（ドキュメントのみ、auth 隣接なので慎重に）。
