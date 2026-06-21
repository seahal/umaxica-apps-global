# 2026-06-21 sign up (email) が birthdate で止まる件の修正メモ

関連プラン: `plans/sign-up-email-fuzzy-ritchie.md`

## 症状

`https://id.umaxica.app/sign/up/check/email/birthdate?pt=...&ri=jp`
で生年月日を入力して「続行」しても先へ進めずループする。`log/development.log` に
`security.csp_violation.reported (form-action)` と `Redirected to https://jump.umaxica.net/?rt=...`
の繰り返し、過去には `ActionController::Redirecting::OpenRedirectError` の 500 が残っていた。

## 確定した原因（実ログ起点）

birthdate は sign up の最終要件。clear すると finalize →
sign-in シーケンスへ handoff する。handoff 先（sign-in
sequence）は別ホスト（`www.umaxica.app`）で、sign（`id.umaxica.app`）からは jump
gateway（`jump.umaxica.net`）経由のクロスホスト遷移になる。

birthdate は `<form method=patch>` で、その応答が jump gateway へクロスホスト 303 する。ところが CSP
`form_action` 許可リストに **jump gateway
origin が無かった**ため、ブラウザがフォーム送信起点のリダイレクトを `form-action`
違反でブロックし、画面が birthdate のまま止まっていた（CSP 仕様によりレポートの `blocked_uri`
は pre-redirect URL =
birthdate になる）。GET 遷移には form-action が効かないので sign-in 完了時の jump は通っており、フォーム送信応答で直接 jump する birthdate のこの経路だけが詰まっていた。

## 修正

- `config/initializers/content_security_policy.rb`: `form_action` に jump gateway
  origin を追加（`boot_config.fetch(:jump).origin.to_s`、ハードコードしない）。これが直接原因の修正。

## 調査で判明した「既に満たされていた」事項（追加のコード変更は不要と判断）

プランの段階A/Bは、現行コードで既に構造的に満たされていたため新規変更は入れていない:

- A（500/ループ防止）: `authentication_sequence_gate.rb:51-58` `redirect_to_sign_in_sequence!`
  は既に `destination.start_with?("/")` で分岐し、クロスホスト絶対 URL は `redirect_to_jump_url`
  に流すため `OpenRedirectError` にならない（ログの 500 はこのガード導入前のもの）。
- B（遷移先 `/settings?ri=jp` の保持）: `return_to` は sign
  up 開始時に検証済みパスへ設定され（`sign/app/sign/up/emails_controller.rb:362` →
  `resolved_path_or_navigation_target`）、`sign_up_handoff_pt`
  （`sign_up_sequence_controller_support.rb:683`）は finalize 内で `reset_session`
  より前に評価・メモ化されるため、nonce 回転後も元の宛先を失わない。完了後の resubmit でも
  `current_db_sign_in_flow_for_sequence.return_to` から復元される。

「`form-action` ブロックでフォーム送信が中止 → ユーザーが何度も続行を押す →
ticket 消失後の再送が同じくブロックされる遷移を繰り返す」ことがループの実体で、段階0 で解消する。

## テスト

- `test/integration/security_headers_test.rb`: CSP `form_action` に jump gateway
  origin を含むことを assert（段階0 の回帰）。
- `test/controllers/sign/app/sign/up/check/email/birthdates_controller_test.rb`（新規）: email
  flow を birthdate まで進め、clear で finalize →
  redirect され birthdate へ戻らないこと、完了後の resubmit でも 500/ループにならず単一の安全な redirect に収束することを assert（A の回帰）。

全て green。`bin/rails test` 該当範囲で確認済み。
