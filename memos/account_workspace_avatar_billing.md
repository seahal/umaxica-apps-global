# Account / Workspace / Avatar / Billing（現段階メモ）

このドキュメントは、現時点で整理した「認証主体（Account）」「テナント（Workspace）」「発信主体（Avatar）」「将来のBilling（Stripe）」の関係を、実装に落としやすい形でまとめたメモです。

## 用語（前提）

- `Session`: ブラウザCookie等で維持されるログイン状態（誰がログインしているか）
- `Account`: 認証・認可の主体（人）。このリポジトリでは `User` / `Staff` が該当（`Account`
  concern を include）
- `Workspace`（= 法人クッション）: 組織・契約・資産の受け皿（旧 `Organization`）
- `Membership`: Account が Workspace に所属する関係（ロール/状態/入退社などを表現）
- `Avatar`: 発信主体（Xでいう投稿主/スクリーンネーム）。会社利用では複数人で運用されうる「資産」
- `AvatarGrant`（または `AvatarAccess`）: Membership が Avatar を操作できる権限付与

## なぜ分けるか（解きたい問題）

- 個人利用は単純に見えるが、企業利用では「複数人で1つの Avatar を運用」「退職した人が触れない」「担当交代しても Avatar（資産）が残る」が必須。
- そのため「人（Account）」と「発信主体（Avatar）」は分離し、間を “所属” と “権限” で接続する。

## 最小構成（推奨の関係）

個人利用（S-A-M-A が線でつながる世界の拡張として扱える）

```
Session -> Account -> Membership -> Workspace
                         |
                         v
                    AvatarGrant -> Avatar
```

ポイント:

- `Session` は「ログインしている Account」を指す（例: `current_account`）。
- `Membership` は「Account の “組織内の立場”」を表す（ロール/状態/入退社）。
- `Avatar` は原則 `Workspace` の資産として扱い、`AvatarGrant` で操作権限を配布する。

## いまの実装方針（User の所属を `Membership` で表現する）

現時点ではまず「User がどの Workspace に所属しているか」を明確にするため、`user_organizations`
ではなく `user_memberships` を導入して表現する（Staff は今回は対象外）。

- 追加: `UserMembership`（`app/models/user_membership.rb`）
- 追加: `user_memberships`
  テーブル（`db/identities_migrate/20251218150000_create_user_memberships.rb`）
  - `user_id` + `workspace_id` をユニークにする
  - `joined_at` / `left_at` で在籍・退職（所属の状態）を表現できるようにする
  - 既存の `user_organizations` のデータは `user_memberships`
    に移行する（マイグレーション内で INSERT）

これにより「User が個人事業主なのか／会社に属しているのか」は、`UserMembership`
を見れば “どの Workspace に所属しているか” として判別できるようになる。

## Team（部署階層）が必要になった場合

```
Account -> Membership -> Workspace -> Team
                         |
                         v
                    AvatarGrant -> Avatar (team_id を持つ)
```

- 部署の粒度で Avatar をぶら下げたい場合、`Avatar.team_id` を追加する。
- `AvatarGrant` は引き続き `Membership` から `Avatar` への付与でOK。

## “他者の Avatar になる” 問題（所有と権限の分離）

「場合によっては Avatar が他者のものになる（譲渡/移管）」があり得るため、`Avatar`
の “owner” と “操作権限” を分離する。

推奨:

- `Avatar.owner`（owner は通常 `Workspace`）を持たせる
- `AvatarGrant` は操作権限を配るだけ（owner 以外も操作できる）

譲渡が本当に起きる想定なら、さらに強くする:

- `AvatarOwnership` を作り、`starts_at`/`ends_at` で所有履歴を残す（監査・揉め事対策）

## Billing

Billing foundation and future Stripe integration tracking moved to GitHub issue #577.

### Billing DB セットアップ（ローカル/CI）

```
bin/rails db:create:billing
bin/rails db:migrate:billing
bin/rails db:prepare
```

## 命名メモ

- `Stakeholder` は `Account` にリネーム済み（`User` / `Staff` が include する concern）
- 旧 `Organization` は `Workspace` にリネーム済み（互換のため `Organization` は shim として残る）。
