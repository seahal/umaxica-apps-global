# Social Login Provider Scope

Social login availability is surface-specific. 本番 target と QA temporary gateway は分けて扱う。

## Production Target

| Surface | Google   | Apple    |
| ------- | -------- | -------- |
| `app`   | Allowed  | Allowed  |
| `org`   | Allowed  | Rejected |
| `com`   | Rejected | Rejected |

## Rules

- `app` may offer Google and Apple social login for end users.
- `org` may offer Google social login for staff, but must reject Apple social login.
- `com` must not offer or accept any social login provider.
- Direct OmniAuth requests must follow the same surface rules as the UI.
- On `app`, an unknown Google or Apple identity is a sign-up entry, not a completed login. It must
  go through the sign-up sequence and required checkpoint setup before it can enter the login
  sequence.
- On `app`, a registered Google or Apple identity enters the login sequence. It must not be treated
  as a new sign-up unless required sign-up setup is still incomplete.
- On `app`, linking Google or Apple from account configuration requires recent token-bound Step-Up
  scope `social_link`. This is separate from `social_unlink`, so a Step-Up completed for one social
  credential operation does not authorize the other.
- `org` Google social login is bound through the provider UID stored on `OperatorGoogleIdentity`.
  Google email-address matching is not an authentication boundary and must not authorize login.

These rules apply to routes, controllers, views, tests, and provider configuration. Do not add Apple
to `org`, or any social login provider to `com`, without a new accepted ADR.

## QA Temporary Gateway

2026-06-02 の一時例外として、Google social gateway を QA と実装検証のためだけに扱う。詳細は
`adr/google-social-temporary-gateway-exception.md` と
`plans/active/org-com-google-social-temporary-gateway-plan.md` を参照する。

| Surface | Google signup                                  | Google signin                                  | Apple             |
| ------- | ---------------------------------------------- | ---------------------------------------------- | ----------------- |
| `app`   | Existing                                       | Existing                                       | Existing app only |
| `org`   | Temporary QA gateway                           | Production candidate                           | Rejected          |
| `com`   | Planned only; not implemented in current slice | Planned only; not implemented in current slice | Rejected          |

Temporary gateway rules:

- `org Google signup` は QA 用の temporary gateway であり、恒久的な public operator
  signup ではない。
- `org Google signin` の flag 判定は `Sign::Social::OrgGoogleSigninGate` が担う。この gate は
  temporary cleanup 対象ではなく、TEMP tag を付けない。
- `org Google signup` の provisioning は `Sign::Social::OrgOperatorProvisioner` に隔離する。
  この service は temporary cleanup 対象であり、controller の signin 経路に `Operator.create!`
  を残さない。
- temporary provisioning marker は migration なしで `OperatorChronicle` context に
  `source: "org_google_social_temporary_gateway"`、`temporary_gateway: true`、`provider: "google_org"`
  を記録して行う。
- temporary gateway では `OperatorEmail` を作成しない。Google email は allowlist の補助条件だけに使い、
  provider + uid を `OperatorGoogleIdentity` の認証境界として維持する。
- `org Google signup` の provisioning gate は最初は allowlist とする。招待制と operator lifecycle
  request は将来の恒久設計候補として残す。
- `org Google signin` は本番に残す候補として扱う。
- `com Google signup/signin` は今回実装しない。`com`
  actor/model 境界が確定してから別 slice で検証し、本番前に削除または ENV false 固定に戻す。
  `VisitorGoogleIdentity` 相当の migration 設計が必要なため、現 slice では descope 承認として扱う。
- `com` を実装する場合は `Visitor` 境界に閉じ、`VisitorGoogleIdentity` 相当の `ComPrincipalRecord`
  model/table を使う。`Client`、`ClientGoogleIdentity`、app policy、 `current_user` を `com`
  経路に持ち込まない。
- `OmniAuthCorporateGuard` を一時的に穴あけする場合は、非 production かつ
  `COM_GOOGLE_SIGNUP_ENABLED` または `COM_GOOGLE_SIGNIN_ENABLED` が true で、対象 provider が
  `google_com` の場合だけに限定する。`google_app`、`google_org`、`apple` は引き続き corporate
  host で拒否する。
- Apple は今回の temporary gateway の対象外。
- `app` の既存 Google OAuth は変更しない。
- signup と signin は別 ENV flag で制御する。
- production 推奨値は `ORG_GOOGLE_SIGNUP_ENABLED=false`、
  `ORG_GOOGLE_SIGNIN_ENABLED=true`、`COM_GOOGLE_SIGNUP_ENABLED=false`、
  `COM_GOOGLE_SIGNIN_ENABLED=false`。
- production で `ORG_GOOGLE_SIGNUP_ENABLED=true` を検出した場合は boot fail とする。
- temporary signup 実装には
  `TEMP(org-google-social-gateway): remove before production cleanup`、feature flag、retirement
  test を必須にする。
