# SMS OTP が Solid Queue に平文で乗っている件

**ステータス: バグ報告 (BUG REPORT) — 検討中。実装はまだ着手しない。**

## 要約

`app/services/sign/in/otp_resend_service.rb` の SMS 配信パスが、生成した OTP コードを
`Outbound::Sms.deliver_later` の引数に **平文文字列補間** で渡している。ActiveJob 引数は Solid
Queue のテーブルにシリアライズされて永続化されるため、SMS OTP コードがキュー DB に **平文**
で書き込まれる。

メール側 (同ファイルの `else` 分岐) は `Outbound::SensitivePayload.encrypt_email_otp(otp_code)`
で先に暗号化してから `deliver_later`
に渡しているため、キューに乗るのは暗号文であり、ジョブ実行時にメイラー内で復号される設計になっている。SMS だけがこの保護を欠いている。

## 該当箇所

`app/services/sign/in/otp_resend_service.rb` (該当部 — 行番号は将来変動の可能性あり)

```ruby
if @kind == "telephone"
  Outbound::Sms.deliver_later(
    to: target.number,
    title: "PassCode => #{otp_code}",
    body: "PassCode => #{otp_code}",
  )
else
  Email::App::OtpMailer.with(
    encrypted_hotp_token: Outbound::SensitivePayload.encrypt_email_otp(otp_code),
    email_address: target.address,
  ).create.deliver_later
end
```

## 影響

直接ネットワーク経由で攻撃可能なバグではない (キュー DB
/ ジョブログ閲覧権限が必要)。ただし以下のシナリオで OTP が想定外に露出する。

1. **キュー DB 漏洩時の影響拡大**
   - `solid_queue_jobs.arguments` カラムが平文 OTP を含む。
   - SQL ダンプ・読み取り権限を持つ運用者・SRE が、配信中の OTP を取り出せる。
   - メール側は同条件でも暗号文しか得られない。
2. **ジョブログ / リトライ画面 / APM**
   - Solid Queue のエラー・リトライ表示、`Performing ...Job from ...`
     ログ、APM の引数キャプチャに OTP コードが残る。
   - Rails の `filter_parameters` はリクエスト側にしか効かず、ジョブ引数には適用されない。
3. **DB バックアップ / レプリカ / WAL**
   - 平文 OTP が短期間とはいえ複数の保管領域に書き込まれる。
   - `Outbound::Sms.deliver_later`
     がリトライキューに長く滞在した場合、その間 valid な状態で平文が露出する。

OTP 自体は短命だが、**メール側と SMS 側で防御の非対称性がある**
ことが本質的な問題。キュー漏洩・ログ漏洩の脅威モデルにおいて、メールが守られて SMS が守られないのは意図された設計とは考えにくい。

## 影響を受けるユーザー

`OtpResendService` の SMS 経路を通る全リクエスト。具体的には `sign/app`・`sign/com`・`sign/org`
の OTP 再送 (`POST /.../resend`) のうち `kind == "telephone"` のフロー。

## 検討事項 (実装前に決めること)

1. **キャリアログとの整合性**
   - SMS は最終的にベンダー API (AWS SNS / Connect /
     Twilio など) に平文で渡すため、ベンダー側のログ・課金記録には平文が残るのは仕様上避けられない。
   - 本対応の目的は **自社境界内 (キュー DB / ジョブログ / APM) での平文露出をなくす** こと。
2. **Outbound::SensitivePayload の SMS 対応**
   - `encrypt_email_otp` は HMAC OTP トークンを扱う前提の API のように見える。
   - SMS OTP 用に同等の `encrypt_sms_otp` を新設するか、汎用的な `encrypt_otp` に統一するか。
   - 鍵管理は email 側と共有でよいか / 分けるべきか (`Rails.application.message_verifier` / KMS)。
3. **Outbound::Sms のジョブシグネチャ変更**
   - 現在は `to:`, `title:`, `body:` という汎用 SMS 送信 API。OTP 専用引数 `encrypted_otp:`
     を追加するか、SMS ジョブを `OtpSms` のように専用化するか。
   - 既存の非 OTP SMS 送信 (販促等があれば) の互換性。今は `title`/`body`
     を平文文字列で渡す呼び出しが他にもあれば、それは別件。
4. **復号タイミング**
   - メール側のように「ジョブ実行時にメイラー内で復号して送信直前に平文化」する形に揃える。
   - ジョブ実行プロセスは MessageVerifier の鍵にアクセスできる前提。

## 修正方針 (案 — 採用は別途決定)

```ruby
# 案 1: 専用引数
encrypted_otp = Outbound::SensitivePayload.encrypt_sms_otp(otp_code)
Outbound::Sms.deliver_later(
  to: target.number,
  encrypted_otp: encrypted_otp,
)
# Outbound::Sms 側で受け取った encrypted_otp を復号し、本文を組み立てて
# ベンダー API に送る。
```

```ruby
# 案 2: 専用ジョブ
encrypted_otp = Outbound::SensitivePayload.encrypt_sms_otp(otp_code)
Outbound::OtpSms.deliver_later(to: target.number, encrypted_otp: encrypted_otp)
# OtpSms は OTP 配信専用ジョブとして独立させる。汎用 Sms との混在を防ぐ。
```

いずれの案でも、`otp_code` を平文のまま `deliver_later` の引数に渡さないことが要件。

## ロールアウト時の注意

- キュー DB に既に平文 OTP が乗っているジョブ (旧形式) と、暗号文しか乗っていないジョブ (新形式) が一時的に混在する。`Outbound::Sms`
  側は両形式を受理する移行期 (数日〜1週間程度) を設けるか、ジョブの新形式投入前にキューがドレインされたことを確認してからデプロイする。
- OTP の TTL が短い (数分) ため、キュードレイン待ちで十分に切り替えられる可能性が高い。

## 関連

- `app/services/sign/in/otp_resend_service.rb` — 該当ファイル。
- `app/services/outbound/sensitive_payload.rb` (存在前提) — 既存の email OTP 暗号化実装。
- `adr/distributor-solid-cache-queue-placement.md` — Solid Queue のホスト先 DB 配置の前提。
- `plans/backlog/credential-abuse-rate-limit-policy.md` — OTP の attempt 制御は別レイヤで対応済み。

## 対象外

- ベンダー API (AWS SNS 等) 以降の経路における OTP 平文露出は本件のスコープ外。
- email 側の追加ハードニングも本件のスコープ外 (既に暗号化されている)。
- レート制限・連投防止は本件のスコープ外。
