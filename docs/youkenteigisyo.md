It's similar to phase 1, but please merge it. > Authentication/authorization system requirements
definition document (Phase 1)

1. Purpose/background

The purpose of this system is to provide users with secure and flexible authentication and
authorization functions, while also allowing users to understand and manage their own security
status, login history, and withdrawal status.

Particular emphasis will be placed on the following:

High security by combining multiple authentication methods

Designed to prevent lockout

User-driven security management

Consideration for privacy and GDPR, etc.

2. Target range

Authentication/authorization/setting functions for users

Sign up/Sign in

Session management

Logout

Adding/deleting authentication methods

Activity confirmation

Withdrawal/reinstatement/anonymization

Not applicable

User-selected withdrawal processing by staff

Audit for administrators/SIEM collaboration

Detailed definition of legal requirements (retention period, etc.)

3. Authentication Methods: Available authentication methods

Email (OTP)

Telephone (SMS OTP)

Passkey

Passcode

Google Social Login (app/org only)

Apple social login (app only)

Scope of use of Social Login

app: Allow Google / Apple

org: allow Google, deny Apple

com: Reject both Google/Apple

Basic policy for authentication methods

Email / Telephone / Passcode values ​​will not be updated (overwritten)

Changes can be made using "Delete + Add new"

Passkey is an exception and only the display name can be changed.

Social Login (Google/Apple) can only be linked/unlocked

4. Sign-in requirements Passkey sign-in

All three elements below are required for sign-in using Passkey.

PII (Email or Telephone)

Authentication with Passkey

Cloudflare Turnstile (stealth/hidden)

Google/Apple sign in

Don't use Turnstile

MFA Does not transition to additional challenge even in request state

Apple sign-in should only be available on apps, denied on org/com

Google Sign-in should be available on app/org and denied on com

5. Session management requirements Number of concurrent sessions

Maximum number of sessions on model: 3

Number of sessions normally available at the same time: 2

session state

The third session is isolated

Login is successful, but pages that require login cannot be accessed

Creation of the fourth session is rejected at the time of login.

Session management screen

Show only active sessions

Current session cannot be deleted

Only other sessions can be revoked (Refresh Token invalidation)

6. Logout requirements

The Refresh Token for the session will be expired by logging out.

Since the Access Token cannot be immediately revoked, future access is denied with a status check.

7. Authentication method deletion/cancellation rules Social Login (Google/Apple)

Cancellation is possible only if there is at least one way to log in even after cancellation.

When canceling, the Social Login linkage record will be physically deleted immediately.

Record cancellation history in activity

Passkey

When deleting all, one of the following must exist

Email

Google

Apple

Do not include Passcode as a condition

Passcode

Can be deleted in principle

Do not create a state where you can log in with only a Passcode after deletion

Email/Telephone (Method of contact)

Treat email and telephone as means of communication

Prohibit transitions where the sum of Email + Telephone becomes "1 or more → 0" as a result of the
operation

Email all deletion conditions

There is at least one Telephone and

Passkey / Google / Apple exists

Telephone all deletion conditions

1 or more emails exist

8. Activity display (/configuration/activity) purpose

Users can check their own login history and operation history

Ability to detect suspicious logins early

Display contents (minimum)

date and time

Event type (login/logout/session expired, etc.)

Login method

Terminal/browser overview

IP (partial mask)

9. Withdrawal requirements basic policy

Can only be executed by the user himself

Immediate suspension (unavailability)

Possible return period is 31 days (required)

Status after withdrawal

You can return for 31 days after canceling your membership.

No return after 31 days

Purge (anonymization)

No physical deletion

Anonymize personal information Logical deletion

Executed by batch processing

Execution timing is approximately within 32 days after 31 days have passed.

Forced anonymization

Exceptionally, it can be executed without waiting for 31 days.

Execution using batch processing

UI will not be provided in Phase 1

10. Non-functional requirements (excerpt)

security

Lockout prevention

High-risk operations require ReAuth

privacy

Minimal log retention

Anonymization considering GDPR etc.

availability

Allow multiple sessions

11. Undecided matters (after Phase 2)

Specific implementation of unrecoverable flag

Automatic activity anomaly detection

Detailed granularity of anonymization

Log retention period
