# SNS ユーザーライフサイクル／年齢制限／人間安全性／コンプライアンス 監査レポート（補正版）

**作成日**: 2026-06-25  
**補正日**: 2026-06-25  
**監査範囲**: docs/, plans/, adr/, notes/, memos/, app/ (read-only)  
**実装変更**: なし（監査・ドキュメント提案のみ）

### 補正の概要（v1 からの変更点）

| 項目                       | v1 の誤り                                                                     | v2 の訂正                                                                                                                    |
| -------------------------- | ----------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| .com / Visitor の年齢制限  | "16+" と記載していた箇所あり                                                  | .com は年齢を理由に情報提供・通報・相談を拒否しない。intake と signup account は別物                                         |
| Minor Safety Policy の文言 | "Direct sign-up is restricted to 16+ on .app (Client) **and .com (Visitor)**" | .com は対象外。正しくは .app / Client direct sign-up のみ 16+                                                                |
| .com の actor 区分         | Data Subject / Reporter / Guest / authenticated Visitor の区別なし            | 明確に分けて記載                                                                                                             |
| .org / Operator の年齢     | 固定年齢の雰囲気で記載                                                        | jurisdiction-dependent として明示。固定値断定なし                                                                            |
| Implementation gap status  | Missing resolved/remaining gap split                                          | `.app` Client 16+ is resolved; `.com` Visitor account 13+ is intentional; `.com` Guest/Reporter intake remains unimplemented |

---

## 1. Existing Docs Inventory

### 1-A. docs/security/

| ファイルパス                                       | 該当テーマ                       | 現在の内容                                                                                                               | 判定                       | 備考                                                                             |
| -------------------------------------------------- | -------------------------------- | ------------------------------------------------------------------------------------------------------------------------ | -------------------------- | -------------------------------------------------------------------------------- |
| `docs/security/sign-up-sequence.md`                | サインアップ手順・サーフェス分岐 | app/com/org の entry method、birthdate checkpoint、finalization 契約                                                     | **要確認**                 | 年齢制限の最低値が記載なし。birthdate 収集の目的が「年齢判定」と明示されていない |
| `docs/security/sign-withdrawal-and-membership.md`  | 退会・削除・復旧                 | withdrawal_started_at / discarded_at / purged_at / terminated_at タイムライン、31 日回復窓口、org は self-service 対象外 | 問題なし（技術仕様として） | データ保持根拠（法的義務 vs. サービス判断）が未記載                              |
| `docs/security/sign-in-sequence.md`                | サインイン手順                   | authority 境界、actor 識別子、session lifecycle、step-up                                                                 | 問題なし                   |                                                                                  |
| `docs/security/credential-abuse-rate-limits.md`    | レート制限・乱用防止             | SMS/OTP/メール変更レート制限、birthdate 登録は全期間 max 1 回                                                            | **要確認**                 | birthdate 変更制限の目的（年齢詐称防止か）が未記載                               |
| `docs/security/mfa-reset-account-recovery.md`      | MFA リセット・アカウント回復     | 72h 冷却期間、operator review、passkey/TOTP 失効                                                                         | 問題なし                   |                                                                                  |
| `docs/security/authentication-assurance-levels.md` | AAL 定義                         | AAL1/AAL2 methods per surface                                                                                            | 問題なし                   |                                                                                  |

### 1-B. docs/reference/

| ファイルパス                                | 該当テーマ                                 | 現在の内容                                                    | 判定       | 備考                                                                  |
| ------------------------------------------- | ------------------------------------------ | ------------------------------------------------------------- | ---------- | --------------------------------------------------------------------- |
| `docs/reference/japan-saas-legal-triage.md` | 日本法コンプライアンス（APPI・利用規約等） | APPI 義務・プライバシーポリシー・外部送信規制・漏洩対応フロー | **要確認** | 未成年保護・COPPA/GDPR への言及なし。データ保持スケジュールの記述なし |

### 1-C. docs/legal/

| ファイルパス                               | 該当テーマ                  | 現在の内容                                  | 判定     | 備考                                     |
| ------------------------------------------ | --------------------------- | ------------------------------------------- | -------- | ---------------------------------------- |
| `docs/legal/analytics-consent-boundary.md` | Cookie 同意・アナリティクス | functional/performant/targetable 同意モデル | 問題なし | 未成年からの同意の有効性については未検討 |

### 1-D. docs/architecture/ および docs/dictionary/

| ファイルパス                                              | 該当テーマ     | 現在の内容                                    | 判定     |
| --------------------------------------------------------- | -------------- | --------------------------------------------- | -------- |
| `docs/architecture/actor-naming.md`                       | actor 命名規則 | Client(app)/Operator(org)/Visitor(com) の定義 | 問題なし |
| `docs/dictionary/identity-account-organization-avatar.md` | DDD 用語定義   | Identity/Account/Organization/Avatar          | 問題なし |

### 1-E. adr/（関連のみ抜粋）

| ファイルパス                                               | 該当テーマ                                 | 判定                       | 備考                                              |
| ---------------------------------------------------------- | ------------------------------------------ | -------------------------- | ------------------------------------------------- |
| `adr/retainable-concern-and-retention-purge.md`            | データ保持・物理削除                       | 問題なし（技術設計として） | 保持期間の法的根拠が未記載                        |
| `adr/retention-lifecycle-column-boundary.md`               | 保持 vs. ライフサイクルカラム境界          | 問題なし                   |                                                   |
| `adr/sign-withdrawal-and-membership-surface-policy.md`     | 退会ポリシー（surface 別）                 | 問題なし                   |                                                   |
| `adr/sign-up-cycle-cancellation-retention.md`              | サインアップ途中キャンセルの保持           | 問題なし                   |                                                   |
| `adr/docs-help-news-discussion-moderation-notification.md` | コンテンツモデレーション（docs/help/news） | **要確認**                 | Proposed 段階・SNS 一般はスコープ外。代替方針なし |
| `adr/sign-com-no-social-login.md`                          | com での social login 非対応               | 問題なし                   |                                                   |

### 1-F. plans/

| ファイルパス                                                              | 該当テーマ                     | 判定               | 備考                                                                                    |
| ------------------------------------------------------------------------- | ------------------------------ | ------------------ | --------------------------------------------------------------------------------------- |
| `plans/active/sign-up-state-machine-implementation-plan.md`               | Sign-up state machine          | Check current code | `.app` Client now uses the 16+ policy; `.com` Visitor account remains 13+ intentionally |
| `plans/archive/withdrawal-state-machine-implementation-plan.md`           | 退会 state machine（実装済み） | 問題なし           |                                                                                         |
| `plans/backlog/org-operator-acquisition-lifecycle-implementation-plan.md` | Operator ライフサイクル        | 要確認             | 就業年齢制限への言及なし                                                                |

### 1-G. コード（実装の裏付け・read-only 確認）

| ファイルパス                                                                 | 該当テーマ               | 現在の内容                                                                     | 判定                                                    |
| ---------------------------------------------------------------------------- | ------------------------ | ------------------------------------------------------------------------------ | ------------------------------------------------------- |
| `app/services/age_eligibility.rb`                                            | 年齢判定サービス         | `minimum_age_reached?(birthdate, minimum_age:, today:)` — 引数で最低年齢を指定 | 仕組みは問題なし                                        |
| `app/services/sign_up_eligibility_policy.rb`                                 | Sign-up age policy       | `.app` Client 16+, `.com` Visitor account 13+                                  | Resolved for `.app`; `.com` 13+ is intentional          |
| `app/services/identity_social_ceremony_final_committer.rb`                   | Social sign-up age check | Calls `SignUpEligibilityPolicy` with `surface: :app`                           | Resolved for Google/Apple `.app` sign-up                |
| `config/locales/*/*.yml` (`sign.app.registration.checkpoint.age_restricted`) | Age-restricted message   | Uses 16th-birthday wording for `.app`                                          | Resolved for `.app`; `.com` keeps 13th-birthday wording |
| `app/controllers/concerns/r18_gate.rb`                                       | NSFW コンテンツゲート    | 18+ チェック、anonymous は cookie 確認                                         | 問題なし                                                |
| `app/models/concerns/withdrawable.rb`                                        | 退会 concern             | 31 日回復・states                                                              | 問題なし                                                |
| `app/models/concerns/retainable.rb`                                          | 保持 concern             | discarded_at + purged_at 2フェーズ                                             | 問題なし                                                |
| `app/models/avatar_block.rb`                                                 | ブロック機能             | blocker/blocked/reason/expires_at                                              | 実装あり・方針文書なし                                  |
| `app/models/avatar_mute.rb`                                                  | ミュート機能             | muter/muted/expires_at                                                         | 実装あり・方針文書なし                                  |

---

## 2. Current Policy Register

### MUST（今すぐ必須）

- `.app` Client direct sign-up (email, telephone, Google, and Apple) is restricted to age 16+. The
  implementation is resolved through `SignUpEligibilityPolicy`.
- 年齢計算は誕生日ベース（数え年でない）→ `AgeEligibility`
  サービスが birthday-based で実装済み。文書化が必要
- 生年月日は暗号化保存 → `has_birthdate` concern で暗号化済み。文書化が必要
- 退会・削除の state machine とデータ保持期間（31 日）→ 実装済み。公式方針文書として整備が必要
- .org / Operator は self-service サインアップを持たない → 実装・ADR 確認済み。方針文書なし
- avatar ブロック・ミュート → モデル実装済み。方針・docs なし
- .com / Visitor intake は年齢のみを理由に情報提供・通報・相談・安全報告を拒否しない
- "年齢ゲートなし" と "未成年の個人情報を無制限に処理してよい" は別物として docs に明記する

### SHOULD（なるべく入れるべき）

- .com / Visitor intake における Data Subject / Reporter（Guest）/ authenticated
  Visitor の明確な区分
- 未成年データ受領時のデータ最小化・公開防止・エスカレーション導線
- 年齢詐称時の対応ポリシー（停止・再確認・削除・通知）
- コンテンツモデレーション方針（SNS 一般向けの方針が現在 docs に存在しない）
- ブロック・ミュート機能の利用方針ドキュメント
- データ保持期間の法的根拠明記（APPI/GDPR 観点から 31 日の根拠）
- GDPR 消去権対応の手順書（退会フローとの対応関係）
- 通報・ハラスメント・なりすまし対応の escalation path
- .org / Operator の就業年齢方針（法的レビュー必要・固定年齢断定なし）
- 閏年・2月29日生まれの誕生日計算ポリシー → テストに実装あり (`age_eligibility_test.rb`)。文書なし

### FUTURE（将来構想として docs に残す）

- 13〜15 歳の保護者 invitation による .app / Client 登録フロー（MVP では実装しない）
- 保護者アカウントからの consent record・revocation・audit log
- 子アカウントの機能制限・データ最小化・デフォルト非公開
- データエクスポート（GDPR Subject Access Request 対応）の self-service 化

### NON-GOAL（今回やらない）

- 保護者同意フロー（MVP では実装しない）
- 13 歳未満の登録フロー
- ID 書類検証による年齢確認（self-declaration で対応）

### OPEN QUESTION（決める必要がある未確定事項）

- **[OQ-01]** .app / Client の最低年齢は確定（**16歳**）。コードは known gap として管理 →
  **実装変更タスクとして backlog に積む**
- **[OQ-02]** .org / Operator の最低就業年齢 → jurisdiction-dependent。legal/HR review required
- **[OQ-03]** .com / Visitor が未成年 Data Subject の情報を受け取った場合の具体的な処置手順
- **[OQ-04]** 退会後 31 日保持の法的根拠（APPI 利用目的との適合性）
- **[OQ-05]** 生年月日は退会・anonymization 後も保持されるか、消去されるか
- **[OQ-06]** 年齢詐称が判明した場合の処置（凍結・削除・再登録制限・通知）
- **[OQ-07]** 通報窓口は .com に設けるか、各 surface に設けるか
- **[OQ-08]** コンテンツモデレーション（SNS 全般）のオーナーと自動 vs. 人手の方針
- **[OQ-09]** GDPR の適用有無（EU ユーザーを受け入れるか）
- **[OQ-10]** COPPA の適用有無（米国ユーザー・13 歳未満受け入れ可否）

---

## 3. Risk Register

### RR-001: `.app` Client age minimum implementation gap

- **affected surface**: `.app` Client
- **severity**: resolved
- **why it matters**: account sign-up policy and implementation must agree before launch.
- **current status**: resolved as of 2026-06-25. `.app` Client email, telephone, Google, and Apple
  sign-up use the 16+ policy through `SignUpEligibilityPolicy`.
- **docs coverage**: `docs/policy/signup-eligibility.md` records the resolved `.app` policy, the
  intentional `.com` Visitor account 13+ policy, and the remaining `.com` Guest / Reporter intake
  product gap.
- **remaining decision**: no migration flow for existing 13-15 accounts is implemented in this P0
  finish-up. の `age_restricted` 文言を 16 に変更（**コード変更は承認後に別タスクで行う**）

### RR-002: 未成年（13〜15歳）が現在の実装で登録可能

- **affected surface**: .app / Client
- **severity**: critical（RR-001 と同根）
- **why it matters**: known
  gap の状態で運用継続する場合、13-15 歳ユーザーが正規フロー内に存在する。方針確定後に移行措置が必要
- **recommended doc action**: age restriction policy に移行措置・既存ユーザー扱いを記載
- **implementation impact**: 移行スクリプト・凍結・通知フロー（実装変更は別タスク）

### RR-003: 年齢詐称への対応方針の欠如

- **affected surface**: .app, .com
- **severity**: high
- **why it matters**:
  birthdate は self-declaration。虚偽申告への対応フローが docs にも実装にも存在しない
- **recommended doc action**: `docs/policy/signup-eligibility.md`
  に詐称対応セクション追加（処置は product decision 待ち）

### RR-004: .com Visitor intake 経由で未成年の個人情報を受け取るケース

- **affected surface**: .com
- **severity**: high
- **why it matters**:
  .com は年齢ゲートなし。しかし "年齢ゲートなし" は "未成年の PII を無制限に処理してよい" ではない。Data
  Subject が未成年であっても Reporter（Guest）は任意の年齢で送信できる。取扱い方針がない
- **recommended doc action**: `docs/policy/visitor-intake-policy.md` を作成

### RR-005: .org / Operator の最低就業年齢未定義

- **affected surface**: .org / Operator
- **severity**: high（労務法令の観点）
- **why it matters**:
  Operator は業務・雇用・契約主体として扱われる。法定就業年齢未満の Operator 登録を防ぐ方針がない
- **recommended doc action**: `docs/policy/operator-eligibility-policy.md`
  に就業年齢・法令管轄の節を追加（固定年齢断定なし、legal/HR review required）

### RR-006: アカウント削除とデータ保持の法的根拠が未記載

- **affected surface**: global
- **severity**: high
- **recommended doc action**: `docs/security/account-deletion-and-retention.md`
  に保持根拠・retention schedule を追加（legal review required）

### RR-007: ブロック・ミュート機能がドキュメントなし

- **affected surface**: .app
- **severity**: medium
- **recommended doc action**: `docs/moderation/block-and-mute-policy.md` 新規作成

### RR-008: 通報・ハラスメント・なりすまし対応フローの欠如

- **affected surface**: .app, .com
- **severity**: high
- **recommended doc action**: `docs/moderation/reporting-and-enforcement.md` 新規作成

### RR-009: 自動モデレーションで拾えない人間関係リスク

- **affected surface**: .app
- **severity**: medium
- **recommended doc action**: `docs/moderation/human-safety-policy.md` に方針記載

### RR-010: 生年月日の erasure と anonymization の関係が未定義

- **affected surface**: global
- **severity**: medium
- **recommended doc action**: `docs/security/account-deletion-and-retention.md`
  に birthdate 扱いの節

### RR-011: 未成年からの同意の有効性

- **affected surface**: .app, .com
- **severity**: medium
- **why it matters**: Cookie 同意・利用規約同意を 13-15 歳が単独で行った場合、日本民法 5 条・GDPR
  Article 8・COPPA の観点で無効になり得る
- **recommended doc action**: 年齢制限方針に「同意の有効年齢」節を追加（legal review required）

### RR-012: 未成年アカウントのデフォルト公開範囲未規定

- **affected surface**: .app
- **severity**: medium
- **recommended doc action**: minor-safety-policy に公開範囲デフォルト節を追加

### RR-013: 閏年・2月29日生まれの年齢計算

- **affected surface**: .app, .com
- **severity**: low
- **recommended doc action**: `docs/policy/signup-eligibility.md`
  に閏年ポリシーを明記（`age_eligibility_test.rb` の仕様と整合させる）

---

## 4. Missing Docs

| 提案ファイルパス                                  | 目的                                                                                                                                                | 優先度   |
| ------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| `docs/policy/signup-eligibility.md`               | `.app` Client 16+ eligibility, intentional `.com` Visitor account 13+ policy, remaining `.com` Guest/Reporter intake gap, and age calculation rules | Highest  |
| `docs/policy/visitor-intake-policy.md`            | .com の情報受領ポリシー。Data Subject/Reporter/Guest/authenticated Visitor の区分。データ最小化・未成年データ・エスカレーション                     | **最高** |
| `docs/policy/minor-safety-policy.md`              | 未成年保護方針。現行制限と将来の guardian invitation 構想を分離して記載                                                                             | 高       |
| `docs/policy/operator-eligibility-policy.md`      | .org / Operator の参加資格。就業年齢・法管轄依存・legal/HR review required                                                                          | 高       |
| `docs/security/account-deletion-and-retention.md` | 退会・削除・データ保持の公式方針。31 日根拠、anonymization 範囲、birthdate 扱い                                                                     | 高       |
| `docs/moderation/reporting-and-enforcement.md`    | 通報フロー・ハラスメント対応・異議申し立て・執行透明性                                                                                              | 高       |
| `docs/moderation/block-and-mute-policy.md`        | ブロック・ミュートの利用方針・解除条件                                                                                                              | 中       |
| `docs/moderation/human-safety-policy.md`          | 人間関係安全（なりすまし・晒し・グルーミング等）の方針                                                                                              | 中       |

> **注**: `docs/policy/` は新規ディレクトリ。既存の `docs/legal/` 以下に統合することも検討可。

---

## 5. Proposed Canonical Text

実際に docs に入れられる文章案。承認後にそのまま各ファイルに書き出す。

---

### 5-A: `docs/policy/signup-eligibility.md`

```markdown
# Sign-Up Eligibility Policy

## Scope

This policy governs eligibility requirements for creating accounts on each surface.

| Surface | Actor    | Policy                                                                               |
| ------- | -------- | ------------------------------------------------------------------------------------ |
| .app    | Client   | Direct sign-up restricted to age 16 and above                                        |
| .com    | Visitor  | Authenticated Visitor account; see also Visitor Intake Policy for non-account intake |
| .org    | Operator | Invitation-only; see Operator Eligibility Policy                                     |

## .app / Client — Direct Sign-Up

**Minimum age: 16 years old** (as of the date sign-up finalization completes).

This applies to all direct registration entry methods for the Client actor:

- Email OTP
- Telephone OTP
- Google social sign-up
- Apple social sign-up

### Known Implementation Gap

Resolved as of 2026-06-25:

- `.app` Client email and telephone sign-up use `SignUpEligibilityPolicy` with the 16+ policy.
- `.app` Client Google and Apple social sign-up use `SignUpEligibilityPolicy` with the 16+ policy.
- `.app` age-restricted copy uses 16th-birthday wording.

Intentional policy:

- Authenticated `.com` Visitor account sign-up remains 13+.

Remaining product gap:

- Unauthenticated `.com` Guest / Reporter intake is not implemented yet.

### Age Calculation Rules

- Age is calculated from the user's submitted birthdate (YYYY-MM-DD).
- A birthday is considered reached when `current_date >= birthday anniversary for the current year`.
- For users born on February 29: birthday is considered reached on February 28 in non-leap years.
  (Canonical: `AgeEligibility` service; covered in `test/services/age_eligibility_test.rb`.)
- Timezone for age calculation: server-configured service timezone. Cross-timezone edge cases
  require legal review before policy change.

### Birthdate Storage

- Birthdate is a mandatory checkpoint during the .app / Client sign-up cycle.
- For .com, birthdate collection depends on whether the flow creates an authenticated Visitor
  account.
- Unauthenticated Guest/Reporter intake must not require birthdate solely as an age gate.
- Birthdate is stored encrypted at rest (`has_birthdate` concern).
- Birthdate may not be changed without AAL2 step-up authentication.
- Birthdate changes are rate-limited (max 1 registration per account, all-time; see
  `docs/security/credential-abuse-rate-limits.md`).
- Birthdate is used solely for:
  - Age eligibility verification at sign-up
  - Age-gated feature access (e.g., NSFW content gate at 18+; see `r18_gate.rb`)
  - Legal compliance

Post-withdrawal handling of birthdate: [TBD — legal review required; see OQ-05]

### Under-13

For .app / Client account registration, users under 13 are not eligible under any pathway.

This does not apply to .com Guest/Reporter intake, where the Data Subject of a submission may be of
any age, including newborns, infants, children, and minors.

### Ages 13–15

Direct sign-up is not available for users aged 13–15 in the current product. A guardian invitation
pathway for ages 13–15 is a future design intent; see Minor Safety Policy.

### Misrepresentation of Age

Users who submit a false birthdate to circumvent age restrictions may have their account suspended,
terminated, and made ineligible for re-registration. Specific enforcement procedure: [TBD — product
decision required; see OQ-06]

### Legal Review Required

This policy intersects with:

- Japan: Civil Code Article 5 (consent capacity of minors)
- Japan: Act on the Protection of Personal Information (APPI)
- EU/UK: GDPR Article 8 (age of digital consent)
- US: Children's Online Privacy Protection Act (COPPA) — applicability depends on whether US minors
  are intentionally served [see OQ-10]
- Other jurisdictions: [TBD]

Do not implement age eligibility changes without legal review.
```

---

### 5-B: `docs/policy/visitor-intake-policy.md`

```markdown
# Visitor Intake Policy

## Scope

This policy covers the .com surface as an information-intake and public-access channel.

## Actor Definitions on the .com Surface

The following distinct roles exist on .com and must not be conflated:

| Role                      | Definition                                                                                                                                                                                                         |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Data Subject**          | The person whose information a submission concerns. May be of any age, including a minor or infant. Is not necessarily the submitter.                                                                              |
| **Reporter / Guest**      | An unauthenticated person submitting a form, report, inquiry, or safety concern on .com. Has no session-bound account.                                                                                             |
| **authenticated Visitor** | A person who has completed .com sign-up and holds a Visitor session. Subject to Visitor sign-up eligibility (see Sign-Up Eligibility Policy).                                                                      |
| **Visitor (general)**     | In code and ADRs, "Visitor" refers specifically to the authenticated actor (`Visitor < ComPrincipalRecord`). In this document, "Visitor" without a qualifier means the authenticated actor unless otherwise noted. |

## .com Intake: No Age Gate on Submissions

The .com surface does not reject information submissions, safety reports, inquiries, or
communications solely on the basis of the age of the Reporter (submitter) or the Data Subject.

Rationale: imposing an age gate on intake would prevent young people from:

- Providing information about safety concerns
- Reporting harm involving themselves or others
- Accessing public resources and support pathways

**Absence of an age gate on intake does not mean unrestricted processing of minors' personal data.**

## Authenticated Visitor Account Sign-Up

Creating an authenticated Visitor account on .com is a distinct act from submitting information as a
Guest. Visitor account sign-up is subject to age eligibility requirements defined in the Sign-Up
Eligibility Policy.

Being unable to create a Visitor account does not prevent a Guest from submitting information or
safety reports via unauthenticated intake forms.

## Personal Data Minimization

For all intake submissions (authenticated or unauthenticated):

- Collect only the data necessary to fulfill the stated purpose.
- Do not collect unnecessary personal identifiers.
- Do not expose submissions publicly by default.
- Retain submitted data only as long as necessary for the stated purpose.

## Submissions Involving Minors as Data Subjects

When a submission concerns a minor as the Data Subject:

- Do not request additional personal data beyond what is necessary to handle the submission.
- Do not share the Data Subject's information with other users or expose it publicly.
- Escalate to the appropriate internal team when the submission involves safety concerns.
- Provide a path to appropriate support resources (e.g., crisis lines, relevant authorities).

## Privacy Notice

A privacy notice must be displayed at all .com intake points (contact forms, report forms, sign-up
pages) explaining:

- What data is collected and from whom
- How it will be used
- How long it will be retained
- How to request correction or deletion

## Escalation Path for Sensitive Reports

If a submission indicates risk of harm to self or others, abuse, exploitation, harassment, or an
emergency: The intake process must have a documented escalation path. [TBD — ops/safety team; see
OQ-07]

## Legal Review Required

Personal data received about minors as Data Subjects may be subject to APPI, GDPR Article 8, COPPA,
or other applicable laws depending on the jurisdiction. Do not expand .com data collection without
legal review.
```

---

### 5-C: `docs/policy/minor-safety-policy.md`

```markdown
# Minor Safety Policy

## Scope

This policy describes the platform's protections for users under 18 and for minors who may be Data
Subjects in submissions received via .com.

## Current State (MVP)

### .app / Client

Direct sign-up on .app (Client) is restricted to users aged 16 and above. Users aged 13–15 are not
eligible for direct Client account creation in the current product. For .app / Client account
registration, users under 13 are not eligible under any pathway.

### .com / Visitor Intake

The .com Guest/Reporter intake surface does not reject submissions solely based on the age of the
Data Subject or the Reporter. A person of any age may appear as the Data Subject in a submission,
including newborns, infants, children, and minors. See Visitor Intake Policy for the full policy.

Authenticated Visitor account sign-up on .com is subject to separate age eligibility requirements;
see Sign-Up Eligibility Policy.

### .org / Operator

Operator accounts are invitation-only and not available via public self-service sign-up. Operator
eligibility is governed by the Operator Eligibility Policy.

### Known Implementation Gap

Resolved as of 2026-06-25: `.app` Client sign-up now enforces the 16+ policy. Authenticated `.com`
Visitor account sign-up intentionally remains 13+. The `.com` Guest / Reporter intake endpoint is
still a remaining product gap.

## Protections for Under-18 Users on .app

- NSFW content is gated behind an 18+ check (`r18_gate.rb`, `adult_for_nsfw?`). Users under 18 have
  the adult content gate set to DENY and cannot override it (`preference_adoption.rb`,
  `force_underage_r18_stopper!`).
- Birthdate is stored encrypted and cannot be changed without AAL2 step-up.

## Future: Guardian Invitation Pathway (not MVP)

The following is a future design intent only. None of this is currently implemented. Do not treat
this section as a current requirement.

### Purpose

To allow users aged 13–15 to create a Client account on .app with a verified guardian's affirmative
consent, via invitation from an existing Client account holder.

### Guardian Account Requirements

- Guardian must hold a verified .app / Client account.
- Guardian must have completed AAL2 verification before issuing an invitation.

### Invitation

- Invitation is issued from the guardian's account settings.
- Invitation is bound to the guardian's account and a specific contact identifier.
- Invitation expires after [TBD] days.

### Consent Record

- Guardian provides affirmative consent at invitation time.
- Consent record is retained after account withdrawal or anonymization of the child account.
- Consent record includes: guardian account identifier, timestamp, consent version, child contact
  identifier.

### Revocation

- Guardian may revoke consent at any time.
- Revocation triggers withdrawal of the child account.
- Child account data handling on revocation: [TBD — legal review required]

### Audit Log

- All guardian invitation, consent, and revocation events are recorded in a durable audit log
  retained even after anonymization.

### Child Account Restrictions

- Child accounts (ages 13–15) must have:
  - NSFW content gate permanently set to DENY (not user-overridable)
  - Default visibility: private / connections only (not publicly indexed)
  - [Additional restrictions TBD]

### Data Minimization

- Collect the minimum personal data necessary for the child account.
- Do not expose child account profiles, posts, or activity publicly by default.

### Legal Review Required

- Age of digital consent varies by jurisdiction.
- Guardian consent mechanism must satisfy GDPR Article 8 (EU), COPPA (US), and applicable local law
  before launch.
- Japan: Civil Code Article 5 implications for contractual consent by minors.
```

---

### 5-D: `docs/policy/operator-eligibility-policy.md`

```markdown
# Operator Eligibility Policy

## Scope

This policy covers eligibility requirements for .org / Operator accounts.

Operators are business/employment actors. They are distinct from .app Clients (consumer users) and
.com Visitors (public-access users). Do not apply consumer sign-up eligibility rules to Operator
onboarding.

## Sign-Up Pathway

Operator accounts are not available via public self-service sign-up. Operators are onboarded
exclusively through operator lifecycle requests initiated by existing authorized Operators or
platform administrators.

This is an intentional design choice. See: `adr/org-actor-operator-naming.md`.

## Eligibility Requirements

An Operator must satisfy all of the following:

1. **Legal working age** applicable to their place of employment or place of contract. Working age
   is jurisdiction-dependent and cannot be reduced to a single fixed minimum. Examples
   (informational; not legal advice; subject to change):
   - Japan: generally 15 with parental consent for certain work; 18 for restricted categories
   - Other jurisdictions: [TBD — legal/HR review required per market]

2. **Contractual capacity** under the civil and commercial law of the applicable jurisdiction.

3. **Valid organizational association**: the Operator must hold a valid invitation or lifecycle
   request from an Organization (workspace) that has entered into a service agreement.

## Age Policy

Unlike Client (16+ minimum), Operator eligibility is governed by employment and contract law, which
varies by jurisdiction. A single fixed age threshold is not appropriate and would be incorrect for
some markets.

**Before enforcing any age restriction on Operator onboarding:**

- Obtain legal and HR review for each operational jurisdiction.
- Document the resulting per-jurisdiction requirement as an appendix to this policy.

This section is intentionally incomplete pending that review.

## Open Items

- [OQ-02] Minimum working age per jurisdiction: legal/HR review required.
```

---

### 5-E: `docs/moderation/human-safety-policy.md`（参考案）

```markdown
# Human Safety and Reputation Safety Policy

## Scope

This policy addresses:

- Harassment, abuse, and targeted attacks
- Impersonation (なりすまし)
- Doxxing (晒し / 個人情報の無断公開)
- Reputational harm
- Human-relationship risks that automated systems may not reliably detect

## Current State

As of the current release:

| Feature                            | Status                                                         |
| ---------------------------------- | -------------------------------------------------------------- |
| Block                              | Implemented (`avatar_block.rb`) — policy documentation pending |
| Mute                               | Implemented (`avatar_mute.rb`) — policy documentation pending  |
| Content moderation queue           | Not yet implemented                                            |
| Reporting system                   | Not yet implemented                                            |
| Appeals / enforcement transparency | Not yet implemented                                            |

## Block and Mute

Users on .app may block or mute other avatars.

**Block**: prevents the blocked avatar from [TBD — surface-specific behavior to be defined]. Whether
blocking is visible to the blocked party: [TBD — product decision required].

**Mute**: suppresses content from the muted avatar. The muted party is not notified. Duration and
expiry: [TBD]

## Reporting

Users must be able to report:

- Harassment, threats, and abuse
- Impersonation of another person
- Doxxing or unauthorized disclosure of personal information
- Spam, scams, and coordinated inauthentic behavior
- Content that sexualizes minors

Reporting pathway: [TBD — see OQ-07]

## Enforcement Actions

Enforcement actions may include, in escalating order:

- Content removal
- Account warning
- Account suspension (`deactivated_at`)
- Account termination (withdrawal → `terminated_at`)
- Permanent re-registration ban

Response time target: [TBD] Reviewer: [TBD — moderation team / operator role]

## Appeals

Users subject to enforcement actions may submit an appeal within [TBD] days. Appeal process: [TBD]

## Automation Limitations

Automated moderation cannot reliably detect:

- Implicit threats or coded language
- Coordinated harassment campaigns using individually benign messages
- Grooming behavior in private messaging
- Context-dependent reputational harm

A human review path must exist for escalated cases.

## Legal Review Required

Defamation, harassment, and impersonation laws vary by jurisdiction. Enforcement decisions that may
constitute tortious interference require legal review.
```

---

## 6. Grill Me Questions（抜粋・補正済み）

### Product Policy

1. **年齢下限 16+ の実装変更をいつ行うか？** 現在 known
   gap として docs に記録したが、実装が 13 のままである間は方針とコードが乖離し続ける。

2. **16 歳に移行した場合、現在登録済みの 13-15 歳アカウントはどう扱うか？**
   凍結・段階的移行・猶予期間・保護者通知、いずれかを選ばないと不利益変更になる。

3. **年齢詐称が発覚した場合の処置を決めているか？（停止・削除・再登録禁止・通知の組み合わせ）**
   運用判断にばらつきが出ないよう policy に明記が必要。

4. **.com に問い合わせフォーム・通報フォームを設ける場合、未認証（Guest）の送信を受け付けるか？**
   未認証を拒否するとアカウントを持てない未成年が通報できなくなる。

5. **ブロックした側・された側への通知有無を決めているか？**
   ブロックを通知するとブロックしたことを相手に知らせ、逆恨みリスクが生じる。

6. **通報窓口の surface 設計（.com のみ、各 surface、全て）は？**
   通報先が表面ごとに違うと、ユーザーがどこに報告すれば良いかわからなくなる。

7. **Operator アカウントに birthdate checkpoint はあるか？目的は何か？** `has_birthdate.rb`
   が Operator に include されているが、sign-up 必須要件として義務付けられているか不明。

8. **SNS 一般のモデレーションのオーナーは決まっているか？**
   `adr/docs-help-news-discussion-moderation-notification.md`
   は SNS をスコープ外とし、`avatar_block` は実装済みだが、オーナー不明のまま。

### Legal/Compliance

9. **COPPA の適用有無（米国ユーザー・13 歳未満）を確認したか？**
   受け入れ有無によって実装要件が根本的に変わる（legal review required）。

10. **GDPR の適用有無（EU/EEA ユーザー受け入れ）を確認したか？** GDPR Article
    8 では 16 歳未満は保護者同意が必要（加盟国で 13 歳まで引き下げ可能）。

11. **日本民法 5 条の観点で、16 歳未満の利用規約同意は有効か？**
    保護者の追認なしで取り消せる可能性がある（legal review required）。

12. **退会後 31 日保持の APPI 上の法的根拠は定義済みか？**
    利用目的外保持禁止に抵触しないよう根拠の明示が必要。

13. **GDPR 消去権（Right to Erasure）への対応手順を定義しているか？**
    現在の退会フローが消去権対応を満たしているか未検証。

14. **birthdate は terminated_at 後に消去されるか？**
    APPI・GDPR の観点で目的外保持にならないか確認が必要（OQ-05）。

### Data Model

15. **avatar_block / avatar_mute は退会後のどのフェーズで削除されるか？** コードに cascade
    delete があるが、discarded_at 時か terminated_at 時かが docs に記載なし。

16. **通報記録（将来実装）の保持期間は？audit retention と PII 消去の交差点の設計は？**
    保持しすぎると APPI 違反、消しすぎると紛争証拠が消える。

### Sign-Up Flow

17. **Google/Apple social sign-up で OIDC の birthdate
    claim が取得できなかった場合の fallback は？** Optional
    claim のため取得できない場合がある。別途入力を求めるかどうかが未確認。

18. **telephone 経由の sign-up は birthdate + passkey +
    passcode がすべて必須か？email より要件が多い理由は？**
    要件の差が年齢ゲートのバイパス経路になっていないか確認が必要。

### Visitor Flow

19. **.com に authenticated Visitor アカウントの sign-up に birthdate
    checkpoint はあるか？年齢制限は何歳か？** docs では.com にも birthdate
    checkpoint があるが、年齢制限の適用が不明確。

20. **Guest（未認証）の .com 送信フォームで個人情報を収集する場合、privacy
    notice をどのタイミングで表示するか？** APPI・GDPR の「収集前の明示」要件に対応する必要がある。

### Future Guardian Invitation

21. **保護者が招待した子アカウントの活動状況を保護者が確認できる仕組みを設ける予定があるか？**
    保護者が関与できない招待は保護者同意として機能しない。

22. **子アカウントの birthdate を保護者が代理登録する場合、虚偽申告リスクをどう設計するか？**
    保護者が年齢詐称した場合のプラットフォーム責任が問われる可能性がある。

23. **保護者が同意 revoke した後、子アカウントの投稿・DM・フォロー関係はどう扱うか？**
    即時削除・非公開化・確認後削除など、要件が複数ある。

### Abuse Cases

24. **凍結・退会させたユーザーが別の連絡先で再登録することを防ぐ仕組みはあるか（ban evasion）？**
    email/telephone の digest は保持されるが、別の連絡先での再登録を防ぐ手段が未規定。

25. **「晒し」（doxxing）コンテンツへの緊急削除フローはあるか？**
    通常の通報フローとは別に緊急対応ラインが必要。

26. **「自傷・他害の予告」を含む通報を受けた場合の外部機関への連絡フローはあるか？**
    プラットフォーム事業者としての法的義務と実務フローの確認が必要。

### Documentation Ownership

27. **docs/policy/ のオーナーは誰か（法務・プロダクト・セキュリティ）？**
    オーナー不明だと実装変更時に docs が陳腐化し続ける。

28. **本監査レポートの OPEN QUESTION は誰がいつまでに決定するか？**
    決定者と期日がなければ方針ドキュメントが書けないまま known gap が積み上がる。

---

## 7. Contradictions / Inconsistencies（補正済み）

### C-01: `.app` Client age minimum implementation gap

- **Status**: resolved as of 2026-06-25.
- **Current implementation**: `.app` Client email, telephone, Google, and Apple sign-up use
  `SignUpEligibilityPolicy` with the 16+ policy.
- **Localized copy**: `.app` age-restricted messages use 16th-birthday wording.
- **Intentional exception**: authenticated `.com` Visitor account sign-up remains 13+.
- **Remaining product gap**: unauthenticated `.com` Guest / Reporter intake is not implemented.

### C-02: .com / Visitor の年齢制限に関する v1 の誤記（補正済み）

- **v1 の誤り**: "Direct sign-up is restricted to users aged 16 and above on .app (Client) **and
  .com (Visitor)**"
- **補正**: .com は年齢のみを理由に intake を拒否しない。authenticated Visitor
  account の sign-up には年齢制限が適用されるが、intake（情報提供・通報等）とは区別する
- **根拠**: Data
  Subject が 0 歳 1 日であっても、その情報を持つ Reporter（Guest）は通報を送信できる必要がある

### C-03: birthdate が "checkpoint" と "age verification" の区別が docs にない

- `docs/security/sign-up-sequence.md`
  では birthdate を checkpoint として記載するが、収集目的（年齢判定）が記載されていない
- APPI の「利用目的の明示」要件（収集前に目的を明示する義務）に対応できていない可能性
- → `docs/policy/signup-eligibility.md` の "Birthdate Storage" 節で明示する

### C-04: withdrawal / deletion / deactivation / anonymization の用語混在

- `withdrawable.rb`、`retainable.rb`、docs、ADR にまたがって異なる用語が使われており、"退会" が論理削除か物理削除か anonymization かが判別しにくい
- `adr/retention-lifecycle-column-boundary.md` が区別を定義しているが参照されにくい
- → `docs/security/account-deletion-and-retention.md`（別タスク）で整理する

### C-05: Operator に birthdate が収集されるが年齢制限方針が存在しない

- `has_birthdate.rb` が Client/Operator/Visitor 全員に include されている
- `sign_up_requirement_registry.rb` での birthdate 要求が Operator にも適用されるか不明
- → `docs/policy/operator-eligibility-policy.md`
  で Operator の birthdate 目的を明記する（あるいは Operator における不要性を記載する）

### C-06: 将来の guardian invitation 構想が docs に存在しない

- 「将来設計として docs に残す」という方針があるのに、保存先がなかった
- → `docs/policy/minor-safety-policy.md` の FUTURE セクションに記載する（今回）

### C-07: moderation ADR が Proposed、SNS 全般が「スコープ外」、しかし実装が先行

- `adr/docs-help-news-discussion-moderation-notification.md` は SNS 一般をスコープ外と明記
- しかし `avatar_block.rb`, `avatar_mute.rb` は実装済みで、利用者向けポリシーが存在しない
- → `docs/moderation/block-and-mute-policy.md` および
  `docs/moderation/human-safety-policy.md`（優先度: 中）

---

## 8. Recommended Next Actions

### P0: docs 作成（実装変更なし、今すぐ可能）

| アクション                       | ファイル                                     | 依存                                           |
| -------------------------------- | -------------------------------------------- | ---------------------------------------------- |
| Sign-Up Eligibility Policy 作成  | `docs/policy/signup-eligibility.md`          | なし（方針確定済み）                           |
| Visitor Intake Policy 作成       | `docs/policy/visitor-intake-policy.md`       | なし                                           |
| Minor Safety Policy 作成         | `docs/policy/minor-safety-policy.md`         | なし                                           |
| Operator Eligibility Policy 作成 | `docs/policy/operator-eligibility-policy.md` | なし（legal review 必要箇所は TBD として残す） |

### P1: docs 作成（product/legal 決定待ちの節あり）

| アクション                                                                | ファイル                                          | 依存                             |
| ------------------------------------------------------------------------- | ------------------------------------------------- | -------------------------------- |
| Account Deletion and Retention Policy                                     | `docs/security/account-deletion-and-retention.md` | legal review（OQ-04, OQ-05）     |
| Human Safety Policy                                                       | `docs/moderation/human-safety-policy.md`          | product decision（OQ-07, OQ-08） |
| Reporting and Enforcement                                                 | `docs/moderation/reporting-and-enforcement.md`    | product decision                 |
| Block and Mute Policy                                                     | `docs/moderation/block-and-mute-policy.md`        | product decision                 |
| `japan-saas-legal-triage.md` に未成年保護・COPPA・GDPR Article 8 の節追加 | `docs/reference/japan-saas-legal-triage.md`       | legal review                     |

### P2: Remaining Follow-Up

| Action                                  | Target                                         | Status                             |
| --------------------------------------- | ---------------------------------------------- | ---------------------------------- |
| `.app` Client 16+ implementation        | `SignUpEligibilityPolicy` callers              | Done                               |
| `.app` age-restricted copy              | `config/locales/*/*.yml` app checkpoint keys   | Done                               |
| `.com` Visitor account 13+ policy       | `SignUpEligibilityPolicy` with `surface: :com` | Intentional                        |
| `.com` Guest / Reporter intake endpoint | TBD                                            | Remaining product gap              |
| Existing 13-15 account migration        | TBD                                            | Out of scope for this P0 finish-up |

### P3: legal review

| 項目                                                                |
| ------------------------------------------------------------------- |
| COPPA 適用有無（米国ユーザー・13 歳未満受け入れ方針）[OQ-10]        |
| GDPR 適用有無（EU/EEA ユーザー）・consent age（Article 8）[OQ-09]   |
| 日本民法 5 条: 16 歳未満の利用規約同意の有効性                      |
| APPI: 退会後 31 日保持の利用目的適合性 [OQ-04]                      |
| APPI: birthdate の収集目的明示と terminated_at 後の保持可否 [OQ-05] |
| Operator の法定就業年齢（jurisdiction 別）[OQ-02]                   |
| 緊急通報（自傷他害）受領時のプラットフォーム義務                    |
| なりすまし・名誉毀損・晒し対応の法的留意点（管轄別）                |

### P4: product decision required

| 項目                                                    | 参照           |
| ------------------------------------------------------- | -------------- |
| 13-15 歳アカウントの移行措置（凍結・猶予・通知）        | RR-002         |
| 年齢詐称発覚時の処置                                    | OQ-06          |
| 通報窓口の surface 設計                                 | OQ-07          |
| コンテンツモデレーション体制（自動 vs. 人手・オーナー） | OQ-08, RR-008  |
| ブロックの通知設計・解除条件                            | RR-007         |
| ban evasion（凍結済みユーザーの再登録防止）設計         | Section 6 Q-24 |

---

## 9. Known Implementation Gaps

| Gap ID  | Area                                                      | Current status                                               | Scope                                         | Priority   |
| ------- | --------------------------------------------------------- | ------------------------------------------------------------ | --------------------------------------------- | ---------- |
| GAP-001 | `.app` Client 16+ email and telephone sign-up             | Resolved                                                     | `.app` Client email/telephone sign-up         | Done       |
| GAP-002 | `.app` Client 16+ Google and Apple sign-up                | Resolved                                                     | `.app` Client social sign-up                  | Done       |
| GAP-003 | `.app` age-restricted copy                                | Resolved                                                     | `.app` localized sign-up checkpoint copy      | Done       |
| GAP-004 | `.com` Visitor account sign-up                            | Intentional policy: remains 13+                              | Authenticated `.com` Visitor account creation | Documented |
| GAP-005 | `.com` Guest / Reporter intake endpoint                   | Remaining product gap: endpoint not implemented              | Unauthenticated `.com` intake                 | High       |
| GAP-006 | `app/models/avatar_block.rb`, `app/models/avatar_mute.rb` | Implemented without policy doc                               | `.app` users                                  | Medium     |
| GAP-007 | Birthdate collection purpose                              | Policy doc started; privacy/legal docs may still need detail | Privacy policy                                | Medium     |
