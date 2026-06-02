# Org/Com Google Social Temporary Gateway Cleanup Plan

Status: withdrawn; cleanup implemented by this work

Date: 2026-06-02

## Summary

The prior temporary Google social gateway direction for `org` and `com` is withdrawn. The production
target is now:

- `app`: Google and Apple social login remain supported.
- `org`: no social login. Staff sign-in uses a personal identifier plus local verifiers only:
  passkey, passcode, and any existing org TOTP path if present.
- `com`: no social login.

The temporary gateway is not promoted to production. This cleanup removes the temporary routes,
controllers, views, services, provider registration, environment flags, and retirement tags.

## Implemented Cleanup

- Removed the legacy org/com Google social environment flags from runtime configuration.
- Removed the org/com Google social OmniAuth registration, callback routes, social entry routes,
  temporary provisioners, gates, and callback-state mappings.
- Removed org Google sign-up/sign-in UI and org Google account linking/unlinking UI.
- Removed com Google sign-up/sign-in UI and the temporary corporate visitor gateway code.
- Kept app Google/Apple social login outside the cleanup scope.

## Production Boundary

- Do not reintroduce Google, Apple, Microsoft, or other external social providers to `org` or `com`
  without a new accepted ADR.
- Do not reintroduce temporary gateway flags or retirement tags.
- A future schema cleanup for historical org/com social tables requires a separate migration plan
  and explicit approval.

## Verification

- Org signup/signin pages must not render Google social controls, even if legacy environment
  variables are present.
- Com signup/signin pages must not render Google social controls.
- Direct org/com Google social routes must be absent or return not found.
- App Google/Apple social login tests must continue to pass.
- Static checks must show no runtime org/com Google social flags, provider IDs, or temporary gateway
  tags.
