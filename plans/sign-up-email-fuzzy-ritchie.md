# sign up（email）が birthdate で止まる件 — 原因調査と修正方針

## Context（なぜ調べているか）

`https://id.umaxica.app/sign/up/check/email/birthdate?pt=...&ri=jp` で sign
up（email 経路）が止まり、生年月日を入力して「続行」しても先に進めない、という不具合報告。本ファイルは
`log/development.log` の実イベントに基づく確定診断と、修正方針の選択肢をまとめる。

調査は推測ではなく、ログに残った実際のリクエスト/レスポンス/例外に基づく。

## 確定した症状（log/development.log の実イベント）

birthdate の `PATCH /sign/up/check/email/birthdate` が `BirthdatesController#update`
に到達するたびに、毎回つぎが起きている（例: 今日 03:21、request_id 8f81c93b… ほか多数）:

```
Processing by Sign::App::Sign::Up::Check::Email::BirthdatesController#update as HTML
  Parameters: {pt=[FILTERED], requirement=birthdate, checkpoint_version=1, birthdate_year/month/day, commit=続行, ri=jp}
{"event":"path_target.rejected","data":{"reason":"signature_invalid", ".../birthdate?ri=jp"}}
{"event":"jump_rt.issued", ...}
Redirected to https://jump.umaxica.net/?rt=[FILTERED]
Completed 303 See Other
```

これが連続して何度も繰り返される（= リダイレクトのループ）。過去（6/20 08:21、code が現在の
`start_with?("/")` ガード導入前）には、同じ経路で次の **500** になっていた:

```
ActionController::Redirecting::OpenRedirectError
  (Unsafe redirect to "https://www.umaxica.app/dashboard?ri=jp", pass allow_other_host: true ...):
  authentication_sequence_gate.rb:52  redirect_to_sign_in_sequence!
  sign_up_explicit_step_controller_support.rb:70  redirect_to_sign_in_sequence_after_completed_sign_up
  sign_up_explicit_step_controller_support.rb:57  render_step_gate_failure
  sign_up_explicit_step_controller_support.rb:43  load_gate_context!
  birthdates_controller.rb:23  #update
```

つまり「500 だったものが、jump 経由のリダイレクトに変わり、今度はループに化けた」状態。ユーザー視点ではどちらも「birthdate から先へ進めない」。

## 根本原因（2つが連鎖している）

### 原因1: handoff 後、`gate_for_update` が "ticket is required" で失敗している

ログでは update 到達時に Client(id=1) が既に `signed_in?` で、`ClientSignInFlow`
(`current_db_sign_in_flow_for_sequence`) も存在している。これは **最初の birthdate 送信で sign
up の finalize 自体は成功し**、actor 作成・サインイン・sign-in
flow 生成まで進んだことを意味する。finalize は `sign_up_session_state.clear_all!` で sequence
id を消すので、以降の birthdate 再送では `SignUpStepGate` が ticket を見つけられず
`failure("ticket is required")` を返す (`app/services/sign_up_step_gate.rb:93`)。

その結果 `render_step_gate_failure`
(`app/controllers/concerns/sign_up_explicit_step_controller_support.rb:56`) が
`completed_sign_up_handoff_request?`（actor signed_in かつ sign-in
flow あり）を true と判定し、`redirect_to_sign_in_sequence_after_completed_sign_up` →
`redirect_to_sign_in_sequence!` を呼ぶ。

### 原因2: handoff 先が別ホストで、pt が nonce 不一致で復元できない

- sign（`id.umaxica.app`）から sign-in sequence（`www.umaxica.app`）への handoff は
  **クロスホスト**。`redirect_to_sign_in_sequence!`
  (`app/controllers/concerns/authentication_sequence_gate.rb:51`) の destination は
  `after_dashboard_path = https://www.umaxica.app/dashboard?ri=jp` のような絶対 URL。
  - 旧コード: `redirect_to(..., allow_other_host: false)` 相当 → `OpenRedirectError` → **500**。
  - 現コード: `start_with?("/")` でないので `redirect_to_jump_url` → **jump.umaxica.net への 303**
    → 跳ね返ってまた birthdate に戻る → **ループ**。
- 本来は元の遷移先（pt = `/settings?ri=jp`
  など）へ戻すはずだが、`path_target.rejected reason=signature_invalid`
  が示すとおり pt が検証に失敗している。`signature_invalid` は署名失敗ではなく
  **claim（session_nonce）不一致**で `verified_signed_target_payload`
  が nil を返したことを意味する（`authentication_redirects.rb` の
  `signed_pt_verification_payload`、`InvalidSignature` のみ `:expired`、それ以外 nil）。
  - pt は flow 途中で発行されたが、sign up → sign in の handoff 過程で session（および
    `authentication_pt_session_nonce`）が変わり、tokenの `session_nonce`
    と現在の nonce が食い違う。よって `signed_pt_param` が nil を返し、`sign_up_handoff_pt`
    のフォールバック（ticket.return_to / cycle.return_to = `/dashboard`
    など）に落ち、結局クロスホスト先へ飛ぶ。

### 原因3（直接原因）: CSP `form-action` が jump へのクロスホスト・リダイレクトをブロック

`config/initializers/content_security_policy.rb:33` の `form_action` 許可リストは `'self'` +
Google/Apple + acme ホスト（`www.umaxica.app/com/org`）+
sign ホスト（`id.umaxica.app/...`）のみで、**`jump.umaxica.net`（JUMP_GATEWAY_URL）を含まない**。

birthdate は `<form method=patch>`。その送信レスポンスが
`Redirected to https://jump.umaxica.net/?rt=...` とクロスホストへ 303 する瞬間、ブラウザは
**form-action 違反**としてそのリダイレクト遷移をブロックする。ログの
`security.csp_violation.reported`（`effective_directive: form-action`）の `blocked_uri`
が birthdate 自身になっているのは、CSP 仕様がリダイレクト先を秘匿し pre-redirect
URL を報告するため。よってブラウザはフォーム送信の遷移を中止し、画面は birthdate のまま＝ユーザーから見た「止まって進めない」。同じ navigation が GET（リンク/通常遷移）なら form-action は効かないので、sign-in 完了時の jump は普通に通る。**フォーム送信の応答で直接 jump へ飛ぶ**この経路だけがブロックされる。

### まとめ

birthdate の finalize 自体は通っているが、その後の handoff が **「フォーム送信の応答 →
jump.umaxica.net へクロスホスト 303」**になっており、(3) CSP `form-action`
がそれをブロックして画面が止まり、(1) ticket 消失後の再送が同じブロックされる遷移を繰り返し、(2)
pt の nonce 不一致で元の遷移先（`/settings?ri=jp`）も復元できずフォールバックが別ホスト（`/dashboard`）になる、という 3 連鎖。旧コードでは (2) が
`OpenRedirectError` の 500、現コードでは jump 経由ループに化けている。

（注: `frolicking-steele` プランの 401 は「最初の hop の preference
cookie」起因で別件・dev 限定だったが、本件は birthdate 送信後の handoff 起因で、再現性のあるループであり別問題。）

## 関連ファイル（確認済み）

- `app/controllers/sign/app/sign/up/check/email/birthdates_controller.rb:22` — `update`
- `app/controllers/concerns/sign_up_explicit_step_controller_support.rb:41,56,69` —
  gate 失敗時の handoff 判定とリダイレクト
- `app/controllers/concerns/sign_up_sequence_controller_support.rb:251,683` —
  `finalize_sign_up_from_checkpoint!` と `sign_up_handoff_pt`（pt フォールバック）
- `app/controllers/concerns/authentication_sequence_gate.rb:51` —
  `redirect_to_sign_in_sequence!`（クロスホスト分岐）
- `app/controllers/concerns/authentication_redirects.rb` — pt 発行/検証、
  `authentication_pt_session_nonce`、`signed_pt_param`
- `app/services/sign_up_step_gate.rb:93` — `failure("ticket is required")`

## 採用方針: C（A+B）＋ 直接原因の CSP 修正（ユーザー選択済み）

> 認証パイプライン・surface 境界・クロスホスト handoff に触れるため、着手前に
> `.agents/harnesses/rules/project/surfaces.mdc`、`.agents/harnesses/rules/generic/routing.mdc`、
> `.agents/harnesses/rules/generic/no-flash-messages.mdc`、`docs/architecture/controller-lifecycle.md`
> を読む。**認証/認可パイプラインの順序は変更しない**。`skip_*` や `html_safe`
> 等の禁止 API も使わない。

実装は「直接原因（CSP）→ ループ停止（A）→ 遷移先復元（B）」の順で、各段ごとにテストを追加する。

### 段階0 — 直接原因: CSP `form-action` に jump gateway を許可（最小・最優先）

- `config/initializers/content_security_policy.rb:33` の `policy.form_action(...)` にjump gateway
  origin（`RedirectsJumpGatewayUrl` / `JUMP_GATEWAY_URL`、既定
  `https://jump.umaxica.net`）を追加する。ハードコードせず既存サービスから origin を解決して渡す（`acme_form_hosts`
  / `sign_form_hosts` と同じ組み立て方）。
- 理由: jump gateway は署名付き `rt`
  を検証する第一者リダイレクトブローカーで、sign系フォーム送信の完了時に経由する正規ホスト。`form-action`
  不在のせいでフォーム送信起点のクロスホスト遷移だけがブロックされている。GET 遷移は元から通る。
- これだけで「画面が止まる」症状自体は解消する見込み。ただし pt消失（段階2）が残ると遷移先が
  `/dashboard` 等になるため、A/B も実施する。
- 注意: `form-action` は対外的なセキュリティ境界。jump gateway 以外は追加しない。

### 段階1 — A: handoff のループ／クロスホスト・フォーム遷移を断つ

- finalize 後の最終遷移（`redirect_after_sign_up_handoff!` →
  `redirect_to_sign_in_sequence!`、および ticket 消失時の
  `redirect_to_sign_in_sequence_after_completed_sign_up`）が、**フォーム送信の応答で直接 jump へ飛ぶ**経路を見直す。実装時に次のどちらかを選択:
  - (a) 段階0 で form-action を許可した上で、現行 jump 経由をそのまま許容（最小）。
  - (b) finalize 後はまず sign 同ホスト（`id.umaxica.app`、form-action
    'self'）の GET インタースティシャルへ 303 し、そこから通常 navigation として jump する（CSP に依存せずより堅牢）。既存 sign 側 handoff/welcome 入口が流用できるか確認。
- ticket 消失後の再送ガード: `completed_sign_up_handoff_request?`
  経路（`sign_up_explicit_step_controller_support.rb:56-71`）が毎回同じクロスホスト遷移を再発行してループしないよう、handoff 済みなら冪等に 1 回の安全な着地へ収束させる。

### 段階2 — B: pt の nonce 連続性（元の遷移先 `/settings?ri=jp` を復元）

- 原因: `establish_signed_in_session!` 系の `reset_session` で `session[:authentication_pt_nonce]`
  が回転し、flow 途中で発行された pt の `session_nonce` claim と現在 nonce が食い違って
  `signed_pt_param`
  が nil になる（`authentication_redirects.rb:363-367`、`verify_authentication_pt_path`）。
- 方針: **検証済みの内部パスを reset_session の前に確定して持ち越す**。
  - `sign_up_handoff_pt`（`sign_up_sequence_controller_support.rb:683`）は既に `ticket.return_to`
    をフォールバックに持つ。問題は ticket.return_to が元の pt 宛先（`/settings?ri=jp`）でない点。**flow 開始〜OTP の段階で検証済み
    `path_from_signed_pt(pt)`
    を ticket.return_to に確定保存**しておけば、nonce回転後でもフォールバックで `/settings`
    を復元できる。return_toがどこで設定されるかを確認し、未設定/`/dashboard` 既定の箇所を是正する。
  - 補強: handoff 直前（reset_session 前）に `sign_up_handoff_pt`
    を評価・確定し、reset 後はその確定値を使う（メモ化順序の保証）。token 再 mint は新 nonce 下で行う。
- いずれも `session_nonce`
  検証自体は維持し（リプレイ/オープンリダイレクト耐性を落とさない）、検証済みパスの持ち越しで連続性を担保する。

### 影響範囲（surface）

App（`id.umaxica.app`）の email 経路で確認しているが、同じ handoff 機構は com/telephone/social でも共有のため、段階0 の CSP は全 surface 共通、段階1/2 は
`sign_up_*`
concern の共有部分。app/org/com を混ぜず、共有 concern の変更が各 surface のテストを壊さないことを確認する。

## Verification（実装後）

```
bin/rails test test/controllers/sign/app/sign/up/check/email/birthdates_controller_test.rb
bin/rails test test/controllers/sign   # handoff/sequence 周辺
# 段階0: CSP form-action 許可リストに jump gateway origin を含むテスト（initializer/CSP テストを拡張 or 追加）
```

- 段階1: birthdate `update`
  の finalize 後遷移と ticket 消失時の再送が、ループせず 1 回で安全に着地することを controller テストで担保。
- 段階2:
  reset_session をまたいでも handoff 先が元 pt（`/settings?ri=jp`）に復元されることをテスト（nonce 回転シナリオ）。

手動: email で sign up → OTP → birthdate 入力 → 「続行」で 500/ループにならず、意図した遷移先（pt =
`/settings?ri=jp`）へ着地することを確認。`log/development.log` に `path_target.rejected` と
`Redirected to https://jump.umaxica.net` のループ、`form-action` 違反レポートが出ないこと。
