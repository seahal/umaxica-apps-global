# 認証認可 failure-first 総点検 — 監査実行プラン

> read-only
> audit。コード変更なし。成果物は**日本語のレポートをチャット出力**する (依頼書 §25 の 1〜15 の構成 +
> §26 の結論)。リポジトリ言語ポリシー(memos/ 含め英語必須)と日本語レポート運用の衝突を避けるため、今回は日本語レポートを
> `memos/`
> に**コミットしない**。実行手法は read-only 並列サブエージェントで最大深度(依頼書全観点を網羅)。

## Context

依頼: sign in / sign up / sign out / OIDC / OAuth / session / cookie / token / passkey / TOTP /
social / Entra ID / state machine / logging / tests / docs / enterprise
readiness を対象とした failure-first authentication lifecycle audit。happy
path ではなく、失敗・キャンセル・途中離脱・再試行・補償・競合・長期運用耐性を重視する。OWASP ASVS /
NIST 800-63 / ISO 27001 系の evidence gap も評価する。

前提事実(Phase 1 探索で確認済み):

- 実装の名前空間は route/controller とも `base`(= ADR 用語 Acme: IdP/durable identity authority)、
  `auth`(= Sign: credential gateway)、`core` / `side` /
  `palm`(RP)、`docs/help/info/news`(公開コンテンツ)。ADR 用語(Acme/Sign/Core/Base/Palm)と実装名(base/auth/core/side/palm)に恒常的なマッピングずれがある。`app/controllers/sign/{app,com,org}/`
  は空ディレクトリ(移行残骸)。
- 認証ドメイン: surface ごとの actor(Client/Visitor/Operator)× token(ClientToken 等)× sign-up flow
  ticket(ClientSignUpFlow/VisitorSignUpFlow + SignUpStateMachine)×
  ceremony 系 service(passkey/TOTP/secret
  credential の result_issuer/result_consumer/final_committer/
  transaction_purger)という構造。session limit は定数(MAX_SESSIONS_PER_USER 等)。
- 監査ログは Chronicle(専用 DB、retention policy、sanitizer)+ `IdentityAudit.record!`。
- rate limit は Rails native
  `rate_limit`(全部 IP キー)+ カスタム increment。prod は Redis、test/dev は MemoryStore/null_store。
- timing 対策は `MinimumResponseBudget` concern + `secure_compare` 多用。
- 既知の課題が `plans/backlog/` に大量に存在(sign-in/sign-up failure handling、OTP plaintext、atomic
  increment、token lifetime policy、gh584 ほか)。前回監査
  `memos/2026-06-13-security-audit-authentication-authorization.md`(FINDING-01..、修正済みあり)がベースライン。今回の finding は「新規」「既知(backlog 追跡済み)」「前回指摘の残存」を区別する。

## 監査の実行方針

依頼書(§0〜§27)のフォーマットに従い、以下のフェーズで実施する。全 read-only。

**実行手法**: Phase
B のフロー別深掘りを read-only 並列サブエージェント(Explore/general-purpose)に分担させ、各エージェントが返した証拠付き finding を私が突合・重複排除・severity 再評価する。finding は adversarial に検証(「本当に到達可能か」「happy
path で隠れていないか」をコード trace で確認)してから採用する。証拠(file:line)のない finding は採用しない。

### Phase A: ベースライン確立(コマンド実行)

- `git status --short`(済: clean)
- `bin/rails routes` を surface ごとに取得(DB 不要と確認済み)
- 認証関連テストの実行:
  `bin/rails test test/controllers/auth test/integration test/services test/models test/security`
  を認証系から優先実行。全体 `bin/rails test` は時間次第。
- `bin/rubocop` は参考程度(失敗しても監査は継続、結果は隠さず記載)。
- テスト失敗・実行不能はレポートに「どの段階で失敗し、監査結論にどう影響するか」を明記。

### Phase B: フロー別深掘り(コード精読)

依頼書 §6〜§21 の観点を、以下のフロー単位で読む。各フローで「DB record 作成時点 / 外部副作用時点 /
user-visible 時点 / rollback 可能範囲 / compensation 必要範囲 / cleanup job /
orphan 検出」を必ずトレースする。

1. **Trust boundary**:
   base(Acme)/auth(Sign)の authority 混線。auth 側が session/token を発行していないか。`/oauth/*`
   の所在(base.rb に OP ルートが見当たらない件の解明を含む)。ceremony
   grant/result(署名・audience・one-shot・TTL)の実装実在性。
2. **Sign in**: `Authentication::Base#log_in`、sign-in cycle、guardrail/check/selector、session
   limit(restricted session 15min)、stale state / tab 並行 /
   replay、MinimumResponseBudget の適用範囲と漏れ、enumeration。
3. **Sign up**: SignUpStateMachine、ClientSignUpFlow/VisitorSignUpFlow、
   `finalize_sign_up_from_checkpoint!` / `IdentityGraphProvisioner.call!` /
   `establish_signed_in_session!`、OTP
   retry/lock、checkpoint(birthdate/passkey/passcode)、途中離脱の cleanup(purge job /
   TTL)、二重 submit / 同時 finalize(row lock)、再登録可能性。
4. **Sign out / logout**:
   PRG、cookie 破棄の完全性(path/domain/name 一致)、LogoutTransaction、backchannel
   logout(署名/iss/aud/sid 検証)、refresh 復活、logout-state-machine 実装プラン(active)と現状の差分。
5. **Ceremony 系(passkey/TOTP/secret credential)**: result_issuer/consumer/final_committer/
   transaction_purger の対称性、challenge 破棄、orphan credential、setup 途中失敗、TOTP
   replay(`last_otp_at`、前回監査 FINDING-06 の lock 残課題)。
6. **Social / Entra**: omniauth callback、state/nonce、one-shot completion、cooldown、org Google
   temporary gateway 例外(ADR)の現状、Entra resolver/connection、disconnection 後の break-glass。
7. **OIDC/OAuth protocol**: authorization code single-use/TTL、PKCE S256、redirect_uri exact
   match、JWT claims(aud 配列、alg 混同、kid)、JWKS rotation、token exchange、refresh rotation /
   reuse detection / family revoke、DPoP/DBSC。
8. **Cookie/session/token matrix**: `__Host-`
   prefix の production ゲート(dev/test との差)、CoreBrowserCredentialContract、SameSite、削除時の属性一致、session
   fixation (reset_session)、Rails session に入る値の最小性。
9. **Rate limit / admission control**: IP 単独キーの弱点(NAT/credential
   stuffing)、email/account 単位の欠落箇所、store 差分による test の false
   confidence、session/device/ceremony 上限の race safety。
10. **Logging/audit**: Chronicle の event
    coverage(依頼書 §18 のイベント一覧との突合)、secret 漏れ、外部レスポンス vs 内部 reason
    code、tamper resistance / retention docs。
11. **Timing/enumeration**:
    MinimumResponseBudget が「disabled-by-default」である点の確認と適用漏れ、メッセージ/ステータス/リダイレクト差分、email 送信有無による存在漏れ。
12. **Tests / docs 整合**: stale test、mock 過多、docs contract(sequence docs /
    mermaid 図 vs 実装 route/state 名)、ADR supersession チェーンと code の乖離、
    `# FIXME: I FOUND DEGRADED ENTRYPOINT!!!!`(config/routes/auth.rb:201 付近)の実態。

### Phase C: マトリクス作成と standards mapping

依頼書 §25 の成果物フォーマット(1〜15)を全て埋める: Executive summary / フロー地図(mermaid)/
Failure-first lifecycle map / Findings(Severity・Evidence・Confidence 付き)/ State machine review /
Compensation review / Token・cookie matrix / Route surface matrix / Admission control matrix /
Timing・enumeration matrix / Enterprise readiness matrix / Test gap matrix / Docs gap matrix /
OWASP・NIST・ISO evidence matrix / Prioritized action plan(P0〜P3、slice prompt 粒度)。

最後に §26 の結論(production 可否、blocking issue、10年品質への最短ルート)を明記。

### 厳守事項(依頼書 §27 の要約)

- コード変更なし。証拠(file:line)なしの断定なし。推測は「推測」と明記+確認手順。
- backlog 追跡済み gap は finding に「既知」ラベルを付けて重複起票しない(ただし severity 再評価)。
- 既存 state machine / Rails Way / authority boundary 方針を尊重。server-side session 化や TLD
  crossing の提案はしない。compatibility shim を残す提案はしない(古い shim / legacy
  route が残ればリスクと削除方針を明記)。
- happy path が通ること・テストが通ること・docs 記載を、それぞれ安全性の証明とみなさない。
- 攻撃者/運用者/監査者/ユーザー復旧の4視点で見る。攻撃手順・悪用コードは書かない。

## 成果物

- 日本語のレポートをチャットに出力(§25 の 1〜15 + §26 の結論)。memos/ にはコミットしない。
- 各 finding は §25.4 形式(Severity / Category / Evidence(file:line)/ Standard reference
  / 観測事実 / なぜ重要 / attack・failure シナリオ / user recovery / enterprise impact / Recommended
  fix / Recommended tests / Recommended docs update / Confidence)。
- Prioritized action plan は P0〜P3。各 action を次の実装依頼にそのまま渡せる slice
  prompt 粒度に分解。
- 実装は行わない(read-only)。

## 検証(このプラン実行後の確認方法)

- 引用した file:line が実在し主張と一致するか、レポート化前に該当箇所を再読して確認。
- テストコマンド(`bin/rails test test/controllers/auth ...`)の実行結果を隠さず記載し、実行不能・失敗があれば監査結論への影響を明記。
- backlog / 前回監査(`memos/2026-06-13-...`)との突合で「新規/既知/残存」ラベルの妥当性を確認。
