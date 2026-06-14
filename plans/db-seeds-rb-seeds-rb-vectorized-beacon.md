# db/seeds.rb 整理: 冗長な参照シードブロックの削除

## Context（なぜこの変更をするのか）

`db/seeds.rb` は現在2つのことをしているが、片方が方針と矛盾している。

このプロジェクトの確定方針は **「参照データ（lookup / status テーブル）は migration に入れる」**
であり、実際そうなっている:

- `db/app_principals_migrate/` 等に `insert_client_identity_statuses_reference_data.rb`、
  `reseed_user_email_status_reference_rows.rb`、`ensure_seed_reference_data_in_operators.rb`
  等、多数の seed/reseed migration が存在し、生 SQL `INSERT ... ON CONFLICT (id) DO NOTHING`
  で参照行を投入している（AGENTS.md「migration 内で app model を使わない」方針通り）。
- 設計根拠は `adr/reference-table-discipline.md`（参照テーブルは PK のみ・`NOTHING` sentinel・
  `id=0` 規約）。投入結果は `db/*_structure.sql` にダンプ済み。

ところが `db/seeds.rb` の 13–67 行は、migration が既に投入しているのと**同じ参照データ**を、 **app
model 経由という別経路**（`ensure_reference_rows` +
`ensure_defaults!`）で重ねて投入している。これは完全に冗長で、まさにプロジェクトが避けたい「二重経路によるドリフト」を生む。

この状態は移行後の **消し忘れ（legacy
leftover）**。`notes/implementation/2026-06-12-oidc-entry-flow-db-bootstrap-repair.md`
には、bootstrap を通すために古い MFA 定数名を直した最小パッチの記録はあるが、整理はされていない。4行目の
`# TODO: by the way, what is the purpose of this file?` も、過去に残された未解決の疑問。

意図する結果: 参照データの所有を migration に一本化し、`seeds.rb`
は本来の用途（開発用サンプルデータの投入）だけを担う状態にする。

## スコープ（確定）

- **削除**: 13–67 行の参照シードブロック全体（`ensure_reference_rows` ヘルパ定義 + その全呼び出し
  - 各モデルの `ensure_defaults!` 呼び出し群）。これらは migration が所有しているため不要。
- **保持**: 69–98 行の開発用サンプル fixture（sample `Client` / `Operator`
  とその email・secret）。これは `return if Rails.env.production?`
  ガード下の、seeds.rb 本来の正当な用途。
- **解消**: 4行目の `# TODO: ...` コメントを、ファイルの目的を説明する正確なコメントに置き換える。

## 変更内容

### 対象ファイル

- `db/seeds.rb`（唯一の変更対象）

### 具体的な編集

1. **4行目の TODO コメントを置換**: ファイルの目的を明記する。例: 「参照データは migration が所有する。このファイルは開発・テスト環境用のサンプル
   `Client` / `Operator`
   fixture のみを投入する（production では no-op）」旨を英語で記述。（リポジトリ言語ポリシー上、コードコメントは英語。）

2. **13–67 行を削除**:
   - `ensure_reference_rows(model_class, ids)` メソッド定義（13–17 行）
   - `ensure_reference_rows(...)` の全呼び出し（20–44 行）
   - `*.ensure_defaults!` の全呼び出し（47–67 行）

3. **8–11 行の sample 定数を確認**: `sample_user_secret` / `sample_staff_*`
   は 69–98 行の fixture が使用しているため**保持**する（削除しない）。

4. **`return if Rails.env.production?`（6行目）は保持**。

### 安全性の確認

- 69–98 行の fixture は `ClientStatus::ACTIVE` / `ClientEmailStatus::VERIFIED` /
  `ClientSecretKind::PERMANENT`
  等の**参照行が存在すること**に依存する。これらは migration が dev/test
  DB に投入するため、参照ブロックを削除しても `db:migrate`
  済みの DB では問題なく動く（これがまさに「migration に所有を一本化する」ことの帰結）。
- 参照行の生成は migration が冪等（`ON CONFLICT DO NOTHING`）に担保しており、seeds 側の二重投入は不要。

## 検証

```bash
# dev: migrate 済み DB で seeds がエラーなく通り、サンプル fixture が作られることを確認
bin/rails db:seed

# サンプル投入の確認（rails runner で存在チェック）
bin/rails runner 'puts Client.find_by(public_id: "sample_user")&.id; \
  puts Operator.find_by(public_id: "2222222222222222")&.id'

# production ガードの確認（no-op であること）
RAILS_ENV=production bin/rails runner 'load Rails.root.join("db/seeds.rb")'
# => 参照行もサンプルも作られない（早期 return）

# 参照データが migration 側で揃っていることの確認（seeds に依存していないこと）
RAILS_ENV=test bin/rails db:drop db:create db:migrate
bin/rails runner -e test 'puts ClientStatus.count; puts ClientEmailStatus.count'
# => DEFAULTS 件数がそろっていること（seed 実行前に migration だけで充足）
```

- スキーマダンプへの影響なし（migration を変更しないため `db:schema:dump` 不要）。
- 必要なら `notes/implementation/`
  に「seeds.rb の参照シードブロックを削除し、参照データの所有を migration へ一本化した」旨の短い handoff
  note を追加（任意）。
