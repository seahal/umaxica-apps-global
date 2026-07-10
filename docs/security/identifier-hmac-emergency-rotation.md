# Identifier HMAC Emergency Rotation

## Purpose

Email and telephone identifiers are stored as encrypted values plus searchable HMAC digest columns.

This document defines the emergency response when an identifier HMAC key is suspected or confirmed
to be exposed.

Covered identifier models:

- `ClientEmail`, `OperatorEmail`, `VisitorEmail`
- `ClientTelephone`, `OperatorTelephone`, `VisitorTelephone`

Covered digest columns:

- `address_digest`
- `number_digest`

## Current Contract

The encrypted identifier columns are the readable source of truth:

- `address`
- `number`

The digest columns are search and uniqueness indexes only. Application search must use the digest
columns, not indexes on encrypted `address` or `number` values.

Email digest input must be normalized to lowercase before HMAC generation. Telephone digest input
must be normalized to E.164 before HMAC generation.

## Emergency Trigger

Start this procedure when any of the following is true:

- `EMAIL_ADDRESS_HMAC_SALT` is exposed or suspected to be exposed.
- `TELEPHONE_NUMBER_HMAC_SALT` is exposed or suspected to be exposed.
- Credentials, environment variables, logs, backups, or operator access paths may have leaked an
  identifier HMAC key.

Treat telephone HMAC exposure as especially sensitive because telephone numbers have a smaller
candidate space than email addresses.

## Response Policy

Identifier HMAC rotation is an outage operation.

Do not attempt a no-downtime HMAC key rotation with the current single digest column design. During
rotation, old-key and new-key digests for the same identifier are different values, so the database
unique index cannot enforce logical uniqueness across both versions.

The approved emergency response is:

1. Stop writes that create or update email and telephone identifier records.
2. Put affected sign-in, sign-up, configuration, and staff-management paths into maintenance mode or
   stop the service.
3. Replace the exposed HMAC key with a new secret.
4. Recompute and overwrite the existing digest columns from the encrypted identifier values.
5. Verify that all target rows have current digests.
6. Restart the service with only the new HMAC key active.

## Rotation Steps

### 1. Freeze Identifier Writes

Block all code paths that can create or update the covered records.

At minimum, freeze:

- email sign-up and sign-in flows
- telephone sign-up and sign-in flows
- email and telephone configuration screens
- staff/operator email and telephone management
- visitor email and telephone registration flows

### 2. Replace Secrets

Rotate the affected secret values in the runtime secret store:

- `EMAIL_ADDRESS_HMAC_SALT`
- `TELEPHONE_NUMBER_HMAC_SALT`

Use a high-entropy random value. Do not reuse previous values.

### 3. Backfill In Place

Recompute the digest columns from decrypted model attributes.

Use the emergency task after the new HMAC secret is present in the runtime environment:

```bash
CONFIRM_IDENTIFIER_HMAC_OVERWRITE=1 bin/rails identifier_hmac:emergency_rotate
```

The backfill must:

- read `address` / `number` through Active Record so Rails encryption decrypts the value;
- normalize through `IdentifierBlindIndex`;
- overwrite the same `address_digest` / `number_digest` column;
- avoid logging raw identifiers, HMAC keys, or full record attributes;
- process all six identifier models.

### 4. Verify Completeness

Before reopening traffic, verify:

- every nonblank `address` row has a nonblank `address_digest`;
- every nonblank `number` row has a nonblank `number_digest`;
- duplicate digest conflicts are resolved before the service starts;
- representative exact-match searches work for client, operator, and visitor records;
- targeted model tests for email and telephone identifiers pass.

### 5. Reopen Service

Restart application processes with only the new HMAC key configured.

Do not keep the exposed HMAC key in runtime configuration after the overwrite is complete.

## Non-Goals

This emergency procedure does not rotate Rails Active Record Encryption keys. Encryption key
rotation uses the Rails encryption key provider and previous-key support.

This procedure does not add parallel digest columns. The accepted emergency design overwrites the
current digest columns after writes are stopped.

## Operational Notes

If a future requirement needs no-downtime HMAC key rotation, introduce a separate design with either
parallel digest columns or an equivalent uniqueness-preserving transition mechanism. Do not retrofit
online rotation onto the single-column emergency procedure.

Related decision record:

- `adr/identifier-hmac-emergency-rotation.md`
