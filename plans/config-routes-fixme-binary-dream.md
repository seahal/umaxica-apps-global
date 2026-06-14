# config/routes FIXME 分析

## Context（なぜこの分析か）

`config/routes/` 配下のルートファイルにはコメントと `FIXME`
が多数残っている。ユーザ依頼は「コメントと FIXME を読んで分析する」こと。本ドキュメントは全 FIXME を分類し、各々が
**正しいか / 誤りか / 既に陳腐化(stale)か**
を実コードと Rails の規約に照らして判定し、適切な対応方針を提示する。実装は未着手（分析のみ）。

対象ファイル: `config/routes/acme.rb` `base.rb` `core.rb` `sign.rb` （`docs.rb` `help.rb` `news.rb`
`palm.rb` に FIXME は無し）

---

## 分類サマリ

| カテゴリ                           | 件数 | 内容                                        | 判定                   |
| ---------------------------------- | ---- | ------------------------------------------- | ---------------------- |
| A. `remove :controller` (health)   | 9    | `resource :health, controller: "health"`    | **誤り**（削除不可）   |
| A. `remove :controller` (account)  | 2    | `resource :account, controller: "accounts"` | 正しい（削除可）       |
| A. `remove :controller` (core sso) | 1    | 対象に `:controller` が存在しない           | **陳腐化**（対象不在） |
| B. `smarter naming`                | 約25 | コマンド/状態遷移の副リソース命名           | 要・設計判断           |
| C. `rename to "secrets"`           | 1    | `emergency_key` → `secrets`                 | 改名先明示済み         |
| D. `REMOVE THIS!!!`                | 1    | sign/com の `r18` namespace                 | 要・確認               |
| E. `hate this env variable`        | 1    | `ACME_CORPORATE_URL` の localhost fallback  | surface 設計依存       |
| F. `Check entrypoints needed`      | 1    | acme app settings sessions collection       | 要・使用調査           |
| G. regional net/dev endpoint       | 2    | core に net/dev surface 未実装              | 要・新規実装           |

---

## カテゴリ A: `# FIXME: remove :controller. I thought non- sense.`

**重要な発見 — このコメントは health については誤り。**

Rails では**単数リソース `resource :foo` も既定でコントローラ名を複数形に解決する**
（`resource :photo` → `PhotosController`）。

### A-1. health（9箇所）— 削除すると壊れる

箇所: `core.rb:10,59,108` / `base.rb:9,26,43` / `acme.rb:287,409,425`

```ruby
resource :health, only: :show, controller: "health"
```

- 既定では `resource :health` → `HealthsController`（複数形）を探す。
- 実在するのは `*/health_controller.rb`（**単数形のみ**、`healths_controller.rb` は存在しない）。
- よって `controller: "health"` は**規約上書きとして必須**。削除するとルーティングが壊れる。
- 対応: **コメント（FIXME）を削除し、なぜ override が必要かを 1 行で説明する**コメントに置換。例:
  `# resource は既定でコントローラを複数形解決するため、HealthController を指すには明示が必要。`

### A-2. account（2箇所）— FIXME は正しい、削除可

箇所: `acme.rb:243`（com）, `acme.rb:372`（org）

```ruby
resource :account, only: :show, controller: "accounts"
```

- `resource :account` は既定で `AccountsController`（複数形）を解決する。
- 実在は `accounts_controller.rb`（複数形）。→ `controller: "accounts"` は**冗長**。
- 対応: `, controller: "accounts"` を削除可能。`resource :account, only: :show`
  で同一に解決。（`acme.rb:115` の app surface は既に `controller: "accounts"`
  付き → ここも同様に整理可）

### A-3. core sso authorization（1箇所）— 陳腐化、対象不在

箇所: `core.rb:145`（org surface の `namespace :sso`）

```ruby
# FIXME: remove :controller. I thought non- sense.
resource :authorization, only: :show, path: "authorize"
```

- この行には `:controller` オプションが**そもそも無い**。FIXME の指す対象が存在しない。
- `AuthorizationsController` は既定解決で OK（`core/org/sso/authorizations_controller.rb` 実在）。
- 対応: **FIXME コメントを削除**（誤って貼られた残骸）。

---

## カテゴリ B: `# FIXME: I want to rename this much smarter naming.`（sign.rb のみ・約25箇所）

非冪等コマンド/状態遷移を REST 化するための「コマンドリソース」命名で、ユーザがより良い名前を求めている。対象の命名群:

- `session_cancellation`（107, 323, 475）
- `connection_attempt` / `disconnection_attempt`（124, 126, 132, 134）
- `redelivery`（164）
- `removal_attempt`（178, 205, 352, 380, 501）
- `telephones` scope（191, 369, 528）
- `rotation_attempt`（202, 379）
- `revocation_attempt`（208, 385, 516）
- `secret_credential`（320, 472）
- `check_cancellation`（327, 479）
- `session_revocations` namespace（388）

**分析:** いずれも標準 CRUD で表せないアクション（取消・試行・回転・失効・再送）を `*_attempt` /
`*_cancellation` / `*_revocation`
の専用リソースに切り出したもの。Rails 的には妥当なイディオムだが、名前が動詞句的で冗長。改善方向は主に 2 つ:

1. 接尾辞を外し名詞コマンドリソースへ（例 `session_cancellation` → `cancellation`、
   `removal_attempt` → `removal`）。親リソース配下なので文脈で意味は通る。
2. 専用リソースをやめ member/collection アクションへ寄せる（REST から外れるので非推奨）。

**この改名は対外契約（path / `*_path`
ヘルパ名）を変える**ため、ビュー・テスト・リダイレクト先の一括追従が必要。`[[feedback_csp_report_url_immutable]]`
のような URL 不変要件が無いか個別確認要。→ **具体的な改名先はユーザの設計判断が必要**。関連:
`plans/backlog/configuration-to-settings-route-rename.md`。

---

## カテゴリ C: `# FIXME: rename this to "secrets"`（sign.rb:199）

```ruby
resource :emergency_key, only: :show   # → secrets へ改名希望
```

- 改名先が明示済み（`emergency_key` → `secrets`）。`[[project_high_assurance_mode_mfa_level]]`
  や recovery
  secret 関連プラン（`plans/objective-recovery-secret-restricted-bootstrap-plan.md`）と語彙整合を取る必要あり。
- 対応: path / コントローラ（`emergency_keys_controller` 相当）/ ビュー / テストを `secrets`
  へ。ドメイン用語が確定しているか `docs/dictionary/` で確認してから実施。

---

## カテゴリ D: `# FIXME: REMOVE THIS!!!`（sign.rb:258）

```ruby
namespace :r18 do
  resource :gate, only: %i(show create) do ... end
end
```

- sign **com** surface の R18（年齢ゲート）ルート。実在
  `app/controllers/sign/com/r18/gates_controller.rb`。
- acme app では R18 は `if Rails.env.local?` 配下の `__dev`
  smoke ルート（`acme.rb:82-94`、別 TODO 付き）になっており、本番 com に R18
  gate を残す意図と矛盾の可能性。
- 対応:
  **削除前にコントローラ・ビュー・参照・テストの利用状況を確認**。R18 ゲートの正式な置き場所（acme 側 / 削除）を決めてから、ルート＋コントローラ＋関連を一括除去。単独でルートだけ消すと参照が宙に浮く。

---

## カテゴリ E: `# FIXME: remove I hate this env variable.`（acme.rb:156）

```ruby
constraints host: [ENV["ACME_CORPORATE_URL"], "com.localhost", "www.com.localhost"].compact do
```

- env 変数とハードコード localhost fallback の混在が不満。他 surface（app: `acme.rb:6`、org:
  `acme.rb:277`、core 各所）も同じ `[ENV[...], "*.localhost"].compact` パターン。
- 関連設計: `adr/acme-rp-boundary-naming.md` / `docs/reference/subdomains.md`。
- 対応:
  host 制約の一元化（surface→host のマッピングを設定/ヘルパへ集約）が本筋。単発の env 削除ではなく surface 境界の設定方針として扱うべき。→ 設計判断が必要。

---

## カテゴリ F: `# FIXME: Check these entrypoints are still needed.`（acme.rb:141）

```ruby
resources :sessions, only: %i(index destroy) do
  collection do
    delete :others
    delete :revoke_all
  end
end
```

- acme app settings sessions の一括失効エンドポイント（`others` / `revoke_all`）。
- sign 側には類似の `session_revocations`（`others` /
  `all`）が別途存在（カテゴリ B 対象）→ 機能重複の可能性。
- 対応: コントローラアクション実装・ビュー・テストでの実利用を grep して、未使用なら削除、利用中なら FIXME を解消（コメント除去 or 仕様コメント化）。

---

## カテゴリ G: regional net/dev endpoint（core.rb:154-155）

```ruby
# FIXME: we need regional net endpoint. look at acme.rb
# FIXME: we need regional dev endpoint. look at acme.rb
```

- core surface に `net`（network）/`dev`（developer）の regional endpoint が未実装。acme.rb の
  `net`（`acme.rb:405`）/ `dev`（`acme.rb:421`）構造が参照モデル。
- 対応: acme の net/dev ブロックに倣い、core に `ENV["CORE_NETWORK_URL"]` /
  `ENV["CORE_DEVELOPER_URL"]` の constraints + `scope module: :net/:dev`
  を追加。新規 surface 追加なのでコントローラ（`core/net/*` `core/dev/*`）も必要。→ 新規実装タスク。

---

## 参考: 近接する TODO（FIXME ではないが関連）

- `sign.rb:159` `# TODO: what is the following line? check it out!`（verification setup）
- `sign.rb:496` `# TODO: move settings to acme's identity entrypoints.`（org settings 移設）
- `acme.rb:83` `# TODO: Remove these temporary R18 smoke-test routes ...`（カテゴリ D と関連）

---

## 推奨アクション順序（実施する場合）

実装は本分析の範囲外。着手するなら独立度・リスクの低い順:

1. **低リスク・即実施可**
   - A-2 account: `, controller: "accounts"` 削除（acme.rb:243,372、必要なら 115 も）。
   - A-3 core sso: 陳腐化 FIXME コメント削除（core.rb:145）。
   - A-1 health: FIXME を「override 必須」の説明コメントに置換（9箇所）。←
     **削除してはいけない**点が要旨。
2. **要・調査**
   - F sessions entrypoint の利用調査 → 去就決定。
   - D r18 com の参照調査 → 正式置き場所決定後に一括除去。
3. **要・設計判断（ユーザ確認）**
   - B/C 命名改善（path・ヘルパ名の対外契約変更を伴う）。
   - E host 制約の一元化方針。
   - G core net/dev surface 新規実装。

## 検証方法（実装時）

- ルート整合: `bin/rails routes -g <name>` で改名前後の path/helper を比較。
- A カテゴリ: `bin/rails routes -c health` / `-c accounts` で解決先コントローラを確認（health から
  `:controller` を外すと `HealthsController` 解決でルートが消える/壊れることを確認）。
- 関連テスト: `bin/rails test test/integration/oidc_rp_browser_flow_test.rb`
  等、surface ルートを踏む統合テスト。改名時は `*_path` ヘルパ参照の grep 追従。
