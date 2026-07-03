# Umaxica 退会プロセス現状監査レポート (Grill Me with Docs v2)

日付: 2026-07-03 / 種別: 現状把握監査(実装変更なし) / 対象:
app/com/org 退会・復旧・早期消去・purge/shred・occurrence

> 注: 本レポートは調査成果物。承認後は `memos/2026-07-03-withdrawal-process-audit.md`
> へ複製保存する運用(feedback_save_plan_reports_to_memos)。

## 用語対応(最重要の前提)

タスク仮説の User/Customer/Staff は改名済み。DB テーブルは旧語彙のまま:

| 仮説の語 | AR モデル  | DB テーブル               | DB            | Surface |
| -------- | ---------- | ------------------------- | ------------- | ------- |
| User     | `Client`   | `clients` (旧 users)      | app_principal | app     |
| Customer | `Visitor`  | `visitors` (旧 customers) | com_principal | com     |
| Staff    | `Operator` | `operators` (旧 staffs)   | org_principal | org     |

---

## A. Executive Summary

**結論: 想像より実装は進んでいるが、設計仮説のうち3つが現実と食い違う。**

1. **通常退会 = deactivation +
   31日復旧猶予は実装済み**。`Withdrawable`(`app/models/concerns/withdrawable.rb:9-11`: 31日復旧 /
   1時間復旧待機 / 7日後早期終了)+ `WithdrawalLifecycle`(`app/services/withdrawal_lifecycle.rb`)+
   `RetentionPurgeJob`(Solid Queue,
   15分毎)で一貫動作。ADR(`adr/retention-lifecycle-column-boundary.md`, 2026-05-25
   Accepted)とコードは整合。
2. **app/com はほぼ同型**。両方 `BaseSettingsWithdrawalFlow`
   concern に委譲(`app/controllers/concerns/base_settings_withdrawal_flow.rb`)。ただし **withdrawal
   gate の allowlist に com が漏れており、suspended
   visitor が com の退会/復旧ページに到達できず app 側へクロスサーフェス redirect される欠陥あり**(`app/controllers/concerns/authentication_withdrawal_gate.rb:44-48,58-65,86-88`)。
3. **org は別設計として正しく分離**。placeholder(show のみ、静的「利用不可」ページ)+ 管理側
   `OperatorLifecycleRequest`。`WithdrawalLifecycle`
   は Operator を raise で拒否(`withdrawal_lifecycle.rb:172`)。
4. **withdrawal ceremony session は存在しない**。退会後 status/復旧は通常 auth
   session の「生き残り1本」(suspend 時に現セッションだけ revoke 除外)+ `enforce_withdrawal_gate!`
   の allowlist で運用。仮説の「専用短命セッション」は未実装。
5. **privacy erasure request は機能として一切存在しない**。model / table / route / controller / job
   / docs すべて無し。早期消去に相当するのは 7日後 `terminate!`(即時匿名化)のみで、削除請求 state
   machine・jurisdiction・response_due・processor notification は全欠落。
6. **legal
   hold は「文書化されているが未実装」**。ADR は legal-hold 対象を purge 対象外と記述(`adr/sign-withdrawal-and-membership-surface-policy.md:69-71`)するが、`RetentionPurgeJob`
   は `purged_at <= now` だけで削除しガード無し・テスト無し。
7. **occurrence は履歴専用で仮説どおり**だが、退会/復旧/終了イベントは occurrence に書かれない。durable
   trail は `*_withdrawal_flow(_event)` 行のみで、`WithdrawalLifecycle#notify` は
   `Rails.logger.info` のログのみ(`withdrawal_lifecycle.rb:249`)。

**最も危険な未解決点トップ7**

1. [High] com surface の withdrawal gate allowlist 欠落 → suspended
   visitor が com の復旧 UI に到達不能(A-2 参照)。
2. [High] deactivated subject の access token が TTL まで有効なまま `current_resource`
   に立つ(gate 頼み)。DBSC エンドポイントは gate を skip。
3. [High] legal hold ガードなしの purge(ADR と矛盾)。
4. [High] privacy erasure request の完全欠落(日米欧対応の state が無い)。
5. [Medium] security invariant テスト2本が死んだ `X-TEST-CURRENT-*`
   ヘッダで実質未認証リクエスト(`test/security/invariants/withdrawal_gate_invariant_test.rb:140-141`
   他)。
6. [Medium] app の step-up-on-withdrawal 統合テストが削除済み(git status
   `D test/integration/app_step_up_verification_enforcer_test.rb`、org 側のみ残存)。
7. [Medium] `RecoverySecretsController`
   が route 未配線の orphan、`ClientStatus::WITHDRAWN/PENDING_DELETION/PRE_WITHDRAWAL_CONDITION/WITHDRAWAL_COMPLETED`
   は一度も代入されない死定数。

**判断: 実装着手は「一部だけ可」。** com allowlist 修正・死テスト修正は即着手可能。ceremony session
/ erasure request は設計判断(下記 N)が先。

---

## B. Evidence Map(主要な主張と証跡)

**Claim 1: app/com controller は同型で、退会 suspend 時に「現セッション以外」を revoke する。**

- `app/controllers/base/app/identity/withdrawals_controller.rb`(VerificationClient +
  BaseSettingsWithdrawalFlow, step-up scope `"withdrawal"` :52-54)
- `app/controllers/base/com/identity/withdrawals_controller.rb`(VerificationVisitor +
  CommonRedirect + 同 flow, :78)
- `app/services/withdrawal_lifecycle.rb:58`
  `revoke_sessions(except_public_id: current_session_public_id)`、:207-234(fresh withdrawal step-up
  session も除外)
- Impact: 生き残った1セッション+その access token で退会後導線を賄う設計。ceremony
  session の代替になっているが、TTL 切れ後は透過 refresh 許可パス(:2630
  `allow_suspended: true`)頼み。

**Claim 2: deactivated subject は通常 auth resolver を通過し、before_action gate だけで止まる。**

- `app/controllers/concerns/authentication_base.rb:1720-1725` `resource_withdrawn?` は
  `withdrawn?`(finalized)のみ null 化。suspended は `current_resource` に立つ。
- `app/controllers/concerns/authentication_withdrawal_gate.rb:17-33`(HTML→redirect、JSON→403
  WITHDRAWAL_REQUIRED)
- gate 登録: base/app `application_controller.rb:82`、base/com :75、core/app :70、core/com
  :67、auth/{app,com,org}、side/{app,com}。ただし `edge/v0/cookies`・`edge/v0/dbsc` 系は skip(例
  `core/app/edge/v0/dbsc_controller.rb:20`)。
- Impact: gate 未登録 controller が1つでも増えると suspended subject が素通りする脆い構造。

**Claim 3: refresh token 経路は deactivated を止める。**

- `authentication_base.rb:1074-1079` `refreshable_resource?`(active? のみ、`allow_suspended`
  例外)、:1009-1015 deactivated → 403 `withdrawal_required`、:1050-1072 refresh-token
  family 全 revoke。
- 新規ログインは `login_allowed?`(`identity.rb:15-17` → `active?`)で拒否。

**Claim 4: legal hold ガードなし purge。**

- `app/jobs/retention_purge_job.rb:62,71,82`(`where(purged_at: ..now)` のみ)。
- ADR 記述: `adr/sign-withdrawal-and-membership-surface-policy.md:69-71`。
- `legal_hold` は admin access-lock の reason
  code としてのみ存在(`db/app_principals_migrate/20260614090000_add_administrative_access_lock_to_clients.rb:29`)。purge 判定には未接続。

**Claim 5: privacy erasure request / retention exception / processor notification は存在しない。**

- `PrivacyRequest`/`ErasureRequest`
  モデル、`response_due_at`/`denial_reason`/`retention_exception_code`/`processor_notification`
  カラム、該当 job: すべて grep 全域で不在。
- 唯一の言及は open question(`plans/analysis/audit-and-evidence-plan.md:116`)。

**Claim 6: occurrence は履歴専用・PII ハッシュ化済みだが、退会イベントは書かれない。**

- 書き手は
  `app/services/sign_risk_emitter.rb:57,73,89`(risk.\* のみ、HMAC 化 :42-51,108-122)。読み手は anomaly 相関のみ(`app/subscribers/jwt_anomaly_subscriber.rb:12`)。
- 退会の durable trail = `ClientWithdrawalFlow`/`VisitorWithdrawalFlow`(+ event 行)+
  `AccountAccessEvent`(chronicle)。`Rails.event.notify` は CSP
  violation 経路のみ(`app/services/csp_violation_report_intake.rb:147`)。

---

## C. Current Flow Diagrams

### 通常退会(app/com 同型)

```text
GET  new  -> ScheduleForm/DeactivateForm 表示 (step-up scope "withdrawal" 必須)
POST update
  ├─ schedule: WithdrawalLifecycle.start!  … flow=REQUESTED、破壊的カラム変更なし
  └─ deactivate today: WithdrawalLifecycle.suspend!
       withdrawal_started_at / deactivated_at / discarded_at = now
       purged_at = now + 31d
       flow -> DISCARDED
       revoke_sessions(except: 現セッション + fresh withdrawal step-up)
       -> redirect edit (status page)
```

### 退会後 status / 復旧 / 早期終了

```text
GET edit (status)  … 生き残り通常 session + gate allowlist で到達 (app のみ; com は欠陥で不達)
POST create  -> can_recover? (deactivated+1h 以降 & purged_at 前) -> recover!
               withdrawal_started_at/deactivated_at/withdrawn_at=nil, discarded/purged=∞, flow=RECOVERED
               ※ 再ログイン強制なし。生き残り session がそのまま通常 session に戻る
DELETE destroy -> early_terminatable? (deactivated+7d 以降) -> terminate!
               terminated_at=now, WithdrawalPersonalDataAnonymizer, 全 session revoke, flow=TERMINATED
```

### purge/shred backend(Solid Queue)

```text
RetentionPurgeJob (recurring.yml:53, 15分毎, queue :retention)
  ├─ 一般 Retainable ~40 model: where(purged_at <= now).in_batches.delete_all (子→親順)
  ├─ Client/Visitor: where(purged_at <= now, terminated_at: nil) -> anonymizer -> withdrawn_at/terminated_at 設定 (行は残す)
  └─ Operator: cross-DB child purge -> delete_all (物理削除、匿名化なし)
  legal hold チェック: なし / occurrence 書き込み: なし
```

### auth/session boundary

```text
access token -> AuthenticationCurrentResourceResolver -> current_resource 成立 (suspended でも成立)
  -> enforce_withdrawal_gate! (allowlist: base/app/identity/withdrawals のみ) -> redirect/403
refresh -> refreshable_resource? (active? のみ; allow_suspended は退会状態ページ経路 :2630 のみ)
新規ログイン -> login_allowed? で拒否
withdrawn? (finalized) -> resolver 自体が subject を null 化
```

---

## D. Route / Controller Matrix

| Surface | Route                                                  | HTTP                           | Controller#action                                | Auth gate                                                             | Subject          | Status                          | Evidence                                 |
| ------- | ------------------------------------------------------ | ------------------------------ | ------------------------------------------------ | --------------------------------------------------------------------- | ---------------- | ------------------------------- | ---------------------------------------- |
| app     | `identity/withdrawal`                                  | new/create/edit/update/destroy | `Base::App::Identity::WithdrawalsController`     | authenticate_client! + step-up "withdrawal" + gate allowlist済        | current_client   | implemented                     | `config/routes/base.rb:213`              |
| com     | `identity/withdrawal`                                  | 同上                           | `Base::Com::Identity::WithdrawalsController`     | authenticate_visitor! + step-up "withdrawal"、**gate allowlist 漏れ** | current_visitor  | implemented (gate欠陥)          | `config/routes/base.rb:353`              |
| org     | `identity/withdrawal`                                  | show のみ                      | `Base::Org::Identity::WithdrawalsController`     | authenticate_operator! + step-up "operator_lifecycle"                 | current_operator | placeholder                     | `config/routes/base.rb:515`              |
| app     | (recovery secrets)                                     | —                              | `Base::App::Identity::RecoverySecretsController` | —                                                                     | —                | **stale/orphan (route 未配線)** | controller 存在、routes 全ファイル不一致 |
| all     | erasure / privacy_request / purge / recover 専用 route | —                              | —                                                | —                                                                     | —                | **missing**                     | routes 全域 grep                         |

復旧は独立 route ではなく `POST withdrawal`(create=recover)、早期終了は
`DELETE withdrawal`(`base_settings_withdrawal_flow.rb:35,77`)。

## E. State Machine Audit

| Field / status / method                                                                                 | Defined in                                  | Written by                       | Read by                                                        | Meaning                                                               | Conflict                                                           |
| ------------------------------------------------------------------------------------------------------- | ------------------------------------------- | -------------------------------- | -------------------------------------------------------------- | --------------------------------------------------------------------- | ------------------------------------------------------------------ |
| `withdrawal_started_at`                                                                                 | actor tables                                | `suspend!`                       | `Withdrawable#closing?/withdrawal_started?`                    | 退会開始                                                              | なし                                                               |
| `deactivated_at`                                                                                        | actor tables                                | `suspend!` / `recover!` が clear | `deactivated?/suspended?/recovery_available_at`                | 可逆停止                                                              | なし                                                               |
| `discarded_at` (∞既定)                                                                                  | `Retainable`                                | suspend/anonymizer               | `accessible?/lapsed?`                                          | 論理非表示                                                            | なし                                                               |
| `purged_at` (∞既定)                                                                                     | `Retainable`                                | suspend (=deactivated+31d)       | **RetentionPurgeJob 唯一の purge ゲート**、`recovery_deadline` | 物理削除可能時刻                                                      | legal hold 非考慮                                                  |
| `withdrawn_at` (∞=未退会)                                                                               | actor tables                                | RetentionPurgeJob(anonymize後)   | `withdrawn?` → resolver null化                                 | 退会**確定**                                                          | 「recoverable」ではなく finalized。docs と一致                     |
| `terminated_at`                                                                                         | Client/Visitor のみ(Operator 無し)          | `terminate!` / purge job         | `terminated?/permanently_deletable?`                           | PII 抹消済                                                            | Operator は物理削除路線で意図的差分                                |
| `ClientStatus::WITHDRAWN(5)/PENDING_DELETION(6)/PRE_WITHDRAWAL_CONDITION(7)/WITHDRAWAL_COMPLETED(8)`    | `client_status.rb`                          | **どこからも代入されない**       | —                                                              | 死定数                                                                | VisitorStatus は3値のみで非対称。実挙動は両者 timestamp 駆動で同一 |
| `*WithdrawalFlow.status_id` (REQUESTED/CLOSING/DISCARDED/RECOVERED/TERMINATED/FAILED + TRANSITIONS map) | `client_withdrawal_flow_status.rb:55-63` 等 | `WithdrawalLifecycle`            | flow guard                                                     | フロー状態の SSOT (Client/Visitor のみ)                               | Operator 版なし(意図的)                                            |
| `scheduled_purge_at`/`recovery_until`/`deletable_at`/`shreddable_at`                                    | —                                           | —                                | —                                                              | **存在しない**(禁止語彙、`deletable_at` は 20260525200000 で drop 済) | backlog plan が「まだある」と主張=stale                            |

## F. Session/Auth Boundary Audit(必須結論)

- **退会済み(finalized withdrawn)subject は通常 auth で拒否されるか** →
  Yes。resolver が null 化(`authentication_base.rb:1720-1725`)。
- **deactivated(suspended)subject は?** → 通常 auth を**通過**し gate で止まる設計。gate
  skip の edge/dbsc controller、gate 未登録 surface が穴になりうる。
- **退会直後の access token は有効なままか** →
  **Yes、TTL まで有効**。token 側の即時失効はない(gate + refresh 拒否のみ)。
- **refresh token は拒否されるか** → Yes(403 withdrawal_required +
  family 全 revoke)。例外: 退会状態ページ経路のみ `allow_suspended: true`(:2630)。
- **復旧は通常 session に依存しているか** → **Yes**。suspend で除外された生き残り通常 session +
  `authenticate_client!/visitor!` 前提。access
  token 失効後は allow_suspended 透過 refresh が生きている限り到達可、切れたら**復旧導線に戻れない**(再ログインは login_allowed? で拒否されるため詰む可能性 — 未検証、要机上確認)。
- **withdrawal ceremony session は存在するか** →
  **No**。仮説モデル(短命・refresh なし・current_user 分離)との差分は全項目。
- notification token(`*NotificationRecord`, signal DB): 退会時の無効化処理**なし**(revoke 対象は
  `*Token` のみ)。OAuth/social token は terminate 時の anonymizer でのみ revoke(suspend 時は残る)。

## G. User-Facing Withdrawal UX Audit

- app status ページ(`app/views/base/app/identity/withdrawals/edit.html.erb`): 復旧 button
  / 早期終了 button / 期限表示。**ただし back link が通常 identity
  settings(`base_app_identity_path`, :36)へ戻る**
  — 仮説の「復旧と早期消去のみ」に反する導線(gate が settings 側で redirect するので実害は循環 redirect だが、UX として混線)。
- com: 同型 view があるが gate 欠陥により suspended visitor は到達不能(→ app へ誤 redirect)。
- org(`show.html.erb`): 静的「利用不可・問い合わせ」+ back link のみ。適切。
- 早期消去 request 画面 / legal hold 中の保持理由説明画面: **存在しない**。
- 空の stale view dir:
  `app/views/base/shared/settings/withdrawals`、`app/views/base/org/settings/withdrawals`。

## H. Privacy / Legal Readiness Audit

| Requirement                          | Existing support                     | Evidence                                        | Gap                                                                      | Severity |
| ------------------------------------ | ------------------------------------ | ----------------------------------------------- | ------------------------------------------------------------------------ | -------- |
| 退会と削除請求の分離                 | なし(terminate! が唯一の消去)        | §B Claim 5                                      | erasure request state machine 全欠落                                     | High     |
| 31日猶予と法定履行期限の分離         | 概念上のみ(ADR)                      | `withdrawable.rb:9`                             | response_due_at 等なし                                                   | High     |
| 保持理由の説明・記録                 | なし                                 | `denial_reason`/`retention_exception_code` 不在 | 全欠落                                                                   | High     |
| processor への削除通知状態           | なし                                 | job/model 不在                                  | 全欠落                                                                   | Medium   |
| request source (agent/guardian) 拡張 | なし                                 | —                                               | 全欠落                                                                   | Medium   |
| legal hold > purge 優先              | ADR 記述のみ、実装なし               | `retention_purge_job.rb:62` vs ADR :69-71       | 未実装・未テスト                                                         | High     |
| 監査ログ・chronicle の保全           | あり(anonymizer が意図的に温存)      | `withdrawal_personal_data_anonymizer.rb:15-17`  | —                                                                        | OK       |
| erasure 完了後の復旧不可             | terminate! 後は `can_recover?` false | `withdrawable.rb:48,60`                         | OK(ただし request モデル不在なので「processing 中の復旧」概念自体がない) | —        |

## I. Occurrence Audit

- 履歴専用: Yes。current state の読み手なし(anomaly 相関のみ)。lifecycle
  SSOT ではない — 仮説どおり。
- PII: HMAC 化済み、plaintext なし。occurrence 自体も `Retainable` で self-expire(risk 系は 1h)。
- **Gap**: 退会・復旧・終了・purge・(将来の)削除請求イベントは occurrence に**残らない**。`WithdrawalLifecycle#notify`
  はログのみ(旧語彙 `user_id`/`visitor_id` キー、:260-266)。`Rails.event.notify` と durable
  write の混同はない(そもそも退会経路で Rails.event 未使用)。

## J. Solid Queue / Backend Audit

- 実装済: `RetentionPurgeJob`(15分毎、冪等: Client/Visitor は `terminated_at: nil`
  フィルタ、Operator は delete_all)。ceremony 系 purge job 8種。すべて Solid Queue。
- **不足機能**(実装提案ではなく欠落一覧): legal hold / retention
  exception チェック、purge 結果の occurrence 記録、processor notification job、erasure
  request 駆動の per-subject job、withdrawal finalize の occurrence 化、notification token 無効化。
- scan と subject 単位 job の分離: なし(単一 job 内で batch)。大量一括 transaction リスクは
  `in_batches` で緩和済み。

## K. Stale Code / Stale Docs / Stale Tests

| Type       | Path                                                                                                                         | Stale evidence                                                                                | Recommendation    |
| ---------- | ---------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- | ----------------- |
| Plan       | `plans/backlog/retention-vocabulary-drift-cleanup.md`                                                                        | `clients.deletable_at` 残存を主張、実際は 20260525200000 で drop 済・参照ゼロ                 | archive 化        |
| Test       | `test/security/invariants/withdrawal_gate_invariant_test.rb:140-141`, `withdrawn_resource_refresh_invariant_test.rb:114-128` | 死んだ `X-TEST-CURRENT-*` のみで Bearer なし → 実質未認証で「正しい結果を誤った理由で」assert | Bearer 認証へ移行 |
| Test       | `test/integration/app_step_up_verification_enforcer_test.rb` (git D)                                                         | app の withdrawal step-up 統合カバレッジ喪失(org 版は残存)                                    | 復元 or 代替      |
| Controller | `Base::App::Identity::RecoverySecretsController`                                                                             | route 未配線 orphan                                                                           | 配線 or 削除判断  |
| Const      | `ClientStatus::WITHDRAWN/PENDING_DELETION/PRE_WITHDRAWAL_CONDITION/WITHDRAWAL_COMPLETED`                                     | 代入箇所ゼロの死定数                                                                          | 削除候補          |
| Comment    | `client_withdrawal_policy.rb:6`, `visitor_withdrawal_policy.rb:6`                                                            | 旧 `Sign::*::Settings::WithdrawalsController` を参照                                          | コメント更新      |
| Form NS    | `Sign::App::Settings::Withdrawal::*Form` が com でも使用(`base_settings_withdrawal_flow.rb:88-89`)                           | 旧 namespace の cross-surface 流用                                                            | 改名候補          |
| Doc        | `docs/security/sign-withdrawal-and-membership.md` 自己 deprecated だが `docs/index.md:90` が生きた参照として列挙             | index 修正                                                                                    |
| ADR        | `adr/retainable-concern-and-retention-purge.md` 例示コードが禁止語彙(`shreddable_at` 等)                                     | 歴史注記追加                                                                                  |
| View       | `app/views/base/shared/settings/withdrawals`, `base/org/settings/withdrawals` 空 dir                                         | 削除                                                                                          |
| Test path  | `test/helpers/sign/app/withdrawals_helper_test.rb`(class は Auth::App::)                                                     | 移動                                                                                          |

## L. Invariants

| Invariant                                             | 判定           | 根拠                                                                                                                                                                 |
| ----------------------------------------------------- | -------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1. deactivated subject が通常 auth session を得ない   | **Fail(部分)** | 新規 login/refresh は拒否だが、既存 access token は TTL まで `current_resource` 成立。gate + allowlist で抑止する多層構造で、com allowlist 漏れ・edge/dbsc skip が穴 |
| 2. 復旧窓内の復旧が通常 active session を要求しない   | **Fail**       | 復旧は生き残り通常 session 前提。session/refresh を失うと復旧導線喪失の可能性(ceremony session 不在)                                                                 |
| 3. 削除請求が withdrawal timestamp だけで表現されない | **Fail**       | erasure request 実体なし。terminate! の timestamp のみ                                                                                                               |
| 4. purge 前に legal hold / retention exception 確認   | **Fail**       | `purged_at <= now` のみ                                                                                                                                              |
| 5. occurrence は証跡であり current state でない       | **Pass**       | 読み手なし・append-only。ただし退会イベント自体が occurrence に残らない(別 gap)                                                                                      |

## M. Findings(要約)

1. **[High] com withdrawal gate allowlist 欠落** — suspended
   visitor が com 退会/復旧 UI 不達、app へ誤 redirect。Evidence:
   `authentication_withdrawal_gate.rb:44-48,86-88`。
2. **[High] deactivated 後も access token が TTL まで有効** — gate 未登録/skip
   controller が即座に穴。Evidence: `authentication_base.rb:1720-1725`、dbsc skip。
3. **[High] legal hold なし purge** — ADR と実装の矛盾。Evidence: `retention_purge_job.rb:62` vs ADR
   :69-71。
4. **[High] privacy erasure request 全欠落** — 日米欧対応 state ゼロ。
5. **[High] ceremony session 不在 + 復旧の通常 session 依存** —
   session 喪失時に復旧窓内でも詰む恐れ(机上、未実証)。
6. **[Medium] invariant テスト2本が実質未認証**、app
   step-up 統合テスト削除、RecoverySecretsController orphan、ClientStatus 死定数、stale
   plan/docs(§K)。
7. **[Medium] 退会イベントの durable
   occurrence 記録なし**(flow 行はあるがイベント基盤未接続)、notification token 未失効。
8. **[Low] status ページの back link が通常 settings へ**、旧 Sign
   namespace の form 流用、i18n 旧キー。

## N. Recommended Implementation Slices(依存順・今回は実装しない)

| #   | Slice                                                                                           | Why first                                        | Dependencies | 主な対象ファイル                           | Tests                                      |
| --- | ----------------------------------------------------------------------------------------------- | ------------------------------------------------ | ------------ | ------------------------------------------ | ------------------------------------------ |
| 1   | com gate allowlist + redirect 分岐修正                                                          | 実ユーザー影響のある既知欠陥、小さく独立         | なし         | `authentication_withdrawal_gate.rb`        | com suspended visitor の到達性 integration |
| 2   | 死テスト修正(invariant 2本の Bearer 化)+ app step-up 統合テスト復元                             | 以降の変更の安全網                               | なし         | `test/security/invariants/*`, 削除テスト   | —                                          |
| 3   | 退会時 token 即時失効方針の決定(access token 短命化 or 失効リスト or token_valid_after_at 活用) | Invariant 1 の根本対処                           | 1,2          | resolver / token models                    | 5.5 シナリオの机上→実テスト                |
| 4   | withdrawal ceremony session 設計                                                                | Invariant 2。復旧導線を通常 session から切り離す | 3            | 新 concern + gate + flow                   | session 喪失後復旧テスト                   |
| 5   | legal hold / retention exception ガード(purge 前チェック)                                       | ADR との矛盾解消                                 | なし(並行可) | `retention_purge_job.rb` + 新 model/column | hold 中 purge skip テスト                  |
| 6   | privacy erasure request state machine(別 model、jurisdiction/source/due/denial)                 | H 表の High gap。withdrawal と別系統             | 4,5          | 新 model/route/controller/job              | 状態遷移+復旧不可テスト                    |
| 7   | occurrence への退会系イベント durable 記録                                                      | 証跡基盤。notify のログのみを置換                | なし(並行可) | `withdrawal_lifecycle.rb` + emitter        | durable write テスト                       |
| 8   | processor notification job(Solid Queue)                                                         | 6 の後段                                         | 6            | 新 job                                     | retry/failure テスト                       |
| 9   | stale 掃除(死定数、orphan controller、stale plan/docs、空 view dir)                             | 低リスク衛生                                     | 1-8 と独立   | §K の一覧                                  | —                                          |

## 次に読むべきファイル(優先順)

1. `adr/retention-lifecycle-column-boundary.md` — 語彙 SSOT
2. `adr/sign-withdrawal-and-membership-surface-policy.md` — 状態機械ポリシー(supersession
   banner に注意)
3. `app/models/concerns/withdrawable.rb` / `retainable.rb`
4. `app/services/withdrawal_lifecycle.rb`
5. `app/controllers/concerns/authentication_withdrawal_gate.rb`(欠陥箇所)
6. `app/controllers/concerns/base_settings_withdrawal_flow.rb`
7. `app/controllers/concerns/authentication_base.rb:1573-1633, 1720-1725, 1000-1079`
8. `app/jobs/retention_purge_job.rb` + `config/recurring.yml:53`
9. `test/integration/withdrawal_lifecycle_security_test.rb` / `withdrawal_gate_test.rb`
10. `plans/analysis/audit-and-evidence-plan.md:116`(erasure open question)
