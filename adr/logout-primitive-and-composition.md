# Logout Primitive And Composition

## Status

Accepted (2026-05-20)

## Context

サインアウト / ログアウトの実装は、IdP 側のセッション管理を中心に「現セッション 1 件だけ消す」フローと「全アクティブセッションを消す」フローの 2 種類が必要になる。

最近のリファクタで `app/controllers/concerns/authentication/logoutable.rb` の
`logout_current_session!` が誤って `Oidc::SingleLogoutService.call(user:)`
を呼ぶ配線になっており、「現ブラウザのログアウト」のはずが「ユーザーの全アクティブトークン破棄」に化けるリグレッションが発生していた。原因は 2 層に分かれる:

1. **名前と機能の乖離**: `Oidc::SingleLogoutService` という名前は OIDC SLO (Single
   Logout) プロトコル (back-channel /
   front-channel での RP 通知) を想起させるが、実装はそれを満たさず、単に「actor の全アクティブトークン革袋」を行うルーチンだった。
2. **配線ミス**: 通常 logout のパスに常時挟み込まれた結果、ユーザーが「このブラウザだけ」と期待する操作で全端末ログアウトが発生していた。

加えて、`Authentication::LogoutAllSessions`
という事実上同等機能のクラスが別途存在しており、「全セッション破棄」が 2 重に実装され乖離する余地があった。

過去にも sign up / sign
in の部品が散らばって「同一機構を別箇所で再実装」する事故が起きており、その教訓として「同一機構は 1 つの concern
/
service に集約し、必要箇所はそれを利用するだけ」にする方針が既に取られている。logout も同じ原則に揃える必要がある。

## Decision

### 1. `Oidc::SingleLogoutService` は削除する

production の呼び出し元 0 件、機能は `Authentication::LogoutAllSessions`
で完全に代替可能だったため、削除する。`app/services/oidc/single_logout_service.rb` と
`test/services/oidc/single_logout_service_test.rb` を物理削除した。

`Oidc::` namespace 自体は、将来 OIDC SLO プロトコル (back-channel / front-channel
logout) を本当に実装する際の置き場所として温存する。本物の OIDC SLO が来た時は、別名 (例:
`Oidc::BackchannelLogoutNotifier`) で実装する。

### 2. logout の primitive は「1 セッション削除」とする

セッション破棄の正準操作 (primitive) は 1 つだけ:

- **`Authentication::LogoutCurrentSession.call(token:, …)`**
  が「セッション 1 件を revoke する」唯一の経路。token の resolve、`revoke!` 呼び出し、narrow
  rescue、application log 出力をここに集約する。

### 3. 「全セッション削除」は primitive の反復として合成する

「全セッション削除」は、primitive を actor の token scope 上で回す合成として実装する:

- **`Authentication::LogoutAllSessions.call(resource:, reason:)`** は
  - `session_version` のインクリメント (= 残存する JWT を refresh 時に弾く)
  - actor の token 一覧の解決
  - 各 token に対し `Authentication::LogoutCurrentSession.call(token:, …)` を委譲
  - 個別 revoke が primitive の narrow
    rescue を抜けた場合の batch 用通知 (`auth.logout_all_sessions.token_failed`)

  だけを担当する。「1 件 revoke する」ロジックは絶対に再実装しない。

擬似コード:

```text
revoke_all_sessions(actor) =
  bump session_version
  for each token in tokens_for(actor):
    revoke_one_session(token)   # ← primitive を呼ぶだけ
```

### 4. 通常ログアウトは primitive 直接呼び出しのみ

`Authentication::Logoutable#logout_current_session!` は

- `LogoutCurrentSession.call` を 1 回呼ぶ
- `record_logout_audit`
- `ensure` で Cookie / Session を破棄

だけを行う。`perform_single_logout`
のような全端末破棄フックは持たない。「全端末ログアウト」が必要なエンドポイントは
`logout_all_sessions_for!(resource:, reason:)` を _明示的に_ 呼ぶ。

## Future direction (IdP / RP 両モード)

この decision は IdP 側 (本リポジトリの現在の主たる役割) の logout 設計だが、同じアプリ群が将来 RP として動作する場合にも primitive
/ 合成のルールは保持する。

### IdP 側 (現状)

- 「セッション 1 件」= surface 別 token row (`ClientToken` / `OperatorToken` / `VisitorToken`)
- primitive = token row の revoke
- 合成 = actor scope での反復

### RP 側 (将来)

RP として OIDC を受ける場合、「セッション」の実体は IdP
token ではなく、RP 自身が持つローカルセッション (Rails
session または独自 RP セッションテーブル) になる。RP 側でも同じルールを当てる:

- 「セッション 1 件」= RP のローカルセッションレコード (IdP の `sid` 主張に紐付く)
- primitive = ローカルセッションを破棄する `Rp::Authentication::LogoutCurrentSession`
- 合成 = `sub` 単位の反復 (`Rp::Authentication::LogoutAllSessions`)

RP 側で扱うべき入口は最低 3 つあり、すべて上記 primitive / 合成に最終的に接続する:

1. **RP-Initiated
   Logout**: ユーザーが RP 内でログアウトする。RP は primitive を呼んでローカルセッションを破棄し、その後 IdP の
   `/oidc/logout` にリダイレクトする (任意)。
2. **Back-channel Logout**: IdP が `logout_token` を RP の back-channel endpoint に POST する。RP は
   `sid` (または `sub`) で対象セッションを特定し、primitive
   (sid 一致なら 1 件) または合成 (sub 一致なら全件) を呼ぶ。
3. **Front-channel Logout**: IdP が iframe から RP の front-channel
   endpoint を踏みに来る。同じく primitive / 合成へ接続する。

IdP 側 (本リポジトリ) で本物の SLO 通知を発行する際は、`Authentication::LogoutAllSessions` の
**後段** に「RP に対する通知」レイヤを別ファイル (例:
`app/services/oidc/backchannel_logout_notifier.rb`) で実装する。`LogoutAllSessions`
自体に通信責務を混ぜない。

### namespace の指針

- `Authentication::*` = IdP 側のセッション操作 (token を実体とする)
- 将来 `Rp::Authentication::*` = RP 側のセッション操作 (ローカル session record を実体とする)
- `Oidc::*` =
  OIDC プロトコル準拠の処理 (logout_request 検証、back-channel 通知、id_token 発行など)。「全トークン革袋」のような非プロトコル処理を
  `Oidc::` に置かない。

## Evidence

- `app/controllers/concerns/authentication/logoutable.rb` は `perform_single_logout` を持たず、
  `LogoutCurrentSession` を 1 回呼んだ後 `ensure` で Cookie / Session を破棄する。
- `app/controllers/concerns/authentication/logout_all_sessions.rb` は token ごとに
  `Authentication::LogoutCurrentSession.call` へ委譲する合成として実装されている。
- 回帰テスト:
  - `test/controllers/concerns/authentication/logoutable_test.rb` の
    `Oidc::SingleLogoutService is intentionally absent` が同名定数の再導入を機械的に弾く。
  - 同ファイル `logout_current_session does NOT invoke logout_all_sessions_for!`
    が通常 logout の fan-out を禁ずる。
  - 同ファイル `logout_current_session clears cookies and session even if revoke raises` が `ensure`
    経路を保証する。
  - `test/controllers/concerns/authentication/logout_all_sessions_test.rb` の
    `delegates each token revoke to LogoutCurrentSession primitive` が合成の経路自体を固定する。
- 各 surface (app / com / org) の `outs_controller_test.rb`
  に「通常 logout は現セッションだけ revoke、他端末トークンは残存」テストを追加済み。

## Consequences

- 「セッション 1 件を消す」ロジックの所在は `Authentication::LogoutCurrentSession`
  ただ 1 つになる。将来 token 構造が変わっても変更点は primitive 1 ヶ所。
- 全端末ログアウト経路が増えても primitive は変わらず、増えるのは合成側だけ。
- 通常 logout で他端末を巻き込むリグレッションは、配線ミスをしようとした瞬間に
  `Oidc::SingleLogoutService is intentionally absent` と `does NOT invoke logout_all_sessions_for!`
  の 2 重の guard で検出される。
- 将来 OIDC SLO プロトコルを実装する際、`Oidc::` namespace は空いており、命名衝突なく置ける。
- RP 側を実装する際は本 ADR の「同じ primitive / 合成ルールを RP 側にもう一枚作る」方針に従う。

## Related

- `adr/session-reset-on-privilege-transition.md`
- `adr/refresh-revoke-aal-downgrade-and-replay-hardening.md`
- `plans/active/logout-state-machine-implementation-plan.md`
