# typed: false
# frozen_string_literal: true

# Decides whether a Turnstile verification that failed because Cloudflare was unreachable
# may be treated as a pass.
#
# The flag is not "skip Turnstile". It only applies to a result the verifier marked
# `unavailable` (a transport or upstream failure), so a visitor who actually fails the
# challenge, or a request with no token at all, is still rejected while the flag is on.
# A missing secret key is configuration, not an outage, and is likewise never degraded.
#
# Default off: the flag exists so that a Cloudflare incident does not close sign-in, and
# it is expected to be turned on for the duration of an incident and turned back off.
class TurnstileDegradation
  FEATURE_NAME = :turnstile_degraded_mode

  def self.apply(result, flipper: Flipper)
    new(flipper: flipper).apply(result)
  end

  def initialize(flipper: Flipper)
    @flipper = flipper
  end

  def apply(result)
    return result if result["success"]
    return result unless result["unavailable"]
    return result unless FeatureFlags.enabled?(FEATURE_NAME, flipper: @flipper)

    # Telemetry only. The durable record that degraded mode was in force is the feature
    # flag row itself; this line ties an individual request to it.
    Rails.logger.warn(JitLogEvent.format("turnstile.degraded", error: result["error"]))
    { "success" => true, "degraded" => true }
  end
end
