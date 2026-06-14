# Recovery Secret Restricted Bootstrap Implementation Plan

> 本書は実装計画のみ。コード・migration・routing・config・test の変更は一切含まない。監査 finding を実コードで line 確認した結果と、残る gap の実装計画を記す。用語は英語識別子、説明は日本語（リポジトリの plan 運用に合わせる）。

---

## 0. Verification Result

### 0.1 確認した files / lines

| #   | 対象                                               | file:line                                                                                                                                                       |
| --- | -------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| V1  | 標準 sign-in entry                                 | `app/controllers/sign/app/in/secret_credentials_controller.rb:93-99` (`create` → `handle_standard_login`)                                                       |
| V2  | recovery 経由でも normal session を作る経路        | 同上 `:131-171` (`handle_standard_login`)、`:208-228` (`process_standard_login`)                                                                                |
| V3  | 候補 secret の eligibility scope                   | `app/models/client_secret_credential.rb:97-102` (`allowed_for_secret_credential_sign_in`)、`:66-67` (`SIGN_IN_ALLOWED_*`)                                       |
| V4  | **recovery が sign-in 可能 kind に含まれる決定打** | `app/models/client_secret_credential_kind.rb:19-21` (`PERMANENT = LOGIN` / **`ONE_TIME = RECOVERY`** / `ALLOWED_FOR_SECRET_SIGN_IN = [PERMANENT, ONE_TIME]`)    |
| V5  | recovery 判定                                      | `app/models/concerns/client_secret_credential_kinds.rb:26-28` (`recovery_secret_credential?`)                                                                   |
| V6  | session 確立の中枢                                 | `app/controllers/concerns/authentication_base.rb:2254-2285` (`establish_signed_in_session!`)                                                                    |
| V7  | MFA gate 判定                                      | 同上 `:2655-2664` (`mfa_required_for?`)、`:2676-2678` (`mfa_bypassed_for_auth_method?` は `passkey` のみ bypass)                                                |
| V8  | log_in（session 発行本体）                         | 同上 `:337-406`（`reset_session` は L352、family/他 device の全 revoke は無し）                                                                                 |
| V9  | consume の verifier（new-axis）                    | `app/services/sign_secret_verify.rb:17-53`（`with_lock` + `consume_success!`）                                                                                  |
| V10 | failure lockout                                    | 同上 `:68-81`（`failure_count` 加算、`max_failures_exceeded?` で `locked_at` + revoke）                                                                         |
| V11 | recovery issue service                             | `app/services/client_secret_credentials_issue_recovery.rb:19-60`（`secret_kind: "recovery"`, `max_uses: 1`, `max_failures: 5`, 既存 active recovery を revoke） |
| V12 | consume 時の chronicle のみの監査                  | `app/controllers/sign/app/in/secret_credentials_controller.rb:330-411` (`audit_recovery_code_used!`)                                                            |
| V13 | recovery reveal（step-up なし）                    | `app/controllers/sign/app/settings/emergency_keys_controller.rb:16-36`（`IdentityOneTimeReveal` + object authz のみ、`step_up` 無し）                           |
| V14 | LOGIN-kind 登録の step-up（参考）                  | `app/controllers/sign/app/settings/secret_credentials_controller.rb:20` (`step_up only: %i(new create)`)                                                        |
| V15 | 既存の全 session revoke primitive（再利用候補）    | `app/controllers/concerns/authentication_logout_all_sessions.rb:23-111`                                                                                         |
| V16 | restricted session の既存概念                      | `app/controllers/concerns/authentication_base.rb:370-386, 2295-2302, 2379-2399`（session-limit 由来の `STATUS_RESTRICTED` token）                               |
| V17 | recovery 動作の characterization test（現状の正）  | `test/controllers/sign/app/in/secret_credentials_controller_test.rb:210-248`                                                                                    |
| V18 | step_up DSL                                        | `app/controllers/concerns/verification_step_up_guard.rb:23-34`、`app/controllers/concerns/verification_base.rb:81-142`                                          |

### 0.2 監査 finding の真偽

- **U1（最重要・UNKNOWN だった点）→ RESOLVED。** Recovery Secret
  consume は MFA を必ず挟まない。`handle_standard_login`
  (`secret_credentials_controller.rb:131`) は recovery-kind を含む eligible secret を検証後
  `process_standard_login` → `establish_signed_in_session!`
  (`:154, :208-209`) を呼ぶ。`establish_signed_in_session!` は
  `mfa_bypassed_for_auth_method?("secret_credential") || !mfa_required_for?(resource)`
  (`authentication_base.rb:2259`) が真なら **そのまま `log_in` で通常 full session を発行**する。
  - `mfa_bypassed_for_auth_method?` は `passkey`
    のみ true（`:2676-2678`）なので secret では bypass しない。
  - しかし `mfa_required_for?` は
    `resource.mfa_level_required?`（`:2655-2664`）依存。actor が mfa_level 未設定なら **second
    factor 無しで直接 full session**。mfa_level 設定済みでも TOTP
    challenge を挟むだけで、**最終的に発行されるのは通常 full session**（restricted ではない）。
  - test `secret_credentials_controller_test.rb:210-248` が、recovery secret を発行 → 標準 sign-in
    endpoint に POST → `sign_app_sign_in_check_path`（通常 sign-in
    sequence）へ redirect することを assert しており、現状動作として確定。

- **Finding「consume が standard login 扱い・通常 session 発行」→ TRUE（確定）。** V2, V4, V6, U1。
- **Finding「consume 時に既存 session / refresh token family を全 revoke していない」→
  TRUE（確定）。** `log_in` (`authentication_base.rb:337-406`) は現在の browser session cookie を
  `reset_session` でクリアし (`:352`)、`session_limit_state_for`
  で MAX_SESSIONS を超えた場合に restricted 化するのみ (`:367-386`)。**他 device session・refresh
  token family の全 revoke は無い**。revoke-all primitive
  (`AuthenticationLogoutAllSessions`) は存在し他所では使用されている（`acme/app/settings/secret_credentials_controller.rb:89`
  の destroy）が、recovery consume では呼ばれない。
- **Finding「consume 後に passkey/TOTP/recovery の再登録・再確認を要求していない」→ TRUE（確定）。**
  consume 成功後は full session が出るだけで再 bootstrap gate は存在しない。
- **Finding「issue 時に step-up が必須でない疑い」→ PARTIALLY CORRECTED / 一部 UNKNOWN。**
  - LOGIN-kind の secret credential 登録 controller は `step_up only: %i(new create)`（V14）を持つ。
  - recovery secret reveal（`emergency_keys_controller#show`, V13）は one-time token + object
    authz のみで **step_up は無い**。
  - recovery codes 生成本体 `ClientSecretCredentialsIssueRecovery` は
    **本 repo 内に非 test の caller が存在しない** （`grep`
    上 caller は test のみ。`secret_credentials_controller.rb` の comment "acme/www owns
    account-facing secret credential
    lifecycle" が示す www 生成経路は本 repo で未確認）。よって「issue が step-up 必須か」は
    **生成経路自体が UNKNOWN**。
- **Finding「high assurance mode / `mfa_level` と issue/consume の連動が無い」→ TRUE（確定）。**
  `ClientSecretCredentialsIssueRecovery`
  は mfa_level を参照しない。consume 側の mfa_level 連動は汎用 sign-in MFA
  gate（`mfa_required_for?`）のみで、recovery 固有のものは無い。
- **Finding「issue/consume の user-visible notification が無い」→ TRUE（確定）。** `grep`
  上 mailer に "recovery" 参照は皆無。issue は ClientChronicle（監査）のみ、consume は
  `audit_recovery_code_used!`（chronicle）のみで、email/SMS/in-app 通知は無い。
- **Finding「consume の rate limit / failed attempt / atomicity が弱い」→ PARTIALLY CORRECTED。**
  - rate limit: `:create` に IP base の `rate_limit`（5/min,
    20/15min）あり（`secret_credentials_controller.rb:20-43`）。ただし key は `request.remote_ip`
    のみ＝**account / credential 単位の limit は無い**（分散 brute force に弱い）。
  - failed attempt: recovery secret は new-axis（`secret_kind` 等を持つ）なので consume は
    `SignSecretVerify` を通り、 `failure_count`/`max_failures`(=5)/`locked_at` の **per-credential
    lockout は実在**（V10, V11）。→ 「failed attempt handling が無い」は誤り。
  - atomicity: `SignSecretVerify` は `with_lock` + reload + consumed/max_uses チェックで
    **同一 credential の二重 consume を row
    level で防止**（V9）。→ 「atomicity が無い」は誤り。ただし
    **consume と session 発行は別 transaction**で、「mark consumed」+「全 revoke」+「restricted
    session 発行」を束ねる atomicity は存在しない（後述 gap）。

### 0.3 残る UNKNOWN

- **U-A**: production で recovery codes を生成する経路（`ClientSecretCredentialsIssueRecovery`
  の非 test caller）。www /
  acme 側に存在する可能性。step-up 適用有無を含め未確認。実装着手前に locate 必須。
- **U-B**: `org` / `com` surface（`sign/org/in/secret_credentials_controller.rb`,
  `sign/com/in/secret_credentials_controller.rb`）の recovery 動作。最初の grep でこれらも
  `process_standard_login` / `establish_signed_in_session!` を参照しており
  **同型の脆弱性が濃厚**だが、kind
  eligibility は Client モデルでのみ line 確認済み。Operator/Visitor の kind 定数は別途確認要。
- **U-C**: refresh token family の「全 revoke」を recovery consume の文脈で
  `AuthenticationLogoutAllSessions`（session 単位 revoke + session_version
  bump）で十分カバーできるか、family 単位の明示 revoke が追加で必要か（`revoke_inactive_refresh_token_family!`
  系との整合）。
- **U-D**: DPoP/DBSC bound session・external OIDC
  grant の revoke 範囲（recovery 時にどこまで巻き込むか）。

> 推測で PASS とは書かない。U-A〜U-D は UNKNOWN として残し、Slice 0 で解消する。

---

## 1. Problem Statement

### 1.1 現状の問題

Recovery Secret が **通常ログイン手段と同一経路**で処理される。`ALLOWED_FOR_SECRET_SIGN_IN` が
`ONE_TIME = RECOVERY` を含む（`client_secret_credential_kind.rb:19-21`）ため、recovery-kind
credential が `allowed_for_secret_credential_sign_in` scope を通過し、標準 sign-in form から検証 →
`process_standard_login` → `establish_signed_in_session!` → `log_in` で **通常 full session**
が発行される。

### 1.2 Account takeover risk

- recovery secret 1 個の漏洩（紙・スクショ・mail 流出・support 経由）で、攻撃者は
  **MFA 未設定 actor なら second factor 無しに full session** を取得できる。
- consume しても **既存 session / refresh
  family は revoke されない**ため、被害者の生きた session と攻撃者の session が
  **併存**する。被害者は乗っ取りに気付きにくく、復旧手段も奪われる。
- consume 後に
  **再 bootstrap（passkey/TOTP 再登録）が強制されない**ため、攻撃者は full 権限のまま email/telephone 変更・API
  token 発行等の重要 write を即実行できる。
- issue/consume の **user-visible notification が無い**ため、被害者への早期警告経路が無い。

### 1.3 なぜ通常 login として扱ってはいけないか

Recovery
Secret は「正規利用者が他の factor を全喪失した状態」での最後の証票であり、提示者が正規である保証は他 factor より弱い。よってこれを通常 session の発行根拠にすると、認証強度の最も低い経路が full 権限を直接与えることになり、AAL
ladder が崩れる。Recovery Secret は **full session を出す credential ではなく、restricted
recovery/bootstrap state へ遷移する one-time 証票**として扱う必要がある。

---

## 2. Target Security Model

### 2.1 Recovery Secret の定義

- 通常ログイン手段ではない。`ALLOWED_FOR_SECRET_SIGN_IN`
  から RECOVERY を外し、標準 sign-in では consume 不可にする。
- 専用の **consume endpoint**（restricted recovery flow）でのみ受理する one-time 証票。

### 2.2 Restricted recovery / bootstrap state の定義

- consume 成功で actor/client を `recovery_bootstrap_required`（採用名は §3）へ遷移。
- この state では **bootstrap 専用 endpoint のみ**許可（§5.3）。通常 read/write は全面禁止。

### 2.3 通常 session を発行してよい条件

以下が **全て**完了して初めて通常 session を発行（目標状態 7）：

1. 既存 client/device session 全 revoke
2. 既存 refresh token family 全 revoke
3. 既存 access token による重要 write 拒否（session_version bump 等で fail-closed）
4. restricted recovery/bootstrap session のみ発行
5. passkey / TOTP / new recovery secret の **再登録または再確認完了**

### 2.4 Revoke 方針

fail-closed。revoke が完了しない限り restricted
session すら発行しない（§4.4）。revoke 対象は §4.1 に列挙。

### 2.5 High assurance mode との関係

- `mfa_level=FULL` の actor は issue に passkey/FIDO
  step-up 必須、bootstrap 完了に passkey 必須（§5.6）。
- recovery state は通常 session より優先（recovery 中は通常 session 復帰不可）。

---

## 3. State / Data Model Plan

### 3.1 状態名（採用案）

採用: **`recovery_bootstrap_required`**（候補 `restricted_recovery` /
`recovery_rebootstrap_required` /
`account_recovery_pending`）。「再 bootstrap が完了するまで通常 access 不可」という不変条件を最も直接表すため。

### 3.2 状態を持たせる model（採用案）

採用: 新 model **`ClientRecoveryCeremony`**（候補 `Client` 直持ち / `ClientRecoveryState` /
`ClientRecoveryAttempt`）。

- 理由: Client への boolean/timestamp 散在は flag 累積（[[feedback_structural_over_flags]]
  参照）になりやすい。1 recovery 行為 = 1 ceremony 行で lifecycle・参照・時刻を集約し、concurrent
  consume の unique 制約も貼りやすい。
- app surface 確定後、org/com（U-B）は同型の `OperatorRecoveryCeremony` 等を別途検討。

### 3.3 必要 columns（migration 候補・別 migration に分離）

`client_recovery_ceremonies`（app_principal DB 想定）:

- `state`（string; `recovery_bootstrap_required` / `completed` / `cancelled` / `expired`）
- 時刻: `recovery_started_at`, `recovery_completed_at`, `recovery_expires_at`,
  `recovery_cancelled_at`
- 参照: `user_id`(client), `initiating_token_id`（発行した restricted session）,
  `consumed_secret_credential_id`, `request_id`, `actor_surface`
- 一意性: `user_id` に対し open（`recovery_bootstrap_required`）行は 1 つだけ → partial unique
  index（`WHERE state = 'recovery_bootstrap_required'`）。**concurrent
  consume の二重 bootstrap 防止の要**。

`client_secret_credentials` への追加（既存 column を最大限再利用）:

- 既存で利用可能: `consumed_at`, `revoked_at`, `last_used_at`, `failure_count`, `max_failures`,
  `safe_prefix`, `last_failed_at`, `locked_at`, `issued_at`（schema コメント
  `client_secret_credential.rb:9-40` で確認済み）。**新規追加は基本不要**。
- expiry/rotation: 現状 `discarded_at` default
  `Infinity`（無期限）。recovery には有限 expiry を issue 時に設定する方針（§4.1）。column 追加は不要、値の設定で対応。

> 既存 column が揃っているため、recovery 専用フィールドの新設は ceremony 表に限定し、secret_credential 表は値運用で賄う。

### 3.4 Transaction / locking plan

- consume の核を 1 transaction で束ねる（§4.3）。順序:
  1. `SignSecretVerify`（`with_lock`）で credential を atomically consume（既存挙動, V9）。
  2. 同一 transaction 内で `ClientRecoveryCeremony`
     を partial-unique 制約付きで作成（二重 consume は unique
     violation で 1 つだけ成功 = 目標状態 10）。
  3. revoke-all（§4.4）。
  4. restricted session 発行。
- 失敗時は全 rollback、通常 session を一切発行しない（fail-closed）。

### 3.5 Expiry / cancellation / completion

- `recovery_expires_at`: restricted session TTL（既存 `RESTRICTED_SESSION_TTL = 15.minutes`,
  `authentication_base.rb:87` を基準に recovery 用 TTL を別定義）。期限切れは `expired`
  化し再 sign-in 要求。
- cancel: actor 明示操作で `cancelled`、restricted
  session を revoke、通常へは戻さず再 sign-in 要求。
- complete: bootstrap（passkey/TOTP/new recovery 再登録）完了で
  `completed`、その後初めて通常 session 発行。

---

## 4. Service / Controller Plan

> 既存の AAL/step-up/verification 基盤（`VerificationBase`, `VerificationStepUpGuard`,
> `AuthenticationLogoutAllSessions`）を再利用し、新規抽象は最小化する。

### 4.1 Issue flow

- 専用 service `ClientRecoverySecretIssue`（既存 `ClientSecretCredentialsIssueRecovery`
  を base に拡張）。
- step-up 必須化（§5.1）。`mfa_level=FULL` は passkey/FIDO step-up 必須。
- 既存 active recovery を revoke（既存 `revoke_existing_recovery_secret_credentials!`,
  `client_secret_credentials_issue_recovery.rb:68-74` を踏襲）。
- raw secret は **一度だけ表示**（既存 `IdentityOneTimeReveal`
  を踏襲、`emergency_keys_controller.rb:17`）。
- raw secret を log/chronicle/mail/job args に出さない（既存 issue は `name: raw.first(4)`
  の safe_prefix のみ保存 = 漏洩していない。この不変条件を test で固定）。
- 有限 expiry を設定（§3.5）。
- issue 時 user-visible notification（§6）。
- issue を chronicle に記録（既存 `RECOVERY_CODES_GENERATED` を踏襲）。
- issue rate limit（§7）。

### 4.2 Consume flow（標準 sign-in から分離）

- `ALLOWED_FOR_SECRET_SIGN_IN` から RECOVERY を除外し、標準 sign-in での recovery
  consume を不可にする（`client_secret_credential_kind.rb:21` の値変更が中心）。
- 専用 controller/endpoint（restricted recovery flow）で recovery secret を受理。
- consume 成功で **通常 session を発行しない**。代わりに §4.3〜4.4 を実行。

### 4.3 Consume の核（1 transaction, fail-closed）

1. `SignSecretVerify` で credential consume（row lock, V9）。失敗は failure lockout（V10）へ。
2. `ClientRecoveryCeremony` を partial-unique 付きで作成（二重 consume を 1 つに収束, §3.4）。
3. revoke-all（§4.4）。
4. restricted recovery/bootstrap session のみ発行。
5. notification（§6） / chronicle（§6）。

### 4.4 Revoke flow

- 既存 `AuthenticationLogoutAllSessions.call(resource: client, reason: "recovery_consume")`
  （`authentication_logout_all_sessions.rb:23-111`）を再利用。これは
  - 全 token を `AuthenticationLogoutCurrentSession` で revoke、
  - `session_version` を bump（still-valid JWT を refresh 時に拒否 = 目標状態 3）。
- refresh token
  family の全 revoke が session 単位 revoke で十分か、family 単位明示 revoke が要るかは **U-C**
  で確定。
- DPoP/DBSC・external grant の巻き込み範囲は **U-D** で確定。
- **fail-closed**: revoke が成功しない限り restricted session を発行しない。順序は「revoke →
  restricted session 発行 → chronicle →
  notification」。notification 失敗は recovery を fail させず audit に残して続行（§6）。

### 4.5 Bootstrap flow

- restricted session 下で passkey/TOTP/new recovery secret の再登録 or 再確認を実施。
- 全要件充足で ceremony を `completed` 化 → 初めて通常 session 発行（`establish_signed_in_session!`
  を bootstrap 完了 context で呼ぶ）。

### 4.6 Notification flow / 4.7 Chronicle flow / 4.8 Rate limit flow

§6, §7 に詳述。

### 4.9 Fail-closed behavior

- verify 失敗・ceremony 作成失敗・revoke 失敗・restricted
  session 発行失敗のいずれも通常 session を発行しない。例外は rescue で握り潰さず、明示 status で sign-in 失敗扱い。

---

## 5. Authorization / Step-Up Plan

### 5.1 Issue authorization

- 既存 `step_up` DSL（`verification_step_up_guard.rb:23`）を recovery issue action に適用。
- `mfa_level=FULL` は `step_up_strong_methods`
  を passkey/FIDO に限定（`verification_base.rb:394`）。

### 5.2 Consume authorization

- 専用 consume endpoint。guest mode だが turnstile + rate limit + per-credential lockout を維持。
- 標準 sign-in controller では recovery を弾く（§4.2）。

### 5.3 Restricted session authorization

- restricted session で **許可**する endpoint:
  - passkey registration
  - TOTP registration
  - recovery secret reissue
  - recovery cancel
  - sign out
- restricted session で **禁止**する endpoint:
  - account settings（email/telephone change 含む）
  - org write
  - API token issue
  - external grants（OIDC consent 等）
  - 通常 app/core/palm API access
- 実装は restricted token status（既存 `STATUS_RESTRICTED` 概念,
  `authentication_base.rb:377`）＋ ceremony state 判定を controller
  pipeline の gate（service/model 層で強制、UI のみに依存しない）として追加。

### 5.4 Bootstrap endpoint authorization

- bootstrap 専用 endpoint は restricted session + open
  ceremony を必須化。ceremony 無し/期限切れは拒否。

### 5.5 Operator / support negative authorization

- operator/support が他 actor の recovery secret を issue/consume/view できないこと（test で固定,
  §6/§H）。
- break-glass が要るなら別 ADR（本計画では bypass を一切作らない）。

### 5.6 High assurance mode behavior

- `mfa_level=FULL`: issue に passkey/FIDO step-up 必須、bootstrap 完了に passkey 必須。weak
  recovery のみでの通常復帰は不可。passkey 完全喪失時の fallback は §8 Open Question。

---

## 6. Test Plan

> 既存 characterization test（`secret_credentials_controller_test.rb:210-248`）は
> **現状の脆弱動作を固定**している。Slice
> 0 で「現状を記録する characterization」を別途追加し、その後この test の期待値を新仕様へ更新する。

### 6.1 Unit tests

- `ClientRecoverySecretIssue`: step-up 必須、`mfa_level=FULL` で passkey 必須、既存 active recovery
  revoke、有限 expiry 設定、raw secret 非永続（safe_prefix のみ）。
- `ClientRecoveryCeremony`:
  state 遷移（required→completed/cancelled/expired）、expiry、partial-unique。
- consume service: 通常 session を作らない／restricted のみ作る／全 revoke する。

### 6.2 Integration tests

- recovery consume が normal session を作らない（現 `:210-248` の期待値更新）。
- consume が全 session / 全 refresh family を revoke する。
- restricted session が account/org/API write に到達できない。
- bootstrap 完了まで通常 access 不可、完了後に通常 session。

### 6.3 Policy tests

- restricted session の許可/禁止 endpoint matrix（§5.3）。
- operator が他 actor の recovery を issue/consume/view 不可。

### 6.4 Security invariant tests

- raw secret が chronicle/log/mail/job args に出ない。
- 標準 sign-in endpoint で recovery secret が consume されない（kind 除外）。

### 6.5 Race / concurrency tests

- concurrent consume が 1 回だけ成功（partial-unique + row lock）。
- concurrent consume で二重 bootstrap が起きない。

### 6.6 Audit / notification tests

- issue / consume / bootstrap complete / cancel / failed-threshold で chronicle event。
- 同イベントで user-visible
  notification 送信。notification 失敗時も recovery 自体は fail しない（audit 継続）。

---

## 7. Rollout Plan

1. **characterization tests first**: 現状（recovery→normal
   session）を固定する test を追加し、回帰検知の土台にする。
2. **Slice 0 で UNKNOWN 解消**: U-A（issue 生成経路）・U-B（org/com）・U-C（family
   revoke）・U-D（DPoP/DBSC/grant）。
3. **migration**: ceremony 表 +
   index を schema 変更として追加（data 変更と分離、reversible、lock 影響を考慮）。既存 recovery
   secret の backfill は原則不要（issue 時のみ新仕様適用）。expiry 無期限の既存 recovery は§8 で扱い。
4. **disabled-by-default flag**: 新 consume 経路は flag 下で段階導入。flag
   off の間は現状動作を維持しつつ characterization test で保護。
5. **existing recovery secrets migration**: 既存 active recovery は次回 issue で revoke される（既存
   `revoke_existing_recovery_secret_credentials!` 踏襲）。強制 rotation の要否は §8。
6. **production safety checks**: fail-closed の検証、notification 経路の死活、rate limit
   key の確認。
7. **rollback strategy**: flag off で旧経路へ即時戻し。ceremony 表は残置可（参照のみで害なし）。

---

## 8. Risks / Open Questions

- **U-A〜U-D（§0.3）**が未解消のまま着手すると、issue 側 hardening と org/com parity が漏れる。
- **UX impact**: recovery 後に必ず bootstrap を要求するため、正規利用者の復旧手順が増える。
- **Account lockout risk**: passkey 完全喪失 + `mfa_level=FULL`
  で bootstrap に passkey 必須にすると正規利用者が締め出される。fallback 設計（別 ADR の break-glass か、TOTP 代替許可か）が Open。
- **Support burden**: 乗っ取り通知増・recovery 失敗問い合わせ増。
- **Compatibility**: 既存無期限 recovery secret の扱い（強制 expire / 次回 issue で revoke
  / 据え置き）を要決定。
- **family revoke の範囲**（U-C）と **DPoP/DBSC/external grant**（U-D）の巻き込み過不足。

---

## 9. Minimal Slice Proposal

推奨順序（各 slice: 変更ファイル候補 / test 候補 / rollback）。

### Slice 0 — Verify & characterize（コード挙動の確定）

- 目的: U-A/U-B/U-C/U-D を line 確認で解消し、現状動作を test で固定。
- 変更ファイル候補: なし（調査）+ characterization
  test 追加のみ（`test/controllers/sign/app/in/secret_credentials_controller_test.rb`
  ほか org/com）。
- test 候補: 「recovery→現状 normal session」を明示的に記録する characterization。
- rollback: test 削除のみ。

### Slice A — Issue step-up gating

- 変更ファイル候補: recovery issue を行う controller（U-A で確定した経路）+
  `ClientRecoverySecretIssue` service、 `verification_step_up_guard` 適用。
- test 候補: 6.1（issue step-up / `mfa_level=FULL` passkey 必須 / raw 非永続）。
- rollback: step_up 宣言を外す。

### Slice B — Consume を normal session から分離（restricted state へ）

- 変更ファイル候補: `client_secret_credential_kind.rb`（`ALLOWED_FOR_SECRET_SIGN_IN`
  から RECOVERY 除外）、新 consume controller、`ClientRecoveryCeremony` model + migration。
- test 候補: 6.2（normal session を作らない /
  restricted のみ）、6.4（標準 sign-in で recovery 不可）。
- rollback: flag off で旧 eligibility に戻す。

### Slice C — Revoke sessions / families on consume

- 変更ファイル候補: consume service に `AuthenticationLogoutAllSessions` 統合（fail-closed 順序）。
- test 候補: 6.2（全 session/family revoke）、fail-closed。
- rollback: revoke 呼び出しを flag で無効化。

### Slice D — Bootstrap completion gate

- 変更ファイル候補: restricted session の endpoint allowlist（§5.3）、bootstrap controller、ceremony
  complete 化。
- test 候補: 6.2（完了まで通常 access 不可 / 完了後 normal session）、6.3（policy matrix）。
- rollback: gate を flag off（restricted=通常扱いに一時退避）。

### Slice E — Chronicle + Notification

- 変更ファイル候補: chronicle
  event 追加、新 mailer/notifier（issue/consume/bootstrap/cancel/failed-threshold）。
- test 候補: 6.6。
- rollback: notification を audit-only に縮退。

### Slice F — Rate limit + concurrency hardening

- 変更ファイル候補: consume/issue の per-account/credential rate limit
  key 追加、partial-unique 制約 migration。
- test 候補: 6.5（concurrent consume 1 回成功 / 二重 bootstrap 不可）、6.4。
- rollback: rate limit を IP-only に戻す（unique 制約は残置可）。

### Slice G — org / com / operator / visitor parity（U-B 依存）

- 変更ファイル候補: `sign/org/in`, `sign/com/in` の対応 controller と各 kind モデル。
- test 候補: app と同一 invariant を各 surface で。
- rollback: surface 単位 flag。
