# Auth Ceremony Grill — AUTHORITY MATRIX

各 mutation に「唯一の authority」「唯一の commit
point」があることを確認する表。EVIDENCE 列はファイル根拠。空欄/`UNKNOWN` は未確認。

| Mutation                                                       | Authority                                       | Commit point                          | Evidence                                                                                               | 備考                                       |
| -------------------------------------------------------------- | ----------------------------------------------- | ------------------------------------- | ------------------------------------------------------------------------------------------------------ | ------------------------------------------ |
| user session create/rotate/reset/revoke                        | `acme/www`                                      | acme session service                  | `adr/acme-session-and-token-authority.md`                                                              | Sign は不可                                |
| refresh token family issue/rotate/replay-detect/revoke         | `acme/www`                                      | acme token service                    | 同上 / 監査メモ（SHA3-384, family revoke）                                                             | reuse 検出で family revoke 実装あり        |
| access / downstream token issue                                | `acme/www`                                      | acme token service                    | `adr/identity-authority-boundary.md`                                                                   | core/line/palm は acme 発行のみ信頼        |
| account / org lifecycle                                        | `acme/www`                                      | account authority                     | `adr/identity-authority-boundary.md`                                                                   | Sign 不可                                  |
| step-up freshness (`recent_auth`/`sudo`/`last_step_up_at`/AAL) | `acme/www`                                      | acme session state                    | `adr/acme-session-and-token-authority.md`                                                              | Sign は ceremony 実行のみ、結果は evidence |
| credential ceremony 実行（passkey/OTP/TOTP/social callback）   | `sign/id`                                       | ceremony transaction                  | `adr/identity-authority-boundary.md`                                                                   | issuer ではない                            |
| social identity link `(uid, provider)`                         | RP provisioning（`OidcRpIdentityProvisioning`） | `ensure_rp_identity_for` + DB UNIQUE  | `app/controllers/concerns/oidc_rp_identity_provisioning.rb`, `app/models/client_google_identity.rb:29` | email 一致 link は **しない**              |
| email OTP attempt/lockout                                      | email model                                     | `with_lock` 内                        | `adr/email-otp-race-condition-fixes.md`                                                                | atomic 化済み                              |
| Turnstile 検証                                                 | RP controller（pre-mutation）                   | `JitSecurityTurnstileVerifier.verify` | `lib/jit_security_turnstile_verifier.rb`                                                               | fail-closed                                |
| ClientToken revoke on credential destroy                       | controller → `AuthenticationLogoutAllSessions`  | controller `destroy`                  | `adr/security-audit-findings-2026-06-13.md` FINDING-02                                                 | 修正済み                                   |

## 未確定 authority（OPEN-QUESTIONS 参照）

- AS（authorization server）の実装上の現在地：ADR は `acme`、note は `sign.*`。→
  Q（実装現況の確認後、矛盾なら ADR 補記）。
- 新規 email の「trust」付与 authority と cooldown：未決（proposal）。
