# Auth Ceremony Grill — CONTEXT

> 状態:
> grill 進行中（read-only 調査）。実装・migration・route・テストは変更しない。docs/ADR のみ更新する。最終更新の根拠は
> `EVIDENCE-LEDGER.md` を参照。確定していない論点は `OPEN-QUESTIONS.md`。

## このリポジトリの実形に合わせた baseline 補正

grill bundle の暫定 baseline は `UserToken`
という単一語彙を仮定しているが、本リポジトリの実体は surface /
actor ごとに分かれている。以下に読み替える。

| bundle 語彙                                | 本リポジトリの実体                                                                                                                                                                        |
| ------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Acme（IdP/AS/Session・Token Authority）    | `acme/www`。`adr/identity-authority-boundary.md`, `adr/acme-session-and-token-authority.md` で確定。                                                                                      |
| Sign（credential ceremony RP, non-issuer） | `sign/id`。Credential Gateway / Ceremony Zone。session/token/refresh/step-up freshness を発行しない。                                                                                     |
| UserToken                                  | actor 別の `VisitorToken` / `ClientToken` / `OperatorToken`（`app/models/*_token.rb`）。                                                                                                  |
| identity                                   | actor 別 `*_identity` と provider 別 `client_google_identity` / `client_apple_identity`。                                                                                                 |
| ceremony state                             | `*_email_ceremony_transaction` / `*_telephone_ceremony_transaction` / `*_secret_credential_ceremony_transaction` / `*_totp_ceremony_transaction` / `identity_social_ceremony_candidate`。 |
| 3 surface                                  | `app`（end-user, social あり）/ `com`（public, social なし）/ `org`（staff, social なし・電話は二要素必須）。                                                                             |

## 現行 component boundary（accepted, 2026-06-12 supersession）

`adr/acme-sign-core-base-port-boundary.md` が現行 source of truth。

- Acme = 唯一の IdP / Authorization Server。
- Sign = special RP（credential ceremony のみ）。
- Core = Next.js web RP/BFF。
- Base = Rails foundation / control-plane subdomain。
- Palm = native bearer-token API Resource Server（旧 Port）。

## 4系統の現行 flow inventory（暫定。詳細は track 別 checklist へ）

### Email

- ceremony state: `visitor_email_ceremony_transaction` / `client_email_ceremony_transaction` /
  `operator_email_ceremony_transaction`。
- OTP race は `adr/email-otp-race-condition-fixes.md` で `with_lock`（SELECT ... FOR
  UPDATE）に修正済み。
- 追加 cooldown（新規 email を一定期間 untrusted 扱い）は
  `plans/backlog/new-email-trust-cooldown.md` の **PROPOSAL のみ・未決**。

### Social

- principal key = `(uid, provider)`。DB UNIQUE `index_client_google_identities_on_uid_and_provider`
  他。
- `SocialAuthVerifiedProviderAssertion` は `email_verified=false` を明示拒否（nil は許容）。
- provisioning（`OidcRpIdentityProvisioning`）は `(iss, sub, aud)` か public subject
  claim でのみ actor を解決。**email 一致での自動 link/merge はしない（fail-closed）**。
- `app` のみ Google/Apple。`org`/`com`
  は social 無し（`adr/google-social-temporary-gateway-exception.md` Withdrawn）。

### Telephone

- ceremony state: `*_telephone_ceremony_transaction`、status/ occurrence 系モデル多数。
- SMS/voice OTP。`org`
  は電話単独で AAL1 を成立させず、passkey/passcode 等の追加 verifier を要求（sign-up plan）。

### Cross-cutting Security

- Turnstile: `lib/jit_security_turnstile_verifier.rb`。outage/timeout/secret 欠落は
  **fail-closed**（`success:false`）。server-side Siteverify。**ただし hostname/action/cdata
  binding と token single-use(replay) のローカル検証は未実装（gap）**。
- session: `__Host-session`（AES-256-GCM, SameSite=lax）。`reset_session` on
  login/logout（fixation 対策あり）。
- token: ES384 JWT、refresh は SHA3-384 digest 保存・rotation・reuse 時 family revoke。
- 直近監査: `memos/2026-06-13-security-audit-authentication-authorization.md` →
  `adr/security-audit-findings-2026-06-13.md`（FINDING-01..04 修正、05 不要、06 未修正）。

## docs/code/tests の矛盾候補（contradiction list, 暫定）

| #   | 矛盾                                                            | 証拠                                                    | 扱い                                                                                      |
| --- | --------------------------------------------------------------- | ------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| C-1 | grill baseline の `UserToken` 単一語彙 vs 実体の actor 別 token | bundle / `app/models/*_token.rb`                        | 語彙補正済み（本ファイル冒頭表）。                                                        |
| C-2 | 多数の ADR が `acme` IdP / `sign` RP の旧モデルで書かれている   | `adr/acme-rp-boundary-naming.md` 他「Superseded」群     | 2026-06-12 boundary が優先。古い ADR は読み替え。                                         |
| C-3 | `notes/oauth2-1-compliance-gap.md` は「sign.\* = AS」と記述     | note vs `adr/identity-authority-boundary.md`（acme=AS） | note は design-direction、ADR が優先。要 OPEN-QUESTION 化（誰が AS か実装上の現況確認）。 |
| C-4 | Turnstile に hostname/action/replay binding が無い              | `lib/jit_security_turnstile_verifier.rb`                | gap。incident pattern #9 と対応。                                                         |
| C-5 | FINDING-06 TOTP same-window replay の lock 未修正               | `memos/2026-06-13-...md`                                | gap、未決（accept か fix か）。                                                           |
| C-6 | token controllers の CSRF `null_session`                        | `plans/backlog/gh584-auth-security-fixmes.md`           | 未調査、要評価。                                                                          |
