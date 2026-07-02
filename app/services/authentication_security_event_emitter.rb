# typed: false
# frozen_string_literal: true

# Emits authentication security events through the repository log transport.
#
# This is not a durable audit store. It is the current taxonomy and redaction
# seam for auth events until a retained audit backend is accepted.
class AuthenticationSecurityEventEmitter
  EVENTS = %w(
    sign_in.success
    sign_in.failure
    sign_up.success
    sign_up.failure
    sign_out.success
    passkey.used
    passkey.failed
    totp.failed
    recovery.used
    social.callback_failure
    entra.callback_failure
    ceremony.cleanup
    rate_limit.exceeded
    csrf.failure
    authorization.failure
    session.max_exceeded
    logout.forced
    policy.changed
  ).freeze

  def self.emit(event_type, **payload)
    raise ArgumentError, "unknown authentication security event: #{event_type}" unless EVENTS.include?(event_type)

    Rails.logger.info(
      JitLogEvent.format(
        "authentication.security_event",
        event_type: event_type,
        severity: payload.delete(:severity) || "info",
        **payload,
      ),
    )
  end
end
