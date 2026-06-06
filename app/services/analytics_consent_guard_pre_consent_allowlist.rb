# typed: false
# frozen_string_literal: true

# Defines the exact event name patterns that may be emitted before
# optional `performant` analytics consent is granted.
#
# These patterns are retained for future consent-aware analytics work.
# Application logging no longer uses Rails.event.
module AnalyticsConsentGuardPreConsentAllowlist
  # Authentication, authorization, session, and identity events.
  # Rationale: required for service delivery, fraud detection, and audit.
  AUTH_EVENTS = [
    /\Aauth\./,
    /\Aauthentication\./,
    /\Aauthorization\./,
    /\Asession\./,
    /\Asocial_auth\./,
    /\Asign\.social\.omniauth/,
    /\Asign\.social\.org\.omniauth/,
    /\Auser\.token\./,
    /\Astaff\.token\./,
    /\Auser\.occurrence\./,
    /\Astaff\.occurrence\./,
    /\Aotp\./,
    /\Awebauthn\./,
    /\Asign\.webauthn\./,
  ].freeze

  # Security, anti-abuse, and anti-fraud events.
  # Rationale: required for abuse prevention and platform integrity.
  SECURITY_EVENTS = [
    /\Arate_limit\./,
    /\Atelephone\.verification\.rate_limited/,
    /\Aturnstile\./,
    /\Acaptcha\./,
    /\Asecurity\./,
    /\Aredirect\.(blocked|invalid_url)/,
    /\Asign\.risk\./,
  ].freeze

  # Incident response, health check, and critical failure events.
  # Rationale: required for reliability, incident response, and debugging.
  INCIDENT_EVENTS = [
    /\Ahealth_check\./,
    /\Aexception\./,
    /\Aunhandled_exception/,
    /\Aerror\.unhandled/,
    /\Apreference\..*\.error/,
    /\Apreference\..*\.rotation_error/,
  ].freeze

  # Contact form delivery events.
  # Rationale: required to confirm delivery of user-initiated contact.
  CONTACT_EVENTS = [
    /\Acontact\.submission\./,
  ].freeze

  ALLOWED = (AUTH_EVENTS + SECURITY_EVENTS + INCIDENT_EVENTS + CONTACT_EVENTS).freeze

  def self.allowed?(event_name)
    return false if event_name.nil? || event_name.to_s.empty?

    ALLOWED.any? { |pattern| pattern.match?(event_name.to_s) }
  end
end
