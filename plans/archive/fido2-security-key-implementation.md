# FIDO2 Security Key Implementation Task List

## Current Analysis

### Completed ✅

- **WebAuthn Gem**: `webauthn` v3.4 already installed.
- **Configuration**: Multi-domain settings finished in `/config/webauthn.rb`.
- **Controller structure**: Skeleton controllers exist.
- **Routing**: Wired up for every domain.
- **View templates**: Basic layouts in place.
- **Database models**: User, Staff, and **Customer** passkey tables implemented.
- **Controller logic**: Registration and authentication flows implemented.
- **MFA integration**: Connected to the existing authentication system.

### Outstanding ❌

- **JavaScript**: No integration with the WebAuthn browser APIs.

## Implementation Tasks

### 1. JavaScript WebAuthn API implementation 🟡 **MEDIUM PRIORITY**

#### 1.1 Directory structure

```
app/javascript/webauthn/
├── registration.js     # Registration flow
├── authentication.js  # Authentication flow
├── management.js       # Management tooling
└── utils.js            # Shared utilities
```

#### 1.2 Registration flow JavaScript

```javascript
// app/javascript/webauthn/registration.js
export class WebAuthnRegistration {
  static async register(options) {
    try {
      const credential = await navigator.credentials.create({ publicKey: options });

      return {
        id: credential.id,
        rawId: arrayBufferToBase64Url(credential.rawId),
        response: {
          attestationObject: arrayBufferToBase64Url(credential.response.attestationObject),
          clientDataJSON: arrayBufferToBase64Url(credential.response.clientDataJSON),
        },
        type: credential.type,
      };
    } catch (error) {
      throw new WebAuthnError(error.message);
    }
  }
}
```

#### 1.3 Authentication flow JavaScript

```javascript
// app/javascript/webauthn/authentication.js
export class WebAuthnAuthentication {
  static async authenticate(options) {
    try {
      const assertion = await navigator.credentials.get({ publicKey: options });

      return {
        id: assertion.id,
        rawId: arrayBufferToBase64Url(assertion.rawId),
        response: {
          authenticatorData: arrayBufferToBase64Url(assertion.response.authenticatorData),
          clientDataJSON: arrayBufferToBase64Url(assertion.response.clientDataJSON),
          signature: arrayBufferToBase64Url(assertion.response.signature),
          userHandle: assertion.response.userHandle
            ? arrayBufferToBase64Url(assertion.response.userHandle)
            : null,
        },
        type: assertion.type,
      };
    } catch (error) {
      throw new WebAuthnError(error.message);
    }
  }
}
```

### 2. Error handling and UX 🟡 **MEDIUM PRIORITY**

#### 2.1 Browser support detection

```javascript
// app/javascript/webauthn/utils.js
export function isWebAuthnSupported() {
  return !!(navigator.credentials && navigator.credentials.create);
}

export function showWebAuthnUnsupportedMessage() {
  alert("Your browser does not support security keys. Please use the latest version.");
}
```

### 3. Testing 🟡 **MEDIUM PRIORITY**

#### 3.1 Model tests

```ruby
# test/models/customer_passkey_test.rb
class CustomerPasskeyTest < ActiveSupport::TestCase
  test "requires mandatory fields" do
    passkey = CustomerPasskey.new
    assert_not passkey.valid?
    assert_includes passkey.errors[:public_id], "can't be blank"
  end
end
```

### 4. Production readiness 🔴 **HIGH PRIORITY**

#### 4.1 Environment variables

```bash
# Required environment variables
WEBAUTHN_RP_NAME="Umaxica"
WEBAUTHN_RP_ID="umaxica.com"
WWW_CORPORATE_URL="https://com.umaxica.com"
WWW_SERVICE_URL="https://app.umaxica.com"
WWW_STAFF_URL="https://org.umaxica.com"
```

#### 4.2 Enforce HTTPS

- Force HTTPS in production.
- Confirm SSL certificates are valid.
- Verify the CSP configuration permits WebAuthn endpoints.

## Prioritisation

### Phase 1: Foundation ✅ **COMPLETE**

1. ~~Customer passkey database migration.~~ ✅

### Phase 2: Feature completion 🟡 **MEDIUM PRIORITY**

2. JavaScript WebAuthn API.
3. Error handling and UX improvements.
4. Tests.

### Phase 3: Production readiness 🔴 **HIGH PRIORITY**

5. Production environment configuration.
6. Documentation.

## Estimated Effort

- **Phase 1**: ✅ Complete
- **Phase 2**: 2–3 person-days.
- **Phase 3**: 1 person-day.
- **Total remaining**: 3–4 person-days.

## Notes

### Security considerations

- Manage WebAuthn challenges carefully.
- Prevent replay attacks via sign_count validation.
- Operate exclusively over HTTPS.
- Handle cross-origin configuration with caution.

### Compatibility with existing systems

- Coexist with TOTP and recovery-code flows.
- Integrate with the session management layer.
- Ensure alignment with the multi-domain architecture.

### Customer Passkey Migration (Completed 2026-04-04)

Created 3 migration files:

- `db/guests_migrate/20260404080001_create_customer_passkey_statuses.rb`
- `db/guests_migrate/20260404080002_insert_customer_passkey_statuses_data.rb`
- `db/guests_migrate/20260404080003_create_customer_passkeys.rb`

Updated: 2026-04-04
