# typed: false
# frozen_string_literal: true

module ExternalAuthenticationEndpoint
  extend ActiveSupport::Concern

  CEREMONY_REFERENCE_SESSION_KEY = :external_authentication_ceremony_reference

  private

  def external_authentication_allowed?(surface:, provider:, operation:)
    ExternalAuthentication::ProviderSurfacePolicy.new.allowed?(surface: surface, provider: provider, operation: operation)
  end

  def external_authentication_start_available?(provider:, operation:, context:)
    decision = ExternalAuthentication::ProviderAvailabilityFactory.current
      .start_decision(provider: provider, operation: operation, context: context)
    decision.state == :enabled
  rescue ExternalAuthentication::EnvironmentProviderAvailabilityAdapter::ConfigurationError, KeyError
    false
  end

  def external_authentication_callback_available?(provider:, ceremony:, context:)
    decision = ExternalAuthentication::ProviderAvailabilityFactory.current
      .callback_decision(provider: provider, ceremony: ceremony, context: context)
    %i(enabled draining).include?(decision.state)
  rescue ExternalAuthentication::EnvironmentProviderAvailabilityAdapter::ConfigurationError, KeyError
    false
  end

  def external_authentication_method_locked?(enforcement_case_class:, principal_public_id:, authentication_method:)
    ExternalAuthentication::AuthenticationMethodLockPolicy.new.locked?(
      enforcement_case_class: enforcement_case_class,
      principal_public_id: principal_public_id,
      authentication_method: authentication_method,
    )
  end

  def store_external_authentication_ceremony_reference(reference)
    session[CEREMONY_REFERENCE_SESSION_KEY] = reference
  end

  def consume_external_authentication_ceremony_reference
    session.delete(CEREMONY_REFERENCE_SESSION_KEY)
  end
end
