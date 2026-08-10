# typed: false
# frozen_string_literal: true

# Runtime kill switch that closes new-user registration on one trust boundary.
#
# Polarity matches OutboundChannelSuspension: the feature names a *suspension*,
# so an unset or never-written feature means registration is open. A flag store
# that has never been written must not take sign-up down.
#
# The surface segment is spelled out per entry instead of being interpolated
# from the surface symbol, for the same reason
# ExternalAuthentication::FlipperProviderAvailabilityAdapter spells out its
# provider map: an operator reading the Flipper UI must see which surface a
# switch closes without cross-referencing this file.
#
# Sign-in is deliberately out of scope -- suspending registration must not lock
# existing users out -- and this switch is independent of the outbound email and
# SMS suspensions.
class SignUpSuspension
  SURFACE_FEATURE_NAMES = {
    app: :sign_up_suspended_app,
    com: :sign_up_suspended_com,
    org: :sign_up_suspended_org,
  }.freeze

  def self.suspended?(surface, flipper: Flipper)
    new(flipper: flipper).suspended?(surface)
  end

  def initialize(flipper: Flipper)
    @flipper = flipper
  end

  def suspended?(surface)
    feature_name =
      SURFACE_FEATURE_NAMES.fetch(surface.to_sym) do
        raise ArgumentError, "unsupported sign up surface: #{surface}"
      end

    FeatureFlags.enabled?(feature_name, flipper: @flipper)
  end
end
