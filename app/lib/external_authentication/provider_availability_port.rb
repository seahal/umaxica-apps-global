# typed: false
# frozen_string_literal: true

module ExternalAuthentication
  # Decides whether an external authentication provider may be used.
  #
  # Invoked through ExternalAuthenticationEndpoint#external_authentication_start_available?
  # and #external_authentication_callback_available? (app/controllers/concerns/external_authentication_endpoint.rb),
  # which call ProviderAvailabilityFactory.current.start_decision / .callback_decision.
  # The org Entra OmniAuth strategy gates on these before redirecting to
  # Microsoft (OmniAuth::Strategies::UmaxicaEntra#request_phase,
  # lib/omniauth/strategies/umaxica_entra.rb) and before processing a
  # callback (Auth::Org::Omniauth::OmniauthCallbacksController#omniauth),
  # so the :social_ceremony_org_entra Flipper kill switch is operational today.
  module ProviderAvailabilityPort
    def start_decision(provider:, operation:, context:)
      raise NotImplementedError
    end

    def callback_decision(provider:, ceremony:, context:)
      raise NotImplementedError
    end
  end
end
