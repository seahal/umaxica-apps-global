# Feature Flags

Flags are stored in Flipper (PostgreSQL `platform` database, see
`config/initializers/flipper.rb`) and toggled through the Flipper UI mounted on the
developer surface. They are runtime operational controls, not deploy-time configuration:
required configuration still uses `ENV.fetch("NAME")` and fails at boot when missing.

## Polarity

Two polarities are in use, and the direction is a deliberate per-flag decision:

- **Availability flags** (`social_ceremony_*`): an unset or unknown feature reads as
  **disabled**. Losing the flag store must stop external authentication ceremonies rather
  than let them through.
- **Suspension flags** (`outbound_*_suspended`, `turnstile_degraded_mode`): an unset
  feature reads as **not suspended**, so a flag store that was never written does not take
  delivery or sign-in down. The operator turns the flag on during an incident.

## Flags

| Flag | Polarity | Effect |
| --- | --- | --- |
| `social_ceremony_app_apple` | availability | Enables Apple sign-in on the `app` surface. Unset stops new ceremonies; issued callbacks drain. |
| `social_ceremony_app_google` | availability | Same, for Google on `app`. |
| `social_ceremony_org_entra` | availability | Same, for Microsoft Entra ID on `org`. |
| `outbound_sms_suspended` | suspension | Stops all outbound SMS (`OutboundSms`). Delivery returns a rejected `OutboundResult`; no SNS call and no job is enqueued. |
| `outbound_email_suspended` | suspension | Stops all outbound email, transactional and promotional, through the ActionMailer interceptor. |
| `outbound_promotional_email_suspended` | suspension | Stops promotional mail only (`*::PromotionalMailer`). Transactional mail keeps delivering. |
| `turnstile_degraded_mode` | suspension | Treats a Turnstile verification that failed **because Cloudflare was unreachable** as a pass. A failed challenge, a missing token, and a missing secret key are still rejected. |

`turnstile_degraded_mode` weakens a bot-defence control while it is on. It exists so a
Cloudflare outage does not close sign-up and sign-in, and it is meant to be turned back off
when the incident ends.

## Operational notes

- Suspending SMS or email does not tell the user why their code never arrived; the request
  path reports an ordinary delivery failure. Treat the flags as incident tooling.
- Per-request degrade and suspension decisions are logged as telemetry only. The durable
  record that a switch was pulled is the Flipper feature row itself; treat that, together
  with the incident record, as the authoritative history.
- `db/seeds.rb` registers the `social_ceremony_*` flags in development only. Suspension
  flags are deliberately not seeded: their default is off, and Flipper reads an unwritten
  feature as off.
