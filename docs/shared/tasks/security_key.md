# FIDO2 Security Key Implementation Task List

## Current Analysis

### Completed ✅

- **WebAuthn Gem**: `webauthn` v3.4 already installed.
- **Configuration**: Multi-domain settings finished in `/config/webauthn.rb`.
- **Controller structure**: Skeleton controllers exist.
- **Routing**: Wired up for every domain.
- **View templates**: Basic layouts in place.

### Outstanding ❌

- **Database models**: No tables to persist WebAuthn credentials.
- **Controller logic**: Registration and authentication flows missing.
- **JavaScript**: No integration with the WebAuthn browser APIs.
- **Security integration**: Not yet connected to the existing MFA system.

## Implementation Tasks

### 1. Database design and implementation 🔴 **HIGH PRIORITY**

#### 1.1 Generate migrations

```bash
# Create migrations in the identifier database
rails generate migration CreateWebauthnCredentials --database=identifier
rails generate migration CreateStaffWebauthnCredentials --database=identifier
```

#### 1.2 Required table structure

```ruby
# webauthn_credentials (for end users)
# staff_webauthn_credentials (for staff)

# Required columns:
- user_id/staff_id (foreign key)
- external_id (WebAuthn credential ID, Base64URL encoded)
- public_key (binary)
- sign_count (bigint)
- nickname (string)
- last_used_at (datetime)
- created_at, updated_at (datetime)
- transports (JSON array)
- aaguid (authenticator GUID, binary, optional)
```

#### 1.3 Index design

```sql
-- Indexes for fast lookups
INDEX idx_webauthn_credentials_user_id (user_id)
INDEX idx_webauthn_credentials_external_id (external_id)
INDEX idx_staff_webauthn_credentials_staff_id (staff_id)
INDEX idx_staff_webauthn_credentials_external_id (external_id)
```

### 2. Model implementation 🔴 **HIGH PRIORITY**

#### 2.1 `WebauthnCredential` model

```ruby
# app/models/webauthn_credential.rb
class WebauthnCredential < IdentitiesRecord
  belongs_to :user

  validates :external_id, presence: true, uniqueness: true
  validates :public_key, presence: true
  validates :sign_count, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :nickname, presence: true, length: { maximum: 255 }

  scope :recent, -> { order(last_used_at: :desc) }

  def update_sign_count!(new_count)
    # Prevent replay attacks
    return false if new_count <= sign_count
    update!(sign_count: new_count, last_used_at: Time.current)
    true
  end
end
```

#### 2.2 `StaffWebauthnCredential` model

```ruby
# app/models/staff_webauthn_credential.rb
class StaffWebauthnCredential < IdentitiesRecord
  belongs_to :staff

  # Mirrors WebauthnCredential
end
```

#### 2.3 Extend User/Staff models

```ruby
# app/models/user.rb additions
has_many :webauthn_credentials, dependent: :destroy

def webauthn_enabled?
  webauthn_credentials.exists?
end

# app/models/staff.rb additions
has_many :staff_webauthn_credentials, dependent: :destroy

def webauthn_enabled?
  staff_webauthn_credentials.exists?
end
```

### 3. JavaScript WebAuthn API implementation 🔴 **HIGH PRIORITY**

#### 3.1 Directory structure

```
app/javascript/webauthn/
├── registration.js     # Registration flow
├── authentication.js  # Authentication flow
├── management.js       # Management tooling
└── utils.js            # Shared utilities
```

#### 3.2 Registration flow JavaScript

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

#### 3.3 Authentication flow JavaScript

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

### 4. Controller logic 🔴 **HIGH PRIORITY**

#### 4.1 Passkey controller for authentication

```ruby
# app/controllers/sign/app/authentication/passkeys_controller.rb
class Sign::App::Authentication::PasskeysController < Sign::App::ApplicationController
  def new
    @options = WebAuthn::Credential.options_for_get(
      allow: user_credentials_for_authentication,
      user_verification: 'preferred'
    )
    session[:webauthn_challenge] = @options.challenge
  end

  def create
    webauthn_credential = WebAuthn::Credential.from_get(credential_params)
    stored_credential = find_credential(webauthn_credential.id)
    return render_error('Authentication failed') unless stored_credential

    begin
      webauthn_credential.verify(
        session.delete(:webauthn_challenge),
        public_key: stored_credential.public_key,
        sign_count: stored_credential.sign_count
      )

      stored_credential.update_sign_count!(webauthn_credential.sign_count)
      sign_in_user(stored_credential.user)
      redirect_to_after_sign_in

    rescue WebAuthn::Error => e
      render_error('Authentication failed')
    end
  end
end
```

#### 4.2 Passkey controller for settings

```ruby
# app/controllers/sign/app/setting/passkeys_controller.rb
class Sign::App::Setting::PasskeysController < Sign::App::ApplicationController
  before_action :authenticate_user!

  def index
    @credentials = current_user.webauthn_credentials.recent
  end

  def new
    @options = WebAuthn::Credential.options_for_create(
      user: webauthn_user_entity,
      exclude: existing_credential_ids
    )
    session[:webauthn_challenge] = @options.challenge
  end

  def create
    webauthn_credential = WebAuthn::Credential.from_create(credential_params)

    begin
      webauthn_credential.verify(session.delete(:webauthn_challenge))

      current_user.webauthn_credentials.create!(
        external_id: webauthn_credential.id,
        public_key: webauthn_credential.public_key,
        sign_count: webauthn_credential.sign_count,
        nickname: params[:nickname].presence || "Security Key #{DateTime.current.strftime('%Y/%m/%d')}"
      )

      redirect_to setting_passkeys_path, notice: 'Security key registered successfully'

    rescue WebAuthn::Error => e
      render_error('Registration failed')
    end
  end

  def destroy
    credential = current_user.webauthn_credentials.find(params[:id])
    credential.destroy!
    redirect_to setting_passkeys_path, notice: 'Security key removed'
  end
end
```

### 5. View implementation 🟡 **MEDIUM PRIORITY**

#### 5.1 Authentication view

```erb
<!-- app/views/sign/app/authentication/passkeys/new.html.erb -->
<div class="webauthn-auth">
  <h2>Authenticate with a security key</h2>
  <p>Touch your security key to continue.</p>

  <button id="webauthn-auth-btn" class="btn btn-primary">
    Authenticate with security key
  </button>

  <script>
    document.addEventListener('DOMContentLoaded', function() {
      const authBtn = document.getElementById('webauthn-auth-btn');
      const options = <%= raw @options.to_json %>;

      authBtn.addEventListener('click', async function() {
        try {
          const assertion = await WebAuthnAuthentication.authenticate(options);
          submitAuthentication(assertion);
        } catch (error) {
          showError('Authentication failed: ' + error.message);
        }
      });
    });
  </script>
</div>
```

#### 5.2 Management view

```erb
<!-- app/views/sign/app/setting/passkeys/index.html.erb -->
<div class="webauthn-management">
  <h2>Security key management</h2>

  <div class="credentials-list">
    <% @credentials.each do |credential| %>
      <div class="credential-item">
        <span class="nickname"><%= credential.nickname %></span>
        <span class="last-used">Last used: <%= credential.last_used_at&.strftime('%Y/%m/%d %H:%M') || 'Never' %></span>
        <%= link_to 'Remove', setting_passkey_path(credential), method: :delete,
                    confirm: 'Remove this security key?',
                    class: 'btn btn-danger btn-sm' %>
      </div>
    <% end %>
  </div>

  <%= link_to 'Add a security key', new_setting_passkey_path, class: 'btn btn-primary' %>
</div>
```

### 6. Security integration 🔴 **HIGH PRIORITY**

#### 6.1 Tie into the existing MFA system

```ruby
# app/views/concerns/authentication.rb additions

def require_second_factor_or_webauthn
  return true if webauthn_authenticated?
  return true if totp_authenticated?
  return true if recovery_code_authenticated?

  redirect_to_mfa_selection
end


def webauthn_authenticated?
  session[:webauthn_verified_at] &&
    session[:webauthn_verified_at] > 30.minutes.ago
end
```

#### 6.2 Session management

```ruby
# After successful security key authentication
session[:webauthn_verified_at] = Time.current
session[:webauthn_credential_id] = credential.external_id

# On sign-out
session.delete(:webauthn_verified_at)
session.delete(:webauthn_credential_id)
```

### 7. Error handling and UX 🟡 **MEDIUM PRIORITY**

#### 7.1 Error messages

```ruby
# app/views/concerns/webauthn_errors.rb
module WebauthnErrors
  WEBAUTHN_ERROR_MESSAGES = {
    'NotAllowedError' => 'Security key not found or the operation was cancelled',
    'InvalidStateError' => 'This security key is already registered',
    'NotSupportedError' => 'Your browser does not support security keys',
    'SecurityError' => 'A secure connection (HTTPS) is required',
    'AbortError' => 'The operation timed out'
  }.freeze

  def webauthn_error_message(error)
    WEBAUTHN_ERROR_MESSAGES[error.name] || 'An error occurred while using the security key'
  end
end
```

#### 7.2 Browser support detection

```javascript
// app/javascript/webauthn/utils.js
export function isWebAuthnSupported() {
  return !!(navigator.credentials && navigator.credentials.create);
}

export function showWebAuthnUnsupportedMessage() {
  alert("Your browser does not support security keys. Please use the latest version.");
}
```

### 8. Testing 🟡 **MEDIUM PRIORITY**

#### 8.1 Model tests

```ruby
# test/models/webauthn_credential_test.rb
class WebauthnCredentialTest < ActiveSupport::TestCase
  test "requires mandatory fields" do
    credential = WebauthnCredential.new
    assert_not credential.valid?
    assert_includes credential.errors[:external_id], "can't be blank"
  end

  test "prevents replay attacks" do
    credential = webauthn_credentials(:one)
    assert_not credential.update_sign_count!(credential.sign_count - 1)
  end
end
```

#### 8.2 Controller tests

```ruby
# test/views/top/app/setting/passkeys_controller_test.rb
class Sign::App::Setting::PasskeysControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:one)
  end

  test "shows the index" do
    get setting_passkeys_url
    assert_response :success
  end

  test "creates a webauthn credential" do
    # Implement WebAuthn credential creation test
  end
end
```

### 9. Multi-domain validation 🟡 **MEDIUM PRIORITY**

#### 9.1 Verify behaviour on each domain

- **Corporate domain** (`WWW_CORPORATE_URL`): Basic authentication.
- **Service domain** (`WWW_SERVICE_URL`): Full registration/authentication/management.
- **Staff domain** (`WWW_STAFF_URL`): Staff-facing authentication.

#### 9.2 Cross-domain settings

```ruby
# Validate config/webauthn.rb
- Ensure allowed_origins are correct
- rp_id should point to the base domain
- Decide whether credentials are shared across domains
```

### 10. Production readiness 🔴 **HIGH PRIORITY**

#### 10.1 Environment variables

```bash
# Required environment variables
WEBAUTHN_RP_NAME="Umaxica"
WEBAUTHN_RP_ID="umaxica.com"
WWW_CORPORATE_URL="https://com.umaxica.com"
WWW_SERVICE_URL="https://app.umaxica.com"
WWW_STAFF_URL="https://org.umaxica.com"
```

#### 10.2 Enforce HTTPS

- Force HTTPS in production.
- Confirm SSL certificates are valid.
- Verify the CSP configuration permits WebAuthn endpoints.

#### 10.3 Security headers

```ruby
# config/application.rb
config.force_ssl = true

# Ensure the CSP allows WebAuthn
Content-Security-Policy: default-src 'self'; connect-src 'self' https:
```

### 11. Documentation and operations 🟡 **MEDIUM PRIORITY**

#### 11.1 User guide

- How to register a security key.
- Supported browsers and devices.
- Troubleshooting steps.

#### 11.2 Operator guide

- Managing WebAuthn settings.
- Security monitoring points.
- Incident response procedures.

#### 11.3 Developer documentation

- API specifications.
- Database schema.
- Testing instructions.

## Prioritisation

### Phase 1: Foundation 🔴 **HIGH PRIORITY**

1. Database design and migrations.
2. Model implementation.
3. JavaScript WebAuthn API.
4. Core controller logic.

### Phase 2: Feature completion 🟡 **MEDIUM PRIORITY**

5. View implementation.
6. Error handling.
7. Tests.
8. Multi-domain verification.

### Phase 3: Production readiness 🔴 **HIGH PRIORITY**

9. Production environment configuration.
10. Security integration.
11. Documentation.

## Estimated Effort

- **Phase 1**: 3–4 person-days.
- **Phase 2**: 2–3 person-days.
- **Phase 3**: 1–2 person-days.
- **Total**: 6–9 person-days.

## Notes

### Security considerations

- Manage WebAuthn challenges carefully.
- Prevent replay attacks via sign_count validation.
- Operate exclusively over HTTPS.
- Handle cross-origin configuration with caution.

### Compatibility with existing systems

- Coexist with TOTP and passcode flows.
- Integrate with the session management layer.
- Ensure alignment with the multi-domain architecture.

Following this task list step by step will deliver a secure and user-friendly FIDO2 security key
experience.
