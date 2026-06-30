# Entra ID Org Sign-In — Slice 0 + Slice 1

Scope: ADR (Slice 0) and org_zenith migrations + models (Slice 1) only. Controllers, routes,
callback, and admin UI are deferred to later slices.

---

## Governing Decisions

These decisions are binding across all future slices.

| Decision                           | Value                                                                  |
| ---------------------------------- | ---------------------------------------------------------------------- |
| Stable Entra lookup key            | `tid + oid` only                                                       |
| Protocol evidence stored           | `iss + sub` (audit/evidence columns; never used for auth lookup)       |
| Email / UPN / `preferred_username` | Never stored, never used for lookup, never requested from Entra        |
| Scope requested from Entra         | `"openid profile"` only — no `"email"`, no `"offline_access"`          |
| UserInfo endpoint                  | Never called                                                           |
| OmniAuth on org surface            | Prohibited — `OmniAuthNonAppSocialGuard` untouched                     |
| App Google/Apple social login      | Untouched                                                              |
| Database for both new models       | `org_zenith` — same database as `OperatorIdentity`                     |
| Default model status               | `:inactive` — both connection and identity require explicit activation |
| Admin provisioning UI              | Not in this plan — deferred                                            |
| Callback / controller              | Not in this plan — deferred until Slice 2                              |
| Client secret storage              | Rails ActiveRecord Encryption (`encrypts :entra_client_secret`)        |
| JIT provisioning                   | Prohibited — resolver must raise on miss, never create                 |

---

## Slice 0 — ADR

**File:** `adr/org-entra-id-sign-in-boundary.md`

### ADR content summary

The ADR must record all decisions in the table above plus:

**Identity model placement:** `OrganizationEntraConnection` and `OperatorEntraIdentity` are placed
in `org_zenith` alongside `OperatorIdentity`. Rationale: both records carry identity-authority
semantics (who is trusted, who is mapped), not transactional or configuration semantics.
`org_zenith` is the identity database; `org_principal` is the actor database; `org_ticket` is the
session/token database. Federation records belong with identity, not sessions.

**Why not `OperatorIdentity` table:** `OperatorIdentity` uses a generic
`(issuer, subject, audience)` key designed for any OIDC IdP. Entra-specific records require `tid`
validation, connection-scoped activation state, and a fixed lookup path that would be obscured by
sharing the table. Separate tables also allow the Entra schema to evolve (e.g., adding
`tid`-specific index) without touching the existing `OperatorIdentity` index.

**Why `tid + oid` not `iss + sub`:** `iss` is derived from `tid`
(`https://login.microsoftonline.com/{tid}/v2.0`), so they carry the same information. `oid` is the
stable, non-reassignable Entra object ID; `sub` is pairwise pseudonymous and varies by client_id.
Using `tid + oid` as the primary lookup key is stable across client_id changes. `iss + sub` are
stored as protocol evidence columns for audit and debugging.

**No email columns:** `email`, `upn`, `preferred_username` are mutable in Entra and must not be
stored as identity-determining fields. No such column will exist in either model's schema.

**Scope `openid profile`:** Sign-in only. `email` scope is unnecessary (and pulls mutable data);
`offline_access` would issue a refresh token, which contradicts the sign-in-only posture.

**Default inactive status:** Both `OrganizationEntraConnection` and `OperatorEntraIdentity` default
to `status: :inactive`. No activation happens automatically; an admin must explicitly activate each
record. This is the deny-by-default principle applied at the data layer.

---

## Slice 1 — org_zenith Migrations and Models

### `OrganizationEntraConnection`

**Purpose:** Represents an Organization's trust relationship with a specific Entra tenant. One row
per organization-per-tenant registration. Must be explicitly activated before use. Contains the OIDC
client credentials used to initiate the Entra authorization code flow.

**Database:** `org_zenith` **Table:** `organization_entra_connections`

**Migration schema:**

```ruby
create_table :organization_entra_connections do |t|
  t.string   :public_id,           null: false, limit: 21
  t.bigint   :organization_id,     null: false
  t.string   :entra_tenant_id,     null: false, limit: 36   # UUID format; the Entra tid claim
  t.string   :entra_client_id,     null: false, limit: 255  # Azure App Registration client_id
  t.text     :entra_client_secret  null: false               # encrypted at rest
  t.integer  :status,              null: false, default: 0  # enum: inactive/active/suspended/revoked
  t.datetime :last_used_at
  t.datetime :revoked_at
  t.timestamps null: false
end

add_index :organization_entra_connections, :public_id, unique: true
add_index :organization_entra_connections, [:organization_id, :entra_tenant_id], unique: true
add_index :organization_entra_connections, [:entra_tenant_id, :entra_client_id], unique: true
add_index :organization_entra_connections, :status
```

**Model:**

```ruby
class OrganizationEntraConnection < OrgZenithRecord
  encrypts :entra_client_secret

  enum :status, { inactive: 0, active: 1, suspended: 2, revoked: 3 }, default: :inactive

  validates :organization_id, :entra_tenant_id, :entra_client_id, :entra_client_secret, presence: true
  validates :entra_tenant_id, uniqueness: { scope: :organization_id }
  validates :entra_client_id, uniqueness: { scope: :entra_tenant_id }
  validates :entra_tenant_id, format: { with: /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i,
                                        message: "must be a valid UUID" }

  has_many :operator_entra_identities,
           foreign_key: :connection_id,
           inverse_of: :connection,
           dependent: :restrict_with_error
end
```

**Key design points:**

- `organization_id` is a logical FK only — references `organizations` in `org_principal`, a
  different database. No cross-DB enforced FK. AR-layer presence validation only.
- `entra_tenant_id` is validated as UUID format before any interpolation into URLs (SSRF defense).
- `encrypts :entra_client_secret` uses Rails 7.1 Active Record Encryption. The plaintext is never
  stored; the column holds a ciphertext envelope. Encryption keys live in Rails credentials.
- Default status `inactive` — connection cannot be used for sign-in without explicit activation.
- No `email`, `upn`, or `preferred_username` column.
- No callback-facing `find_or_create` or `upsert` method — all records created by provisioning only.

---

### `OperatorEntraIdentity`

**Purpose:** Pre-provisioned mapping between an Entra `(tid, oid)` pair and a specific Operator.
Created by admin provisioning only — never created during a sign-in callback. Must be explicitly
activated before use.

**Database:** `org_zenith` **Table:** `operator_entra_identities`

**Migration schema:**

```ruby
create_table :operator_entra_identities do |t|
  t.string   :public_id,             null: false, limit: 21
  t.bigint   :operator_id,           null: false             # FK to operators (org_principal, logical)
  t.bigint   :connection_id,         null: false             # FK to organization_entra_connections
  t.string   :entra_tenant_id,       null: false, limit: 36  # denormalized tid for single-table lookup
  t.string   :entra_object_id,       null: false, limit: 36  # the oid claim from the Entra ID token
  t.string   :evidence_issuer,       null: true,  limit: 512 # iss claim — protocol evidence only
  t.string   :evidence_subject,      null: true,  limit: 512 # sub claim — protocol evidence only
  t.integer  :status,                null: false, default: 0 # enum: inactive/active/suspended/revoked
  t.datetime :last_authenticated_at
  t.timestamps null: false
end

add_index :operator_entra_identities, :public_id, unique: true
add_index :operator_entra_identities, [:entra_tenant_id, :entra_object_id], unique: true
add_index :operator_entra_identities, :operator_id, unique: true
add_index :operator_entra_identities, :connection_id
add_index :operator_entra_identities, :status
```

**Model:**

```ruby
class OperatorEntraIdentity < OrgZenithRecord
  enum :status, { inactive: 0, active: 1, suspended: 2, revoked: 3 }, default: :inactive

  belongs_to :connection,
             class_name: "OrganizationEntraConnection",
             foreign_key: :connection_id,
             inverse_of: :operator_entra_identities

  validates :operator_id, :connection_id, :entra_tenant_id, :entra_object_id, presence: true
  validates :entra_tenant_id, format: { with: /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i,
                                        message: "must be a valid UUID" }
  validates :entra_object_id, format: { with: /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i,
                                        message: "must be a valid UUID" }
  validates :operator_id, uniqueness: true
  validates :entra_tenant_id, uniqueness: { scope: :entra_object_id }
end
```

**Key design points:**

- Lookup key: `(entra_tenant_id, entra_object_id)` — unique index enforces one Operator per
  `(tid, oid)` pair across the entire table.
- `entra_tenant_id` is denormalized from the associated connection to enable a single-table lookup
  without a cross-database join.
- `evidence_issuer` / `evidence_subject` store the `iss` / `sub` claims for audit/debugging. Both
  are nullable because they are evidence, not keys. Neither participates in the lookup index.
- No `email`, `upn`, or `preferred_username` column in schema.
- Default status `inactive` — identity cannot be used for sign-in without explicit activation.
- `operator_id` uniqueness: one Entra identity per Operator (start strict; loosen in future if
  multi-tenant operators are needed).
- `operator_id` is a logical FK only — references `operators` in `org_principal`.
- No callback-facing `find_or_create` or `upsert` method.

---

## Model Tests Required

### `test/models/organization_entra_connection_test.rb`

```
Security invariants:
- No email/upn/preferred_username column exists in the table (schema assertion)
- entra_tenant_id must be UUID format (validates format)
- entra_tenant_id + organization_id unique (database constraint)
- entra_tenant_id + entra_client_id unique (database constraint)
- entra_client_secret is NOT stored in plaintext (read raw column value from DB, confirm ciphertext)
- status defaults to :inactive
- Connection with status :inactive cannot... (model has no auth-lookup method to test here; policy
  tested in Slice 2 resolver)

Validation tests:
- Valid record saves
- Missing organization_id → invalid
- Missing entra_tenant_id → invalid
- Missing entra_client_id → invalid
- Missing entra_client_secret → invalid
- entra_tenant_id non-UUID format (e.g., "not-a-uuid") → invalid
- entra_tenant_id duplicate for same organization → invalid
- entra_client_id duplicate for same entra_tenant_id → invalid

No callback API:
- OperatorEntraConnection.respond_to?(:find_or_create_by_entra_claims) → false
- OperatorEntraConnection.respond_to?(:upsert_from_token) → false
```

### `test/models/operator_entra_identity_test.rb`

```
Security invariants:
- No email/upn/preferred_username/display_name column exists in the table (schema assertion)
- entra_tenant_id must be UUID format
- entra_object_id must be UUID format
- (entra_tenant_id, entra_object_id) unique (database constraint)
- operator_id unique (database constraint)
- status defaults to :inactive
- evidence_issuer and evidence_subject are nullable (they are evidence, not keys)

Validation tests:
- Valid record saves
- Missing operator_id → invalid
- Missing connection_id → invalid
- Missing entra_tenant_id → invalid
- Missing entra_object_id → invalid
- entra_tenant_id non-UUID → invalid
- entra_object_id non-UUID → invalid
- Duplicate (entra_tenant_id, entra_object_id) → invalid
- Duplicate operator_id → invalid

No callback API:
- OperatorEntraIdentity.respond_to?(:find_or_create_by_entra_claims) → false
- OperatorEntraIdentity.respond_to?(:upsert_from_token) → false
```

---

## Passkey / Secret-Credential Completion Path (for Slice 2 reference)

Documented from `app/controllers/concerns/authentication_base.rb` (lines 350–521),
`app/controllers/auth/org/sign/in/passkeys_controller.rb`, and
`app/controllers/auth/org/sign/in/secret_credentials_controller.rb`.

The Entra callback in Slice 2 must call `establish_signed_in_session!` with
`auth_method: "entra_id"` to enter the same pipeline.

### Exact call chain

```
POST /in/passkeys/verification
  verify_authentication_credential!          # WebAuthn assertion check
  perform_passkey_sign_in(passkey)
    establish_signed_in_session!(
      passkey.staff,
      pt:          retrieve_pt_for_checkpoint,
      ri:          current_region_identifier,
      auth_method: "passkey",
    )

POST /in/secret_credentials
  verify_secret_credential_for_sign_in       # raw secret vs stored credential
  process_standard_login(staff)
    establish_signed_in_session!(
      staff,
      pt:          pt,
      ri:          current_region_identifier,
      auth_method: "secret_credential",
    )
```

### Inside `establish_signed_in_session!` (authentication_base.rb:2319)

```
1. start_sign_in_flow_for!(resource, pt:)        # creates DB sign-in cycle record
2. mfa_bypassed_for_auth_method?(auth_method)
     "passkey"           → true  (line 2768: auth_method.to_s == "passkey")
     "secret_credential" → false (may gate on TOTP challenge)
     "entra_id"          → false by default — Slice 2 must decide policy
3. pending_sign_in_result_after_primary!
     session_limit_state_for(resource)
       within limit  → log_in(resource, ...)
       at/above limit → issue_session_limit_gate! → restricted session → redirect /in/session
```

### Inside `log_in` (authentication_base.rb:350)

```
1. check_login_cooldown!(resource)            # 30-second re-login cooldown
2. reset_session                              # Rails: clears session, rotates session ID
3. clear_previous_login_cookies!              # deletes __Host-Access, __Host-Refresh
4. with_actor_session_lock(resource)
     issue_login_tokens_within_lock(resource, ...)
       create_login_token_record → OperatorToken (org_ticket)
         staff_id, staff_token_kind_id (BROWSER_WEB=1), staff_token_status_id (ACTIVE=1)
       ensure_device_session_for!(resource, token_record)
       rotate_login_refresh_token!(token_record)  → refresh JWT
       encode_login_access_token(resource, token_record)
         JWT claims: sub, session_public_id, acr:"aal1", amr:["passkey"|"secret_credential"]
       set_login_auth_cookies(token_record, access_token, refresh_plain, access_expires_at)
         __Host-Access  (short-lived JWT, HttpOnly, Secure, SameSite=Strict)
         __Host-Refresh (long-lived, HttpOnly, Secure, SameSite=Strict)
       record_audit(AUDIT_EVENTS[:logged_in], resource:, context:)
5. return {status: :success, redirect_path: sign_in_sequence_redirect_path(pt:)}
```

### Slice 2 decisions required (not in this plan)

- **MFA bypass for Entra:** `mfa_bypassed_for_auth_method?("entra_id")` currently returns `false`
  (only `"passkey"` returns `true`). Entra ID with the right AAL can be treated as equivalent to
  passkey for MFA purposes, but this is a policy decision that must be explicitly recorded in an ADR
  before implementation.
- **`amr` claim in JWT:** The access token `amr` array needs an agreed string for Entra sign-in
  (e.g., `"fed"` per RFC 8176, or `"entra_id"` as a local convention).
- **Session limit:** `OperatorToken::MAX_SESSIONS_PER_STAFF = 1`. Entra sign-in will hit the same
  session limit gate as passkey; the session management redirect path is `/in/session`. No change
  needed, but verify in integration tests.

---

## Files to Create / Modify

### New files

```
adr/org-entra-id-sign-in-boundary.md
db/migrate/{timestamp}_create_organization_entra_connections.rb
db/migrate/{timestamp}_create_operator_entra_identities.rb
app/models/organization_entra_connection.rb
app/models/operator_entra_identity.rb
test/models/organization_entra_connection_test.rb
test/models/operator_entra_identity_test.rb
```

### Existing files untouched

```
config/initializers/omniauth.rb                         (OmniAuthNonAppSocialGuard — do not touch)
app/controllers/auth/org/application_controller.rb      (no change)
app/controllers/auth/org/sign/in/passkeys_controller.rb (no change)
app/models/operator_identity.rb                         (no change)
```

---

## Verification

After Slice 1 lands:

```bash
bin/rails test test/models/organization_entra_connection_test.rb
bin/rails test test/models/operator_entra_identity_test.rb
bin/rails db:verify_no_schema_drift   # confirm schema_dump matches migrations
```

Confirm the schema contains no `email`, `upn`, or `preferred_username` columns:

```bash
grep -n "email\|upn\|preferred_username\|display_name" \
  db/migrate/*_create_organization_entra_connections.rb \
  db/migrate/*_create_operator_entra_identities.rb
# must return zero matches
```
