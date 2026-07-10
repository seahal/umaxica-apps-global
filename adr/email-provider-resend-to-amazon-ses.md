# ADR: Email Provider Migration from Resend to Amazon SES

**Status:** Accepted on 2026-05-06.

## Context

The application's transactional email delivery was previously migrated from AWS to Resend (commit
`a9bb96add`, 2025-04-29). After roughly a year of operation on Resend, the project is moving the
SMTP relay back to Amazon SES.

Transactional email in this codebase is used for:

- Email OTP delivery for sign-in and signup verification
  (`app/controllers/concerns/sign/email_registrable.rb`)
- `UserMailer` notifications (`app/mailers/user_mailer.rb`)

The send volume and per-message latency requirements have not changed; the driver for the migration
is operational consolidation onto AWS (the application already uses AWS for other infrastructure),
cost predictability at the current sending volume, and removal of an external vendor dependency from
the critical signup path.

## Decision

Action Mailer is configured to deliver via Amazon SES over SMTP using SMTP credentials issued from
the SES console. The configuration lives in `config/environments/development.rb` and the equivalent
production environment file:

```ruby
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address: "email-smtp.#{ENV.fetch("AWS_SES_REGION", "ap-northeast-1")}.amazonaws.com",
  user_name: Rails.app.creds.option(:AWS_SES_SMTP_USERNAME),
  password: Rails.app.creds.option(:AWS_SES_SMTP_PASSWORD),
  port: 465,
  tls: true,
  authentication: :login,
  openssl_verify_mode: "peer",
  open_timeout: 5,
  read_timeout: 10,
}
```

Key choices:

- **Implicit TLS on port 465** rather than STARTTLS on 587. The two cannot be combined; mixing
  `tls: true` with `enable_starttls_auto: true` produces inconsistent behavior across Mail gem
  versions.
- **SMTP credentials, not raw IAM access keys.** SES SMTP credentials are derived from an IAM user
  but are distinct values; the IAM policy backing them is scoped to `ses:SendRawEmail` only.
- **Region defaults to `ap-northeast-1`** (Tokyo) via `ENV.fetch` so non-production environments can
  override without code changes.
- **Explicit timeouts** (`open_timeout: 5`, `read_timeout: 10`) prevent the mailer from hanging
  indefinitely if SES is slow to respond. Combined with `deliver_later`, transient failures are
  retried by Active Job rather than surfaced to the request.

## Trade-offs

- **Sandbox onboarding.** Each new SES account starts in sandbox mode and can only send to verified
  addresses. Production use requires an explicit production-access request to AWS and can take 24
  hours or more to approve. Resend has no equivalent gate.
- **Reputation is per-account, not per-vendor.** Bounce and complaint rates accrue to the SES
  account; sustained high rates can suspend sending. Resend isolated some of this concern behind a
  managed pool.
- **DNS configuration is the project's responsibility.** SPF, DKIM (three CNAMEs issued by SES), and
  DMARC must be present on the sending domain or messages are rejected by Gmail and Outlook under
  the 2024 sender requirements.
- **Webhook surface differs.** Bounce and complaint notifications arrive via SNS topics rather than
  Resend's webhook endpoints; any existing handlers are replaced.

## Follow-ups

- Confirm the SES account is out of sandbox in the production region before cutover.
- DNS records for SPF, DKIM, and DMARC are in place on every sending domain.
- IAM policy for the SMTP credentials is restricted to `ses:SendRawEmail`.
- Production `default_url_options` is set to a real host (not the `localhost` value used in
  development). Production must not override this with a `localhost` mailer host.
- Bounce and complaint handling is wired to an SNS topic and processed asynchronously.

## Related

- Prior migration: commit `a9bb96add` — _migrated smtp server from aws to resend_ (2025-04-29).
