# typed: false
# frozen_string_literal: true

class AnalyticsConsentGuard
  # Prepended module that guards ActiveSupport::EventReporter#notify.
  module EventReporterPatch
    def notify(name, ...)
      unless AnalyticsConsentGuard.permit?(name)
        Rails.logger.debug { "[AnalyticsConsentGuard] Dropped event '#{name}' (missing performant consent)" }
        return
      end

      super
    end
  end

  # Returns true if the event may be emitted given the current preference.
  #
  # Rules:
  # - Events in {PreConsentAllowlist} are always permitted.
  # - All other events require `performant` consent.
  # - Product analytics and marketing analytics remain disabled when
  #   `performant` consent is missing.
  #
  # @param event_name [String, Symbol] the event name
  # @param preference [Actor::Preference] the resolved preference (defaults to Actor.preferences)
  # @return [Boolean]
  def self.permit?(event_name, preference: Actor.preference)
    return true if PreConsentAllowlist.allowed?(event_name)

    preference&.cookie&.performant? || false
  end
end
