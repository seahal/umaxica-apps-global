# Authentication / Authorization Requirements Specification (Phase 1)

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

### Available methods

- Email (OTP)
- Telephone (SMS OTP)
- Passkey
- Secret
- Google social login
- Apple social login

### Basic policy for authentication methods

- Email / Telephone / Secret must not be updated in place
- Changes must be handled as "delete + add new"
- Passkey is the exception; only the display name may be changed
- Social login (Google / Apple) is limited to linking and unlinking

## 4. Sign-in Requirements

### Passkey sign-in

Passkey sign-in requires all three of the following:

- PII (Email or Telephone)
- Passkey authentication
- Cloudflare Turnstile (stealth / hidden)

### Google / Apple sign-in

- Turnstile is not used
- Even when MFA is required, the flow does not transition to an additional challenge

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

- Unlinking is allowed only if at least one other login method remains available

### Passkey

If removing all passkeys, at least one of the following must exist:

- Email
- Google
- Apple

Secret is not counted in this condition.

### Secret

- In principle, it may be removed
- Do not create a state where login is possible only through Secret after removal

### Email / Telephone (contact methods)

Email and Telephone are treated as contact methods.

The system must prevent transitions where the total number of Email + Telephone methods goes from 1
or more to 0.

#### Email deletion conditions

- At least one Telephone exists, and
- At least one of Passkey / Google / Apple exists

#### Telephone deletion conditions

- At least one Email exists

## 8. Activity Display (`/configuration/activity`)

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
