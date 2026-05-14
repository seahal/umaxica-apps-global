# Step-Up MFA Status

This document describes the current step-up gate used by the `app`, `com`, and `org` sign
configuration surfaces.

## Purpose

Step-up protects sensitive signed-in pages, such as personal information, credential management,
session revocation, and withdrawal. Lightweight users may sign up without being forced to register
MFA immediately, but sensitive pages either require recent step-up or route the actor into MFA
registration when no step-up method exists.

## Columns

`multi_factor_id` is the actor policy level. It describes the requested MFA strength and must not
be used as the credential-availability cache.

`multi_factor_status_id` is the credential-availability cache:

| value | name           | meaning                                                                 |
| ----- | -------------- | ----------------------------------------------------------------------- |
| `0`   | `NOTHING`      | Placeholder only. Runtime checks raise because this is an implementation bug. |
| `1`   | `ACTIVE`       | At least one surface-counting step-up method exists.                    |
| `5`   | `UNCONFIGURED` | No surface-counting step-up method exists. New actors default here.     |

## Surface Criteria

The status is recalculated from surface-specific step-up methods:

| surface | `ACTIVE` when any of these exist |
| ------- | -------------------------------- |
| `app`   | verified user email, active user passkey, or active user TOTP |
| `com`   | verified visitor email or active visitor passkey |
| `org`   | active operator passkey |

Telephone numbers, social identities, and recovery secrets do not count as step-up methods.

## Page Classes

Pages fall into three classes:

| class | behavior |
| ----- | -------- |
| No step-up | The page does not read `multi_factor_status_id`. |
| Sensitive | The page requires step-up. If status is `UNCONFIGURED`, it redirects to setup first. |
| Bootstrap-exempt registration | The page allows access without step-up only while status is `UNCONFIGURED`; once status is `ACTIVE`, it requires step-up. |

Bootstrap-exempt registration actions are:

| surface | bootstrap-exempt actions |
| ------- | ------------------------ |
| `app` | email registration, passkey registration, TOTP registration |
| `com` | email registration, passkey registration |
| `org` | passkey registration |

For `org`, email registration is credential management, not bootstrap. The first step-up method is
operator passkey.

## Runtime Rule

Controllers use `multi_factor_status_id` through the shared verification concern. They do not decide
bootstrap by checking only their own credential type. For example, an `app` user with a verified
email has status `ACTIVE`, so `/configuration/totps` requires step-up even if the user has no TOTP.

Successful credential registration updates the status through model callbacks. The standard
credential registration audit events continue to record the actual registration.
