# Retainable Concern と Retention Purge の設計

## 状態

Accepted

## コンテキスト

アプリケーションには多くのモデルでretention（保持期間）管理が必要ですが、現在は以下のような問題があります：

1. 物理削除時刻を表すカラムが `deletable_at`、`shreddable_at`、`scheduled_purge_at`
   など複数存在し、統一されていない
2. 論理削除時刻を表すカラムも `revoked_at`、`expires_at`、`refresh_expires_at`、`compromised_at`
   など複数存在
3. 各モデルで異なる方法でこれらのカラムを管理しており、一貫性がない

## 決定

### カラムの統一

1. **`lapses_at`** - 論理削除時刻（アクセス不可となる時刻）
2. **`purge_at`** - 物理削除候補時刻（実際にデータを削除できる時刻）

### Retainable Concern の導入

すべてのモデルで共通の `Retainable` concern を使用して、上記2つのカラムを一元管理します。

```ruby
module Retainable
  extend ActiveSupport::Concern

  SENTINEL = ::Float::INFINITY

  included do
    attribute :lapses_at, :datetime, default: -> { SENTINEL }
    attribute :purge_at, :datetime, default: -> { SENTINEL }

    validates :lapses_at, presence: true
    validates :purge_at, presence: true
    validate :lapses_at_not_after_purge_at
    validate :retention_times_not_before_created_at, on: :update
  end

  def accessible?
    lapses_at > Time.current
  end

  def lapsed?
    lapses_at <= Time.current
  end

  def purgeable?
    purge_at <= Time.current
  end

  def schedule_retention!(lapses_at:, purge_at:)
    raise ArgumentError, 'lapses_at must be in the future' if lapses_at <= Time.current
    raise ArgumentError, 'purge_at must be in the future' if purge_at <= Time.current
    raise ArgumentError, 'lapses_at must be <= purge_at' if lapses_at > purge_at
    update!(lapses_at: lapses_at, purge_at: purge_at)
  end
end
```

### カラムの統合マップ

#### `lapses_at` に統合するカラム

- `revoked_at`
- `expires_at` (credential variant)
- `refresh_expires_at`
- `compromised_at`

#### `purge_at` に統合するカラム

- `deletable_at`
- `shreddable_at`
- `scheduled_purge_at`
- `expires_at` (audit/chronicle variant)

#### 削除するカラム

- `expired_at` (user_token, customer_token)

#### 据え置きするカラム（sub-state column）

- `token_expires_at`
- `verifier_expires_at` / `otp_expires_at`
- `expires_at` (token のみ: user/staff/customer_token)
- `consumed_at`
- `used_at`

### Solid Queue retention job

RetentionPurgeJob を作成し、`purge_at` 経過したレコードを定期的に削除します。

```ruby
class RetentionPurgeJob < ApplicationJob
  queue_as :retention

  RETAINABLE_MODELS = [
    User, Customer, Staff, AppPreference, OrgPreference, ComPreference,
    UserToken, StaffToken, CustomerToken,
    UserVerification, StaffVerification, CustomerVerification,
    UserAuthorizationCode, StaffAuthorizationCode, CustomerAuthorizationCode,
    UserReauthSession, StaffReauthSession, CustomerReauthSession,
    AreaOccurrence, UserOccurrence, StaffOccurrence, ZipOccurrence,
    DomainOccurrence, IpOccurrence, EmailOccurrence, JwtOccurrence, TelephoneOccurrence,
    AppJumpLink, ComJumpLink, OrgJumpLink
  ].freeze

  def perform(batch_size: 500)
    now = Time.current
    RETAINABLE_MODELS.each do |klass|
      klass.where('purge_at <= ?', now).in_batches(of: batch_size).delete_all
    end
  end
end
```

## 理由

1. カラムを統一することで、retention管理の複雑さを大幅に削減
2. `Retainable` concernにより、すべてのモデルで一貫したインターフェースを提供
3. Solid Queue jobにより、物理削除処理を効率的に実行
4. `Float::INFINITY` をsentinel値として使用することで、NULLチェックを不要にし、クエリの簡素化を実現

## 影響

- 24以上のモデルでカラム名の変更とデータ移行が必要
- 既存のcontrollerやserviceでの参照箇所を新しいカラム名に変更
- テストコードも新しいカラム名に対応させる必要がある
- migration戦略として、既存カラムの値を新しいカラムにコピーした後、既存カラムを削除する
