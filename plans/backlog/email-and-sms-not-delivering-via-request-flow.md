# Email / SMS が Web リクエスト経由で配送されない件の切り分け

作成日: 2026-05-07

## 症状

- AWS SES に切り替えたメール (Email OTP, `UserMailer` 等) が届かない。
- SMS (AWS SNS 経由) も届かない。
- **Rails console から直接呼び出すと正常に動く。**

## 仮説 (本命)

Email も SMS も両方 ActiveJob 経由で送っている。`solid_queue`
ワーカー (`bin/jobs`) が動いていないとキューに積まれるだけで永久に滞留する。エラーはリクエストには返らないので、Web からは "成功したように見える" が何も飛ばない。Rails
console は `deliver_now` や `AwsSmsService.send_message` を直叩きできるため、キューを介さず動く。

### 根拠

- `config/application.rb:63` — `config.active_job.queue_adapter = :solid_queue`
- 全ての送信経路が `deliver_later` / `perform_later`:
  - `app/controllers/concerns/sign/email_registrable.rb:245`
  - `app/controllers/concerns/sign/telephone_registrable.rb:99`
  - `app/controllers/concerns/sign/staff_telephone_registrable.rb:85`
  - `app/services/sign/in/otp_resend_service.rb:122,131`
  - その他 `sign/{app,com,org}/...` 配下の controller 群
- `Procfile.dev` — `web` と並列で `job: bin/jobs start` が必要。`bin/rails server`
  単発起動だとワーカーが上がらない。
- `config/puma.rb:41` —
  `plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]`。本番側で in-Puma 実行か別ジョブコンテナのどちらかが必須。

## 確認手順 (上から順に)

### 1. ワーカープロセスが起動しているか

```bash
ps aux | grep -E "solid_queue|bin/jobs" | grep -v grep
```

何も出なければコレが原因確定。対応:

- 開発: `bin/rails server` 単発を止め、`bin/dev` で起動 (Procfile.dev で `web` `css` `job` `vite`
  をまとめて立てる) するか、別端末で `bin/jobs start` を併走させる。
- 本番: `SOLID_QUEUE_IN_PUMA=1` を Puma に渡すか、Kamal accessory なりで `bin/jobs`
  を独立プロセスとして常駐させる。

### 2. キューに死体が積まれていないか

```ruby
# bin/rails c
SolidQueue::Job.where(finished_at: nil).count
SolidQueue::FailedExecution.last(10).map { [_1.job.class_name, _1.error] }
SolidQueue::ReadyExecution.count
```

- `Job.where(finished_at: nil).count` が増えていく一方ならワーカー停止。
- `FailedExecution` に並ぶエラーが原因の本体:
  - `Net::SMTPAuthenticationError` / `Aws::Errors::MissingCredentialsError`
    → クレデンシャル未注入 (下記 3 へ)。
  - `Aws::SNS::Errors::AuthorizationError` / `OptedOut` →
    SNS の IAM ポリシーまたは送信先番号の opt-out。
  - `Net::OpenTimeout` / `Net::ReadTimeout` → ネットワーク到達性 (VPC / SG / DNS)。
  - `Aws::SNS::Errors::InvalidParameter` の `Invalid parameter: PhoneNumber` →
    E.164 整形漏れ (`+81...` で渡しているか)。

### 3. クレデンシャルがリクエストプロセスに行き渡っているか

Rails console で動くということは、少なくとも console を起こした環境変数 /
credentials は通っている。Web プロセスが別ユーザーや別 systemd unit
/ 別コンテナで起動されている場合、env が違う可能性がある。

```ruby
# bin/rails c (= 動く方)
Rails.app.creds.option(:AWS_SES_SMTP_USERNAME).present?
Rails.app.creds.require(:AWS_ACCESS_KEY_ID).then { _1[0..3] }
```

を確認し、`web` プロセス側でも同じ値が読めているか確認する。production 側は `RAILS_MASTER_KEY`
が web/job 両方の env に渡っているか要確認。

### 4. Email 固有の落とし穴

`config/environments/{development,production}.rb` の SMTP 設定:

```ruby
port: 465,
tls: true,
authentication: :login,
```

Mail gem は `tls: true` (= 暗黙 TLS) と `enable_starttls_auto: true` の併用で壊れる。今は
`enable_starttls_auto` を入れていないので一応 OK。`port: 587 + enable_starttls_auto: true`
に切り替える場合は `tls: true` を必ず外す (ADR `email-provider-resend-to-amazon-ses.md` 記載)。

また、SES が **sandbox モード** から出ていない場合、verified address 以外への送信は
`MessageRejected: Email address is not verified` で 4xx になり、 `FailedExecution`
に出る。production 移行前に sandbox 解除を必ず確認。

### 5. SMS 固有の落とし穴

`app/services/aws_sms_service.rb` は `Rails.app.creds.require(:AWS_ACCESS_KEY_ID)`
を使うため、無いと **初期化時に例外** になる。これは `discard_on ArgumentError`
には引っかからないので、`FailedExecution`
にそのまま記録されるはず。`Aws::Errors::MissingCredentialsError`
が出ていたら IAM ユーザー or インスタンスロールのいずれかを供給する必要がある。

SNS は region と sender ID の設定 (日本宛なら sender
ID 必須ではないが、米国宛などはオリジネーティングナンバー要登録) の罠も別にある。

## 期待される結末

ほぼ確実に「ワーカー未起動 or env 未注入」のどちらか。ワーカーを上げてからキューに溜まった
`FailedExecution` を見れば、本物のクレデンシャル問題かネットワーク問題か即判明する。

## 関連

- `adr/email-provider-resend-to-amazon-ses.md` — SES への切り戻し決定。
- `app/jobs/sms_delivery_job.rb` — SMS の retry/discard ポリシー。
- `app/services/aws_sms_service.rb` — SNS 経由の送信実装。
