# typed: false
# frozen_string_literal: true

module ExternalAuthentication
  # Decides whether an external authentication provider may be used.
  #
  # Invoked through ExternalAuthenticationEndpoint#external_authentication_start_available?
  # and #external_authentication_callback_available? (app/controllers/concerns/external_authentication_endpoint.rb),
  # which call ProviderAvailabilityFactory.current.start_decision / .callback_decision.
  # The org Entra ceremony gates on these before issuing ceremony state
  # (Auth::Org::Sign::In::Entra::AuthorizationsController#create) and before
  # processing a callback (Auth::Org::Sign::In::Entra::CallbacksController#show),
  # so the ENTRA_SOCIAL_CEREMONY_ENABLED kill switch is operational today.
  module ProviderAvailabilityPort
    def start_decision(provider:, operation:, context:)
      raise NotImplementedError
    end

    def callback_decision(provider:, ceremony:, context:)
      raise NotImplementedError
    end
  end
end
