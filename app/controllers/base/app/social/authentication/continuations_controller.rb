# typed: false
# frozen_string_literal: true

module Base
  module App
    module Social
      module Authentication
        # POST /social/authentication/continuation
        # Issues a login ceremony grant and hands the browser to the Auth
        # host's social ceremony endpoint.
        #
        # The handoff is a 307 rather than a 303: the Auth ceremony accepts POST
        # only, because a GET entry could be triggered by a link and would be
        # login CSRF. 307 preserves the method, and the two hosts are same-site,
        # so Auth verifies the forwarded request the same way it verifies its own
        # buttons.
        class ContinuationsController < ::Base::App::ApplicationController
          include SocialCeremonyParams

          AUTHENTICATION_MODE = :open
          declare_authentication_mode! :open

          def create
            provider = social_provider_param
            issuance = IdentitySocialCeremonyGrantIssuer.issue!(
              surface: "app",
              actor_ref: "anonymous",
              session_ref: SecureRandom.hex(24),
              operation: "login",
              provider: provider,
              resource_ref: social_entry_param,
              return_to: safe_social_return_to(params[:pt].presence),
            )

            redirect_to(
              social_sign_in_url_for(
                provider,
                entry: social_entry_param,
                ri: params[:ri],
                social_ceremony_grant: issuance.grant,
                host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
              ),
              status: :temporary_redirect,
              allow_other_host: cross_host_redirect_allowed?,
            )
          end

          private

          def social_sign_in_url_for(provider, **params)
            normalized_provider = SocialIdentifiable.normalize_provider(provider)
            public_send(:"auth_app_social_#{normalized_provider}_session_url", **params)
          end
        end
      end
    end
  end
end
