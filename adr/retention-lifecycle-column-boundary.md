# Retention 列と Lifecycle 列の境界

## ステータス

Accepted (2026-05-25)

## 文脈

`adr/retainable-concern-and-retention-purge.md` で retention 列は `discarded_at` (論理削除) と
`purged_at` (物理削除候補時刻) の 2 列に統一すると決定済みであり、 `Retainable` concern
(`app/models/concerns/retainable.rb`) と `RetentionPurgeJob`
(`app/jobs/retention_purge_job.rb`) として実装されている。

しかし以下の不整合が現存する。

1. `clients` テーブルだけが旧名 `deletable_at` を残し、同テーブルに `purged_at` と `discarded_at`
   も併存している (`db/app_principal_schema.rb`)。`RetentionPurgeJob` は `purged_at`
   しか参照しないため `deletable_at` は dead column である。
2. `SignUp::Cancellation` および `SignUp::ArtifactCleanup` に
   `attrs[:deletable_at] = purged_at if record.has_attribute?(:deletable_at)`
   の防御コードが残っており、上記 dead column のためだけに分岐が生きている。
3. `clients` テーブルには retention 列以外にも `withdrawn_at`, `deactivated_at`, `terminated_at`,
   `withdrawal_started_at`
   といった lifecycle 系の時刻列が並ぶ。これらを retention 列の派生として扱うと、退会・停止・匿名化のドメイン意味が削除概念と混線し、worker と service が誤って消す事故を招く。
4. `RefreshTokenable` concern には `default_lapses_at` という method が残り、ドメイン語の
   `lapses_at` を `discarded_at`
   列に書き込む。語彙としては有用だが、DB 列名と概念名の対応関係が ADR で明文化されていない。

retention の正本は決定済みだが「**何が retention 列で何がそうでないか**」と「ドメイン語の alias
method をどう扱うか」が定義されておらず、上記 drift が温存される根本原因になっている。

## 決定

### 1. retention 列は 2 つだけ

retention に分類される DB 列は次の 2 列に限定する。これ以外の名前で retention 用列を新規追加してはならない。

| 列名           | 意味                                                                                   | 型       | デフォルト        | NULL     | 既定値の挙動                 |
| -------------- | -------------------------------------------------------------------------------------- | -------- | ----------------- | -------- | ---------------------------- |
| `discarded_at` | 論理削除タイムスタンプ。`<= now` で「もう参照しない」                                  | datetime | `Float::INFINITY` | NOT NULL | Infinity の間は accessible   |
| `purged_at`    | 物理削除可能タイムスタンプ。`<= now` で `RetentionPurgeJob` が `delete_all` 対象に拾う | datetime | `Float::INFINITY` | NOT NULL | Infinity の間は purge 対象外 |

不変条件:

- `discarded_at <= purged_at` を DB check constraint で強制 (`chk_<table>_retention_order`)
- 両者ともに `>= created_at` を model
  validate で強制 (`Retainable#retention_times_not_before_created_at`)

### 2. lifecycle 列は retention 列と別概念として共存する

以下の列は actor
lifecycle の意味を持ち、**retention 列ではない**。retention 列と意味を混ぜず、それぞれ独立に更新する。

| 列名                    | テーブル     | 意味                                                             | retention との関係                                                                                      |
| ----------------------- | ------------ | ---------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| `withdrawn_at`          | `clients` 他 | withdrawal cycle 完了タイムスタンプ。退会済みであることのみ示す  | 退会完了は論理削除ではない。法令保管期間中は `discarded_at` は Infinity のまま、`withdrawn_at` のみ立つ |
| `withdrawal_started_at` | `clients` 他 | 退会フロー開始時刻                                               | flow sequencing 専用。retention には影響しない                                                          |
| `deactivated_at`        | `clients` 他 | 運営判断による無効化時刻                                         | 停止は削除ではない。再有効化があり得る                                                                  |
| `terminated_at`         | `clients` 他 | `RetentionPurgeJob#anonymize_accounts` による PII 匿名化完了時刻 | 物理削除の直前ステップ。`terminated_at` 設定後も `purged_at <= now` でなければ row は残る               |

これらの列を新規導入する場合は、退会・停止・匿名化など
**削除そのものではない lifecycle 事象**であることを明示する命名を選び、retention 列の意味と明確に切り分ける。`discarded_at`
/ `purged_at` をこれらの導出として書くパターンも禁止する (例: 「退会したら自動で
`discarded_at = now`」のような暗黙連動)。

### 3. ドメイン語の alias は model instance method で表現する

`discarded_at` の意味をドメイン語で呼びたい場合 (例: refresh
token の「失効」、verification の「期限切れ」、authorization code の「revoke」)、 **DB 列は
`discarded_at` 一本のまま**、model instance method で alias を提供する。

```ruby
class ClientRefreshToken < AppTicketRecord
  include Retainable

  def lapses_at         = discarded_at
  def lapses_at=(value) = self.discarded_at = value
end
```

新規列を切らない理由:

- 列が増えると `RetentionPurgeJob` の scan 対象が分岐し、漏れの原因になる
- check constraint と index policy が列ごとに重複する
- `Retainable` concern の単一インターフェースを利用できなくなる

### 4. index policy

retention 列の index は以下を標準とする。

- `discarded_at`: 単独 b-tree index (`index_<table>_on_discarded_at`)
- `purged_at`: **partial** b-tree index (`index_<table>_on_purged_at` with
  `WHERE purged_at < 'infinity'`)。`purged_at = Infinity` の行が大多数のテーブルで full index は無駄

retention 列以外の lifecycle 列の index は別途決める。原則は partial index
(`WHERE <col> IS NOT NULL`)。

### 5. 物理削除 worker の単一責任

物理削除は `RetentionPurgeJob` のみが行う。サービス層や controller は `purged_at`
への時刻設定までを行い、判定 (`where(purged_at: ..now)`) と削除 (`delete_all`) は worker の専管とする。

例外として、`Withdrawal::PersonalDataAnonymizer` などの匿名化は worker が `delete_all`
前に呼び出すが、これは PII 削除 (anonymization) と row 削除 (purge) を別ステップに分けるための整理であり、retention 判定ロジックの分散ではない。

### 6. 禁止語彙

retention 用 DB 列として以下の名前を新規導入してはならない (過去に使われ、正式に廃止された語彙):

- `deletable_at`
- `shreddable_at`
- `scheduled_purge_at`
- `expired_at` (audit 系では `purged_at`、credential 系では `discarded_at` へ統合済み)

過去に表れた `lapses_at` は **DB 列としては禁止**だが、ドメイン語の **instance
method 名としては許可**する (第 3 項)。

### 7. 新規 retainable テーブルの規定

新規に retention 管理対象テーブルを追加する migration は次を必ず守る。

- `t.datetime :discarded_at, default: ::Float::INFINITY, null: false`
- `t.datetime :purged_at, default: ::Float::INFINITY, null: false`
- `add_check_constraint :<table>, "discarded_at <= purged_at", name: "chk_<table>_retention_order"`
- `add_index :<table>, :discarded_at`
- `add_index :<table>, :purged_at, where: "purged_at < 'infinity'"`
- model 側に `include Retainable`
- `RetentionPurgeJob::RETAINABLE_MODELS` への追加

## 帰結

- 既存 ADR `adr/retainable-concern-and-retention-purge.md` の決定 (列の 2 本化、Retainable
  concern、RetentionPurgeJob) はそのまま有効。本 ADR はその境界と運用ガイドを補強する。
- `clients.deletable_at` は本 ADR の決定に違反する dead column であり、撤去対象として
  `plans/backlog/retention-vocabulary-drift-cleanup.md` で扱う。
- `SignUp::Cancellation` / `SignUp::ArtifactCleanup` の `has_attribute?(:deletable_at)` 分岐は dead
  column への防御コードであり、上記 plan で削除する。
- `RefreshTokenable#default_lapses_at` は第 3 項の alias method 規則に従う実装例として残置する。doc
  comment で「`discarded_at` 列へのドメイン語alias」であることを明記する。
- lifecycle 列 (`withdrawn_at` 等) の意味と運用は別 ADR
  / 別 plan で扱う。本 ADR は retention 列との境界のみを定める。
- 過去の英語 ADR `adr/retainable-concern-and-retention-purge.md` の日本語化とクラス名更新 (`User` →
  `Client` 等) は別タスクとして扱い、本 ADR の範囲外とする。
