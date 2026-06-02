# Org/Com Google Social Temporary Gateway Plan

Status: active planning

Date: 2026-06-02

## Summary

この plan は、`org` と `com` の Google social
gateway を QA と実装検証のために一時的に許可する例外計画である。恒久仕様ではない。

`org` は当面 app の Google OAuth 実装水準へ寄せる。ただし `org`
は staff/operator 向け surface であり、public signup は本番仕様にしない。`org` Google
signup は QA 用 temporary gateway、`org` Google signin は将来本番に残す候補として扱う。

`com` Google signup/signin は今回実装しない。`com`
actor/model 境界が確定してから別 slice で検証し、本番前に削除または ENV false 固定に戻す。

Apple は対象外。既存 `app` Google OAuth は壊さない。

## Source Material

- `adr/google-social-temporary-gateway-exception.md`
- `adr/sign-up-authentication-handoff-and-social-rt.md`
- `adr/sign-com-no-social-login.md`
- `docs/security/social-login-provider-scope.md`
- `docs/security/sign-up-sequence.md`
- `plans/active/sign-up-state-machine-implementation-plan.md`

## Feature Flags

Production 推奨値:

```text
ORG_GOOGLE_SIGNUP_ENABLED=false
ORG_GOOGLE_SIGNIN_ENABLED=true
COM_GOOGLE_SIGNUP_ENABLED=false
COM_GOOGLE_SIGNIN_ENABLED=false
```

Development/QA 中の値:

```text
ORG_GOOGLE_SIGNUP_ENABLED=true
ORG_GOOGLE_SIGNIN_ENABLED=true
COM_GOOGLE_SIGNUP_ENABLED=false
COM_GOOGLE_SIGNIN_ENABLED=false
```

`docker/core/env` には今回 `ORG_GOOGLE_SIGNUP_ENABLED=true` と `ORG_GOOGLE_SIGNIN_ENABLED=true`
だけを追記する。`COM_GOOGLE_SIGNUP_ENABLED` と `COM_GOOGLE_SIGNIN_ENABLED` は、`com`
actor/model 境界が未決のため今回追記しない。

Production で `ORG_GOOGLE_SIGNUP_ENABLED=true` を検出した場合は boot fail とする。runtime
deny ではなく fail fast で誤設定を止める。

## Boundaries

- `org` Google signup は TEMP tag を付けた temporary gateway として実装する。
- `org Google signup` の provisioning gate は最初は allowlist とする。
- `org Google signup` の provisioning は `Sign::Social::OrgOperatorProvisioner`
  に隔離する。`OperatorEmail` は temporary gateway では作成しない。
- no-migration marker は `OperatorChronicle` の context に
  `source: "org_google_social_temporary_gateway"`、`temporary_gateway: true`、`provider: "google_org"`
  を記録して行う。専用 column/status は追加しない。
- 招待制と operator lifecycle request は将来の恒久設計候補として残すが、temporary
  gateway では最初から重くしない。
- `org` Google signin は本番に残せる品質を目標にする。signin gate は
  `Sign::Social::OrgGoogleSigninGate` に分離し、temporary cleanup 対象にしない。
- `com` Google signup/signin は今回実装しない。予定だけを記録する。
- `com` no-social は production target として維持する。
- Apple は対象外。
- `app` の既存 Google OAuth、signup、signin、link/unlink の挙動を変更しない。
- route/controller/model/service/test 実装は後続 slice で行う。

## Required Retirement Controls

後日削除しやすいよう、temporary gateway 実装では以下を必須にする。

- TEMP tag: temporary signup route、controller branch、view affordance、test 名には
  `TEMP(org-google-social-gateway): remove before production cleanup` を置く。
- Feature flag: signup と signin を分離し、signup は production default false にする。
- Gate lifetime: `ORG_GOOGLE_SIGNIN_ENABLED` は temporary signup gate ではなく
  `OrgGoogleSigninGate` で判定する。`TemporarySignupGate` と `OrgOperatorProvisioner`
  を削除しても linked active `Operator` の Google signin が残る構造にする。
- Retirement test: flag false 時に UI が出ない、route/callback が provisioning しない、 `com`
  は本番前に全削除または false 固定できることを固定する。
- Cleanup checklist: `com` は本番前 cleanup で全削除または ENV false 固定、`org`
  は signin のみ残す。

## Implementation Slices

### Slice 0: docs/ADR/plans 整流のみ

- この plan を追加する。
- 衝突する backlog plan に Deprecated notice を追記する。
- accepted ADR には恒久方針を残したまま temporary exception を追記する。
- docs に暫定運用方針を追加する。
- `docker/core/env` に `ORG_GOOGLE_SIGNUP_ENABLED=true` と `ORG_GOOGLE_SIGNIN_ENABLED=true`
  だけを追記する。
- 実装コード、route、controller、model、service、test は変更しない。

### Slice 1: temporary signup gate 設計

- `org Google signup` が Operator を作成してよい条件は allowlist とする。
- 招待制と operator lifecycle request は将来の恒久設計候補として記録するが、temporary
  gateway の初期 gate にはしない。
- Google email は login authentication boundary にしない。QA provisioning
  gate の補助条件として使う場合も provider UID を主キーにする。

### Slice 2: org Google signin の本番品質化

- `ORG_GOOGLE_SIGNIN_ENABLED` で signin UI、continue、callback を制御する。
- `ORG_GOOGLE_SIGNIN_ENABLED` の判定は `Sign::Social::OrgGoogleSigninGate`
  に閉じ、TEMP tag を付けない。
- provider+uid で `OperatorGoogleIdentity` を解決する。
- unknown UID は signin 失敗として扱い、Operator を作成しない。
- session、Actor、token、audit、policy が `Operator` 系だけに閉じることをテストする。

### Slice 3: org Google signup temporary gateway

- `ORG_GOOGLE_SIGNUP_ENABLED` が true かつ Slice 1 の gate を満たす場合だけ temporary
  provisioning を許可する。
- 作成する場合も `Operator`、`OperatorGoogleIdentity`、`OperatorChronicle` に閉じる。
- `Operator` / `OperatorGoogleIdentity` の作成は `Sign::Social::OrgOperatorProvisioner`
  のみが担当する。
- `OperatorEmail` は temporary gateway では作成しない。Google email は allowlist
  補助条件だけに使い、signin 認証境界にはしない。
- provisioning marker は no-migration で `OperatorChronicle` context に記録し、login audit
  と区別できるようにする。
- 作成後の session issuance は既存 org signin sequence を通す。

### Slice 4: retirement tests

- `ORG_GOOGLE_SIGNUP_ENABLED=false` で signup UI が出ないことを固定する。
- `ORG_GOOGLE_SIGNUP_ENABLED=false` で signup direct
  request が state/provisioning に進まないことを固定する。
- signup callback state が残っていても flag off なら unknown
  UID が provisioning しないことを固定する。
- `ORG_GOOGLE_SIGNIN_ENABLED=true` なら linked active `Operator`
  の signin は引き続き成功することを固定する。
- production 相当では `ORG_GOOGLE_SIGNUP_ENABLED=true` が boot fail になることを固定する。
- `TEMP(org-google-social-gateway): remove before production cleanup`
  が残っている箇所を grep できるようにする。
- `org` signin は残しても signup を消せることをテストで固定する。

### Slice 5: com temporary gateway

- `com` actor/model 境界は `Visitor` に閉じる。`Client`、`Operator`、app/org social identity
  model は使わない。
- 現状 `com` には Google social identity model がないため、実装する場合は
  `VisitorGoogleIdentity < ComPrincipalRecord` 相当の migration が必要になる。
- この migration 設計が未承認のため、`com` temporary gateway はこの plan では後続 slice
  として descope 承認する。
- `VisitorSignUpFlow` は現在 `social_provider` absence を検証しているため、temporary
  gateway 実装時に social signup ticket へ雑に流用してはいけない。
- `COM_GOOGLE_SIGNUP_ENABLED` / `COM_GOOGLE_SIGNIN_ENABLED` は docs 上の予定として残すが、
  `docker/core/env` には actor/model migration 設計が承認されるまで追加しない。
- `OmniAuthCorporateGuard` は production
  target の no-social を維持する。穴あけする場合は非 production かつ COM flags true かつ
  `google_com` のみに限定し、`google_app`、 `google_org`、`apple` は開けない。
- production で COM flags true を検出した場合は boot fail とする。
- 実装する場合も QA 用 temporary
  gateway とし、`TEMP(com-google-social-gateway): remove before production cleanup` と retirement
  tests を必須にする。

### Slice 6: 本番前 cleanup

- `com` Google signup/signin は全削除または ENV false 固定に戻す。
- `org` は Google signin のみ残す。
- `org` temporary signup route/controller/view/test/TEMP tag を削除する。
- docs/ADR/plans を production target に合わせて更新する。

#### Cleanup Checklist

- `rg -n "TEMP\\(org-google-social-gateway\\): remove before production cleanup" app config test plans docs adr`
  を実行し、該当箇所を削除または production target に更新する。
- `rg -n "TEMP\\(com-google-social-gateway\\): remove before production cleanup" app config test plans docs adr`
  を実行し、`com` temporary gateway が残っていないことを確認する。
- `ORG_GOOGLE_SIGNUP_ENABLED` は production で false 固定にし、signup
  route/view/callback/provisioning を削除する。`ORG_GOOGLE_SIGNIN_ENABLED=true` と linked active
  `Operator` signin は残す。
- `COM_GOOGLE_SIGNUP_ENABLED` と `COM_GOOGLE_SIGNIN_ENABLED` は削除または false 固定にする。
  `OmniAuthCorporateGuard` は `com` no-social の 404 境界に戻す。
- retirement tests を本番前 gate として必須にする。最低限、signup UI 非表示、direct
  request 拒否、callback provisioning 不可、production boot fail、org signin 継続を確認する。

#### Cleanup Deletion Targets

- `config/routes/sign.rb` の `signup_sign_org_social_authentication` member route。
- `Sign::Org::Social::AuthenticationsController#signup` と signup flag helper/redirect branch。
- `Sign::Social::OrgOperatorProvisioner` と signup callback の provisioner 呼び出し。
- `Sign::Social::TemporarySignupGate`。ただし `Sign::Social::OrgGoogleSigninGate`
  は削除しない。
- `app/views/sign/org/sign_ups/new.html.erb` の Google temporary signup button。
- org temporary signup integration/controller tests。ただし org Google signin tests は残す。
- `ORG_GOOGLE_SIGNUP_ALLOWLIST` と temporary signup 用 ENV 記述。
- com temporary gateway を実装した場合は、`google_com` strategy、CorporateGuard 穴あけ、
  `VisitorGoogleIdentity` temporary code、COM flags、関連 tests。

#### Rollback

- cleanup 後に QA-only gateway を戻す場合は、production ではなく development/QA
  branch でのみ revert する。production では `ORG_GOOGLE_SIGNUP_ENABLED=true` と COM flags
  true を許可しない。
- rollback しても app Google/Apple と org Google signin の provider+uid 境界を変更しない。

## Open Decisions Before Implementation

- `com` temporary gateway の actor/model 境界。

## Decisions Before Implementation

- `org Google signup` の provisioning gate は最初は allowlist とする。
- 招待制と operator lifecycle request は将来の恒久設計候補として残す。
- production で `ORG_GOOGLE_SIGNUP_ENABLED=true` を検出した場合は boot fail とする。
- TEMP tag は `TEMP(org-google-social-gateway): remove before production cleanup` に統一する。
