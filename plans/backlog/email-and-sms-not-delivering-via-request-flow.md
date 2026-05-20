# Isolating the case where Email / SMS is not delivered via web request

Creation date: 2026-05-07

## Symptoms

- Email switched to AWS SES (Email OTP, `UserMailer`, etc.) is not delivered.
- SMS (via AWS SNS) also does not arrive.
- **Works correctly when called directly from the Rails console.**

## Primary Hypothesis

Both Email and SMS are sent via ActiveJob. `solid_queue` If the worker (`bin/jobs`) is not running,
it will remain in the queue forever. No error is returned to the request, so nothing is returned
from the web, although it appears to be successful. Rails The console can directly call
`deliver_now` and `Outbound::Sms.deliver_now`, so it works without going through the queue.

### Evidence

- `config/application.rb:63` — `config.active_job.queue_adapter = :solid_queue`
- All transmission paths are `deliver_later` / `perform_later`:
  - `app/controllers/concerns/sign/email_registrable.rb:245`
  - `app/controllers/concerns/sign/telephone_registrable.rb:99`
  - `app/controllers/concerns/sign/staff_telephone_registrable.rb:85`
  - `app/services/sign/in/otp_resend_service.rb:122,131`
  - Other controllers under `sign/{app,com,org}/...`
- `Procfile.dev` — Requires `job: bin/jobs start` in parallel with `web`. `bin/rails server` If it
  is started by itself, the worker will not start.
- `config/puma.rb:41` — `plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]`. Either in-Puma
  execution or a separate job container is required on the production side.

## Confirmation steps (from top to bottom)

### 1. Is the worker process running?

```bash
ps aux | grep -E "solid_queue|bin/jobs" | grep -v grep
```

If nothing is returned, this is the confirmed cause. Remediation:

- Development: `bin/rails server` Stop single shot and start with `bin/dev` (`web` `css` `job`
  `vite` in Procfile.dev ) or run `bin/jobs start` on a separate terminal.
- Production: Give `SOLID_QUEUE_IN_PUMA=1` to Puma or use Kamal accessory as `bin/jobs` Make it
  resident as an independent process.

### 2. Are jobs stuck in the queue?

```ruby
# bin/rails c
SolidQueue::Job.where(finished_at: nil).count
SolidQueue::FailedExecution.last(10).map { [_1.job.class_name, _1.error] }
SolidQueue::ReadyExecution.count
```

- If `Job.where(finished_at: nil).count` continues to increase, the worker will stop.
- Body caused by error in `FailedExecution`:
  - `Net::SMTPAuthenticationError` / `Aws::Errors::MissingCredentialsError` → Credentials not
    injected (see 3 below).
  - `Aws::SNS::Errors::AuthorizationError` / `OptedOut` → IAM policy or destination number opt-out
    for SNS.
  - `Net::OpenTimeout` / `Net::ReadTimeout` → Network Reachability (VPC / SG / DNS).
  - `Invalid parameter: PhoneNumber` of `Aws::SNS::Errors::InvalidParameter` → E.164 Missing
    formatting (is it passed by `+81...`?)

### 3. Are credentials passed through the request process?

Running on the Rails console means that at least the environment variable that started the console /
Credentials are working. If the web process is a different user or a different systemd unit / If it
is started in a different container, the env may be different.

```ruby
# bin/rails c (= the working path)
Rails.app.creds.option(:AWS_SES_SMTP_USERNAME).present?
Rails.app.creds.require(:AWS_ACCESS_KEY_ID).then { _1[0..3] }
```

Check that the same value can be read on the `web` process side. The production side is
`RAILS_MASTER_KEY` Please check whether it is passed to both web/job and env.

### 4. Email-specific pitfalls

SMTP settings for `config/environments/{development,production}.rb`:

```ruby
port: 465,
tls: true,
authentication: :login,
```

Mail gem breaks when using `tls: true` (= implicit TLS) and `enable_starttls_auto: true` together.
now Since `enable_starttls_auto` is not installed, it is OK.
`port: 587 + enable_starttls_auto: true` When switching to , be sure to remove `tls: true` (ADR
`email-provider-resend-to-amazon-ses.md` is described).

Also, if SES is not out of **sandbox mode**, sending to other than verified addresses will be
disabled. `MessageRejected: Email address is not verified` becomes 4xx and `FailedExecution` Go out.
Make sure to release the sandbox before moving to production.

### 5. SMS specific pitfalls

`app/services/aws_sms_service.rb` is `Rails.app.creds.require(:AWS_ACCESS_KEY_ID)` is used, so if it
is absent, an exception will occur during initialization. This is `discard_on ArgumentError`
`FailedExecution` It should be recorded as is. `Aws::Errors::MissingCredentialsError` If it appears,
you need to supply either IAM user or instance role.

SNS is the region and sender ID settings (for Japan, sender Although ID is not required, there is
also the trap of needing to register an originating number when sending to the United States.

## expected outcome

It's almost certainly either "worker not started or env not injected". Piled up in queue after
raising worker If you look at `FailedExecution`, you will immediately know if it is a genuine
credential problem or a network problem.

## Related

- `adr/email-provider-resend-to-amazon-ses.md` — Decision to switch back to SES.
- `app/jobs/outbound/sms_delivery_job.rb` — retry/discard policy for SMS.
- `app/services/outbound/sms.rb` — Outbound SMS entry point.
