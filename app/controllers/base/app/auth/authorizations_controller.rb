# typed: false
# frozen_string_literal: true

module Base
  module App
    module Auth
      class AuthorizationsController < Base::App::BareController
        include ::OidcSsoInitiator

        AUTHENTICATION_MODE = :open

        skip_before_action :set_region, raise: false

        def show
          url = initiate_oidc_session!(screen_hint: "signup")
          redirect_to(url, allow_other_host: true)
        end

        private

        def oidc_client_id
          "base-rails-rp"
        end

        def oidc_acme_host
          ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
        end
      end
    end
  end
end
