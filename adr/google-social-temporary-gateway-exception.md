# Google Social Temporary Gateway Exception

Status: ADR note

Date: 2026-06-02

## Context

既存の恒久方針では、`org` は staff/operator 向け surface であり public self-service
signup を提供しない。`com` は production target として Google/Apple social login を提供しない。`app`
は Google/Apple social signup/signin を提供する。

一方で、`org` の Google OAuth 実装を app と同等水準へ寄せるため、QA と com/org 実装検証中だけ Google
social login を temporary gateway として使う必要がある。

## Temporary Exception

QA と実装検証中に限り、以下の一時例外を認める。

- `org Google signup` は QA 用 temporary gateway として許可できる。
- `org Google signin` は将来本番に残す候補として品質を上げる。
- `com Google signup/signin` は今回実装しないが、後続 slice の QA 用 temporary
  gateway 予定として plan に記録できる。

この例外は恒久仕様ではない。`org` public signup と `com` social
login を production 仕様に昇格するものではない。

## Required Controls

- Apple は対象外。
- `app` 既存 Google OAuth を壊さない。
- signup と signin の ENV flag を分離する。
- `org Google signin` の判定は `Sign::Social::OrgGoogleSigninGate` に分離し、
  temporary cleanup 対象にしない。この gate には TEMP tag を付けない。
- `org Google signup` の temporary provisioning gate は最初は allowlist とする。
- `org Google signup` の temporary provisioning は
  `Sign::Social::OrgOperatorProvisioner` に隔離し、controller の signin 経路へ
  `Operator.create!` を残さない。
- `Sign::Social::OrgOperatorProvisioner` には
  `TEMP(org-google-social-gateway): remove before production cleanup` を付ける。
- temporary provisioning の no-migration marker は `OperatorChronicle` の context に
  `source: "org_google_social_temporary_gateway"`、`temporary_gateway: true`、
  `provider: "google_org"` を記録して行う。
- temporary gateway では `OperatorEmail` を作成しない。Google email は allowlist の補助条件であり、
  signin 認証境界にはしない。
- 招待制と operator lifecycle request は将来の恒久設計候補として残す。
- production で `ORG_GOOGLE_SIGNUP_ENABLED=true` を検出した場合は boot fail とする。
- TEMP tag は `TEMP(org-google-social-gateway): remove before production cleanup` に統一する。
- production 推奨値は以下とする。

```text
ORG_GOOGLE_SIGNUP_ENABLED=false
ORG_GOOGLE_SIGNIN_ENABLED=true
COM_GOOGLE_SIGNUP_ENABLED=false
COM_GOOGLE_SIGNIN_ENABLED=false
```

- temporary signup 実装には統一 TEMP tag と retirement test を必須にする。
- `com` は actor/model 境界が確定するまで実装しない。`VisitorGoogleIdentity` 相当の migration
  設計が必要なため、この exception では descope 承認として後続 slice に残す。
- `com` を実装する場合の actor/model 境界は `Visitor` / `VisitorGoogleIdentity` 相当とし、 `Client`
  や app social identity
  model に寄せてはならない。現状 model/table がないため、実装には別途 migration 設計レビューが必要である。
- `OmniAuthCorporateGuard` の穴あけは非 production かつ COM flags true かつ `google_com`
  のみに限定し、production target は `com` no-social のままとする。
- `com` は本番前に Google signup/signin を削除または ENV false 固定に戻す。
- `org` は本番前に Google signup を削除または無効化し、Google signin のみ残す。

## Consequences

- `adr/sign-up-authentication-handoff-and-social-rt.md` と `adr/sign-com-no-social-login.md`
  の production target は維持する。
- temporary gateway の実装方向は `plans/active/org-com-google-social-temporary-gateway-plan.md`
  に集約する。
- この note と新 plan がない状態で `org` public self-service signup や `com` social
  login を実装してはならない。
