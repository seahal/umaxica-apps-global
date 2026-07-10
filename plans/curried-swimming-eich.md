# Project Umaxica — app 面 認証フロー セキュリティ監査レポート

- 監査日: 2026-06-22
- 対象: `sign.app` / `acme.app` / `base.app` / `core.app` / `palm.app`(`com`/`org` は対象外)
- 種別:
  **静的監査(調査・テスト設計・報告のみ)**。実装変更・migration・設定変更・テスト実行は行っていない。
- 方式: route / controller / concern / service / model / schema を `path:line`
  で追跡。動的テストは plan mode 制約により未実行 → §12.1「実行できなかったこと」に明記。

> 注記: 本ファイルは plan
> mode 上の唯一の書込先のため監査レポートをここに置いた。確定後は運用慣習に従い
> `memos/2026-06-22-app-auth-audit.md` への複製を推奨。

---

## 12.1 Executive summary

```
Overall: CONDITIONAL（コア OIDC/CSRF/セッション設計は堅牢。ただし region 起因の logout 不成立=P1 を要修正）

Release blockers:
  - F1 (P1): ri != "jp"（正式サポートの "us" を含む）で RP-initiated logout が
    沈黙裂(silent reject)し、ローカル/Acme 双方のセッションを残したまま
    「サインアウト完了」画面を表示する logout illusion。

Top 3 risks:
  1. F1 (P1) logout illusion: completion_url の exact-match 検証が ri を欠落
     させており、非既定 region のユーザはサインアウトできない。
  2. F4 (P2) organization invitation の consume! が check-then-act（行ロック無し）
     → 同時消費で benefit/membership 二重取得の TOCTOU。
  3. F3 (P2) Palm logout が refresh_token_family を失効させず、別 device_session
     に属する refresh token が logout 後も生存しうる。

What was actually executed:
  - 静的コード追跡（routes/controllers/concerns/services/models/schema/route-contract test）。
  - 仮説（307 利用 / Palm は Rails session のみ削除 / /auth/logout 生存）を実装で反証/確認。
  - F1 は preference の before_action 経路まで含め手動でフロー全追跡し再現条件を確定。

What could not be executed:
  - 実テスト/並行(concurrency)テスト/ブラウザ実機リダイレクト検証（plan mode のため
    非読取りツール不可）。F4/F5/F6 の race window は静的根拠どまり、UNKNOWN を併記。
  - `bin/rails routes` 実行は未実施。route file + route-contract test から復元。
```

---

## 12.2 現状シーケンス(主要経路, ASCII)

### sign-out(Sign/Base/Core RP, 正常 = ri:"jp")

```
Browser            RP(sign/base/core).app                    Acme.app
  | GET /sign/out/new ----> redirect 303 -> /sign/out/edit
  | GET /sign/out/edit ---> render 確認フォーム(CSRF token)
  | POST /sign/out ------->#create -> launch_oidc_rp_logout!
  |                         issue!(completion_url, ri=jp)  [allowlist OK]
  |                         id_token_hint = OidcIdTokenIssuer (★ logout 前に発行)
  |                         logout_current_session!(local)
  |                         redirect 303(jump-token gateway) -------------->
  |                                          /:ri/oidc/logout?id_token_hint,
  |                                          post_logout_redirect_uri,state,logout_challenge
  |                                                        Acme: id_token_hint 検証
  |                                                        (iss/aud/sig/exp/sub/sid)
  |                                                        post_logout_redirect_uri
  |                                                        exact-match allowlist
  |                                                        logout_current_session!(Acme)
  |                                                        back-channel notify(jti/sid)
  | <----- redirect 303 -> /sign/out/complete?state ------ (signed jump gateway)
  | #complete: state secure_compare -> render complete
```

### sign-out(F1 経路 = ri:"us" / 任意非既定値)

```
  | POST /sign/out?ri=us --> launch_oidc_rp_logout!
  |                          issue!(completion_url, ri=us)
  |                            allowed_completion_url? は ri 既定(jp)で expected を再計算
  |                            "?ri=us" != "?ri=jp" -> REJECTED
  |                          return render_oidc_rp_logout_unavailable
  |                            -> render "sign_outs/complete" 200   ★logout 実行されず
  | <--- 「サインアウト完了」表示。ローカル/Acme セッションは生存(illusion)
```

### sign-up / sign-in(RP 起点 OIDC, 概要)

```
RP.app -> GET /oidc/authorization -> redirect(Acme /oauth/authorize; state,nonce,PKCE,client_id,redirect_uri)
Acme -> (未認証なら) sign.app ceremony(email/passkey/secret/totp) -> 検証完了で認証
Acme -> code 発行(TTL 10s,single-use,PKCE S256) -> RP /oidc/callback
RP callback -> iss/aud/sig/exp/nonce/state 検証 -> log_in: reset_session(セッション固定対策) -> サーバ側セッション確立
```

---

## 12.3 Route / 責任境界マップ(抜粋, すべて `path:line` 付き)

| host     | role                     | user 起点                                     | authority             | local session/token                         | logout 参加                   |
| -------- | ------------------------ | --------------------------------------------- | --------------------- | ------------------------------------------- | ----------------------------- |
| sign.app | credential ceremony / RP | `/sign/in`,`/sign/up`,`/sign/out`             | Acme(issuer ではない) | cookie session + auth cookies               | RP-initiated(303)             |
| acme.app | 唯一の IdP/OP/AS         | `/oauth/authorize`,`/oidc/logout`,`/sign/out` | **本体**              | cookie session                              | end-session + back-channel    |
| base.app | browser RP               | `/sign/out`,`/oidc/callback`                  | Acme                  | cookie session                              | RP-initiated(303)             |
| core.app | browser RP/BFF           | `/sign/out`,`/oidc/callback`,`/api/v0/*`      | Acme                  | cookie session                              | RP-initiated(303)+backchannel |
| palm.app | native/public client     | `POST /sign/out`(JSON)                        | Acme                  | **bearer ClientToken**(cookie session 無し) | server 失効+任意 Acme global  |

主要 route(代表):

- `config/routes/sign.rb:25` `resource :out, only: %i(new edit create)` + `get :complete`(sign.app)
- `config/routes/base.rb:41` / `config/routes/core.rb:77` 同型(`path: "sign/out"`)
- `config/routes/acme.rb:121,289,493` `resource :logout, only: %i(show create)`(OIDC end-session)
- `config/sign_route_mapper.rb:67-69` RP back-channel logout receiver(`oidc/backchannel/logout`)
- `config/routes/palm.rb:40` `resource :sign_out, only: %i(show create)`

controller#action(GET=確認 / POST=変更):

- `app/controllers/sign/app/sign/outs_controller.rb:20`(new→edit 303), `:24`(edit 確認),
  `:30`(create 変更), `:40`(complete)
- `app/controllers/core/app/sign_outs_controller.rb:21,25,29,37`(同型, `:15`
  `before_action :authenticate!, only: :create`)
- `app/controllers/base/app/sign_outs_controller.rb`(同型)
- `app/controllers/palm/app/sign_outs_controller.rb:9`(show), `:23`(create=`PalmLogoutService.call`)

cookie / session(`config/initializers/session_store.rb`):

- session cookie: 本番 `__Host-session`(`lib/jit_session_cookie_config.rb:25-27`), HttpOnly,
  `SameSite=:lax`, 14日, 本番 partitioned
- auth cookie(`authentication_cookie_service.rb:26-48`): 本番 `__Host-auth_access/refresh/dbsc`,
  HttpOnly, `SameSite=:strict`, path `/`
- cookie domain(`core_cookie_domain.rb`): `HOST_ONLY`
  既定 / 本番は apex(`.umaxica.app`)で cross-subdomain SSO。`:83-86` に「apex scope は subdomain
  XSS で auth cookie 読まれる」リスクを自己文書化。

CSRF: app 全 sign-out で
`protect_from_forgery using: :header_or_legacy_token, with: :exception`。`skip_forgery_protection` /
`permit!` は app 面 sign-out 経路に**無し**。

---

## 12.4 正常系結果

| flow          | initiator                  | expected                                 | actual                                                                                | status       | evidence                                                                       |
| ------------- | -------------------------- | ---------------------------------------- | ------------------------------------------------------------------------------------- | ------------ | ------------------------------------------------------------------------------ |
| sign-out      | sign/base/core(ri=jp)      | local+Acme logout, complete              | 設計通り(303 chain, state 検証)                                                       | PASS         | `oidc_rp_logout_launcher.rb:9-53`                                              |
| sign-out      | sign/base/core(ri≠jp/"us") | local+Acme logout                        | **logout 実行されず complete 表示**                                                   | **FAIL(F1)** | `oidc_rp_logout_launcher.rb:10-24`, `acme_logout_transaction_service.rb:74-77` |
| sign-out 確認 | 全 RP                      | GET は非変更                             | GET edit は基本非変更。例外: `edit?logout_challenge` で `logout_current_session!`(F8) | CONDITIONAL  | `sign/app/sign/outs_controller.rb:24-28,50-54`                                 |
| sign-out      | acme                       | end-session+backchannel                  | 設計通り(id_token_hint/redirect 検証強固)                                             | PASS         | `sign_oidc_logout.rb`, `oidc_end_session_request.rb`                           |
| sign-out      | palm                       | bearer 失効+任意 global                  | サーバ失効は実装済。refresh family 失効は未確認(F3)                                   | CONDITIONAL  | `palm_logout_service.rb:44-51`                                                 |
| sign-in       | RP 起点                    | nonce/state/PKCE/code 検証, session 確立 | 設計通り、`reset_session` でセッション固定対策                                        | PASS         | `authentication_base.rb:360-365`                                               |
| sign-up       | RP 起点                    | 検証完了前に session 発行しない          | ceremony transaction(pending/consume)で隔離                                           | PASS         | `secret_credential_ceremony_transactionable.rb:101-115`                        |

---

## 12.5 Dropout マトリクス(logout 中断)

| stage                            | action       | persisted state                         | session/token                          | return UX                 | status                                                   | evidence                                 |
| -------------------------------- | ------------ | --------------------------------------- | -------------------------------------- | ------------------------- | -------------------------------------------------------- | ---------------------------------------- |
| GET `/sign/out/edit`             | Cancel/離脱  | 変更なし                                | local/Acme 維持                        | 安全                      | PASS                                                     | `sign/app/sign/outs_controller.rb:24`    |
| POST 前 tab close                | —            | 変更なし                                | 維持                                   | 安全                      | PASS                                                     | 同上                                     |
| RP local cleanup 後・Acme 到達前 | network 断   | RP logged out / Acme 生存可能           | 分裂                                   | 回復UI/idempotency 要確認 | CONDITIONAL                                              | `oidc_rp_logout_launcher.rb:34-52`(§9.2) |
| Acme logout 後・backchannel 前後 | —            | Acme logged out, 通知 retry/idempotent  | 確定                                   | PASS                      | back-channel: jti replay + sid UUID                      |
| complete で refresh/back         | —            | 再ログイン無し                          | state secure_compare + no-store header | PASS                      | `oidc_rp_logout_launcher.rb:55-69`, `sign_out_notice.rb` |
| **ri≠jp で POST**                | サインアウト | **local+Acme 維持のまま complete 表示** | illusion                               | **FAIL(F1)**              | §F1                                                      |

selector dropout(account/org/avatar/consent): selected
ID はサーバ側で候補集合と全一致照合(`acme_selectable_context.rb:40-56`)。hidden
ID は authority でない=良好。ただし enumerate→persist 間の membership/avatar 失効 race は未ガード(F5)。

---

## 12.6 TOCTOU マトリクス

| invariant                 | race pair         | atomic guard                  | DB constraint                        | test         | status              | evidence                                                |
| ------------------------- | ----------------- | ----------------------------- | ------------------------------------ | ------------ | ------------------- | ------------------------------------------------------- |
| email/phone 一意          | 同時 sign-up      | blind_index 検証(行ロック無)  | **条件付** unique index(active のみ) | 要追加       | CONDITIONAL(F6)     | `visitor_email.rb:33`, `visitor_telephone.rb:27`        |
| OTP single-use            | 同時 verify       | 悲観ロック+二重チェック       | unique `result_jti`                  | 有(ceremony) | PASS                | `secret_credential_ceremony_transactionable.rb:101-115` |
| ceremony 二重完了         | 同時 consume      | `lock.find` + consumed 再判定 | unique                               | —            | PASS                | 同上                                                    |
| authorization code        | 同時 redeem       | `consume!` consumed_at        | `valid` scope                        | —            | PASS                | `client_authorization_code.rb`(TTL 10s, S256)           |
| refresh rotation/reuse    | 同時 refresh      | reuse 検出で family revoke    | family_id                            | 有           | PASS                | `acme_refresh_token_service.rb:50-70`                   |
| **invitation single-use** | 同時 consume      | **check-then-act, ロック無**  | unique `code`(消費は別カラム)        | 要追加       | **CONDITIONAL(F4)** | `organization_invitation.rb:58-62`                      |
| selector ownership        | enumerate→persist | persist 時 re-check 無        | —                                    | 要追加       | CONDITIONAL(F5)     | `acme_selectable_context.rb:24-73`                      |
| logout idempotency        | 同時 sign-out     | session 失効 + cycle          | —                                    | 有           | PASS                | `authentication_logout_current_session.rb:120-181`      |

---

## 12.7 CAPTCHA / abuse controls

| flow/action           | CAPTCHA     | provider             | server verify                         | rate limit                                 | fail behavior            |
| --------------------- | ----------- | -------------------- | ------------------------------------- | ------------------------------------------ | ------------------------ |
| sign-up email submit  | 有(visible) | Cloudflare Turnstile | `JitSecurityTurnstileVerifier.verify` | IP burst+sustained, email digest           | reject(no silent bypass) |
| sign-in email submit  | 有(visible) | Turnstile            | 同上                                  | IP burst 5/1m, sustained 20/15m + cooldown | reject                   |
| TOTP verify / passkey | 有(stealth) | Turnstile            | stealth 検証                          | —                                          | reject                   |
| sign-out              | 無(正しい)  | —                    | —                                     | —                                          | —                        |

- 評価:
  defense-in-depth として適切(sign-out に CAPTCHA を要求せず、signup/OTP/credential-stuffing には feature-specific
  rate limit を前置)。
- 注意: 上記 evidence は `sign/com/*`
  を主証跡として採取(agent)。**app 面 (`sign/app/sign/in/emails_controller`
  等) の同等配置を確定する controller-level test が必要**(§11)。残余リスク: Turnstile
  solver/proxy 前提で rate limit + email verification との併用は維持されている。

---

## 12.8 Findings

### F1 — RP-initiated logout が非既定 region で沈黙裂し logout illusion を生む

```
ID: F1
Severity: P1
Title: ri!="jp"(サポート対象 "us" を含む)で sign-out が成立せず「完了」表示
Affected flow/surface: sign.app / base.app / core.app の POST /sign/out (launch_oidc_rp_logout!)
Precondition: 当該ユーザの request に ri が "jp"(小文字・既定)以外で乗る。
  ALLOWED_REGIONS=%w(jp us) のため "us" は正式構成。region を URL に保持する UI 経路で常時再現。
Attack/failure sequence:
  1. rp_logout_region は params[:ri].presence をそのまま採用(normalize_region 未適用, downcase 無)
     -> oidc_rp_logout_launcher.rb:116-118
  2. completion_url = AcmeLogoutTransactionService.completion_url_for(ri: "us") を作り issue! へ渡す
     -> oidc_rp_logout_launcher.rb:10-18
  3. issue! は allowed_completion_url? で検証。expected = completion_url_for(...)（ri 引数無=既定 "jp"）
     を exact-string 比較。"?ri=us" != "?ri=jp" -> not allowlisted -> Result rejected
     -> acme_logout_transaction_service.rb:12-19, 74-77 / request_context_contract.rb:9-10,79
  4. launch_oidc_rp_logout! は line 24 で return render_oidc_rp_logout_unavailable。
     これは render_oidc_rp_logout_completion = "sign/shared/sign_outs/complete" を 200 で描画
     -> oidc_rp_logout_launcher.rb:24,107-114
  5. logout_current_session!(line 34) に到達しない -> ローカルセッション/auth cookie 残存、
     Acme への redirect も発生せず Acme セッションも残存。
  ※ preference の set_region before_action は POST かつ valid ri では何もしない
     (return unless query_changed && (get?||head?)) ため params[:ri]="us" は素通り
     -> preference_global.rb:197-208
Impact: ユーザが「サインアウト完了」を見ても実際は未ログアウト。共有/公共端末で
  次の利用者がセッションを再利用可能(=認証バイパスに連鎖しうる)。logout illusion。
  さらに二段目の Acme 側 post_logout_redirect_uri exact-match(client registry)も
  同じく ri 差異で失敗するため、仮に RP 側を通過しても完了し得ない。
Evidence:
  - app/controllers/concerns/oidc_rp_logout_launcher.rb:10-24,34,107-118
  - app/services/acme_logout_transaction_service.rb:12-19,74-80
  - app/services/request_context_contract.rb:9-10,79,100-103
  - app/controllers/concerns/preference_global.rb:197-214
Existing control: ri="jp"(既定)では正常。完了画面の state は secure_compare。
Missing control: allowed_completion_url?/issue! 経路で ri を expected に反映していない。
  rp_logout_region が normalize_region を通していない。
Minimal fix(参考, 実装は未着手):
  - allowed_completion_url? と issue! に ri を伝播し、expected も同じ ri で生成して比較する、
    あるいは completion_url 比較を「host+path のみ」に正規化し ri はクエリとして別途検証。
  - rp_logout_region で RequestContextContract.normalize_region を適用(jp/us 以外は既定へ)。
  - issue! 失敗時は complete を 200 で描かず、明示的な「サインアウト未完了/再試行」を返す
    (fail-closed, illusion 回避)。
Regression test:
  - test/controllers/{sign,base,core}/app/sign_outs_controller_test: POST /sign/out?ri=us で
    (a) session/auth cookie がクリアされ (b) Acme /oidc/logout へ 303、を assert。
  - issue! 拒否時に complete テンプレートを成功表示しないことの assert。
Confidence: High(コードロジック)。Medium(本番で "us" region が実稼働かは要確認 —
  未稼働でも任意 ri による latent defect として有効)。
```

### F2 — region 入力の検証が経路で不統一(rp_logout_region が normalize_region を迂回)

```
ID: F2
Severity: P2
Title: logout 経路の ri が未正規化のまま URL/transaction 保存へ流入
Affected flow/surface: sign/base/core POST /sign/out
Precondition: 任意の ri クエリ。
Failure: rp_logout_region = params[:ri].presence || default。downcase/allowlist 無し。
  "JP","us","任意文字列" が completion_url / acme_oidc_logout_url / AcmeLogoutTransaction.completion_url
  に格納される。host はサーバ側 boot_config 固定のため open redirect には至らない(良)が、
  spec(jp/us)逸脱と F1 連鎖の温床。
Impact: 単体では低(クエリ値のみ, url_helper でエスケープ)。F1 と合わせ logout 不成立を拡大。
Evidence: oidc_rp_logout_launcher.rb:84-92,116-118 / request_context_contract.rb:100-103
Missing control: normalize_region 一貫適用。
Minimal fix: rp_logout_region で normalize_region。
Regression test: ri="JP"/"xx" で正規化 or fail-closed を assert。
Confidence: High。
```

### F3 — Palm logout が refresh_token_family を失効させない(global logout は native 任せ)

```
ID: F3
Severity: P2
Title: Palm bearer logout が現行 token 行+device_session cascade のみ失効。family 失効無し
Affected flow/surface: palm.app POST /sign/out (PalmLogoutService -> AuthenticationLogoutCurrentSession)
Precondition: 同一 refresh_token_family の token が別 device_session に存在する場合。
Failure: revoke_token! は当該 token の revoke!、revoke_device_session! は device_session_id 一致分のみ
  cascade。reuse 検出時(AcmeRefreshTokenService)に存在する family-revoke は logout では呼ばれない。
Impact: logout 後も family 内 refresh token から access token 再発行が成立しうる。
  また Acme global logout は返却 logout_url を native が開くかに依存(best-effort/任意)。
Evidence:
  - app/services/palm_logout_service.rb:44-55
  - app/controllers/concerns/authentication_logout_current_session.rb:122-181
  - app/services/acme_refresh_token_service.rb:50-70(family revoke は reuse 経路のみ)
Note: 仮説「Palm は Rails session のみ削除/revoke 未実装」は不正確。
  Palm は cookie session を持たず bearer ClientToken をサーバ側 revoke している。
Missing control: logout 時の refresh_token_family 失効ポリシ。global logout の product 決定明文化。
Minimal fix: logout で family_id 単位 revoke、または「local-only logout」である旨を UI/契約で明示。
Regression test: 同 family 別 device_session の token が logout 後 refresh 不可であることの service test。
Confidence: Medium(static)。要 concurrency/refresh 実機確認 -> UNKNOWN 併記。
```

### F4 — organization invitation の consume! が check-then-act で二重消費可能

```
ID: F4
Severity: P2
Title: invitation consume! が active? 判定後に update!(行ロック/原子 CAS 無)
Affected flow/surface: org invitation/referral consume(app 招待受諾に波及)
Precondition: 同一 code への同時 consume。
Failure: `return false unless active?; update!(consumed_at: now)` は 2 段。並行で双方 active? を
  通過し двойに成功 -> membership/benefit 二重付与の可能性。
Impact: 招待/紹介特典の重複取得、二重 membership。
Evidence: app/models/organization_invitation.rb:58-62,42-47 / app/services/org_invitation_service.rb:54-66
Existing control: code は unique。だが consume 自体は consumed_at 列で別管理。
Missing control: `where(consumed_at: nil).update_all(...)` の affected-rows==1 判定、
  または悲観ロック/状態遷移ガード。
Regression test: barrier/latch で 2 並行 consume -> 片方のみ成功を assert
  (working tree の test/services/org/invitation_service_test.rb 変更と整合確認)。
Confidence: Medium(static)。実 race は未実行 -> UNKNOWN。
```

### F5 — selector の enumerate→persist 間で membership/avatar 失効を再検証しない

```
ID: F5
Severity: P2
Title: 選択時に候補照合する一方、確定(persist)時の所有/membership 再検証が無い
Affected flow/surface: acme selector(account/org/avatar/consent)。app 面 selector に波及。
Failure: candidate_for_public_ids は selectable_candidates と全一致照合(良)だが、
  enumerate 後 persist_selection! までに membership.active? や avatar_assignment が剥奪されても
  確定が通る(persist 時 re-check/ロック無)。
Impact: 失効直後の権限で context 固定 -> 後続 private アクセスに連鎖しうる。
Evidence: app/services/acme_selectable_context.rb:24-35,40-56,60-74
Missing control: persist 時に owner/membership/state を原子的に再確認。
Regression test: selector 表示後に membership revoke -> 確定が拒否されることの test。
Confidence: Medium。
```

### F6 — email/telephone の条件付 unique index による soft-delete 競合

```
ID: F6
Severity: P2
Title: active レコード限定の条件付 unique index で削除↔再作成 race
Affected: sign-up identity 作成
Failure: index は (digest IS NOT NULL AND status<>DELETED) 条件。soft-delete とのタイミング次第で
  同一 normalized 値の重複が一時成立しうる。正規化(downcase/E.164)自体は適切。
Evidence: app/models/visitor_email.rb:33,68-74 / app/models/visitor_telephone.rb:27,58-64 /
  app/models/concerns/{email.rb:94-99,telephone_normalization.rb:81-100}
Missing control: 作成経路の行ロック or upsert、または delete+create を同一 transaction で直列化。
Regression test: 同 email 同時 sign-up の deterministic conflict test。
Confidence: Medium-Low(exploit 難)。
```

### F7 — 未ルートの local-only logout controller(dead code)

```
ID: F7
Severity: P3
Title: Sign::App::Auth::LogoutsController(OidcRpLogout=log_out+"/" 303)が孤立存在
Detail: 当該 controller は中央 logout に参加しない local-only logout を実装するが、
  sign_route_mapper は auth/logout を map せず、route-contract test が GET /auth/logout の
  RoutingError を assert。現状ユーザ到達不可(dead code)。
Risk: 将来ここへ route を付けると中央 logout を迂回する local-only logout を露出。
Evidence: app/controllers/sign/app/auth/logouts_controller.rb / app/controllers/concerns/oidc_rp_logout.rb /
  test/integration/routes/sign_route_contract_test.rb:247-252
Fix: 当該 controller/concern を削除、または internal-only 境界を明示。
Confidence: High。
```

### F8 — GET `/sign/out/edit?logout_challenge=…` がセッションを変更する

```
ID: F8
Severity: P3
Title: 確認(GET edit)が logout_challenge 提示時に logout_current_session! を実行
Detail: GET は非変更が原則だが、Acme coordinated 復路の edit?logout_challenge で
  logout_current_session! が走る。有効な single-use transaction が必要なため悪用は限定的。
Evidence: app/controllers/sign/app/sign/outs_controller.rb:24-28,50-73
Risk: logout-CSRF/軽微 DoS の表面。impact 低(logout 操作)。
Fix: coordinated 復路を POST 化、または challenge 厳格検証の維持を明文化。
Confidence: High。
```

### PASS として確認した主要事項(誤検出防止のため明示)

- **307 不使用**: app の logout chain は全て
  `:see_other`(303)。仮説の 307 は実装に存在せず、§9.1 の 307-POST 懸念は設計上解消済(303+GET
  completion)。`grep 307/temporary_redirect` 0 件。
- **id_token_hint の発行順**: working tree 変更で `oidc_rp_logout_id_token_hint` を
  `logout_current_session!`
  の**前**に移動(launcher:28-34)。logout 後発行による取り違い/空 hint を是正(良い修正)。
- **post_logout_redirect_uri**: Acme 側は client registry の exact-match allowlist
  (`oidc_redirect_uri_validator.rb:11-13`)。加えて全 redirect は `redirect_to_jump_url`
  の署名付き jump-token gateway 経由(`common_redirect.rb:77-102`)。open redirect 表面は小。
- **back-channel logout token**: alg!=none, iss/aud/iat/exp/events 完全一致, sid=UUID, nonce 不在,
  jti replay cache(10m), 不正=400/成功=200。spec 準拠。
- **session fixation**: log_in で reset_session(`authentication_base.rb:360-365`)。
- **CSRF**: 全 app sign-out で protect_from_forgery(exception)。skip_forgery_protection 無し。
- **OTP/ceremony/auth code/refresh**: 悲観ロック/single-use/TTL/reuse-family-revoke を確認。

---

## 12.9 Go / No-Go gate

| 条件                                            | 判定                                  |
| ----------------------------------------------- | ------------------------------------- |
| P0/P1 = 0                                       | ✗(F1 が P1)                           |
| 正常系 sign-in/up/out 実行済                    | △(静的確認のみ。動的未実行)           |
| selector dropout 安全                           | ◯(候補全一致照合)/△(F5 race 未テスト) |
| 307 chain 実機テスト or 安全方式                | ◯(303 採用済)                         |
| CSRF/open redirect/state/nonce/PKCE/code replay | ◯(静的確認)                           |
| duplicate signup/OTP/code/logout concurrency    | △(F4/F6 未テスト, UNKNOWN)            |
| signup/sign-in/OTP の automation control        | ◯(Turnstile+rate limit)               |
| Palm deferred revocation の誤表示無し           | △(F3 family/global を要明文化)        |
| logout 後の Acme/RP session 観測可能            | △(F1 で illusion, 観測性要追加)       |
| test 未実行を PASS 扱いしていない               | ◯(UNKNOWN 明記)                       |

**結論: No-Go(F1 解消が条件)。** F1 修正 + F4 の concurrency 検証で Conditional-Go。

---

## §11 推奨テスト(実装はしない / 名称と対象 file)

Route/HTTP:

- `test/integration/routes/sign_route_contract_test`: GET `/sign/out/{new,edit}` 非変更, POST
  `/sign/out` CSRF 必須, `/auth/logout` 非到達(既存)。
- 追加: POST `/sign/out` 以外の method/未対応 GET mutation の拒否。

Controller/E2E:

- `test/controllers/{sign,base,core}/app/sign_outs_controller_test`:
  - `ri=us`/`ri=JP`/`ri=任意` で **session/auth cookie クリア + Acme 303** を assert(**F1 回帰**)。
  - issue! 拒否時に complete を成功表示しない assert。
- `test/controllers/palm/app/sign_outs_controller_test`: bearer 失効と「token
  revoke」表示の区別、refresh_token_family の logout 後不可(F3)。
- cancel/back/refresh/timeout/double-submit / stale transaction / invalid selector ID。
- callback replay / code replay / invalid post_logout_redirect / invalid|missing|mismatch
  id_token_hint / back-channel valid|invalid|replay。

Concurrency(barrier/latch 必須):

- duplicate normalized identity(F6), OTP single consume, invitation single consume(F4), selector
  state transition(F5), authorization code single redeem, refresh rotation/reuse, logout
  idempotency, CAPTCHA token replay, distributed rate-limit threshold。

---

## Security observability(§10)メモ

- logout illusion(F1)は現状「complete
  200」を返すため、失敗が監視に乗りにくい。issue! 拒否を security event(理由付き,
  PII 抑制)として記録し correlation ID で追跡することを推奨。
- back-channel delivery/result/retry, selector invalid/stale, duplicate/race
  conflict のイベント化状況は §10 リストに対し別途棚卸しが必要(本監査では未網羅, UNKNOWN)。
