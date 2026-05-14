# Move CustomerPreference Family to `setting` Database

## Summary

`customer_preferences` 系のテーブル群が現状 `guest` DB に存在しているが、これは役割不一致である。

`guest` DB は contact / 通信権など別目的の actor 関連 DB であり、`com`
セッション側の preference（`com_preferences` 系）は既に `setting`
DB にある。Com に対応する actor 側 preference である `customer_preferences` 系も `setting`
DB に揃えるべきである。

## Motivation

- `setting` DB は preference 専用バブルとして既に `com_preference_*` を保持している。
- `customer_preferences` を `setting` DB に置けば、Com 側（session-side +
  actor-side）の preference がひとつのバブル内で完結し、cross-DB の特殊配慮が減る。
- `guest` DB が contact 系の責務に純化される。
- `Preference::Adoption` が App ↔ User と Org ↔ Staff だけ同 DB（`principal` /
  `operator`）で動くのに対し、Com ↔ Customer だけ DB 跨ぎになっている現状の非対称が解消される。

## Current State (2026-05-06)

### `guest` 配下（移動対象）

- `customer_preferences`（デノーマル: `language`, `region`, `timezone`, `theme`,
  cookie 同意列を直接保持）
- `customer_preference_languages`, `customer_preference_language_options`
- `customer_preference_regions`, `customer_preference_region_options`
- `customer_preference_timezones`, `customer_preference_timezone_options`
- `customer_preference_colorthemes`, `customer_preference_colortheme_options`

### `setting` 配下（既存・近隣に置きたい先）

- `com_preferences` ファミリー（正規化、option_id 外部キー方式）

### コード参照点

- `app/models/customer_preference.rb` — `# Database name: guest` のコメントと暗黙の接続先
- `app/models/customer_preference_*.rb` 8 ファイル
- `app/services/preference/class_registry.rb` — `"Customer"` エントリ
- `app/controllers/concerns/preference/core.rb` — `sync_to_resource_preference!` で `ComPreference`
  → `CustomerPreference` 同期（cross-DB アクセス）
- `app/controllers/concerns/preference/adoption.rb` —
  Customer は対象外（`adoptable_preference_class?` が App/Org のみ true）

## Target State

- `customer_preferences` 系すべてが `setting` DB に存在する。
- `app/models/customer_preference*.rb` の `# Database name: ` コメントが `setting` を指す。
- 接続先の親クラスが `GuestRecord` から `SettingRecord` 系に変わる（または `SettingRecord`
  自体に直接接続する）。
- `Preference::Core#sync_to_resource_preference!` の Com → Customer 同期が同 DB 内で済む。
- `guest` DB から `customer_preference_*` テーブルが削除される（cutover 完了後）。

## Migration Steps (high level)

1. **Schema 移植**:
   - `db/settings_migrate/` に `customer_preferences` 系テーブル作成のマイグレーションを追加。
   - 構造は当面**現状維持**（デノーマルのまま）。正規化に揃えるかどうかは B2（actor-side
     schema 統一）の決定後に別途実施。
2. **モデルの接続先変更**:
   - `app/models/customer_preference*.rb` の親クラスを `GuestRecord` 系から `SettingRecord` に変更。
   - スキーマコメント（`# Database name: guest` → `setting`）を更新。
3. **データ移行**:
   - 既存 `guest` 側のデータを `setting` 側に丸ごとコピーする one-time マイグレーション。
   - `customer_id` は `principal` / `guest` に存在する `customers.id` を参照する application-level
     FK のため、cross-DB 参照のまま（FK 制約なし）。`SettingPreference`
     で先行採用済みのパターンを踏襲。
4. **Cutover**:
   - 読み書き両方を `setting` 側に切り替え。
   - 切替後、guest 側のテーブルを削除するマイグレーションを `db/guests_migrate/` に追加。
5. **検証**:
   - Sign / Apex 各 surface の preference 編集（region / language / timezone / colortheme / cookie
     consent）の integration test が緑であること。
   - `Preference::Core#sync_to_resource_preference!` の Com → Customer 同期が回帰しないこと。
   - JWT `prf` クレームと `Actor::Preference` の整合性が保たれること。

## Out of Scope

- `customer_preferences` の正規化（デノーマル列 → option_id FK 形式）への変更。これは actor-side
  schema 統一（B2）の課題として独立。
- `customer_preferences` 以外の `guest` DB テーブルの整理（contact 系など）。
- `Preference::Adoption` への Customer 追加。これは Adoption の役割再評価（B3）と一緒に判断。
- 新しい preference キーの追加。

## Risks / Notes

- `customer_id` への application-level FK は変わらないが、`customers` テーブルが `guest`
  側にある場合、cross-DB 参照になる点は移動前後で同じ（あるいは増減する）ので、移動前に `customers`
  テーブルの所在を確認する。
- 既存 `customer_preferences` の本番データ件数次第ではメンテナンス時間の確保が必要。
- guest 側テーブル削除はデータ完全移行と読み取り経路の切替確認が完了してから実施する。

## Acceptance Criteria

- [ ] `customer_preferences` 系テーブルが `setting` DB に存在する。
- [ ] `app/models/customer_preference*.rb` の接続先が `setting` になっている。
- [ ] `Preference::Core#sync_to_resource_preference!` が同一 DB 内で完結する。
- [ ] `guest` DB から `customer_preference_*` テーブルが削除されている。
- [ ] preference 編集 / cookie consent / token rotation の回帰テストが緑。

## References

- 関連方針（draft 予定）: `adr/preference-soft-bubble-doctrine.md`
  （DB は別バブルのまま維持、interface だけ `Actor::Preference` で統一）
- 関連 plan: `plans/backlog/legacy-preference-models-retirement-plan.md`（書き直し予定）
- 関連 plan: `plans/backlog/gh578-preference-consolidation.md`（`Actor::Preference` の集約）
- 関連 ADR（既存）: `adr/setting-preference-remove-polymorphic-owner.md`（`SettingRecord`
  採用の前例）

## 2026-05-07 現状差分と改善として残すこと

この計画の主要な DB 移動は現行ツリーでは実装済み。

確認済み:

- `app/models/customer_preference.rb` は `SettingRecord` を継承している。
- `db/settings_migrate/20260506194200_create_customer_preferences_in_setting.rb` が存在する。
- `db/settings_migrate/20260506194300_migrate_customer_preferences_data_to_setting.rb` が存在する。
- `db/guests_migrate/20260506194400_drop_customer_preferences_from_guest.rb` が存在する。

したがって、この文書は「移行計画」としてではなく、移行後の改善チェックリストとして残す。

残す改善:

- `guest` 側 schema / fixture / model comment に `customer_preference*`
  の古い前提が残っていないか確認する。
- `Preference::Core#sync_to_resource_preference!` の Com -> Customer 同期が `setting`
  内で完結していることをテストで固定する。
- `Preference::Adoption` に Customer を加えるかどうかは、この移行とは別の設計判断として扱う。
- `colortheme` -> `theme` の名称整理とは混ぜない。
