# GH-266: Set Up Permissions-Policy

GitHub: #266

## Summary

Configure the `Permissions-Policy` HTTP response header to restrict browser feature access (camera,
microphone, geolocation, payment, etc.) across all surfaces.

## Scope

- Define the policy based on features actually used by the application.
- Add the header via Rails middleware or initializer configuration.
- Verify the header is present in responses for all domains (app, org, com).
- Restrict unused features (e.g., `camera=(), microphone=(), payment=(), geolocation=()`).
- Allow features that the application may need (e.g., `publickey-credentials-get` for WebAuthn).

## Related

- GH-231: Configure CSP in Rails.

## Implementation Status (2026-04-07)

**Status: COMPLETE**

`config/initializers/permissions_policy.rb` configured with: accelerometer, camera, geolocation,
gyroscope, magnetometer, microphone, midi, usb set to `:none`. `publickey-credentials-get` and
`publickey-credentials-create` set to `:self` for WebAuthn. This issue can be closed.

## Improvement Points (2026-04-07 Review)

- Add the exact header owner and insertion point. Without that, the task still reads like policy
  advice instead of an implementation plan.
- Add a feature matrix that marks required, denied, and intentionally omitted directives so review
  can distinguish security hardening from accidental breakage.
