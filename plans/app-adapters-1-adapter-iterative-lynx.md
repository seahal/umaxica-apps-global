# OTP 配信 Adapter パターン導入計画

## Context

`sign_otp_ceremony.rb` と `sign_in_otp_resender.rb` に `case [surface, channel]`
によるチャネル分岐が直書きされている。新チャネル追加や変更のたびに複数箇所を触る必要があり、Adapter パターンで一元管理したい。

`app/adapters/` ディレクトリは作成済みで空。

---

## 現状の配信分岐

### sign_otp_ceremony.rb（issue フェーズ）

```ruby
when [:app, :email]
  Email::App::OtpMailer.with(encrypted_hotp_token, email_address).create.deliver_later
when [:com, :email]
  Email::Com::OtpMailer.with(encrypted_hotp_token, email_address).create.deliver_later
when [:app, :telephone], [:com, :telephone]
  SignTelephoneOtpDelivery.deliver!(record, otp_code)
```

### sign_in_otp_resender.rb

```ruby
# email
Email::App::OtpMailer.with(...).create.deliver_later
# telephone
SignTelephoneOtpDelivery.deliver!(target, otp_code)
```

---

## 作成ファイル（app/adapters/）

### 1. `app/adapters/otp_delivery_adapter.rb` — 基底 + Factory

```ruby
class OtpDeliveryAdapter
  def self.for(surface:, channel:)
    case [surface.to_sym, channel.to_sym]
    when [:app, :email]                    then OtpEmailDeliveryAdapter.new(Email::App::OtpMailer)
    when [:com, :email]                    then OtpEmailDeliveryAdapter.new(Email::Com::OtpMailer)
    when [:org, :email]                    then OtpEmailDeliveryAdapter.new(Email::Org::OtpMailer)
    when [:app, :telephone],
         [:com, :telephone]                then OtpTelephoneDeliveryAdapter.new
    else
      raise ArgumentError, "Unknown OTP channel: #{surface}/#{channel}"
    end
  end

  # Subclasses implement this. Callers pass all keyword args;
  # each adapter uses only what it needs.
  def deliver(encrypted_hotp_token: nil, email_address: nil, record: nil, otp_code: nil)
    raise NotImplementedError, "#{self.class}#deliver is not implemented"
  end
end
```

### 2. `app/adapters/otp_email_delivery_adapter.rb`

```ruby
class OtpEmailDeliveryAdapter < OtpDeliveryAdapter
  def initialize(mailer)
    @mailer = mailer
  end

  def deliver(encrypted_hotp_token:, email_address:, **)
    @mailer.with(encrypted_hotp_token, email_address).create.deliver_later
  end
end
```

### 3. `app/adapters/otp_telephone_delivery_adapter.rb`

```ruby
class OtpTelephoneDeliveryAdapter < OtpDeliveryAdapter
  def deliver(record:, otp_code:, **)
    SignTelephoneOtpDelivery.deliver!(record, otp_code)
  end
end
```

---

## 変更ファイル

### `app/services/sign_otp_ceremony.rb`

issue フェーズの `case [surface, channel]` ブロックを以下に置き換える：

```ruby
OtpDeliveryAdapter
  .for(surface: surface, channel: channel)
  .deliver(
    encrypted_hotp_token: encrypted_hotp_token,
    email_address:        email_address,
    record:               record,
    otp_code:             otp_code,
  )
```

### `app/services/sign_in_otp_resender.rb`

同様に telephone/email 分岐を `OtpDeliveryAdapter.for(surface:, channel:).deliver(...)`
に置き換える。surface は resender が保持するコンテキスト（`:app` 固定か変数か）を確認して合わせる。

---

## テスト（test/adapters/）

- `otp_delivery_adapter_test.rb`
  - `for` が surface/channel 組み合わせごとに正しいサブクラスを返す
  - 未知の組み合わせで `ArgumentError`
- `otp_email_delivery_adapter_test.rb`
  - `deliver` が指定マルエーラーの `with(...).create.deliver_later` を呼ぶ（mailer モック）
- `otp_telephone_delivery_adapter_test.rb`
  - `deliver` が `SignTelephoneOtpDelivery.deliver!` を呼ぶ

既存テストへの影響確認：

- `test/services/sign_otp_ceremony_test.rb`
- `test/services/sign_in_otp_resender_test.rb`

---

## 検証手順

```bash
bin/rails test test/adapters/
bin/rails test test/services/sign_otp_ceremony_test.rb
bin/rails test test/services/sign_in_otp_resender_test.rb
```

---

## 注意事項

- `sign_in_otp_resender.rb` の surface が `:app` 固定かどうか実装前に確認する。
- `**`
  で余分なキーワード引数を無視する設計のため、呼び出し側は surface/channel を問わず全引数を渡してよい。
- `Email::Org::OtpMailer` は現在 sign_up/sign_in フローで未使用だが、org
  surface への拡張に備えて factory に含める。
