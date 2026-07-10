# Grill: OpenAI 流アカウント保護観点での Umaxica 認証認可レビュー（改訂 v2）

> **このファイルについて.**
> プランモードの制約で編集可能なのはこのファイルのみのため、レビュー本体をここに書いている。承認後、内容をそのまま
> `plans/objective-grill-openai-style-account-security.md`
> に保存する（実装変更・migration・config 変更・ルーティング変更・テスト修正は一切行わない、レビューと差分抽出のみ）。
> **改訂メモ (v2):** v1 で「高保証モードは存在しない」と判定したが、ユーザ指摘どおり **`mfa_level`
> という per-account モードが実在**
> した。再分析の結果、モードは「実装はあるがトグルが未ルーティング・浅い・無監査」という別種のギャップだった。Section
> A・Executive Summary・Mapping・Remediation を改訂。 **言語ポリシーの衝突メモ:** `AGENTS.md`
> の Repository Language Policy は `plans/`
> を English-only とするが、ユーザの明示指示（[[feedback_japanese_docs]]
> / 本タスクの依頼言語）に従い散文は日本語、識別子・ファイルパス・control 名は英語。

レビュー対象: Acme / Sign / Core /
Palm の認証認可実装、ADR、docs/security、memos/notes、tests。外部参照モデル: OpenAI ChatGPT Advanced
Account Security / Lockdown Mode / Enterprise security controls。
**OpenAI と完全一致は目標にしない。Umaxica に必要な差分として評価する。**

---

## 0. 訂正サマリ（v1 → v2 の差分）

| 項目                         | v1 判定                 | v2 判定（訂正後）                                     | 根拠                                                                                                                                   |
| ---------------------------- | ----------------------- | ----------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| 高保証アカウントモードの存在 | **FAIL（無い）** ❌誤り | **PARTIAL（実在するが浅い・未ルーティング・無監査）** | `app/models/client_mfa_level.rb`、`app/controllers/sign/app/settings/mfa/challenges_controller.rb`、`authentication_base.rb:2654-2679` |

**何が実在するか（モードの実体）:**

- per-account 永続状態 `mfa_level`。`ClientMfaLevel`:
  `NOTHING=0 / WEAK=1 / MEDIUM=5 / FULL=9`（`app/models/client_mfa_level.rb:13-18`）。Client 列
  `mfa_level_enabled:boolean default(FALSE)`・`mfa_level_id:bigint default(0)`（`app/models/client.rb:15,22`）。Operator/Visitor にも同型（`OperatorMfaLevel`
  / `VisitorMfaLevel`）。
- スイッチ =
  `Sign::App::Settings::Mfa::ChallengesController#update`（`:32-46`、org/com 同型）。`user.mfa_level_id = ...; user.mfa_level_enabled = (id != NOTHING); user.save!`。
- **モード変更は step-up 必須** — `include VerificationClient` +
  `verification_required_action? = show/update` +
  `verification_scope = "settings_mfa"`（`:50-56`）＋ owner-self ActionPolicy
  `authorize!(current_client, to: :update?)`（`:48-49`）。
- 強制内容 = `mfa_required_for?`（`authentication_base.rb:2654-2664`）が `mfa_level_required?`
  で MFA を要求。`mfa_bypassed_for_auth_method?` は
  **passkey のみ第2要素を免除**（`:2677-2679`）。email/telephone
  OTP・social は第2要素（TOTP）へ escalate。

**それでも残る欠陥（モードが「浅い」理由）— ここが本当の grill ポイント:**

1. **トグルが未ルーティング.** `bin/rails routes` は `GET /settings/mfa/challenge → challenges#show`
   のみを app/com/org に出す。`update`（PUT/PATCH）ルートが**存在しない**。controller は `update`
   を実装し show/update を authorize するのに、ルートからは到達不能。→ スイッチは設計・コードとしては在るが、現状 UI から切り替えられない dormant 状態。
2. **二値しか配線していない.** `requested_mfa_level_id` は `[NOTHING, FULL]`
   のみ許可（`:64-66`）。`WEAK=1 / MEDIUM=5`
   は定義済みだが未使用 → 段階的保証（phishing-resistant-only 等）の hook が休眠。
3. **有効化の前提条件が無い.** FULL を on にする前に passkey≥2 や recovery key を要求しない。
4. **「弱い method の禁止」ではなく「第2要素の強制」.**
   FULL でも password/email-OTP を sign-in 入口として使える（OTP のみなら TOTP へ escalate するだけ）。OpenAI の「password
   disabled / passkey required」には達していない。
5. **モード変更が監査されない.** `update` は `user.save!` のみで chronicle
   event を出さない。`ClientChronicleEvent`
   に MFA/ADVANCED/SECURITY 系定数が無い（`app/models/client_chronicle_event.rb`）。

つまり「モードが無い」のではなく「**モードはあるが、到達不能・二値・無前提・無監査で、enforcement も MFA 必須化どまり**」。直すべきは新規構築ではなく
**既存モードの完成（ルーティング + 段階化 + 前提条件 + 監査 + enforcement 強化）**。

---

## 1. Executive Summary

### 全体判定: **YELLOW**

理由: 認証認可の **プリミティブは強い** — refresh rotation + family + reuse
detection、AAL1/2/3 と phishing-resistant 順序、exact step-up scope、72h cooling-off の MFA reset
recovery、chronicle 監査基盤、session
revoke 一式。**per-account の高保証モード（`mfa_level`）も実在し、変更は step-up でガードされている**。一方でそのモードは未ルーティング・二値・無前提・無監査で浅く、`credential-change revocation 未配線`・`軽量 recovery secret の即時利用`・`login notification 不明`
も残るため GREEN には届かない。RED でもない（中核は壊れていない）。

### 最大の不足 5 件

1. **高保証モードが浅く、かつ現状 dormant.**（v2 訂正）モード自体は実在（`mfa_level`
   FULL、step-up ガード付き）だが、(a) 切替 `update` が未ルーティング、(b) `NOTHING/FULL`
   の二値のみで `WEAK/MEDIUM` 休眠、(c) 有効化前提（passkey≥2 / recovery key）無し、(d)
   enforcement が「MFA 必須化（passkey が第2要素免除）」どまりで弱い method を禁止しない、(e) 変更が無監査。→
   **モードの完成**が必要。
2. **Credential-change の session / refresh-family
   revocation が ADR 要求どおり配線されていない（かつ ADR と監査 finding が矛盾）.**
   `adr/session-token-hardening-baseline.md:96-98` は password/passkey/email 変更時の他 session +
   refresh family revoke を要求し「not wired today」と明記。一方
   `adr/security-audit-findings-2026-06-13.md` FINDING-02 は「credential
   destroy で revoke 済み」とする。**統合・真偽確定が必要**（ユーザ: 「ここは統合しないとね」）。
3. **軽量 recovery secret が即時アクセスを与える（待機期間・再検証なし）.**
   `app/services/client_secret_credentials_issue_recovery.rb:34,41` は `single_use`/`max_uses:1`
   で発行のみ。`recovery_started_at`/`unlock_after_at`
   相当の遅延も使用後の全 method 再検証も無い。重い MFA
   reset は 72h あるのに軽い経路は素通りという非対称。**改める**（ユーザ: 「それはだめだ。あらためよう」）。
4. **Lockdown / capability policy 軸が無い.** identity state（admin
   lock）はあるが、外部 fetch/unfurl/webhook/connector/export を制限する capability policy（OpenAI
   Lockdown 相当）が無い。**追加が必要**（ユーザ: 「ついかしないとね」）。現状は外部連携機能自体が乏しいため実害は将来寄り。
5. **Enterprise controls（SSO/SCIM/claimed
   domain）は今回スコープ外.**（ユーザ: 「こんかいはそうていしてない。ただ、つばはつけたい」）実装はしないが、将来のために
   `adr/collective-hierarchy-model.md`
   の Collective を土台に「足場（reservation）」を残す方針を明文化する。

### すぐ直すべきもの 3 件（低コスト・高価値）

1. **モードの切替 `update` をルーティングして dormant を解消 + 変更を監査.**
   route 追加（実装フェーズ）＋ `ClientChronicleEvent` に mode enable/disable event を定義（A1,
   A9）。step-up ガードは既存（A8 PASS）なので接続コストは小。
2. **#2 の真偽確定 + invariant test.**
   ADR と FINDING-02 を 1 つの真実に統合し、「credential 変更で他 session + refresh
   family が revoke される」invariant test を追加。
3. **軽量 recovery secret の使用後セマンティクス決定.** 「使用後に全 active session revoke +
   step-up 再要求」または「即時許可の根拠を明文化」のどちらかを ADR/docs/security 化（B4, B7）。

（補足: `login / new-device notification` の有無確定も低コスト・要対応だが UNKNOWN。OpenAI の login
notification 相当。）

### 後回し / 足場のみ 3 件

1. **モードの段階化（WEAK/MEDIUM 活用、passkey-only 高保証層）と有効化前提条件（passkey≥2, recovery
   key）.** モード完成の第2段。二値運用が安定してから。
2. **Lockdown / capability policy の実装.** 外部 connector/webhook/export/AI
   tool が実際に入る時点まで。設計原則 ADR（足場）だけ先に。
3. **Enterprise（SSO/SCIM/claimed domain）.** 今回スコープ外。Collective を土台に reservation
   note のみ残す。

---

## 2. OpenAI-style Control Mapping

### 2.1 Advanced Account Security 相当

| OpenAI control                       | Umaxica 現状（v2 訂正済み）                                                                                                | 判定     |
| ------------------------------------ | -------------------------------------------------------------------------------------------------------------------------- | -------- |
| password login disabled              | `mfa_level=FULL` でも password/OTP を入口として使え、第2要素を強制するのみ。password 無効化はしない                        | 差分: 中 |
| email/SMS code disabled              | telephone は元々非 AAL（`authentication-assurance-levels.md:43-47`）。email OTP は FULL でも入口可（TOTP へ escalate）     | 差分: 中 |
| email recovery disabled              | モードで recovery 経路を無効化する配線は無し                                                                               | 差分: 中 |
| passkey/FIDO required                | FULL で passkey は第2要素を免除する優遇あり（`authentication_base.rb:2677-2679`）。だが passkey「必須化」「最小2本」は無し | 差分: 中 |
| ≥2 secure sign-in methods            | no-lockout（最後の1個を消せない）はあるが「2個以上要求」無し（`authentication-assurance-levels.md:84,90-93`）              | 差分: 中 |
| recovery key required                | recovery secret は発行可だが必須化しない。`recovery_identity_required_validator.rb` は連絡先必須のみ                       | 差分: 中 |
| active sessions shortened            | モード連動の session 短縮は無し                                                                                            | 差分: 中 |
| login notification                   | **UNKNOWN**（通常 sign-in 通知の証跡未確認）                                                                               | 要検証   |
| recovery key 使用後も遅延            | MFA reset 経路は 72h（`mfa-reset-account-recovery.md:30-31`）。軽量 recovery secret は遅延無し                             | 部分一致 |
| support が mode を簡単に解除できない | モード変更は owner-self ActionPolicy + `settings_mfa` step-up でガード。operator が他人のモードを解除できるかは UNKNOWN    | 部分一致 |

**要点（v2）:** 「per-account persistent mode」という OpenAI の核は **Umaxica にも `mfa_level`
として存在する**。差は「深さ」: Umaxica のモードは MFA 必須化どまりで、弱い method 禁止 /
passkey 必須 / 前提条件 / 監査 / 段階化 / 到達可能な UI が欠ける。

### 2.2 Lockdown Mode 相当

| OpenAI control                                   | Umaxica 現状                                                                                                         | 判定                          |
| ------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------- | ----------------------------- |
| data exfiltration リスク低減                     | 設計上の脅威として明示されていない                                                                                   | 差分: 大                      |
| web/external service アクセス制限                | OIDC client registry の redirect_uri whitelist（`oidc_client_registry.rb:69-85`）はあるが capability policy ではない | 差分: 大                      |
| connector/tool/app を capability risk として扱う | connector/tool/app 機能自体が未実装。third-party grant は `client_oidc_connection.rb`（`revoked_at` あり）のみ       | 差分: 中（機能未実装）        |
| prompt injection / malicious content 対策        | 該当箇所無し                                                                                                         | 差分: 大（AI 機能の有無次第） |

**要点:** Lockdown は **identity state ではなく capability policy**
として分離すべき。`mfa_level`(モード) も `admin lock`(凍結) も identity 側で、capability
policy 層が無い。ユーザ指示により**追加対象**（ただし制限すべき外部連携が乏しいため、まず設計原則 ADR の足場から）。

### 2.3 Enterprise Controls 相当（今回スコープ外・足場のみ）

| OpenAI control                       | Umaxica 現状                                                                                 | 判定                  |
| ------------------------------------ | -------------------------------------------------------------------------------------------- | --------------------- |
| SSO/SAML/OIDC enforcement            | Acme=唯一 IdP/AS（`adr/acme-sign-core-base-port-boundary.md`）だが org 強制 enforcement 無し | 差分: 大 / スコープ外 |
| SCIM provisioning/deprovisioning     | 無し                                                                                         | 差分: 大 / スコープ外 |
| domain verification / claimed domain | `Organization#domain`(unique) のみ、検証無し                                                 | 差分: 大 / スコープ外 |
| RBAC / admin controls                | `application_policy.rb` role 述語 + Collective 階層あり。owner vs admin の分離は薄い         | 差分: 中              |
| audit/compliance logs                | chronicle 基盤が強い（§H）                                                                   | 一致に近い            |
| group/org scoped access              | Collective 階層（`adr/collective-hierarchy-model.md`）+ membership models                    | 部分一致              |
| org deprovision で revoke            | sessions/refresh/grants/API token 一括 revoke は未確認                                       | UNKNOWN               |

**足場（reservation）方針:** enterprise は今回実装しないが、将来 SSO enforcement / claimed domain /
org
policy を載せる土台として Collective 階層を指定し、`org policy ⊃ account `mfa_level`` の優先順位を将来 ADR で決める旨だけ残す。

### 2.4 Umaxica 現行実装との差分（総括・v2）

- **強い:** token rotation/family/reuse、step-up scope 厳密性、AAL 語彙、MFA reset
  recovery、chronicle 監査、session revoke、**per-account `mfa_level`
  モードの骨格（step-up ガード付き）**。
- **浅い/未完:** `mfa_level` モードの完成度（到達不能・二値・無前提・無監査・enforcement 弱）。
- **欠落軸:** capability policy（lockdown）、enterprise（今回スコープ外）。
- **配線/運用ギャップ:** credential-change revocation、軽量 recovery secret の待機・再検証、login
  notification、org deprovision 一括 revoke。

---

## 3. PASS / FAIL / UNKNOWN Table

判定:
**PASS**=実コード/ADR/test で確認、**PARTIAL**=一部のみ、**FAIL**=仕組み無しと確認、**UNKNOWN**=証拠不十分（推測で PASS にしない）。行番号は直接確認したものは確定、Explore
agent 由来でファイル単位確認は `(file)` 注記。

### A. 高保証アカウントモード（v2 全面改訂）

| #   | control                                   | evidence                                                                                                                               | files/lines                                                                                                                                                                                                                        | 判定             | risk | recommendation                                                     |
| --- | ----------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------- | ---- | ------------------------------------------------------------------ |
| A1  | advanced security mode 相当の状態         | `mfa_level`(NOTHING/WEAK/MEDIUM/FULL) が per-account 永続状態。enforcement あり。**ただし切替 `update` が未ルーティング（show のみ）** | `app/models/client_mfa_level.rb:13-18`; `app/models/client.rb:15,22`; `app/controllers/sign/app/settings/mfa/challenges_controller.rb:32-46`; `authentication_base.rb:2654-2664`; `bin/rails routes`（challenge は GET show のみ） | **PARTIAL**      | 中   | `update` をルーティングし dormant 解消（Phase 1）                  |
| A2  | 有効化条件が十分か                        | `update` は `[NOTHING, FULL]` のみ許可、WEAK/MEDIUM 休眠。前提条件無し                                                                 | `challenges_controller.rb:64-66`; `client_mfa_level.rb:14-16`                                                                                                                                                                      | **PARTIAL**      | 中   | 段階化 + 有効化前提（passkey≥2, recovery key）                     |
| A3  | passkey 複数登録要求                      | FULL 有効化に passkey 数前提無し。max 4 のみ                                                                                           | `app/models/client_passkey.rb:44`(file)                                                                                                                                                                                            | **FAIL**         | 中   | FULL 有効化に passkey≥2 invariant                                  |
| A4  | 1個は cross-device/roaming 扱い           | authenticator attachment/transport 区別 未確認                                                                                         | passkey ceremony 周辺(file)                                                                                                                                                                                                        | **UNKNOWN**      | 中   | attachment を保存し roaming 判別                                   |
| A5  | mode 中に password/OTP/SMS 禁止 or 低保証 | FULL は MFA 必須化。passkey のみ第2要素免除（phishing-resistant 区別あり）。だが弱い method を入口として禁止しない                     | `authentication_base.rb:2666-2679`                                                                                                                                                                                                 | **PARTIAL**      | 中   | FULL で弱い method を AAL1 入口から外す policy（WEAK/MEDIUM 活用） |
| A6  | mode 中に弱い sign-in method 追加不可     | モードに連動した credential-add 制約は未確認（おそらく無し）                                                                           | `challenges_controller.rb`（制約記述なし）                                                                                                                                                                                         | **FAIL/UNKNOWN** | 中   | mode 中の add policy                                               |
| A7  | mode 中に弱い recovery method 追加不可    | 同上                                                                                                                                   | 同上                                                                                                                                                                                                                               | **FAIL/UNKNOWN** | 中   | 同上                                                               |
| A8  | mode 変更に step-up 必須                  | `VerificationClient` + `verification_scope "settings_mfa"` + owner-self ActionPolicy                                                   | `challenges_controller.rb:48-56`                                                                                                                                                                                                   | **PASS**         | —    | —                                                                  |
| A9  | mode 変更が監査ログに残る                 | `update` は `user.save!` のみ。mode 用 chronicle event 無し                                                                            | `challenges_controller.rb:32-46`; `app/models/client_chronicle_event.rb`（MFA/SECURITY 定数なし）                                                                                                                                  | **FAIL**         | 中   | enable/disable を chronicle event 化                               |

### B. 復旧経路

| #   | control                                          | evidence                                                                              | files/lines                                                                                      | 判定                  | risk | recommendation                                                         |
| --- | ------------------------------------------------ | ------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ | --------------------- | ---- | ---------------------------------------------------------------------- |
| B1  | recovery secret/key の存在                       | recovery secret 発行サービスあり                                                      | `app/services/client_secret_credentials_issue_recovery.rb:20-59`                                 | **PASS**              | —    | —                                                                      |
| B2  | one-time use                                     | `single_use`/`max_uses:1`/`max_failures:5`                                            | `client_secret_credentials_issue_recovery.rb:34,41,42`                                           | **PASS**              | —    | —                                                                      |
| B3  | ハッシュ化/漏洩耐性保存                          | raw は返却のみ、保存は digest（`generate_raw_secret_credential`）。consume 経路は未読 | `client_secret_credentials_issue_recovery.rb:20`; `app/models/client_secret_credential.rb`(file) | **PARTIAL**           | 中   | 保存方式（digest/暗号化）を consume 側で直接確認                       |
| B4  | 使用後に待機期間                                 | 軽量 recovery secret は即時。遅延フィールド無し                                       | `client_secret_credentials_issue_recovery.rb`（遅延無し）                                        | **FAIL**              | 高   | 使用後 session revoke + step-up 再要求 or 遅延を決定（ユーザ: 改める） |
| B5  | recovery_started_at/unlock_after_at/completed_at | MFA reset 経路は 72h + request lifecycle あり。軽量 secret には無し                   | `adr/mfa-reset-account-recovery.md:29-36`                                                        | **PARTIAL**           | 中   | 軽量経路にも lifecycle state                                           |
| B6  | recovery 中の refresh/session/family 扱い        | MFA reset 中は restricted session 可。軽量 secret 経路は未定義                        | `mfa-reset-account-recovery.md:38-44`                                                            | **PARTIAL**           | 中   | 軽量経路の session 扱い明文化                                          |
| B7  | recovery 完了後に全 method 再検証/再登録         | MFA reset は全 MFA revoke + 再 bootstrap 強制                                         | `mfa-reset-account-recovery.md:54-63`                                                            | **PASS（MFA reset）** | —    | 軽量経路には無し                                                       |
| B8  | email/SMS/support recovery を high mode で無効化 | `mfa_level` モードに recovery 無効化の配線無し                                        | —                                                                                                | **FAIL**              | 中   | モード enforcement に recovery 制限を追加                              |
| B9  | recovery 通知が既存連絡先へ                      | MFA reset は全 channel 通知。軽量 secret は未確認                                     | `mfa-reset-account-recovery.md:38-41`                                                            | **PARTIAL**           | 中   | 軽量経路の通知確認                                                     |
| B10 | recovery cancel / report abuse 経路              | MFA reset は cooling-off 中に cancel 可                                               | `mfa-reset-account-recovery.md:32-33`                                                            | **PASS（MFA reset）** | —    | report-abuse 専用導線は UNKNOWN                                        |

### C. 管理者・サポート制限

| #   | control                                                | evidence                                                                                                  | files/lines                                         | 判定        | risk                        | recommendation                                           |
| --- | ------------------------------------------------------ | --------------------------------------------------------------------------------------------------------- | --------------------------------------------------- | ----------- | --------------------------- | -------------------------------------------------------- |
| C1  | operator が high mode を安易に解除不可                 | モード変更は owner-self ActionPolicy（`authorize!(current_client,...)`）。operator 経由の解除可否は未確認 | `challenges_controller.rb:48-49`                    | **PARTIAL** | 中                          | operator がモードを解除できないことを policy test で確認 |
| C2  | operator が passkey/security key を勝手に追加/削除不可 | passkey policy はあるが operator 越権の test 未確認                                                       | `test/policies/client_passkey_policy_test.rb`(file) | **UNKNOWN** | 高                          | operator-cannot-modify test                              |
| C3  | operator が recovery key を再発行不可                  | 発行 service は actor 指定だが authz 境界未確認                                                           | `client_secret_credentials_issue_recovery.rb:10`    | **UNKNOWN** | 高                          | self-service 限定か確認                                  |
| C4  | break-glass に二者承認/監査/待機                       | MFA reset = non-self operator + 72h + early override 禁止 + audit。正式 break-glass ADR 未作成            | `mfa-reset-account-recovery.md:48-52,83-85`         | **PARTIAL** | 中                          | break-glass ADR（後回し可）                              |
| C5  | support 操作と self-service の権限分離                 | actor type 分離（Client/Operator/Visitor）+ Pundit                                                        | `app/policies/application_policy.rb`(file)          | **PARTIAL** | 中                          | sensitive 操作の operator 不可範囲を明文化               |
| C6  | org owner / org admin / system operator 境界           | role 述語はあるが owner vs admin の明確分離薄い                                                           | `application_policy.rb:161-180`(file)               | **PARTIAL** | 中                          | role 階層を明示                                          |
| C7  | claimed domain / managed account で self-service 制限  | claimed domain 概念が無い                                                                                 | —                                                   | **FAIL**    | 低（enterprise スコープ外） | enterprise 設計時                                        |

### D. セッション一覧と失効

| #   | control                                                       | evidence                                                                                                       | files/lines                                                                                                              | 判定        | risk | recommendation                                      |
| --- | ------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ | ----------- | ---- | --------------------------------------------------- |
| D1  | active sessions 一覧を user が確認                            | settings/sessions（acme/app）+ sign 各 surface に sessions controller。self-service revoke UI は gh634 backlog | `app/controllers/sign/app/settings/sessions_controller.rb`(file); `plans/backlog/gh634-self-service-revoke-sessions.md`  | **PARTIAL** | 中   | gh634 を進める                                      |
| D2  | device/session 単位 revoke                                    | `DeviceSessionable.revoke!` + revocation_attempt                                                               | `app/models/concerns/device_sessionable.rb:31-38`(file); `sessions_controller.rb`(file)                                  | **PASS**    | —    | —                                                   |
| D3  | all sessions revoke                                           | `session_revocations/all`                                                                                      | `config/routes/sign.rb:213-216`; `sessions_controller`(file)                                                             | **PASS**    | —    | —                                                   |
| D4  | current 以外 revoke                                           | `session_revocations/others`                                                                                   | `config/routes/sign.rb:213-216`                                                                                          | **PASS**    | —    | —                                                   |
| D5  | session に device_id/UA/ip digest/last_seen/created/refreshed | `last_seen_at`/`dpop_jkt`/`last_network_hmac`/`refresh_token_family_id`。ip は network HMAC(/24,/48)           | `app/models/client_device_session.rb`(file); `adr/ip-anomaly-session-revocation.md`                                      | **PASS**    | —    | UA digest 化は要確認                                |
| D6  | 表示が privacy leak にならない丸め                            | ip は /24,/48 HMAC。表示丸めは UI 次第                                                                         | `adr/ip-anomaly-session-revocation.md`                                                                                   | **PARTIAL** | 低   | gh634 UI で表示粒度規定                             |
| D7  | high mode 有効化時に既存 session 短縮/再認証                  | `mfa_level` 有効化に session 短縮の連動は無し                                                                  | `challenges_controller.rb`（session 操作なし）                                                                           | **FAIL**    | 中   | モード on 時に既存 session 再認証要求               |
| D8  | logout/refresh/revoke が token family と整合                  | sign-out flow state machine + family + reuse invariant test                                                    | `app/models/client_sign_out_flow.rb`(file); `test/security/invariants/refresh_token_reuse_invariant_test.rb:23-66`(file) | **PASS**    | —    | —                                                   |
| D9  | stale access token による重要 write 拒否                      | sensitive action は DB step-up row 検証。admin lock は `token_valid_after_at`                                  | `authentication-assurance-levels.md:117-121`; `plans/active/administrative-access-lock-implementation-plan.md`           | **PARTIAL** | 中   | 全 sensitive write が step-up gate を通るか網羅確認 |

### E. Step-Up / MFA 強度

| #   | control                                     | evidence                                                                                       | files/lines                                                                      | 判定        | risk | recommendation                                                     |
| --- | ------------------------------------------- | ---------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- | ----------- | ---- | ------------------------------------------------------------------ |
| E1  | step-up assurance level 定義                | AAL1/2/3 定義                                                                                  | `docs/security/authentication-assurance-levels.md:16-22`                         | **PASS**    | —    | —                                                                  |
| E2  | 強度順序の明文化                            | passkey→TOTP(app)、email OTP は default 外、passcode/social/telephone は非AAL2                 | `authentication-assurance-levels.md:100-115`                                     | **PASS**    | —    | —                                                                  |
| E3  | sensitive 操作で step-up 必須               | credential 変更/削除/revoke-all/withdrawal/**mode 変更(settings_mfa)** で step-up。exact scope | `authentication-assurance-levels.md:117-129`; `challenges_controller.rb:52-56`   | **PASS**    | —    | API token 発行/export/外部連携 scope は未定義                      |
| E4  | recent window が適切                        | step-up freshness 15 分                                                                        | `test/integration/step_up_authentication_test.rb`(file)                          | **PASS**    | —    | —                                                                  |
| E5  | high mode で step-up を passkey/FIDO に限定 | FULL は passkey を優遇（第2要素免除）するが AAL2 method を passkey 限定にはしない              | `authentication_base.rb:2677-2679`; `authentication-assurance-levels.md:100-110` | **PARTIAL** | 中   | 高保証層で AAL2 を passkey 限定に（WEAK/MEDIUM/FULL の段階で表現） |
| E6  | phishing-resistant MFA を区別               | 明示的に passkey 優先 + passkey のみ免除                                                       | `authentication-assurance-levels.md:108-110`; `authentication_base.rb:2666-2679` | **PASS**    | —    | —                                                                  |

### F. Lockdown / 外部連携制御

| #   | control                                                        | evidence                                                        | files/lines                                        | 判定           | risk        | recommendation                                 |
| --- | -------------------------------------------------------------- | --------------------------------------------------------------- | -------------------------------------------------- | -------------- | ----------- | ---------------------------------------------- |
| F1  | account/org に lockdown capability restriction                 | admin lock は identity 凍結であり capability policy でない      | `adr/administrative-access-lock.md`                | **FAIL**       | 中          | capability policy 層を別軸で追加（ユーザ指示） |
| F2  | lockdown 中に外部 fetch/unfurl/webhook/connector/export 制限   | これら機能自体がほぼ未実装                                      | —                                                  | **FAIL / N/A** | 低          | 機能追加時に同時設計                           |
| F3  | prompt injection / data exfiltration を設計考慮                | 該当無し                                                        | —                                                  | **FAIL**       | AI 機能次第 | AI/外部content 機能があれば必須                |
| F4  | connector/app/webhook の admin 明示許可制                      | connector 機能未実装                                            | —                                                  | **N/A**        | 低          | —                                              |
| F5  | third-party grants 一覧/revoke                                 | `client_oidc_connection`（`revoked_at`、user×client_id unique） | `app/models/client_oidc_connection.rb`(file)       | **PARTIAL**    | 中          | grant 一覧 UI/revoke 導線確認                  |
| F6  | external integration 作成/更新/削除に step-up + 監査           | OIDC connection 操作の step-up scope 未定義                     | —                                                  | **UNKNOWN**    | 中          | scope `external_link` を定義                   |
| F7  | open redirect / callback abuse 防止                            | redirect_uri strict whitelist + secure_compare                  | `app/services/oidc_client_registry.rb:69-85`(file) | **PASS**       | —           | —                                              |
| F8  | Lockdown を identity state でなく capability policy として分離 | 分離軸が存在しない                                              | —                                                  | **FAIL**       | 中          | 設計原則として ADR 化（足場）                  |

### G. Enterprise / Organization controls（今回スコープ外・足場のみ）

| #   | control                                                     | evidence                                                         | files/lines                                                               | 判定        | risk             | recommendation                                                  |
| --- | ----------------------------------------------------------- | ---------------------------------------------------------------- | ------------------------------------------------------------------------- | ----------- | ---------------- | --------------------------------------------------------------- |
| G1  | SSO/SAML/OIDC enforcement                                   | Acme=唯一 IdP/AS だが org 強制 enforcement 無し                  | `adr/acme-sign-core-base-port-boundary.md`                                | **FAIL**    | 低（スコープ外） | reservation note のみ                                           |
| G2  | SCIM provisioning/deprovisioning                            | 無し                                                             | —                                                                         | **FAIL**    | 低               | 同上                                                            |
| G3  | domain verification / claimed domain                        | `Organization#domain` unique のみ                                | `app/models/organization.rb`(file)                                        | **FAIL**    | 低               | 同上                                                            |
| G4  | managed vs personal account 境界                            | 無し                                                             | —                                                                         | **FAIL**    | 低               | 同上                                                            |
| G5  | org policy で MFA/Passkey/SSO/TTL/Connector 制御            | 無し。token TTL は surface 別 ADR はあるが org policy 駆動でない | `adr/token-lifetime-policy-by-surface.md`                                 | **FAIL**    | 低               | 将来 org policy ⊃ `mfa_level` の優先順位を ADR 化               |
| G6  | org policy と account mode の優先順位                       | 両者未実装                                                       | —                                                                         | **FAIL**    | 低               | 足場 ADR で優先順位を予約                                       |
| G7  | org deprovision で sessions/refresh/grants/API token revoke | 一括 revoke 経路未確認                                           | `plans/backlog/org-operator-acquisition-lifecycle-implementation-plan.md` | **UNKNOWN** | 高               | deprovision フックで revoke を確認/追加（スコープ外でも要監視） |
| G8  | org owner recovery/transfer/break-glass                     | 未確認                                                           | —                                                                         | **UNKNOWN** | 中               | ownership transfer 設計（足場）                                 |

### H. Audit / Compliance logs

| #   | control                                                              | evidence                                                                 | files/lines                                                                                | 判定        | risk | recommendation                   |
| --- | -------------------------------------------------------------------- | ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------ | ----------- | ---- | -------------------------------- |
| H1  | security event を append-only 近似で記録                             | chronicle = 不変・retention 管理・consolidated DB                        | `app/models/chronicle.rb`(file); `adr/chronicle-audit-db-consolidation.md`                 | **PASS**    | —    | 暗号署名による改竄検知は無し     |
| H2  | sign-in success/failure                                              | `AUDIT_EVENTS` に logged_in/login_failed                                 | `authentication_base.rb:114-120`(file)                                                     | **PASS**    | —    | —                                |
| H3  | MFA/step-up success/failure                                          | step-up/mfa status の枠組みあり                                          | `authentication-assurance-levels.md:141-148`                                               | **PARTIAL** | 中   | challenge failure 記録の網羅確認 |
| H4  | passkey/TOTP/OTP method add/remove                                   | chronicle event はあるが網羅未確認                                       | `app/models/client_chronicle.rb`(file)                                                     | **UNKNOWN** | 中   | 各 method lifecycle event 確認   |
| H5  | recovery start/cancel/complete                                       | MFA reset の全段監査が ADR 要求。recovery secret 発行も監査              | `mfa-reset-account-recovery.md:65-72`; `client_secret_credentials_issue_recovery.rb:48-55` | **PASS**    | —    | —                                |
| H6  | advanced security（mode）enable/disable                              | **mode 変更が無監査**（A9）                                              | `challenges_controller.rb:32-46`; `client_chronicle_event.rb`                              | **FAIL**    | 中   | mode enable/disable event 追加   |
| H7  | lockdown enable/disable                                              | lockdown が無い                                                          | —                                                                                          | **FAIL**    | 低   | 実装時に追加                     |
| H8  | session revoke                                                       | revoke 経路で監査                                                        | `acme/app/settings/sessions_controller.rb:75`(file)                                        | **PASS**    | —    | —                                |
| H9  | refresh reuse detection                                              | `refresh_reuse_detected` emit + log                                      | `app/services/acme_refresh_token_service.rb:107-121`(file)                                 | **PASS**    | —    | —                                |
| H10 | org policy / connector grant / admin intervention                    | admin lock/unlock は監査。org policy/connector は機能未実装              | `adr/administrative-access-lock.md`                                                        | **PARTIAL** | 中   | 機能追加時に event 定義          |
| H11 | actor/subject/org/session/ip digest/UA digest/request_id/occurred_at | actor/subject/ip(inet)/user_agent/request_id/occurred_at/event_uuid あり | `app/models/chronicle.rb`(file)                                                            | **PASS**    | —    | ip は inet 生値。digest 化検討   |
| H12 | user-visible history と internal audit を分離                        | `chronicle_visibility`/`chronicle_visibility_context`                    | `app/models/chronicle_visibility.rb`(file)                                                 | **PASS**    | —    | —                                |
| H13 | privacy と forensic のバランス                                       | retention policy + encrypted previous_value                              | `app/models/client_chronicle.rb`(file)                                                     | **PASS**    | —    | ip digest 化で更に改善           |

### I. テスト・不変条件

| #   | control                                                  | evidence                                                                                          | files/lines                                                                                                                        | 判定             | risk | recommendation                                           |
| --- | -------------------------------------------------------- | ------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | ---------------- | ---- | -------------------------------------------------------- |
| I1  | high mode 中に weak login/recovery 不可の invariant test | mode の enforcement が「MFA 必須化」どまりで weak 禁止が無いため、その invariant 自体が成立しない | `authentication_base.rb:2666-2679`                                                                                                 | **FAIL**         | 中   | 段階化後に invariant test                                |
| I2  | passkey<2 で advanced mode 有効化不可 test               | 前提条件が無いので test も無い                                                                    | `challenges_controller.rb:64-66`                                                                                                   | **FAIL**         | 中   | 前提条件実装と同時に test                                |
| I3  | recovery key 使用後に待機が必要な test                   | MFA reset cooling-off test は要確認。軽量 secret は待機自体が無い                                 | `test/` MFA reset 要確認                                                                                                           | **UNKNOWN/FAIL** | 中   | 軽量経路の待機を決め test 化                             |
| I4  | support/operator が安易に解除できない authz test         | operator 境界 test の網羅未確認。mode 変更は owner-self policy だが operator 経路 test 無し       | `test/policies/`(file)                                                                                                             | **UNKNOWN**      | 高   | operator-cannot-toggle-mode / modify-credential test     |
| I5  | lockdown 中に外部連携 unusable test                      | lockdown が無い                                                                                   | —                                                                                                                                  | **FAIL/N/A**     | 低   | 機能追加時                                               |
| I6  | org policy が account behavior に反映 test               | org policy が無い（スコープ外）                                                                   | —                                                                                                                                  | **FAIL/N/A**     | 低   | enterprise 後                                            |
| I7  | token/session race condition test                        | refresh concurrency + reuse invariant あり                                                        | `test/models/refresh_token_concurrency_test.rb:1-51`(file); `test/security/invariants/refresh_token_reuse_invariant_test.rb`(file) | **PASS**         | —    | session 作成×revoke race は未カバー                      |
| I8  | audit log が必ず作成される test                          | authorization_audit_test 等あり。mode 変更には監査自体が無い                                      | `test/concerns/authorization_audit_test.rb`(file)                                                                                  | **PARTIAL**      | 中   | 各 security event の audit 必須 test を網羅（mode 含む） |

---

## 4. Attack / Abuse Scenarios

1. **盗まれた email inbox**
   - 防御: personal identifier + AAL
     verifier の両方が要る（`authentication-assurance-levels.md:167-176`）。`mfa_level=FULL`
     なら email-OTP のみの sign-in は第2要素へ escalate（`authentication_base.rb:2666-2679`）。
   - 残存:
     FULL でも email-OTP を入口として使え、password を無効化しない。FULL が dormant（未ルーティング）かつ default
     OFF のため、多くのアカウントは email-OTP 単独 AAL1 で sign-in 可能。→ A1, A5。
   - 軽減: モードを到達可能にし、高保証層で弱い入口を禁止。

2. **盗まれた refresh token** —
   rotation+family+reuse 検出（`acme_refresh_token_service.rb:99-121`）。残存:
   binding(DBSC/DPoP) が任意なら盗用容易。→ D8 PASS / binding enforcement UNKNOWN。

3. **盗まれた access token** — sensitive write は DB step-up + binding 検証、admin lock は
   `token_valid_after_at`。残存: 非 sensitive write は JWT TTL まで有効、DPoP enforcement UNKNOWN。→
   D9 PARTIAL。

4. **compromised support/operator** — MFA reset は non-self + 72h + early
   override 禁止 + 監査。mode 変更は owner-self policy。残存:
   operator が他人の mode/passkey/recovery を操作できないかの test 未確認。→ C1-C3, I4。

5. **malicious connector** — OIDC client は固定 audience + redirect
   whitelist、grant に revoked_at。残存: connector/webhook/capability policy・admin
   enablement・step-up付き連携作成が無い。→ F1-F8（ユーザ指示で追加対象）。

6. **prompt injection via external content** — 該当設計無し。AI
   tool/外部取り込みを追加するなら Lockdown が前提。→ F3。

7. **org deprovision race** —
   deprovision 時の一括 revoke 未確認。退会後も短時間 access 残存の恐れ。→ G7
   UNKNOWN（enterprise スコープ外でも高リスクとして監視）。

8. **passkey loss / device loss** — MFA reset(72h+approval+再bootstrap)。残存: 軽量 recovery
   secret は即時で使用後 revoke/再検証無し、紛失デバイスが生きていると危険。→ B4, B7。

9. **account recovery abuse** — MFA reset は cancel + 通知あり。残存: 軽量 recovery
   secret は通知/cancel/待機が未確認、入手した attacker が即時悪用。→ B4, B9, B10。

---

## 5. Minimal Remediation Plan

**本タスクでは実装しない。** 各 Phase は別途承認・別 PR。

- **Phase 0: documentation / ADR（最優先・低コスト）**
  - `mfa_level`
    モードの現状（dormant・二値・無前提・無監査）を docs/security に正確化。「高保証モード = 既存
    `mfa_level` の完成」と位置づけ。
  - credential-change
    revocation の ADR(`session-token-hardening-baseline.md:96-98`) と FINDING-02 の矛盾を調査し 1 つの真実に**統合**（#2）。
  - 軽量 recovery secret の使用後セマンティクス（revoke+再 step-up
    / 即時許可の根拠）を明文化（#3）。
  - capability policy（lockdown）と enterprise(org policy ⊃ mode) を **identity
    state と分離した将来軸**として足場 ADR に予約（#4, #5）。

- **Phase 1: mode 完成（最重要・新規構築でなく既存の接続）**
  - 切替 `update` を PUT/PATCH ルートに接続して dormant 解消（A1）。step-up ガードは既存（A8）。
  - mode enable/disable を `ClientChronicleEvent` で監査（A9, H6）。
  - mode on 時に既存 session の再認証/短縮（D7）。

- **Phase 2: mode 深化**
  - `WEAK/MEDIUM/FULL` を段階運用し、高保証層で AAL2 を passkey 限定・弱い入口を禁止（A5, E5）。
  - FULL 有効化前提（passkey≥2, recovery key）と mode 中の credential-add 制約（A2, A3, A6, A7）。

- **Phase 3: recovery hardening**
  - 軽量 recovery secret 使用後に他 session/refresh family revoke + step-up 再要求（B4,
    B7）。通知/cancel/report-abuse（B9, B10）。high mode 中の弱い recovery 無効化（B8）。

- **Phase 4: session UI / revoke**
  - gh634 self-service session 一覧/revoke（D1）、表示粒度規定（D6）。org
    deprovision の一括 revoke 確認/実装（G7、enterprise スコープ外でも監視）。

- **Phase 5: lockdown / capability policy（足場 → 機能追加時に実装）**
  - capability policy 層（identity と分離）。connector/webhook/export の admin enablement +
    step-up + 監査（F1-F8）。

- **Phase 6: enterprise（今回スコープ外・reservation のみ）**
  - SSO/SCIM/claimed domain は Collective を土台に reservation note を残すのみ。実装しない。

- **Phase 7: tests / audit hardening**
  - §6 の test 群。chronicle の ip digest 化検討。

---

## 6. Concrete Test Plan

**本タスクでは追加しない。** 流用元: `test/security/invariants/`,
`test/integration/step_up_authentication_test.rb`, `test/models/refresh_token_concurrency_test.rb`。

- **Unit**
  - mode 変更が `ClientChronicleEvent` を 1 件出す（A9, H6）。
  - FULL 有効化が passkey<2 で失敗（A3, I2、Phase 2 後）。
  - 軽量 recovery secret 使用後に該当 token/session が revoke（B4）。

- **Integration**
  - mode `update` がルート経由で到達でき、step-up 無しでは拒否される（A1, A8）。
  - mode on で既存 session が再認証要求（D7）。
  - recovery 起動が全 channel 通知 + cooling-off 中 cancel 可（B9, B10）。
  - org deprovision で member の sessions/refresh/grants/API token revoke（G7）。

- **Authorization**
  - operator が他 actor の mode/passkey/recovery を toggle/add/remove/reissue 不可（C1, C2, C3,
    I4）。
  - mode 変更が exact scope `settings_mfa` を要求し generic
    verification では通らない（A8、`authentication-assurance-levels.md:120-121`）。

- **Race / concurrency**
  - session 作成 × revoke-all race（D8 を拡張、I7）。
  - mode on と並行 sign-in（mode 後 session が即再認証対象）。
  - recovery secret 同時消費の DB レベル排他（B2 を race で）。

- **Invariant**
  - 段階化後「高保証層では弱い login/recovery が使えない」（I1, A5）。
  - 「credential 変更で他 session + refresh family が必ず revoke」（#2 統合後）。
  - 「security-critical event（mode 含む）は必ず chronicle に残る」（I8）。

---

## 7. Final Recommendation

- **Implement now（小・高価値）**
  - Phase 0 全部（ドキュメント/ADR、#2 統合、#3 recovery 方針、#4/#5 足場）。
  - Phase 1: mode の `update` ルーティング接続 + mode 変更監査 + mode
    on 時の session 再認証。**新規構築でなく既存モードの接続**なので低コスト。
  - 軽量 recovery secret の使用後 revoke/再検証（B4, B7）。
  - login/new-device notification の有無確定、無ければ追加。

- **Implement next（中）**
  - Phase 2: mode 深化（段階化・passkey 限定・前提条件）。OpenAI Advanced
    Security の核との差を埋める。
  - Phase 4: gh634 session UI、org deprovision 一括 revoke（G7）。

- **Defer / 足場のみ**
  - Phase 5 lockdown/capability policy: 外部 connector/webhook/export/AI
    tool が入るまで設計原則 ADR の足場のみ（ユーザ指示で「追加」対象だが実装は機能顕在化後）。
  - Phase 6 enterprise（SSO/SCIM/claimed domain）: 今回スコープ外、reservation
    note のみ（ユーザ: 「つばはつけたい」）。

- **Reject as overkill（現段階）**
  - OpenAI と機能単位で完全一致させること自体。AAL3/quorum/正式 break-glass は
    `authentication-assurance-levels.md:227-240` と `mfa-reset-account-recovery.md:84`
    で既に reserved 済み。現運用規模では即時実装は過剰。

---

## 付録: 根拠ファイル一覧（直接確認したもの）

| ファイル                                                                 | 確認内容                                                                               |
| ------------------------------------------------------------------------ | -------------------------------------------------------------------------------------- |
| `docs/security/authentication-assurance-levels.md`（Read）               | AAL1/2/3、phishing-resistant 順序、exact scope、telephone 非AAL、no-lockout            |
| `adr/session-token-hardening-baseline.md`（Read、:96-98,113-122）        | credential-change revocation 未配線、cookie 硬化、rotation/family、logout              |
| `adr/mfa-reset-account-recovery.md`（Read）                              | 72h cooling-off、non-self operator、early override 禁止、再 bootstrap、全段監査        |
| `app/services/client_secret_credentials_issue_recovery.rb`（Read）       | recovery secret single_use/max_uses:1、即時発行（待機無し）、発行監査                  |
| `app/models/client_mfa_level.rb`（Read）                                 | mode の段階定義 NOTHING/WEAK/MEDIUM/FULL                                               |
| `app/controllers/sign/app/settings/mfa/challenges_controller.rb`（Read） | mode トグル `update`、step-up `settings_mfa` ガード、`[NOTHING,FULL]` のみ許可、無監査 |
| `app/controllers/concerns/authentication_base.rb:2654-2679`（Read）      | `mfa_required_for?` / `mfa_bypassed_for_auth_method?`(passkey のみ免除)                |
| `bin/rails routes`（実行）                                               | `settings/mfa/challenge` は GET show のみ、`update` 未ルーティング                     |

**Explore agent 由来（ファイル単位は確実、行番号は `(file)`）:** session/token
models、`acme_refresh_token_service.rb`、sessions
controllers、`chronicle.rb`、`oidc_client_registry.rb`、`client_oidc_connection.rb`、`adr/administrative-access-lock.md`、各 plan、`test/security/invariants/`・`test/models/refresh_token_concurrency_test.rb`・`test/integration/step_up_authentication_test.rb`。

**UNKNOWN（推測で PASS にしない）:** A4 roaming 区別、A6/A7 mode 中の add 制約、C2/C3
operator の credential 操作境界、D9 全 sensitive
write の step-up 網羅、F6 外部連携作成の step-up、G7/G8 org deprovision・ownership transfer、H4
method add/remove 監査網羅、B3 secret 保存方式（consume 経路）、login notification の有無、DPoP
proof enforcement の実体。
