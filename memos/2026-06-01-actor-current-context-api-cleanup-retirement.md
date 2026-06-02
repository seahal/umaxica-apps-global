# actor-current-context-api-cleanup プラン退役メモ（2026-06-01）

## 結論

`plans/active/actor-current-context-api-cleanup.md` を **完了・退役** とし、
`plans/archive/actor-current-context-api-cleanup.md` へ移動した。

「実装を完了するか / active から外すか」の二択だったが、調査の結果
**残実装ゼロ（既に全スコープ達成済み）** だったため、active から退役を選択した。

## 退役判断のエビデンス（2026-06-01, grep ベース）

プランの Scope 各項目を実コードと突き合わせた結果:

- `Actor.surface` / `Actor.domain` / `Actor.session` / `Actor.token` … `app` `lib` `test` とも
  **0 件**（削除済）。
- `Current.*` / `Jumper` / `Acmeer` / `Signer` の残骸 … **0 件**。
- `ActiveSupport::CurrentAttributes` を継承するのは `app/models/actor.rb` のみ（facade 一本化済）。
- `context.{authn,authz,configuration,preferences,tld}` を直接読む非 Actor コード … **0 件**。
- プランが唯一の残務とした "migration-only direct readers" … 該当コード・マーカーとも **存在せず**。
- facade 本体は `adr/actor-current-facade.md` 通り（`tld` / `authn` / `authz` / `configuration` /
  `preferences` / `step_up`）。

## 付随変更

- `plans/active/controller-boundary-lifecycle-unification.md` 内の
  `plans/active/actor-current-context-api-cleanup.md`
  参照（2 箇所）を archive パスへ更新し、「完了・退役（2026-06-01）」と文言修正。

## 未処理・フォローアップ

- `plans/archive/` 内の以下 2 ファイルが旧 active パスを参照（歴史的資料のため実害なし、未修正）:
  - `plans/archive/actor-support-integration-test-coverage.md`
  - `plans/archive/public-controller-preference-leak-test.md`
- `plans/backlog/gh610-decouple-session-id-from-token.md`
  は引き続き有効（ランタイム API ターゲット = `Actor.authn.login_public_id`）。
- `plans/active/controller-boundary-lifecycle-unification.md` 自体も「Deprecated by 2026-05-25
  two-base direction」宣言済みで、archive 退役の候補（ユーザー判断待ち）。

## 関連

- ADR: `adr/actor-current-facade.md`, `docs/architecture/current_context.md`
