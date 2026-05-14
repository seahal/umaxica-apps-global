# Service Layer 設計ドキュメント

最終更新: 2025-11-12

## 概要

このドキュメントは、マルチデータベース環境における UserService と StaffService の Service Class
Layer の導入設計について記録します。

## 設計の根拠

### 1. データとロジックの分離の必要性

現在のアプリケーションは複雑なマルチデータベース構成を持っており、以下の理由から Service
Layer の導入が推奨されます：

#### Identity vs. Personality の分離

- **Identity データ（認証情報）**: グローバルに一意。ログイン認証情報、MFA設定など
- **Personality データ（プロフィール）**: 地域固有。ユーザー設定、ロケール、地域特有の情報など
- この分離により、スケーラビリティとデータのローカリティが向上

#### User vs. Staff の分離

- **セキュリティ要件の違い**: Staff と User は異なる認証システム（SSO vs OAuth など）
- **アクセスパターンの違い**: 明確なセキュリティ境界と負荷分離が必要
- **運用上の理由**: 別々のサービス境界で管理することで、セキュリティ強化と負荷分離を実現

### 2. Service Layer の役割

マルチモデル・マルチデータベース環境において、Service Layer は以下の責務を持ちます：

#### 集約（Aggregation）

- サービスは **Aggregate Root** として機能
- 複数の分離されたモデル（*Identity と *Personality）を組み合わせて、完全な User または Staff を表現
- ビジネスロジックの一元化

#### トランザクション管理

- 異なるデータベース間での分散トランザクションの管理
  - Identity データベース: グローバル DB
  - Personality データベース: リージョナル DB
- データ整合性の保証

#### デザインパターンの実装場所

- **CQRS（Command Query Responsibility Segregation）**: コマンドとクエリの責任分離
- **Saga Pattern**: 分離されたデータストア間でのデータ整合性管理

## 現在のアーキテクチャ分析

### データベース構成

アプリケーションは10以上の PostgreSQL データベースを使用：

```
universal      - ユニバーサル識別子とユーザーデータ
identity       - 認証と ID 管理
guest          - ゲスト連絡先情報
profile        - ユーザープロフィールと設定
token          - セッションと認証トークン
business       - ビジネスロジックとエンティティ
message        - メッセージングシステム
notification   - 通知管理
cache          - アプリケーションキャッシュ
speciality     - ドメイン固有機能
storage        - ファイルストレージメタデータ
```

各データベースは Primary/Replica ペアを持ち、別々のマイグレーションパス（`db/{database_name}_migrate/`）を持っています。

### 現在のモデル構造

#### Base クラス

1. **IdentitiesRecord** (Identity データベース)

   ```ruby
   class IdentitiesRecord < ApplicationRecord
     self.abstract_class = true
     connects_to database: { writing: :identity, reading: :identity_replica }
   end
   ```

2. **OccurrenceRecord** (Occurrence データベース)

   ```ruby
   class OccurrenceRecord < ApplicationRecord
     self.abstract_class = true
     connects_to database: { writing: :occurrence, reading: :occurrence_replica }
   end
   ```

3. **ProfilesRecord** (Profile データベース)
   ```ruby
   class ProfilesRecord < ApplicationRecord
     self.abstract_class = true
     connects_to database: { writing: :profile, reading: :profile_replica }
   end
   ```

#### Identity モデル（既存）

##### User モデル

```ruby
# Identity データベース
class User < IdentitiesRecord
  # 認証情報
  has_secure_password algorithm: :argon2

  # 認証手段
  has_many :user_emails
  has_many :user_telephones
  has_one :user_apple_auth
  has_one :user_google_auth
  has_many :user_sessions
  has_many :user_time_based_one_time_password
  has_many :user_webauthn_credentials
end
```

テーブル: `users`

- id (uuid)
- password_digest
- webauthn_id
- created_at, updated_at

##### Staff モデル

```ruby
# Identity データベース
class Staff < IdentitiesRecord
  has_secure_password algorithm: :argon2
  has_many :staff_emails
end
```

テーブル: `staffs`

- id (uuid)
- password_digest
- webauthn_id
- created_at, updated_at

##### Universal Identity モデル

```ruby
# Universal データベース - OTP 用
class UniversalUserIdentity < OccurrenceRecord
  self.table_name = "universal_user_identifiers"
end

class UniversalStaffIdentity < OccurrenceRecord
  self.table_name = "universal_staff_identifiers"
end
```

テーブル構造:

- id (uuid)
- otp_private_key
- last_otp_at
- created_at, updated_at

#### Identity データベースの関連モデル

認証関連:

- UserEmail, OperatorEmail
- UserTelephone, OperatorTelephone
- UserIdentitySocialApple, UserIdentitySocialGoogle
- UserWebauthnCredential, StaffWebauthnCredential
- UserTimeBasedOneTimePassword, StaffTimeBasedOneTimePassword
- UserHmacBasedOneTimePassword, StaffHmacBasedOneTimePassword
- UserRecoveryCode, StaffRecoveryCode

#### Profile モデル

Profile / Personality モデルの実装トラッキングは GitHub issue #575 へ移動しました。

### ドメイン構造

#### Web インターフェース（WWW）

- `WWW_CORPORATE_URL` (com): 法人/クライアントサイト
- `WWW_SERVICE_URL` (app): メインサービスアプリケーション
- `WWW_STAFF_URL` (org): スタッフ管理インターフェース

#### API エンドポイント

- `API_CORPORATE_URL`, `API_SERVICE_URL`, `API_STAFF_URL`

#### コントローラー構成

```
app/controllers/www/{com,app,org}/  - 各ドメインの Web コントローラー
app/controllers/api/{com,app,org}/  - 各ドメインの API コントローラー
app/controllers/concerns/           - 共有コントローラーロジック
```

### Service Layer の実装パターン

#### 基本構造案

```ruby
# app/services/user_service.rb
class UserService
  # Identity + Personality の集約
  # トランザクション管理
  # ビジネスロジック

  def create_user(identity_params, personality_params)
    # 分散トランザクション管理
  end

  def find_complete_user(id)
    # Identity + Personality を結合して返す
  end

  def update_identity(id, params)
    # Identity のみ更新
  end

  def update_personality(id, params)
    # Personality のみ更新
  end
end

# app/services/staff_service.rb
class StaffService
  # Staff 用の同様の実装
end
```

#### トランザクション戦略

複数のデータベースにまたがるトランザクションの扱いについて、要件を明確化する必要があります：

1. **強整合性（ACID）が必要か？**
   - Identity と Personality の両方が成功するか、両方が失敗するか
   - 実装は複雑になるが、データ整合性は最も高い

2. **結果整合性で許容できるか？**
   - Identity を先に作成し、Personality は非同期で作成
   - 実装は簡単だが、一時的に不整合な状態が発生する可能性
   - 必要ならバックグラウンドジョブを使用

3. **Saga Pattern の導入**
   - 複数ステップのトランザクションを管理
   - 各ステップの補償トランザクション（ロールバック処理）を定義
   - 複雑だが、柔軟性が高い

### CQRS の適用

Command（書き込み）と Query（読み込み）を分離：

```ruby
# Command 側
class UserCommandService
  def create_user(params)
  def update_identity(id, params)
  def update_personality(id, params)
  def delete_user(id)
end

# Query 側
class UserQueryService
  def find_by_id(id)
  def find_by_email(email)
  def list_users(filters)
end
```

## 次のステップ（未解決の質問）

### 1. Personality に移行したいデータの明確化

- 具体的にどのようなデータ/属性を Personality として扱うか？
- 現在のデータの保存場所は？
- 新規実装なのか、既存データの移行なのか？

### 2. トランザクション要件の定義

- どの程度の整合性が必要か？
- パフォーマンス要件は？
- 障害時の挙動（リトライ、ロールバック）はどうあるべきか？

### 3. 実装の優先順位

- UserService と StaffService、どちらから実装するか？
- 段階的な移行計画は？
- 既存機能への影響範囲は？

### 4. 認証フローの理解

- 現在の User/Staff 認証フローの詳細確認
- Service Layer との統合ポイントの特定
- セッション管理との連携

### 5. テスト戦略

- マルチデータベース環境でのテスト方法
- トランザクション管理のテスト
- 統合テストのスコープ

## 参考情報

### 現在の技術スタック

- **認証**: WebAuthn, TOTP, Apple/Google OAuth, recovery codes
- **認可**: Pundit + Rolify
- **バックグラウンドジョブ**: 未定
- **パスワードハッシュ**: argon2
- **セキュリティ**: Rack::Attack (レート制限)

### 関連ファイル

- モデル: `app/models/user.rb`, `app/models/staff.rb`
- Base クラス: `app/models/identities_record.rb`, `app/models/occurrence_record.rb`,
  `app/models/profiles_record.rb`
- データベース設定: `config/database.yml`
- マイグレーション: `db/identity_migrate/`, `db/occurrences_migrate/`, `db/profile_migrate/`

## まとめ

Service Class Layer の導入は、以下の理由から強く推奨されます：

1. **明確な責任分離**: Identity（認証）と Personality（プロフィール）の分離
2. **スケーラビリティ**: グローバル DB とリージョナル DB の最適な使用
3. **保守性**: ビジネスロジックの一元化と再利用性の向上
4. **テスタビリティ**: モデル層とビジネスロジック層の分離によるテストの容易化
5. **セキュリティ**: User と Staff の明確な境界による安全性の向上

このアーキテクチャは、大規模・国際的なシステムに適した成熟した設計であり、セキュリティ、異なるビジネスドメイン、高いスケーラビリティを優先するアプリケーションに最適です。

---

## 変更履歴

- 2025-11-12: 初版作成、現在のアーキテクチャ分析と設計方針の記録
