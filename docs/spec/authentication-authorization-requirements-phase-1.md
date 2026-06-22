# Authentication / Authorization Requirements Specification (Phase 1)

> **Deprecated / partially superseded by Identity Authority inversion:** `acme/www` is the Session,
> Token, Account, Preference, Authorization, and downstream-token Authority. `sign/id` is
> ceremony-only: it may host credential entry points and execute delegated credential ceremonies,
> but it must not own sessions, refresh tokens, preference writes, dashboards, account lifecycle,
> token issuance, logout, or step-up freshness. Existing sign-side physical tables/models do not
> imply sign-side authority. Do not use this document to reintroduce sign-side sessions, refresh,
> preference, dashboard, account lifecycle, token issuance, logout, or step-up freshness.

## 1. Purpose and Background

This system aims to provide users with safe and flexible authentication and authorization features,
while also allowing users to understand and manage their own security status, login history, and
withdrawal status.

The following points are especially important:

- High security through multiple authentication methods
- A design that avoids lockouts
- User-led security management
- Privacy and GDPR considerations

## 2. Scope

### In scope

- User authentication, authorization, and settings
- Sign-up / sign-in
- Session management
- Logout
- Add or remove authentication methods
- Activity review
- Withdrawal, restoration, and anonymization

### Out of scope

- Staff-driven user-selected withdrawal processing
- Administrative auditing and SIEM integration
- Detailed legal requirements such as retention periods

## 3. Authentication Methods

### Available methods and entry points

- Email (OTP)
- Passkey
- TOTP (`app`)
- Passcode
- Google social login (`app` and `org` only)
- Apple social login (`app` only)

Telephone (SMS OTP) is a sign-in or sign-up entry point and contact identifier. It is not itself an
AAL authentication method. Knowing the telephone number may identify the actor and route them to an
actual verifier such as TOTP, passcode, or passkey.

Email address, telephone number, Google identity, and Apple identity are personal identifiers. Email
address and telephone number are also contact identifiers. A sign-in flow that requires a personal
identifier must require both the identifier and an AAL1 verifier; knowing only the identifier, or
knowing only the verifier without the required identifier, must not complete login.

Email address is not an AAL method by itself. Email functions as AAL1 or AAL2 only when email OTP
verification succeeds.

Social login provider availability is surface-specific:

| Surface | Google   | Apple    |
| ------- | -------- | -------- |
| `app`   | Allowed  | Allowed  |
| `org`   | Allowed  | Rejected |
| `com`   | Rejected | Rejected |

### Basic policy for authentication methods

- Email / Telephone / Passcode must not be updated in place
- Changes must be handled as "delete + add new"
- Passkey is the exception; only the display name may be changed
- Social login (Google / Apple) can be used for sign-in/sign-up on supported surfaces and can be
  linked or unlinked through credential management

### Duplicate sign-up policy

Email and telephone sign-up must distinguish incomplete OTP verification from completed
registration.

- A record in `UNVERIFIED_WITH_SIGN_UP` is the only sign-up record eligible for re-registration
  overwrite.
- If that unverified record is still inside the re-registration overwrite window, the new sign-up
  attempt is rejected with the OTP resend/cooldown response and must not send a new OTP.
- If that unverified record is outside the overwrite window, the pending record and its pending
  account may be replaced and a fresh OTP may be issued.
- A completed or otherwise already-registered identifier, including `VERIFIED` and
  `VERIFIED_WITH_SIGN_UP`, must not receive a new sign-up OTP and must not create or reuse sign-up
  account artifacts. The sign-up create response must remain indistinguishable from a normal valid
  submission by redirecting to the OTP entry step with the same visible copy. Submitted OTPs for that
  dummy flow must fail with the normal invalid-code feedback.

## 4. Sign-in Requirements

### Passkey sign-in

Passkey sign-in requires all three of the following:

- PII (Email or Telephone)
- Passkey authentication
- Cloudflare Turnstile (stealth / hidden)

### Google / Apple sign-in

- Turnstile is not used
- Even when MFA is required, the flow does not transition to an additional challenge
- Apple sign-in is available only on `app`; `org` and `com` must reject it.
- Google sign-in is available on `app` and `org`; `com` must reject it.

## 5. Session Management Requirements

### Concurrent session count

- Maximum session count in the model: 3
- Normally usable concurrent sessions: 2

### Session states

- The third session is isolated
- Login succeeds, but login-required pages cannot be accessed
- The fourth session creation is rejected at login time

### Session management screen

- Show active sessions only
- The current session cannot be deleted
- Only other sessions can be invalidated (refresh token invalidation)

## 6. Logout Requirements

- Logout invalidates the refresh token for the session
- Access tokens cannot be invalidated immediately, so subsequent access must be denied through state
  checks

## 7. Rules for Removing or Unlinking Authentication Methods

### Social Login (Google / Apple)

- Unlinking is allowed only if at least one other social-unlink-safe sign-in method remains
  available after removal.
- For `app`, social-unlink-safe sign-in methods are verified email OTP, active passkey, active
  Google social, and active Apple social.
- Passcode is not counted for the social unlink no-lockout guard.
- Unlinking requires recent AAL2 step-up and Cloudflare Turnstile validation before the destructive
  request is executed.
- Unlinking physically deletes the linked social identity immediately
- Each unlink writes a `SOCIAL_UNLINKED` activity entry

### Passkey

If removing all passkeys, at least one of the following must exist:

- Email
- Google
- Apple

Passcode is not counted in this condition.

### Passcode

- In principle, it may be removed
- Do not create a state where login is possible only through passcode after removal

### Email / Telephone (contact methods)

Email and Telephone are treated as contact methods.

The system must prevent transitions where the total number of Email + Telephone methods goes from 1
or more to 0.

#### Email deletion conditions

- At least one Telephone exists, and
- At least one of Passkey / Google / Apple exists

#### Telephone deletion conditions

- At least one Email exists

## 8. Activity Display (`/settings/activity`)

### Purpose

- Let users review their login history and action history
- Help users detect suspicious logins early

### Minimum displayed information

- Date and time
- Event type (login / logout / session invalidation, etc.)
- Login method
- Device / browser summary
- IP (partially masked)

## 9. Withdrawal Requirements

### Basic policy

- Only the user themselves can perform withdrawal
- The account becomes unavailable immediately
- The restoration period is 31 days (required)

### State after withdrawal

- Restoration is possible for 31 days after withdrawal
- After 31 days, restoration is not possible

### Purging (anonymization)

- No physical deletion is performed
- Personally identifiable information is anonymized through logical deletion
- Executed by batch processing
- Timing: around 32 days after the 31-day period ends

### Forced anonymization

- May be executed exceptionally without waiting 31 days
- Executed by batch processing
- No UI will be provided in Phase 1

## 10. Non-functional Requirements (Excerpt)

### Security

- Prevent lockouts
- Require ReAuth for high-risk operations

### Privacy

- Keep logs to a minimum
- Support anonymization in consideration of GDPR and similar requirements

### Availability

- Allow multiple sessions

## 11. Open Items (Phase 2 and later)

- Concrete implementation of the non-restorable flag
- Automatic anomaly detection for activity
