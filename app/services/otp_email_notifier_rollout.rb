# typed: false
# frozen_string_literal: true

# Migration switch that moves OTP email delivery from OtpEmailAdapter to the
# Noticed notifiers, one trust boundary at a time.
#
# Polarity is deliberately opt-in, the opposite of OutboundChannelSuspension and
# SignUpSuspension: the feature names the *new* path, so an unset feature, an
# unwritten flag store, or an unreachable one all keep production on the shipped
# OtpEmailAdapter. Losing a suspension flag must not take the product down;
# losing this one must not silently move live OTP traffic onto new code. A
# stalled rollout is the acceptable failure here.
#
# The surface segment is spelled out per entry for the same reason
# SignUpSuspension spells its own out: an operator reading the Flipper UI must
# see which surface a switch moves without cross-referencing this file. Rolling
# out `app` must not be able to move `org` traffic.
#
# This class is temporary. It is deleted together with OtpEmailAdapter and
# OtpEmailNotifierAdapter once every surface has baked on the notifier path and
# the call sites address the notifiers directly.
class OtpEmailNotifierRollout
  SURFACE_FEATURE_NAMES = {
    app: :otp_email_notifier_app,
    com: :otp_email_notifier_com,
    org: :otp_email_notifier_org,
  }.freeze

  def self.enabled?(surface, flipper: Flipper)
    new(flipper: flipper).enabled?(surface)
  end

  def initialize(flipper: Flipper)
    @flipper = flipper
  end

  def enabled?(surface)
    feature_name =
      SURFACE_FEATURE_NAMES.fetch(surface.to_sym) do
        raise ArgumentError, "unsupported otp email surface: #{surface}"
      end

    FeatureFlags.enabled?(feature_name, flipper: @flipper)
  end
end
