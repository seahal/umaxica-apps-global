# バックログ: preference 子レコードを「明示時のみ作成」モデル(A案)へ移行

Status: Backlog（B案実装後のフォローアップ）親プラン:
`plans/active/preference-actor-hydration-ssot.md`

## 背景

B案では「全子レコード常在＋親に `explicit_fields`
マーカー」という二重表現で「明示設定 vs 未設定(default)」を区別する。これは冗長で本質的に良くない。長期的には
**不在＝未設定** という素直なモデル(A案)へ移行し、`explicit_fields` を撤去する。

## 方針

- `create_preference_option_records`（`app/controllers/concerns/preference/base.rb:206`）:
  param/明示値が無い type の子レコードを作らない。
- `load_or_create_preference_child`（`base.rb:980`）: 閲覧（編集画面入場）で永続化しない。表示は in-memory
  build（`load_or_build_selectable_preference_child` `core.rb:364` 方式）へ統一。
- 全 `CHILD_RECORD_TYPES` 反復箇所を nil 安全化: `adoption.rb:86,117,270,279` /
  `resource_sync.rb:75,133,239,248` / `core.rb:241,537`。
- `build_preferences_payload`（`base.rb:618`）: 未設定キーは default 埋めせず省略。
- B案の `explicit_fields` カラム（`app/com/org` setting DB）を撤去するマイグレーション。

## 要設計（着手前に詰める）

- 既存データ移行: 既に作られている「default のままの子レコード」を「未設定」とみなして消すか、保持するか。消すなら不可逆性とロールバック方針、段階リリース（dual-read 期間）を設計。
- 影響範囲が広い（「子は常在」前提コードが多数）ため、回帰テストを先に厚くしてから着手。
- soft bubble（app/com/org 各 DB 別）ごとに段階適用。

## 完了条件

- 未設定言語のユーザーは `?ri` で動的に region シードされ続ける（B案と同じ外部挙動を維持）。
- `explicit_fields` 不要化。子レコード不在＝未設定で一貫。
