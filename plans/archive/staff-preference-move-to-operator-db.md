# Move StaffPreference Family to `operator` Database

## Status

Completed (2026-05-07).

> **Completion notes (2026-05-07):**
>
> - All 9 `staff_preference_*` tables exist in the `operator` DB:
>   `db/operators_migrate/20260506020000_create_staff_preferences_in_operator.rb` creates the
>   schema; `db/operator_schema.rb` is the dump.
> - Data migration:
>   `db/operators_migrate/20260506210800_migrate_staff_preferences_data_to_operator.rb`.
> - Principal-side drop:
>   `db/principals_migrate/20260506210900_drop_staff_preferences_from_principal.rb`.
> - All 9 model files (`app/models/staff_preference*.rb`) inherit from `OperatorRecord` and carry
>   `# Database name: operator`.
> - The Org↔Staff sync path in `Preference::Adoption` and
>   `Preference::Core#sync_to_resource_preference!` now operates within a single DB (`operator`).
> - `Preference::Adoption#resolve_cross_db_option_id`
>   (`app/controllers/concerns/preference/adoption.rb:131,148`) still exists — this is the
>   intentional out-of-scope follow-up. Its removal is paired with the customer-side move
>   (`plans/backlog/customer-preferences-move-to-setting-db.md`); once both are landed, the helper
>   becomes dead code and can be removed in a separate retirement pass.

## Summary

`staff_preference_*` 系のテーブル群が現状 `principal` DB に残置されている。これは org
TLD バブルの完結性を阻害しており、`Staff` 本体（`operator`）と
`StaffPreference`（`principal`）の DB が分かれている唯一の不整合である。`operator` DB に統一する。

これは `customer-preferences-move-to-setting-db.md` と並列の作業（com TLD のために customer
preference を guest → setting に移すのと同じ構造を、org TLD のために principal →
operator で実施する）。

## Motivation

### org TLD バブルの完結

`adr/preference-soft-bubble-doctrine.md` で確認した「TLD
blast-radius を抑えるために 3 バブルに分割した」設計に対し、現状 org
TLD だけがバブル境界を跨いでいる:

| TLD | 匿名 preference | actor preference    | actor 本体                          | actor 認証情報 |
| --- | --------------- | ------------------- | ----------------------------------- | -------------- |
| app | principal ✓     | principal ✓         | principal ✓                         | principal ✓    |
| com | setting ✓       | setting ✓（移植中） | guest（com 認証 DB として意図通り） | guest ✓        |
| org | operator ✓      | **principal** ✗     | operator ✓                          | operator ✓     |

`staff_preference_*` を `operator` に移すと org TLD 全体が `operator` で完結する。

### Login 時 double-write の cross-DB 解消

`Preference::Adoption` および `Preference::Core#sync_to_resource_preference!`
は、ログイン時とおこのみ更新時に session-side と actor-side を双方向同期する。現状:

- app: `principal.app_preferences` ↔ `principal.user_preferences` — 同 DB
- com: `setting.com_preferences` ↔ `setting.customer_preferences`（移植後）— 同 DB
- **org**: `operator.org_preferences` ↔ **`principal.staff_preferences`** — **DB 跨ぎ**

その対処のために `Preference::Adoption#resolve_cross_db_option_id`
が存在し、option_id を名前で再解決している（DB が違うと option テーブルの ID 連番が一致しないため）。本移植が完了すれば org も同 DB 内 sync になり、`resolve_cross_db_option_id`
経路は不要になる。

### DB 制約の追加余地

現状 `staff_preferences.staff_id` は app-level FK にとどまる（`staffs` が `operator` にあり
`staff_preferences` が `principal`
にあるため、DB 制約を貼れない）。移植後は同 DB に揃うので、`staffs.id` への DB-level
FK を追加できる（これは別件として扱ってよい）。

## Current State (2026-05-06)

### `principal` 配下（移動対象、9 テーブル）

- `staff_preferences`（親）
- `staff_preference_languages`, `staff_preference_language_options`
- `staff_preference_regions`, `staff_preference_region_options`
- `staff_preference_timezones`, `staff_preference_timezone_options`
- `staff_preference_colorthemes`, `staff_preference_colortheme_options`

これらの DB-level FK は `staff_preference_<child>` → `staff_preferences` および
`staff_preference_<child>` → `staff_preference_<child>_options` の internal リンクのみ。 `staffs`
への DB-level FK は無い（cross-DB なので app-level のみ）。

### `operator` 配下（既存・近隣に置きたい先）

- `staffs`（actor 本体）
- `staff_passkeys`, `staff_emails`, `staff_telephones`, `staff_secrets` 等（認証情報）
- `org_preferences` 系（session-side preference）
- `staff_org_preferences`（ブリッジ、現在 `org_preference_id` → `org_preferences`
  の FK あり、`staff_id` は app-level FK）

### モデル参照点

- `app/models/staff_preference.rb` —
  `# Database name: principal`、`class StaffPreference < PrincipalRecord`
- `app/models/staff_preference_language.rb` 他 8 ファイル — 同様に `PrincipalRecord` 継承
- `app/models/staff.rb` — `has_one :staff_preference, dependent: :destroy`
- `app/services/preference/class_registry.rb` — `"Staff"` エントリ
- `app/controllers/concerns/preference/adoption.rb` — `find_resource_preference` で
  `resource.staff_preference` を参照（適応経路は OrgPreference ↔ StaffPreference）
- `app/controllers/concerns/preference/adoption.rb` — `resolve_cross_db_option_id` ヘルパーが org
  TLD のために存在している（移植後は org TLD では未使用になる）

## Target State

- `staff_preferences` 系すべてが `operator` DB に存在する。
- `app/models/staff_preference*.rb` の `# Database name:` コメントが `operator` を指す。
- 親クラスが `PrincipalRecord` から `OperatorRecord` に変更されている。
- `Preference::Adoption` の Org↔Staff 経路が同一 DB 内で済む。
- `principal` DB から `staff_preference_*` テーブルが削除される（cutover 完了後）。

## Migration Steps (high level)

1. **Schema 移植**:
   - `db/operators_migrate/` に `staff_preferences` 系 9 テーブル作成のマイグレーションを追加。
   - 構造は当面**現状維持**（正規化スキーマ・option_id 外部キー方式のまま）。
   - 内部 FK（`staff_preference_<child>` → `staff_preferences`、`<child>` →
     `<child>_options`）は同 DB なのでそのまま再現。
   - **追加の改善**として、新 `operator.staff_preferences.staff_id` に対し
     `add_foreign_key :staff_preferences, :staffs`
     を追加してよい（同 DB で可能）。これは本作業に含めるか分離するかは実装者判断。
2. **モデルの接続先変更**:
   - `app/models/staff_preference*.rb` 全 9 ファイルで:
     - 親クラス `PrincipalRecord` → `OperatorRecord`
     - スキーマコメント `# Database name: principal` → `operator`
3. **データ移行**:
   - `principal.staff_preferences` 系全 9 テーブルから `operator.staff_preferences`
     系にデータを丸ごとコピーする one-time マイグレーション。
   - `staff_id` は app-level FK のため cross-DB 参照は移動前後で同じ。
   - option テーブル（`staff_preference_language_options`
     等）は静的シードに近いので id を保ったままコピー、子テーブル（`staff_preference_languages`
     等）も `option_id` を保ったままコピーすれば整合する。
4. **Cutover**:
   - 読み書き両方を `operator` 側に切り替え（モデル修正で自動的に切り替わる）。
   - 切替後、`db/principals_migrate/` に `staff_preference_*`
     9 テーブルを drop する post-cutover マイグレーションを追加。
   - drop 順序は内部 FK に注意（子テーブル → 親テーブル → option テーブルの順）。
5. **検証**:
   - Sign / Apex 各 surface（org / sign-org）の preference 編集（region / language / timezone /
     colortheme）の integration test が緑であること。
   - `Preference::Adoption` の Org→Staff 同期が回帰しないこと（login 時に `org_preferences` と
     `staff_preferences` の updated_at 比較とコピーが同 DB 内で成功する）。
   - `Preference::Core#sync_to_resource_preference!`
     の OrgPreference→StaffPreference 経路が回帰しないこと。
   - JWT `prf` クレームと `Current::Preference` の整合性が保たれること（org TLD で login →
     preference 更新 → token 再発行）。

## Out of Scope

- `staff_preferences` の構造変更（正規化からデノーマル化、あるいは逆）。これは B2（actor-side
  schema 統一）の課題として独立。
- `Preference::Adoption#resolve_cross_db_option_id`
  自体の削除。本移植後はこの経路を使うコードが居なくなるが、`customer_preferences`
  移植 plan と整合させて C3 / 撤去 plan で扱う（dead-code としての扱い）。
- `staff_org_preferences` ブリッジの設計見直し。現状で同 DB 内に収まっているので本件では触らない。
- token DB 周り（mark / symbol / token）には触らない。
- `staffs` への DB-level
  FK 追加が範囲内かどうかは実装者判断（本作業に含めても、別 patch にしてもよい）。

## Risks / Notes

- option テーブル（`staff_preference_language_options`
  等）は ID を保ったままコピーする必要がある。コードが定数（`StaffPreferenceLanguageOption::JA`
  等）で ID を直接参照しているため、新旧で ID が一致していないと回帰する。
- `Preference::Adoption#resolve_cross_db_option_id`
  が「name で再解決」していたのはまさに ID が一致していないケースを救済するためなので、移植時にこのヘルパーを使えば片付くが、ID を保てるならそちらの方が単純。
- 既存 `staff_preferences` の本番データ件数次第ではメンテナンス時間の確保が必要。
- principal 側 drop migration はデータ完全移行と読み書き経路の切替確認が完了してから実施。

## Acceptance Criteria

- [ ] `staff_preference_*` 系 9 テーブルが `operator` DB に存在する。
- [ ] `app/models/staff_preference*.rb` 9 ファイルの親クラスが `OperatorRecord`、schema コメントが
      `operator`。
- [ ] `Preference::Adoption` の Org↔Staff 同期が同一 DB 内で完結する。
- [ ] `principal` DB から `staff_preference_*` 9 テーブルが削除されている。
- [ ] org TLD の preference 編集 / cookie consent / token rotation の回帰テストが緑。
- [ ] login 時の double-write（`AppPreference`↔`UserPreference`、
      `OrgPreference`↔`StaffPreference`、`ComPreference`↔`CustomerPreference`）がすべて同 DB 内で完結する。

## References

- `adr/preference-soft-bubble-doctrine.md` — DB は別バブルのまま、interface だけ統一という基本方針
- `plans/backlog/customer-preferences-move-to-setting-db.md` — 同パターンの先行/並列作業（com TLD:
  guest → setting）
- `plans/backlog/legacy-preference-models-retirement-plan.md` — 全体の retirement ロードマップ
- `app/services/preference/class_registry.rb` — `"Staff"` エントリ
- `app/controllers/concerns/preference/adoption.rb` — `resolve_cross_db_option_id`
  を含む double-write ロジック
- `app/controllers/concerns/preference/core.rb` — `sync_to_resource_preference!` の OrgPreference →
  StaffPreference 経路
- `app/models/staff.rb` — `has_one :staff_preference`
