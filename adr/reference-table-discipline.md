# 参照テーブル規約

## 状態

Accepted

## コンテキスト

参照テーブル（lookup
table）はアプリケーション全体で広く使用されていますが、一貫性のない設計が課題となっています。

主な問題点：

1. 参照テーブルの多くは `record_timestamps = false`
   で日付情報を持たないが、NOTHING定数の値が0/1/11とバラバラ
2. 「未指定 = 0」という規約が暗黙的にしか運用されていない
3. join系テーブルには不要な`created_at`/`updated_at`が残存している場合がある

## 決定

以下の規約を採用します：

1. 参照テーブルはPKのみを持つ。`record_timestamps = false` を全モデルに必須化。
2. 全参照モデルは `NOTHING = 0` をsentinelとして持ち、reference dataの最初の行は
   `id = 0`、論理的に「未指定/不明/未設定」を意味する。
3. 参照テーブルへのFKは `default: 0` を持ち、未設定状態をNOTHING行で表現する（NULLable
   FKは使わない）。
4. 参照テーブル間のjoin系テーブル（例:
   `avatar_role_permissions`）も日付カラムを持たない。ライフサイクルは参照データそのものとして扱う。

## 例外

一部の既存モデルでは互換性維持のためNOTHING値を変更しない場合があります。これらのモデルは個別に文書化されます。

- `AppContactStatus`: NOTHING = 1
- `AvatarMembershipStatus`: NOTHING = 1
- `AvatarMonikerStatus`: NOTHING = 1
- `AvatarOwnershipStatus`: NOTHING = 1
- `AvatarPermission`: NOTHING = 1
- `AvatarRole`: NOTHING = 1
- `ComContactCategory`: NOTHING = 1
- `ComContactChronicleEvent`: NOTHING = 1
- `ComContactChronicleLevel`: NOTHING = 1
- `ComContactStatus`: NOTHING = 1
- `ComPreferenceStatus`: NOTHING = 2
- `CustomerEmailStatus`: NOTHING = 5
- `CustomerPasskeyStatus`: NOTHING = 5
- `CustomerSecretStatus`: NOTHING = 6
- `CustomerStatus`: NOTHING = 2
- `CustomerTelephoneStatus`: NOTHING = 5
- `DepartmentStatus`: NOTHING = 1
- `DivisionStatus`: NOTHING = 1
- `HandleAssignmentStatus`: NOTHING = 5
- `HandleStatus`: NOTHING = 5
- `MemberStatus`: NOTHING = 5
- `OperatorStatus`: NOTHING = 2
- `OrgContactCategory`: NOTHING = 1
- `OrgContactChronicleEvent`: NOTHING = 1
- `OrgContactChronicleLevel`: NOTHING = 1
- `OrgContactStatus`: NOTHING = 1
- `OrgPreferenceStatus`: NOTHING = 2
- `OrganizationStatus`: NOTHING = 1
- `PostReviewStatus`: NOTHING = 1
- `PostStatus`: NOTHING = 1
- `StaffChronicleEvent`: NOTHING = 7
- `StaffChronicleLevel`: NOTHING = 1
- `StaffEmailStatus`: NOTHING = 4
- `StaffOccurrenceStatus`: NOTHING = 1
- `StaffSecretKind`: NOTHING = 1
- `StaffStatus`: NOTHING = 2
- `StaffTelephoneStatus`: NOTHING = 4
- `UserChronicleEvent`: NOTHING = 9
- `UserChronicleLevel`: NOTHING = 4
- `UserEmailStatus`: NOTHING = 5
- `UserOneTimePasswordStatus`: NOTHING = 5
- `UserPasskeyStatus`: NOTHING = 5
- `UserSecretStatus`: NOTHING = 6
- `UserSocialAppleStatus`: NOTHING = 6
- `UserSocialGoogleStatus`: NOTHING = 6
- `UserStatus`: NOTHING = 11

## 理由

この規約により、参照テーブルの一貫性が確保され、データの整合性が向上します。また、FKのデフォルト値を統一することで、未設定状態の扱いが明確になります。

## 影響

- 68個の既存参照モデルに`include ReferenceRecord`を追加
- `NOTHING = 0`に統一するために必要なデータ移行
- join系テーブルから日付カラムを削除するマイグレーションの実施
